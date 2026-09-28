import 'package:flutter/foundation.dart';

import '../engine/cue_engine.dart';
import '../models/cue_step.dart';
import '../models/ids.dart';
import '../models/show.dart';
import '../osc/osc_codec.dart';
import '../osc/osc_message.dart';
import '../osc/x32.dart';
import '../storage/show_repository.dart';
import '../transport/osc_transport.dart';
import 'log_entry.dart';

class ShowController extends ChangeNotifier {
  ShowController({
    required this.repository,
    required this.transport,
    DelayFn? delay,
  }) : _runner = CueRunner(delay: delay);

  final ShowRepository repository;
  final OscTransport transport;
  final CueRunner _runner;

  ShowData show = ShowData.seed();
  int standby = 0;
  String? runningCueId;
  bool probing = false;
  final List<OscLogEntry> log = [];
  final CommandedState commanded = CommandedState();
  CommandedState? panicSnapshot;
  bool panicked = false;

  int _serial = 0;
  bool _ready = false;

  bool get ready => _ready;

  Cue? get standbyCue {
    if (show.cues.isEmpty) return null;
    final index = standby.clamp(0, show.cues.length - 1);
    return show.cues[index];
  }

  bool get canGo => show.cues.isNotEmpty;

  bool get canRestore => panicSnapshot != null && !panicSnapshot!.isEmpty;

  Future<void> load() async {
    final stored = await repository.load();
    if (stored == null) {
      show = ShowData.seed();
      await repository.save(show);
    } else {
      show = stored;
    }
    standby = 0;
    _ready = true;
    notifyListeners();
  }

  void select(int index) {
    if (index < 0 || index >= show.cues.length) return;
    standby = index;
    notifyListeners();
  }

  Cue addCue() {
    final cue = Cue(
      id: newId('cue'),
      name: 'New cue',
      autoFollow: false,
      steps: [],
    );
    final insertAt = show.cues.isEmpty
        ? 0
        : (standby.clamp(0, show.cues.length - 1) + 1);
    show.cues.insert(insertAt, cue);
    standby = insertAt;
    notifyListeners();
    _persist();
    return cue;
  }

  void updateCue(Cue cue) {
    final index = show.cues.indexWhere((item) => item.id == cue.id);
    if (index < 0) return;
    show.cues[index] = cue;
    notifyListeners();
    _persist();
  }

  void deleteCue(String id) {
    final index = show.cues.indexWhere((item) => item.id == id);
    if (index < 0) return;
    show.cues.removeAt(index);
    if (show.cues.isEmpty) {
      standby = 0;
    } else if (index < standby) {
      standby -= 1;
    } else if (standby >= show.cues.length) {
      standby = show.cues.length - 1;
    }
    notifyListeners();
    _persist();
  }

  void reorderCues(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= show.cues.length ||
        newIndex < 0 ||
        newIndex >= show.cues.length) {
      return;
    }
    final cue = show.cues.removeAt(oldIndex);
    show.cues.insert(newIndex, cue);
    if (standby == oldIndex) {
      standby = newIndex;
    } else if (oldIndex < standby && newIndex >= standby) {
      standby -= 1;
    } else if (oldIndex > standby && newIndex <= standby) {
      standby += 1;
    }
    notifyListeners();
    _persist();
  }

  void setChannelName(int channel, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      show.channelNames.remove(channel);
    } else {
      show.channelNames[channel] = trimmed;
    }
    notifyListeners();
    _persist();
  }

  void updateSettings(ConsoleSettings settings) {
    show = show.copyWith(settings: settings);
    notifyListeners();
    _persist();
  }

  Future<void> resetExampleShow() async {
    final settings = show.settings;
    show = ShowData.seed().copyWith(settings: settings);
    standby = 0;
    notifyListeners();
    await _persist();
  }

  void stop() {
    _cancelRun();
    _push(
      OscLogEntry.note(
        'Stopped. The cue in progress and auto-follow were cancelled.',
      ),
    );
    notifyListeners();
  }

  Future<void> go() async {
    if (!_ready || show.cues.isEmpty) return;
    if (!_guardLive(action: 'GO')) return;
    final serial = ++_serial;
    while (serial == _serial) {
      if (show.cues.isEmpty) return;
      final index = standby.clamp(0, show.cues.length - 1);
      final cue = show.cues[index];
      final hasNext = index + 1 < show.cues.length;
      runningCueId = cue.id;
      if (hasNext) standby = index + 1;
      notifyListeners();
      final status = await _runner.run(
        steps: List<CueStep>.of(cue.steps),
        send: _emit,
        onNote: (text) {
          _push(
            OscLogEntry(
              at: DateTime.now(),
              title: text,
              detail: '',
              dryRun: show.settings.dryRun,
              ok: true,
            ),
          );
          notifyListeners();
        },
      );
      if (serial != _serial) return;
      runningCueId = null;
      notifyListeners();
      if (status == RunStatus.failed) {
        _push(
          OscLogEntry.error(
            'Cue "${cue.name}" stopped. A packet did not send.',
          ),
        );
        notifyListeners();
        return;
      }
      if (status != RunStatus.completed || !cue.autoFollow || !hasNext) return;
    }
  }

  Future<void> allMute() async {
    _cancelRun();
    notifyListeners();
    if (!_guardLive(action: 'ALL MUTE')) return;
    if (!show.settings.dryRun && !panicked) {
      panicSnapshot = commanded.clone();
      panicked = true;
    }
    for (final message in X32.allInputMutes()) {
      try {
        await _emit(message);
      } catch (_) {
        _push(
          OscLogEntry.error(
            'ALL MUTE stopped early. Hit it again, or check the IP.',
          ),
        );
        notifyListeners();
        return;
      }
    }
    _push(
      OscLogEntry.note(
        show.settings.dryRun
            ? 'ALL MUTE logged ${X32.channelCount} input mutes. Nothing was sent.'
            : 'ALL MUTE sent. Inputs 1–${X32.channelCount} commanded off. Main, buses, and DCAs were not touched.',
      ),
    );
    notifyListeners();
  }

  Future<void> restore() async {
    final snapshot = panicSnapshot;
    if (snapshot == null || snapshot.isEmpty) {
      _push(
        OscLogEntry.error(
          'Nothing to restore. Fire a cue while live, then ALL MUTE. Restore replays what this phone sent.',
        ),
      );
      notifyListeners();
      return;
    }
    _cancelRun();
    notifyListeners();
    if (!_guardLive(action: 'Restore')) return;
    for (final message in messagesForState(snapshot)) {
      try {
        await _emit(message);
      } catch (_) {
        _push(OscLogEntry.error('Restore stopped early.'));
        notifyListeners();
        return;
      }
    }
    if (!show.settings.dryRun) panicked = false;
    _push(
      OscLogEntry.note(
        show.settings.dryRun
            ? 'Restore logged the pre-panic state. Nothing was sent.'
            : 'Restore sent the pre-panic mutes and levels.',
      ),
    );
    notifyListeners();
  }

  Future<void> probe() async {
    if (!transport.canSend) {
      _push(
        OscLogEntry.error(
          'This build has no UDP socket. Use the Android app to reach the X32.',
        ),
      );
      notifyListeners();
      return;
    }
    final host = show.settings.host.trim();
    if (host.isEmpty) {
      _push(
        OscLogEntry.error('Enter the X32 IP before testing the connection.'),
      );
      notifyListeners();
      return;
    }
    probing = true;
    notifyListeners();
    try {
      final result = await transport.probe(_endpoint());
      _push(
        OscLogEntry(
          at: DateTime.now(),
          title: result.gotReply
              ? 'Console replied to /info'
              : 'No reply to /info',
          detail: result.message,
          dryRun: false,
          ok: result.gotReply,
        ),
      );
    } catch (error) {
      _push(OscLogEntry.error('Connection test failed.', detail: '$error'));
    } finally {
      probing = false;
      notifyListeners();
    }
  }

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  ConsoleEndpoint _endpoint() {
    return ConsoleEndpoint(
      host: show.settings.host.trim(),
      port: show.settings.port,
      localPort: show.settings.localPort,
    );
  }

  bool _guardLive({required String action}) {
    if (show.settings.dryRun) return true;
    if (!transport.canSend) {
      _push(
        OscLogEntry.error(
          '$action was not sent. This build has no UDP socket.',
        ),
      );
      notifyListeners();
      return false;
    }
    if (show.settings.host.trim().isEmpty) {
      _push(
        OscLogEntry.error('$action was not sent. Enter the X32 IP in Setup.'),
      );
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> _emit(OscMessage message) async {
    final bytes = OscCodec.encode(message);
    final title = _titleFor(message);
    final detail = '${message.describe()}\n${hexDump(bytes)}';
    if (show.settings.dryRun) {
      _push(
        OscLogEntry(
          at: DateTime.now(),
          title: title,
          detail: detail,
          dryRun: true,
          ok: true,
        ),
      );
      notifyListeners();
      return;
    }
    if (!_guardLive(action: title)) {
      throw StateError('not sent');
    }
    try {
      await transport.send(bytes, _endpoint());
    } catch (error) {
      _push(OscLogEntry.error(title, detail: '$error\n$detail'));
      notifyListeners();
      rethrow;
    }
    rememberCommand(commanded, message);
    _push(
      OscLogEntry(
        at: DateTime.now(),
        title: title,
        detail: detail,
        dryRun: false,
        ok: true,
      ),
    );
    notifyListeners();
  }

  String _titleFor(OscMessage message) {
    final on = RegExp(r'^/ch/(\d{1,2})/mix/on$').firstMatch(message.address);
    if (on != null && message.args.isNotEmpty) {
      final bit = message.args.first.type == OscArgType.int32
          ? message.args.first.asInt
          : null;
      final verb = bit == 0 ? 'MUTE' : 'UNMUTE';
      return '$verb  ${show.labelFor(int.parse(on.group(1)!))}';
    }
    final fader = RegExp(r'^/ch/(\d{1,2})/mix/fader$')
        .firstMatch(message.address);
    if (fader != null &&
        message.args.isNotEmpty &&
        message.args.first.type == OscArgType.float32) {
      final db = formatDb(unitIntervalToDb(message.args.first.asFloat));
      return 'LEVEL  ${show.labelFor(int.parse(fader.group(1)!))}  $db';
    }
    return message.describe();
  }

  void _cancelRun() {
    _serial++;
    _runner.cancel();
    runningCueId = null;
  }

  void _push(OscLogEntry entry) {
    log.insert(0, entry);
    if (log.length > 200) log.removeLast();
  }

  Future<void> _persist() async {
    try {
      await repository.save(show);
    } catch (error) {
      _push(
        OscLogEntry.error(
          'Could not save the show on this phone.',
          detail: '$error',
        ),
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _runner.cancel();
    transport.close();
    super.dispose();
  }
}
