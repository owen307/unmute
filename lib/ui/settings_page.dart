import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../osc/x32.dart';
import '../state/show_controller.dart';
import '../theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final ShowController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _host = TextEditingController(
    text: widget.controller.show.settings.host,
  );
  late final TextEditingController _port = TextEditingController(
    text: '${widget.controller.show.settings.port}',
  );
  late final TextEditingController _local = TextEditingController(
    text: widget.controller.show.settings.localPort?.toString() ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _local.dispose();
    super.dispose();
  }

  int? _portValue(String raw, {required bool allowEmpty}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return allowEmpty ? null : null;
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 1 || parsed > 65535) return null;
    return parsed;
  }

  void _publish({bool? dryRun}) {
    final port = _portValue(_port.text, allowEmpty: false);
    if (port == null) {
      setState(
        () => _error = 'Port must be 1–65535. The X32 OSC port is ${X32.port}.',
      );
      return;
    }
    int? local;
    if (_local.text.trim().isNotEmpty) {
      local = _portValue(_local.text, allowEmpty: true);
      if (local == null) {
        setState(() => _error = 'Local port must be 1–65535, or blank.');
        return;
      }
    }
    setState(() => _error = null);
    final current = widget.controller.show.settings;
    widget.controller.updateSettings(
      current.copyWith(
        host: _host.text.trim(),
        port: port,
        localPort: local,
        clearLocalPort: local == null,
        dryRun: dryRun ?? current.dryRun,
      ),
    );
  }

  Future<void> _setDryRun(bool dryRun) async {
    if (!dryRun) {
      if (_host.text.trim().isEmpty) {
        setState(() => _error = 'Enter the X32 IP before leaving test mode.');
        return;
      }
      final goLive = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Send cues to the console?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'GO, ALL MUTE, and RESTORE will change input mutes and faders on ${_host.text.trim()}:${_port.text.trim()}.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: bigFill(
                      background: panicRed,
                      foreground: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Go live'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Stay in test mode'),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (goLive != true) return;
    }
    _publish(dryRun: dryRun);
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reload the example show?'),
        content: const Text(
          'Replaces cues and channel names with Worship team on, Pastor only, and Band + vocal. The console IP stays. The desk is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reload examples'),
          ),
        ],
      ),
    );
    if (ok == true) await widget.controller.resetExampleShow();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.controller.show.settings;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'SETUP',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The phone and the X32 must be on the same network. Guest Wi-Fi that isolates clients will not work. OSC is UDP, not MIDI.',
              style: TextStyle(color: dim, fontSize: 15, height: 1.35),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _host,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              style: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'X32 IP address',
                hintText: '192.168.1.50',
              ),
              onChanged: (_) => _publish(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'OSC port',
                hintText: '10023',
              ),
              onChanged: (_) => _publish(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _local,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                labelText: 'Local bind port (optional)',
                helperText: 'Blank uses a free port on this phone. Set one only if a firewall expects a fixed source port.',
                helperMaxLines: 3,
              ),
              onChanged: (_) => _publish(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFF8A80),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Test mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Log every cue and do not send UDP. Turn this off only when the IP is the live desk.',
              ),
              value: settings.dryRun,
              onChanged: (value) => _setDryRun(value),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: FilledButton(
                style: bigFill(background: panelRaised, foreground: paper),
                onPressed: widget.controller.probing
                    ? null
                    : widget.controller.probe,
                child: Text(
                  widget.controller.probing
                      ? 'Asking the console…'
                      : 'Test connection',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Test connection sends one /info query even in test mode. Cues stay silent until test mode is off.',
              style: TextStyle(color: dim, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 20),
            const Text(
              'How levels are sent',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Mute uses /ch/01/mix/on with int 0 (muted, channel OFF) or int 1 (unmuted, channel ON). '
              'Faders use /ch/01/mix/fader with a float from 0 to 1. That float is not dB. '
              '0 is −∞, 0.75 is 0 dB, 1.0 is +10 dB. ALL MUTE covers inputs 1–32 only.',
              style: TextStyle(color: dim, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 12),
            const _MapTable(),
            const SizedBox(height: 20),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _reset,
                child: const Text('Reload example cues'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unmute 1.0 · X32 / M32 · UDP 10023',
              style: TextStyle(color: dim, fontSize: 13),
            ),
          ],
        );
      },
    );
  }
}

class _MapTable extends StatelessWidget {
  const _MapTable();

  static const rows = <(String, String)>[
    ('0.000', '−∞'),
    ('0.0625', '−60 dB'),
    ('0.25', '−30 dB'),
    ('0.5', '−10 dB'),
    ('0.75', '0 dB'),
    ('1.0', '+10 dB'),
  ];

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth()},
      border: TableBorder.all(color: line),
      children: [
        const TableRow(
          decoration: BoxDecoration(color: panel),
          children: [
            _Cell('Console float', head: true),
            _Cell('Desk dB', head: true),
          ],
        ),
        for (final row in rows)
          TableRow(children: [_Cell(row.$1), _Cell(row.$2)]),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.head = false});

  final String text;
  final bool head;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontWeight: head ? FontWeight.w800 : FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
