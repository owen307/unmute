import '../osc/osc_message.dart';
import '../osc/x32.dart';
import 'channel_list.dart';
import 'ids.dart';

enum LevelUnit { db, float }

sealed class CueStep {
  const CueStep(this.id);

  final String id;

  Map<String, Object?> toJson();

  String get typeLabel;

  /// One line for the cue editor header.
  String summary(String Function(int channel) label);

  factory CueStep.fromJson(Map<String, dynamic> json) {
    final id = json['id'] is String ? json['id'] as String : newId('step');
    switch (json['type']) {
      case 'unmute':
        return UnmuteStep(id: id, channels: _channels(json));
      case 'mute':
        return MuteStep(id: id, channels: _channels(json));
      case 'fader':
        return FaderStep(
          id: id,
          channel: _channel(json['channel']),
          unit: json['unit'] == 'float' ? LevelUnit.float : LevelUnit.db,
          value: _num(json['value']),
        );
      case 'wait':
        return WaitStep(id: id, milliseconds: _millis(json['ms']));
      case 'osc':
        final address = json['address'];
        if (address is! String) {
          throw const FormatException('Custom OSC step needs an address.');
        }
        return CustomOscStep(
          id: id,
          message: OscMessage.fromJson({
            'address': address,
            'args': json['args'] ?? const [],
          }),
        );
      default:
        throw FormatException('Unknown cue step type "${json['type']}".');
    }
  }
}

class UnmuteStep extends CueStep {
  const UnmuteStep({required String id, required this.channels}) : super(id);

  final List<int> channels;

  UnmuteStep withChannels(List<int> next) => UnmuteStep(id: id, channels: next);

  @override
  String get typeLabel => 'UNMUTE';

  @override
  String summary(String Function(int channel) label) =>
      _channelSummary('Unmute', channels, label);

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': 'unmute',
    'channels': channels,
  };
}

class MuteStep extends CueStep {
  const MuteStep({required String id, required this.channels}) : super(id);

  final List<int> channels;

  MuteStep withChannels(List<int> next) => MuteStep(id: id, channels: next);

  @override
  String get typeLabel => 'MUTE';

  @override
  String summary(String Function(int channel) label) =>
      _channelSummary('Mute', channels, label);

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': 'mute',
    'channels': channels,
  };
}

class FaderStep extends CueStep {
  const FaderStep({
    required String id,
    required this.channel,
    required this.unit,
    required this.value,
  }) : super(id);

  final int channel;
  final LevelUnit unit;
  final double value;

  FaderStep copyWith({int? channel, LevelUnit? unit, double? value}) {
    return FaderStep(
      id: id,
      channel: channel ?? this.channel,
      unit: unit ?? this.unit,
      value: value ?? this.value,
    );
  }

  double get unitInterval => unit == LevelUnit.float
      ? value.clamp(0.0, 1.0).toDouble()
      : dbToUnitInterval(value);

  @override
  String get typeLabel => 'LEVEL';

  @override
  String summary(String Function(int channel) label) {
    final level = unit == LevelUnit.db
        ? formatDb(value)
        : 'float ${value.toStringAsFixed(3)}';
    return 'Level ${label(channel)} to $level';
  }

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': 'fader',
    'channel': channel,
    'unit': unit == LevelUnit.float ? 'float' : 'db',
    'value': value,
  };
}

class WaitStep extends CueStep {
  const WaitStep({required String id, required this.milliseconds}) : super(id);

  final int milliseconds;

  WaitStep withMs(int ms) => WaitStep(id: id, milliseconds: ms);

  @override
  String get typeLabel => 'WAIT';

  @override
  String summary(String Function(int channel) label) => 'Wait $milliseconds ms';

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': 'wait',
    'ms': milliseconds,
  };
}

class CustomOscStep extends CueStep {
  const CustomOscStep({required String id, required this.message}) : super(id);

  final OscMessage message;

  CustomOscStep withMessage(OscMessage next) =>
      CustomOscStep(id: id, message: next);

  @override
  String get typeLabel => 'OSC';

  @override
  String summary(String Function(int channel) label) => message.describe();

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'type': 'osc',
    'address': message.address,
    'args': message.args.map((a) => a.toJson()).toList(),
  };
}

String _channelSummary(
  String verb,
  List<int> channels,
  String Function(int channel) label,
) {
  if (channels.isEmpty) return '$verb — no channels';
  if (channels.length > 4) {
    return '$verb ${channels.length} channels (${formatChannelList(channels)})';
  }
  return '$verb ${channels.map(label).join(', ')}';
}

List<int> _channels(Map<String, dynamic> json) {
  final raw = json['channels'];
  if (raw is! List) return const [];
  return [for (final item in raw) _channel(item)];
}

int _channel(Object? raw) {
  if (raw is! num) {
    throw const FormatException('A channel number is missing.');
  }
  final n = raw.toInt();
  if (n < 1 || n > X32.channelCount) {
    throw FormatException('Channel $n is outside 1–${X32.channelCount}.');
  }
  return n;
}

double _num(Object? raw) {
  if (raw is! num || raw.isNaN || raw.isInfinite) {
    throw const FormatException('A level value is missing.');
  }
  return raw.toDouble();
}

int _millis(Object? raw) {
  if (raw is! num) {
    throw const FormatException('A wait needs milliseconds.');
  }
  final ms = raw.toInt();
  if (ms < 0 || ms > 3600000) {
    throw const FormatException('Wait must be between 0 ms and 1 hour.');
  }
  return ms;
}
