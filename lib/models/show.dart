import '../osc/x32.dart';
import 'cue_step.dart';
import 'ids.dart';

class ConsoleSettings {
  const ConsoleSettings({
    required this.host,
    required this.port,
    required this.localPort,
    required this.dryRun,
  });

  final String host;
  final int port;
  final int? localPort;
  final bool dryRun;

  static const empty = ConsoleSettings(
    host: '',
    port: X32.port,
    localPort: null,
    dryRun: true,
  );

  ConsoleSettings copyWith({
    String? host,
    int? port,
    int? localPort,
    bool clearLocalPort = false,
    bool? dryRun,
  }) {
    return ConsoleSettings(
      host: host ?? this.host,
      port: port ?? this.port,
      localPort: clearLocalPort ? null : (localPort ?? this.localPort),
      dryRun: dryRun ?? this.dryRun,
    );
  }

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'localPort': localPort,
    'dryRun': dryRun,
  };

  factory ConsoleSettings.fromJson(Map<String, dynamic> json) {
    final port = json['port'];
    final local = json['localPort'];
    return ConsoleSettings(
      host: json['host'] is String ? (json['host'] as String).trim() : '',
      port: port is num && port >= 1 && port <= 65535 ? port.toInt() : X32.port,
      localPort: local is num && local >= 1 && local <= 65535
          ? local.toInt()
          : null,
      dryRun: json['dryRun'] is bool ? json['dryRun'] as bool : true,
    );
  }
}

class Cue {
  Cue({
    required this.id,
    required this.name,
    required this.autoFollow,
    required this.steps,
  });

  final String id;
  String name;
  bool autoFollow;
  List<CueStep> steps;

  Cue copyWith({String? name, bool? autoFollow, List<CueStep>? steps}) {
    return Cue(
      id: id,
      name: name ?? this.name,
      autoFollow: autoFollow ?? this.autoFollow,
      steps: steps ?? this.steps,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'autoFollow': autoFollow,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  factory Cue.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final steps = <CueStep>[];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item is! Map) {
          throw const FormatException('A cue step is not an object.');
        }
        steps.add(CueStep.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    final name = json['name'];
    return Cue(
      id: json['id'] is String ? json['id'] as String : newId('cue'),
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Untitled cue',
      autoFollow: json['autoFollow'] == true,
      steps: steps,
    );
  }
}

/// Last mute/level values this phone actually sent. Restore replays this.
class CommandedState {
  CommandedState({Map<int, bool>? on, Map<int, double>? fader})
    : on = on ?? <int, bool>{},
      fader = fader ?? <int, double>{};

  /// True means the channel was commanded ON (unmuted).
  final Map<int, bool> on;

  /// Console float 0–1.
  final Map<int, double> fader;

  bool get isEmpty => on.isEmpty && fader.isEmpty;

  CommandedState clone() => CommandedState(
    on: Map<int, bool>.of(on),
    fader: Map<int, double>.of(fader),
  );
}

class ShowData {
  ShowData({
    required this.settings,
    required this.channelNames,
    required this.cues,
  });

  ConsoleSettings settings;
  final Map<int, String> channelNames;
  final List<Cue> cues;

  ShowData copyWith({ConsoleSettings? settings}) {
    return ShowData(
      settings: settings ?? this.settings,
      channelNames: channelNames,
      cues: cues,
    );
  }

  String labelFor(int channel) {
    final name = channelNames[channel]?.trim();
    if (name == null || name.isEmpty) return 'Ch $channel';
    return '$name ($channel)';
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'settings': settings.toJson(),
    'channels': [
      for (final entry in channelNames.entries)
        if (entry.key >= 1 &&
            entry.key <= X32.channelCount &&
            entry.value.trim().isNotEmpty)
          {'n': entry.key, 'name': entry.value.trim()},
    ],
    'cues': cues.map((c) => c.toJson()).toList(),
  };

  factory ShowData.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw FormatException('Unsupported show version "${json['version']}".');
    }
    final settingsRaw = json['settings'];
    final settings = settingsRaw is Map
        ? ConsoleSettings.fromJson(Map<String, dynamic>.from(settingsRaw))
        : ConsoleSettings.empty;
    final names = <int, String>{};
    final channels = json['channels'];
    if (channels is List) {
      for (final item in channels) {
        if (item is! Map) continue;
        final n = item['n'];
        final name = item['name'];
        if (n is num &&
            name is String &&
            n >= 1 &&
            n <= X32.channelCount &&
            name.trim().isNotEmpty) {
          names[n.toInt()] = name.trim();
        }
      }
    }
    final cues = <Cue>[];
    final rawCues = json['cues'];
    if (rawCues is List) {
      for (final item in rawCues) {
        if (item is! Map) {
          throw const FormatException('A cue is not an object.');
        }
        cues.add(Cue.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return ShowData(settings: settings, channelNames: names, cues: cues);
  }

  /// Example Sunday patch. Levels are a starting point, not a mix.
  factory ShowData.seed() {
    return ShowData(
      settings: ConsoleSettings.empty,
      channelNames: {
        1: 'Pastor',
        2: 'Keys',
        3: 'Vocal 1',
        4: 'Vocal 2',
        5: 'Acoustic',
        6: 'Electric',
        7: 'Bass',
        8: 'Drums',
      },
      cues: [
        Cue(
          id: 'cue-worship',
          name: 'Worship team on',
          autoFollow: false,
          steps: [
            MuteStep(id: 'seed-w-mute', channels: const [1]),
            UnmuteStep(
              id: 'seed-w-unmute',
              channels: const [2, 3, 4, 5, 6, 7, 8],
            ),
            FaderStep(
              id: 'seed-w-keys',
              channel: 2,
              unit: LevelUnit.db,
              value: -6,
            ),
            FaderStep(
              id: 'seed-w-v1',
              channel: 3,
              unit: LevelUnit.db,
              value: -8,
            ),
            FaderStep(
              id: 'seed-w-v2',
              channel: 4,
              unit: LevelUnit.db,
              value: -8,
            ),
            FaderStep(
              id: 'seed-w-ag',
              channel: 5,
              unit: LevelUnit.db,
              value: -10,
            ),
            FaderStep(
              id: 'seed-w-eg',
              channel: 6,
              unit: LevelUnit.db,
              value: -10,
            ),
            FaderStep(
              id: 'seed-w-bass',
              channel: 7,
              unit: LevelUnit.db,
              value: -12,
            ),
            FaderStep(
              id: 'seed-w-drums',
              channel: 8,
              unit: LevelUnit.db,
              value: -14,
            ),
          ],
        ),
        Cue(
          id: 'cue-pastor',
          name: 'Pastor only',
          autoFollow: false,
          steps: [
            UnmuteStep(id: 'seed-p-on', channels: const [1]),
            MuteStep(id: 'seed-p-off', channels: const [2, 3, 4, 5, 6, 7, 8]),
            FaderStep(
              id: 'seed-p-level',
              channel: 1,
              unit: LevelUnit.db,
              value: 0,
            ),
          ],
        ),
        Cue(
          id: 'cue-band',
          name: 'Band + vocal',
          autoFollow: false,
          steps: [
            MuteStep(id: 'seed-b-mute', channels: const [1, 2]),
            UnmuteStep(id: 'seed-b-unmute', channels: const [3, 4, 5, 6, 7, 8]),
            FaderStep(
              id: 'seed-b-v1',
              channel: 3,
              unit: LevelUnit.db,
              value: -5,
            ),
            FaderStep(
              id: 'seed-b-v2',
              channel: 4,
              unit: LevelUnit.db,
              value: -5,
            ),
            FaderStep(
              id: 'seed-b-ag',
              channel: 5,
              unit: LevelUnit.db,
              value: -8,
            ),
            FaderStep(
              id: 'seed-b-eg',
              channel: 6,
              unit: LevelUnit.db,
              value: -8,
            ),
            FaderStep(
              id: 'seed-b-bass',
              channel: 7,
              unit: LevelUnit.db,
              value: -10,
            ),
            FaderStep(
              id: 'seed-b-drums',
              channel: 8,
              unit: LevelUnit.db,
              value: -12,
            ),
          ],
        ),
      ],
    );
  }
}
