import '../models/cue_step.dart';
import '../models/show.dart';
import '../osc/osc_message.dart';
import '../osc/x32.dart';

sealed class CueAction {}

class SendOsc extends CueAction {
  SendOsc(this.message);
  final OscMessage message;
}

class WaitAction extends CueAction {
  WaitAction(this.duration);
  final Duration duration;
}

class NoteAction extends CueAction {
  NoteAction(this.text);
  final String text;
}

/// Turns cue steps into ordered OSC sends and waits. Does not touch the network.
List<CueAction> compileStep(CueStep step) {
  switch (step) {
    case UnmuteStep(:final channels):
      return _onOff(channels, on: true, empty: 'Unmute step has no channels.');
    case MuteStep(:final channels):
      return _onOff(channels, on: false, empty: 'Mute step has no channels.');
    case FaderStep():
      return [SendOsc(X32.channelFader(step.channel, step.unitInterval))];
    case WaitStep(:final milliseconds):
      if (milliseconds < 0) return [NoteAction('Wait must be 0 ms or more.')];
      return [WaitAction(Duration(milliseconds: milliseconds))];
    case CustomOscStep(:final message):
      final address = message.address.trim();
      if (address.isEmpty || !address.startsWith('/')) {
        return [NoteAction('Custom OSC needs an address that starts with /.')];
      }
      return [SendOsc(OscMessage(address, message.args))];
  }
}

List<CueAction> compileCue(Iterable<CueStep> steps) => [
  for (final step in steps) ...compileStep(step),
];

List<CueAction> _onOff(
  List<int> channels, {
  required bool on,
  required String empty,
}) {
  if (channels.isEmpty) return [NoteAction(empty)];
  final actions = <CueAction>[];
  for (final channel in channels) {
    try {
      actions.add(SendOsc(X32.channelOn(channel, on: on)));
    } on ArgumentError catch (error) {
      actions.add(NoteAction('$error'));
    }
  }
  return actions;
}

/// Updates [state] from a message this app sent. Custom OSC that hits the
/// input mute or fader paths is included, so Restore stays honest.
void rememberCommand(CommandedState state, OscMessage message) {
  final on = RegExp(r'^/ch/(\d{1,2})/mix/on$').firstMatch(message.address);
  if (on != null && message.args.isNotEmpty) {
    final bit = _bit(message.args.first);
    if (bit != null) state.on[int.parse(on.group(1)!)] = bit != 0;
    return;
  }
  final fader = RegExp(r'^/ch/(\d{1,2})/mix/fader$')
      .firstMatch(message.address);
  if (fader != null &&
      message.args.isNotEmpty &&
      message.args.first.type == OscArgType.float32) {
    state.fader[int.parse(fader.group(1)!)] = message.args.first.asFloat
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

int? _bit(OscArg arg) {
  switch (arg.type) {
    case OscArgType.int32:
      return arg.asInt;
    case OscArgType.float32:
      return arg.asFloat.round();
    case OscArgType.string:
      return null;
  }
}

/// Fader first, then mute, channel numbers ascending. Channels this phone
/// never touched are left alone.
List<OscMessage> messagesForState(CommandedState state) {
  final channels = {...state.on.keys, ...state.fader.keys}.toList()..sort();
  final messages = <OscMessage>[];
  for (final channel in channels) {
    final level = state.fader[channel];
    if (level != null) messages.add(X32.channelFader(channel, level));
    final on = state.on[channel];
    if (on != null) messages.add(X32.channelOn(channel, on: on));
  }
  return messages;
}

typedef DelayFn = Future<void> Function(Duration duration);

enum RunStatus { completed, cancelled, failed }

/// Plays compiled steps. [send] performs the side effect (or the dry-run log).
class CueRunner {
  CueRunner({DelayFn? delay})
    : _delay = delay ?? ((duration) => Future<void>.delayed(duration));

  final DelayFn _delay;
  int _token = 0;

  void cancel() {
    _token++;
  }

  Future<RunStatus> run({
    required List<CueStep> steps,
    required Future<void> Function(OscMessage message) send,
    void Function(String note)? onNote,
  }) async {
    final my = ++_token;
    for (final step in steps) {
      for (final action in compileStep(step)) {
        if (my != _token) return RunStatus.cancelled;
        switch (action) {
          case SendOsc(:final message):
            try {
              await send(message);
            } catch (_) {
              return RunStatus.failed;
            }
          case WaitAction(:final duration):
            onNote?.call('WAIT  ${duration.inMilliseconds} ms');
            await _delay(duration);
          case NoteAction(:final text):
            onNote?.call(text);
        }
      }
    }
    if (my != _token) return RunStatus.cancelled;
    return RunStatus.completed;
  }
}
