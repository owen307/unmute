enum OscArgType { int32, float32, string }

/// One OSC argument. Ints are signed 32-bit, floats are 32-bit IEEE.
class OscArg {
  const OscArg.int32(int value) : this._(OscArgType.int32, value);

  const OscArg.float32(double value) : this._(OscArgType.float32, value);

  const OscArg.string(String value) : this._(OscArgType.string, value);

  const OscArg._(this.type, this.value);

  final OscArgType type;
  final Object value;

  int get asInt => value as int;
  double get asFloat => (value as num).toDouble();
  String get asString => value as String;

  String describe() {
    switch (type) {
      case OscArgType.int32:
        return 'int $value';
      case OscArgType.float32:
        return 'float ${asFloat.toStringAsFixed(4)}';
      case OscArgType.string:
        return 'string "$value"';
    }
  }

  Map<String, Object> toJson() {
    final tag = switch (type) {
      OscArgType.int32 => 'i',
      OscArgType.float32 => 'f',
      OscArgType.string => 's',
    };
    return {'t': tag, 'v': value};
  }

  factory OscArg.fromJson(Map<String, dynamic> json) {
    final tag = json['t'];
    final raw = json['v'];
    switch (tag) {
      case 'i':
        if (raw is! num) {
          throw const FormatException('OSC int argument is missing a number.');
        }
        final v = raw.toInt();
        if (v < -2147483648 || v > 2147483647) {
          throw FormatException('OSC int $v does not fit in 32 bits.');
        }
        return OscArg.int32(v);
      case 'f':
        if (raw is! num || raw.isNaN || raw.isInfinite) {
          throw const FormatException(
            'OSC float argument is missing a number.',
          );
        }
        return OscArg.float32(raw.toDouble());
      case 's':
        if (raw is! String) {
          throw const FormatException('OSC string argument is missing text.');
        }
        return OscArg.string(raw);
      default:
        throw FormatException('Unknown OSC argument type "$tag".');
    }
  }
}

class OscMessage {
  const OscMessage(this.address, [this.args = const []]);

  final String address;
  final List<OscArg> args;

  String describe() {
    if (args.isEmpty) return address;
    return '$address   ${args.map((a) => a.describe()).join('  ')}';
  }

  Map<String, Object> toJson() => {
    'address': address,
    'args': args.map((a) => a.toJson()).toList(),
  };

  factory OscMessage.fromJson(Map<String, dynamic> json) {
    final address = json['address'];
    if (address is! String || address.isEmpty) {
      throw const FormatException('OSC message needs an address.');
    }
    final rawArgs = json['args'];
    final args = <OscArg>[];
    if (rawArgs is List) {
      for (final item in rawArgs) {
        if (item is! Map) {
          throw const FormatException('OSC argument is not an object.');
        }
        args.add(OscArg.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return OscMessage(address, args);
  }
}
