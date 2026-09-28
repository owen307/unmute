import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../osc/osc_codec.dart';
import '../osc/x32.dart';
import 'osc_transport.dart';

OscTransport createOscTransport() => UdpOscTransport();

/// One unbound-or-bound UDP socket. Packets are not retried; OSC to an X32
/// is fire-and-forget. The socket stays open so replies to `/info` come back
/// to a stable source port.
class UdpOscTransport implements OscTransport {
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  int? _requestedPort;
  final _inbox = StreamController<Datagram>.broadcast();

  @override
  bool get canSend => true;

  @override
  Future<void> send(Uint8List packet, ConsoleEndpoint endpoint) async {
    final socket = await _bind(endpoint.localPort);
    final address = await _resolve(endpoint.host);
    final sent = socket.send(packet, address, endpoint.port);
    if (sent != packet.length) {
      throw StateError(
        'UDP send delivered $sent of ${packet.length} bytes to ${endpoint.host}:${endpoint.port}.',
      );
    }
  }

  @override
  Future<ProbeResult> probe(ConsoleEndpoint endpoint) async {
    final socket = await _bind(endpoint.localPort);
    final address = await _resolve(endpoint.host);
    final packet = OscCodec.encode(X32.infoProbe());
    socket.send(packet, address, endpoint.port);
    try {
      final datagram = await _inbox.stream.first.timeout(
        const Duration(milliseconds: 900),
      );
      String detail;
      try {
        detail = OscCodec.decode(Uint8List.fromList(datagram.data)).describe();
      } catch (_) {
        detail =
            '${datagram.data.length} byte reply from ${datagram.address.address}:${datagram.port}';
      }
      return ProbeResult(
        gotReply: true,
        message:
            'Reply from ${datagram.address.address}:${datagram.port}. $detail',
      );
    } on TimeoutException {
      return ProbeResult(
        gotReply: false,
        message:
            'No reply from ${endpoint.host}:${endpoint.port} in 900 ms. '
            'Check that the phone and the X32 are on the same Wi-Fi, client isolation is off, '
            'and the IP matches Setup → Network on the desk. Cues can still work if the path is one-way.',
      );
    }
  }

  Future<RawDatagramSocket> _bind(int? localPort) async {
    final requested = localPort ?? 0;
    final existing = _socket;
    if (existing != null && _requestedPort == requested) return existing;
    await _subscription?.cancel();
    existing?.close();
    _socket = null;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        requested,
      );
      _requestedPort = requested;
      _socket = socket;
      _subscription = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram != null && !_inbox.isClosed) _inbox.add(datagram);
      });
      return socket;
    } on SocketException catch (error) {
      final where = requested == 0
          ? 'an ephemeral UDP port'
          : 'UDP port $requested';
      throw StateError(
        'Could not bind $where on this phone. ${error.message}. Leave the local port blank unless you need a fixed source port.',
      );
    }
  }

  Future<InternetAddress> _resolve(String host) async {
    final trimmed = host.trim();
    if (trimmed.isEmpty) {
      throw StateError('No console IP. Open Setup and enter the X32 address.');
    }
    final parsed = InternetAddress.tryParse(trimmed);
    if (parsed != null) {
      if (parsed.type != InternetAddressType.IPv4) {
        throw StateError(
          'Use the X32 IPv4 address. OSC on port ${X32.port} is IPv4.',
        );
      }
      return parsed;
    }
    try {
      final found = await InternetAddress.lookup(trimmed);
      for (final address in found) {
        if (address.type == InternetAddressType.IPv4) return address;
      }
    } on SocketException catch (error) {
      throw StateError('Could not resolve $trimmed. ${error.message}');
    }
    throw StateError('No IPv4 address for $trimmed.');
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _socket?.close();
    _socket = null;
    if (!_inbox.isClosed) await _inbox.close();
  }
}
