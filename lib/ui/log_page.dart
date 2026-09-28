import 'package:flutter/material.dart';

import '../state/log_entry.dart';
import '../state/show_controller.dart';
import '../theme.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key, required this.controller});

  final ShowController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final entries = controller.log;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'OSC LOG',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: entries.isEmpty ? null : controller.clearLog,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Newest first. DRY means the packet was not sent. SENT left this phone — the X32 does not confirm mute changes.',
                style: TextStyle(color: dim, fontSize: 14, height: 1.35),
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Press GO in test mode to see the OSC a cue would send.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: dim, fontSize: 18),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _LogTile(entry: entries[index]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final OscLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final badge = !entry.ok ? 'ERROR' : (entry.dryRun ? 'DRY' : 'SENT');
    final color = !entry.ok
        ? const Color(0xFFFF8A80)
        : (entry.dryRun ? goYellow : liveGreen);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                formatClock(entry.at),
                style: const TextStyle(
                  color: dim,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (entry.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.detail,
              style: const TextStyle(
                color: dim,
                fontSize: 12,
                height: 1.35,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
