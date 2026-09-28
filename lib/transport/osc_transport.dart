import 'dart:typed_data';

class ConsoleEndpoint {
  const ConsoleEndpoint({
    required this.host,
    required this.port,
    this.localPort,
  });

  final String host;
  final int port;
  final int? localPort;
}

class ProbeResult {
  const ProbeResult({required this.gotReply, required this.message});

  final bool gotReply;
  final String message;
}

/// Fire-and-forget OSC UDP. Implementations must not throw for an empty send
/// queue; they throw when the packet cannot leave the phone.
abstract class OscTransport {
  bool get canSend;

  Future<void> send(Uint8List packet, ConsoleEndpoint endpoint);

  Future<ProbeResult> probe(ConsoleEndpoint endpoint);

  Future<void> close();
}
