import 'dart:typed_data';

import 'osc_transport.dart';

OscTransport createOscTransport() => const _StubOscTransport();

class _StubOscTransport implements OscTransport {
  const _StubOscTransport();

  @override
  bool get canSend => false;

  @override
  Future<void> send(Uint8List packet, ConsoleEndpoint endpoint) async {
    throw StateError(
      'This build has no UDP socket. Use the Android app on the same Wi-Fi as the X32.',
    );
  }

  @override
  Future<ProbeResult> probe(ConsoleEndpoint endpoint) async {
    return const ProbeResult(
      gotReply: false,
      message: 'This build has no UDP socket. Install the Android app to reach the console.',
    );
  }

  @override
  Future<void> close() async {}
}
