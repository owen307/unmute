import 'dart:typed_data';

import 'package:unmute/transport/osc_transport.dart';

class MockTransport implements OscTransport {
  final List<Uint8List> sent = [];
  ProbeResult probeResult = const ProbeResult(gotReply: false, message: 'mock');

  @override
  bool get canSend => true;

  @override
  Future<void> send(Uint8List packet, ConsoleEndpoint endpoint) async {
    sent.add(Uint8List.fromList(packet));
  }

  @override
  Future<ProbeResult> probe(ConsoleEndpoint endpoint) async => probeResult;

  @override
  Future<void> close() async {}
}
