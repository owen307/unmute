import 'dart:convert';
import 'dart:typed_data';

import 'osc_message.dart';

/// OSC 1.0 packet codec.
///
/// Strings are UTF-8, null-terminated, and padded to a 4-byte boundary.
/// Ints and floats are big-endian 32-bit. One message per datagram — the X32
/// accepts that form for `/ch/NN/mix/on` and `/ch/NN/mix/fader`.
class OscCodec {
  static Uint8List encode(OscMessage message) {
    if (message.address.isEmpty) {
      throw ArgumentError.value(
        message.address,
        'address',
        'OSC address is empty',
      );
    }
    final builder = BytesBuilder(copy: false);
    _writeString(builder, message.address);
    final tag = StringBuffer(',');
    for (final arg in message.args) {
      tag.write(switch (arg.type) {
        OscArgType.int32 => 'i',
        OscArgType.float32 => 'f',
        OscArgType.string => 's',
      });
    }
    _writeString(builder, tag.toString());
    for (final arg in message.args) {
      switch (arg.type) {
        case OscArgType.int32:
          _writeInt(builder, arg.asInt);
        case OscArgType.float32:
          _writeFloat(builder, arg.asFloat);
        case OscArgType.string:
          _writeString(builder, arg.asString);
      }
    }
    return builder.toBytes();
  }

  static OscMessage decode(Uint8List packet) {
    if (packet.length < 4) {
      throw const FormatException('OSC packet is too short.');
    }
    if (packet.length >= 8 &&
        utf8.decode(packet.sublist(0, 7), allowMalformed: true) == '#bundle') {
      throw const FormatException('OSC bundles are not used.');
    }
    final data = ByteData.sublistView(packet);
    final cursor = _Cursor();
    final address = _readString(data, cursor);
    final tag = _readString(data, cursor);
    if (tag.isEmpty || !tag.startsWith(',')) {
      throw const FormatException('OSC type tag is missing.');
    }
    final args = <OscArg>[];
    for (final code in tag.substring(1).codeUnits) {
      switch (code) {
        case 0x69: // i
          args.add(OscArg.int32(_readInt(data, cursor)));
        case 0x66: // f
          args.add(OscArg.float32(_readFloat(data, cursor)));
        case 0x73: // s
          args.add(OscArg.string(_readString(data, cursor)));
        default:
          throw FormatException(
            'Unsupported OSC type tag "${String.fromCharCode(code)}".',
          );
      }
    }
    return OscMessage(address, args);
  }

  static void _writeString(BytesBuilder builder, String value) {
    final bytes = utf8.encode(value);
    builder.add(bytes);
    builder.addByte(0);
    final pad = (4 - ((bytes.length + 1) % 4)) % 4;
    if (pad != 0) builder.add(List<int>.filled(pad, 0));
  }

  static void _writeInt(BytesBuilder builder, int value) {
    final data = ByteData(4)..setInt32(0, value, Endian.big);
    builder.add(data.buffer.asUint8List());
  }

  static void _writeFloat(BytesBuilder builder, double value) {
    final data = ByteData(4)..setFloat32(0, value, Endian.big);
    builder.add(data.buffer.asUint8List());
  }

  static String _readString(ByteData data, _Cursor cursor) {
    final start = cursor.offset;
    while (cursor.offset < data.lengthInBytes &&
        data.getUint8(cursor.offset) != 0) {
      cursor.offset++;
    }
    if (cursor.offset >= data.lengthInBytes) {
      throw const FormatException('OSC string is not terminated.');
    }
    final slice = Uint8List.sublistView(
      data.buffer.asUint8List(data.offsetInBytes),
      start,
      cursor.offset,
    );
    final value = utf8.decode(slice);
    cursor.offset++;
    final aligned = (cursor.offset + 3) & ~3;
    if (aligned > data.lengthInBytes) {
      throw const FormatException('OSC string padding overflows the packet.');
    }
    cursor.offset = aligned;
    return value;
  }

  static int _readInt(ByteData data, _Cursor cursor) {
    _need(data, cursor, 4);
    final value = data.getInt32(cursor.offset, Endian.big);
    cursor.offset += 4;
    return value;
  }

  static double _readFloat(ByteData data, _Cursor cursor) {
    _need(data, cursor, 4);
    final value = data.getFloat32(cursor.offset, Endian.big);
    cursor.offset += 4;
    return value;
  }

  static void _need(ByteData data, _Cursor cursor, int n) {
    if (cursor.offset + n > data.lengthInBytes) {
      throw const FormatException('OSC packet ended early.');
    }
  }
}

class _Cursor {
  int offset = 0;
}

String hexDump(List<int> bytes, {int max = 48}) {
  final shown = bytes
      .take(max)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join(' ');
  if (bytes.length > max) return '$shown … (${bytes.length} bytes)';
  return shown;
}
