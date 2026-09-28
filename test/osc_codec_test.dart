import 'package:flutter_test/flutter_test.dart';
import 'package:unmute/osc/osc_codec.dart';
import 'package:unmute/osc/osc_message.dart';
import 'package:unmute/osc/x32.dart';

void main() {
  test('channel on encodes the X32 24-byte int packet', () {
    final bytes = OscCodec.encode(X32.channelOn(1, on: true));
    expect(bytes.length, 24);
    expect(bytes.sublist(0, 16), [
      0x2f, 0x63, 0x68, 0x2f, 0x30, 0x31, 0x2f, 0x6d, // /ch/01/m
      0x69, 0x78, 0x2f, 0x6f, 0x6e, 0x00, 0x00, 0x00, // ix/on\0\0\0
    ]);
    expect(bytes.sublist(16, 20), [0x2c, 0x69, 0x00, 0x00]); // ,i
    expect(bytes.sublist(20, 24), [0x00, 0x00, 0x00, 0x01]);
    final decoded = OscCodec.decode(bytes);
    expect(decoded.address, '/ch/01/mix/on');
    expect(decoded.args.single.type, OscArgType.int32);
    expect(decoded.args.single.asInt, 1);
  });

  test('mute is int 0, not a float', () {
    final bytes = OscCodec.encode(X32.channelOn(8, on: false));
    final decoded = OscCodec.decode(bytes);
    expect(decoded.address, '/ch/08/mix/on');
    expect(decoded.args.single.describe(), 'int 0');
    expect(String.fromCharCodes(bytes.sublist(16, 18)), ',i');
  });

  test('fader 0.5 is the documented 28-byte float packet', () {
    final bytes = OscCodec.encode(
      OscMessage(X32.faderPath(1), const [OscArg.float32(0.5)]),
    );
    expect(bytes.length, 28);
    expect(String.fromCharCodes(bytes.sublist(0, 16)), '/ch/01/mix/fader');
    expect(bytes.sublist(16, 20), [0x00, 0x00, 0x00, 0x00]);
    expect(bytes.sublist(20, 24), [0x2c, 0x66, 0x00, 0x00]); // ,f
    expect(bytes.sublist(24, 28), [0x3f, 0x00, 0x00, 0x00]); // 0.5
    expect(OscCodec.decode(bytes).args.single.asFloat, 0.5);
  });

  test('0 dB fader is float 0.75', () {
    final bytes = OscCodec.encode(X32.channelFader(1, dbToUnitInterval(0)));
    expect(bytes.sublist(24, 28), [0x3f, 0x40, 0x00, 0x00]);
    expect(OscCodec.decode(bytes).args.single.asFloat, 0.75);
  });

  test('string arguments pad to 4 bytes and round-trip', () {
    const message = OscMessage('/foo', [OscArg.string('hi')]);
    final bytes = OscCodec.encode(message);
    // /foo\0\0\0\0 (8) + ,s\0\0 (4) + hi\0\0 (4)
    expect(bytes.length, 16);
    final decoded = OscCodec.decode(bytes);
    expect(decoded.address, '/foo');
    expect(decoded.args.single.asString, 'hi');
  });

  test('mixed int and float arguments stay aligned', () {
    const message = OscMessage('/x', [OscArg.int32(-2), OscArg.float32(0.5)]);
    final decoded = OscCodec.decode(OscCodec.encode(message));
    expect(decoded.args[0].asInt, -2);
    expect(decoded.args[1].asFloat, 0.5);
  });

  test('empty address is rejected', () {
    expect(() => OscCodec.encode(const OscMessage('')), throwsArgumentError);
  });
}
