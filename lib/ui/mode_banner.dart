import 'package:flutter/material.dart';

class ModeBanner extends StatelessWidget {
  const ModeBanner({super.key, required this.dryRun});

  final bool dryRun;

  @override
  Widget build(BuildContext context) {
    final background = dryRun
        ? const Color(0xFF3A2E10)
        : const Color(0xFF3D1214);
    final foreground = dryRun
        ? const Color(0xFFFFE08A)
        : const Color(0xFFFFD0D0);
    return Container(
      key: const Key('mode-banner'),
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        dryRun
            ? 'TEST MODE — cues are logged and not sent'
            : 'LIVE — GO changes mutes and faders on the console',
        style: TextStyle(
          color: foreground,
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
