import 'osc_message.dart';

/// Behringer X32 / Midas M32 input-channel OSC.
///
/// Paths and types follow Patrick-Gilles Maillot's unofficial X32/M32 OSC
/// remote protocol (the reference X32_Command and the published examples use):
///
/// * `/ch/01/mix/on ,i 0` — channel OFF, which is muted
/// * `/ch/01/mix/on ,i 1` — channel ON, which is unmuted
/// * `/ch/01/mix/fader ,f 0.5` — fader at the −10 dB breakpoint
///
/// Mute is an int32 enum, not a float. Channels are 1–32, zero-padded to two
/// digits. This app's panic mute covers those input channels only, not main,
/// buses, or DCAs. Use a custom OSC step for other paths (`/main/st/mix/on`,
/// `/bus/01/mix/fader`, and so on).
class X32 {
  static const int port = 10023;
  static const int channelCount = 32;

  static String _nn(int channel) {
    if (channel < 1 || channel > channelCount) {
      throw ArgumentError.value(
        channel,
        'channel',
        'X32 input channels are 1–$channelCount',
      );
    }
    return channel.toString().padLeft(2, '0');
  }

  static String onPath(int channel) => '/ch/${_nn(channel)}/mix/on';

  static String faderPath(int channel) => '/ch/${_nn(channel)}/mix/fader';

  /// [on] true sends int 1 (unmuted). False sends int 0 (muted).
  static OscMessage channelOn(int channel, {required bool on}) {
    return OscMessage(onPath(channel), [OscArg.int32(on ? 1 : 0)]);
  }

  /// [unit] is the console float, clamped to 0–1. See [dbToUnitInterval].
  static OscMessage channelFader(int channel, double unit) {
    final clamped = unit.clamp(0.0, 1.0).toDouble();
    return OscMessage(faderPath(channel), [OscArg.float32(clamped)]);
  }

  static List<OscMessage> allInputMutes() => [
    for (var ch = 1; ch <= channelCount; ch++) channelOn(ch, on: false),
  ];

  /// Read-only console identity query. The desk replies on the source port.
  static OscMessage infoProbe() => const OscMessage('/info');
}

/// X32 fader law. The wire value is a float 0.0–1.0, not dB.
///
/// Piecewise linear, matching Maillot `float_to_db` / `db_to_float`:
///
/// | float | dB shown on the desk |
/// | --- | --- |
/// | 0.0 | −∞ (formula endpoint −90) |
/// | 0.0625 | −60 |
/// | 0.25 | −30 |
/// | 0.5 | −10 |
/// | 0.75 | 0 |
/// | 1.0 | +10 |
///
/// dB outside −90…+10 is clamped. 0.0 is what the console draws as −∞.
double dbToUnitInterval(double db) {
  if (db.isNaN) {
    throw ArgumentError.value(db, 'db', 'Level is not a number');
  }
  if (db <= -90) return 0;
  if (db >= 10) return 1;
  final double unit;
  if (db < -60) {
    unit = (db + 90) / 480;
  } else if (db < -30) {
    unit = (db + 70) / 160;
  } else if (db < -10) {
    unit = (db + 50) / 80;
  } else {
    unit = (db + 30) / 40;
  }
  return unit.clamp(0.0, 1.0).toDouble();
}

/// Inverse of [dbToUnitInterval]. A unit of 0 is reported as −90.
double unitIntervalToDb(double unit) {
  if (unit.isNaN) {
    throw ArgumentError.value(unit, 'unit', 'Level is not a number');
  }
  if (unit <= 0) return -90;
  if (unit >= 1) return 10;
  if (unit >= 0.5) return unit * 40 - 30;
  if (unit >= 0.25) return unit * 80 - 50;
  if (unit >= 0.0625) return unit * 160 - 70;
  return unit * 480 - 90;
}

/// Desk-style level. The bottom of the fader is −∞, which we send as float 0.
String formatDb(double db) {
  if (db <= -90) return '−∞ dB';
  final rounded = (db * 10).round() / 10;
  final sign = rounded > 0 ? '+' : '';
  return '$sign${rounded.toStringAsFixed(1)} dB';
}
