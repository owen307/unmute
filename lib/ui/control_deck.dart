import 'package:flutter/material.dart';

import '../state/show_controller.dart';
import '../theme.dart';

class ControlDeck extends StatelessWidget {
  const ControlDeck({super.key, required this.controller});

  final ShowController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final next = controller.standbyCue;
        final running = controller.runningCueId != null;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF101418),
            border: Border(top: BorderSide(color: line)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      next == null ? 'NO CUE' : 'NEXT   ${next.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: paper,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: const Key('stop-button'),
                      onPressed: running ? controller.stop : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: paper,
                        side: const BorderSide(color: line),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('STOP'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: FilledButton(
                        key: const Key('all-mute-button'),
                        style: bigFill(
                          background: panicRed,
                          foreground: Colors.white,
                        ),
                        onPressed: controller.allMute,
                        child: const Text('ALL MUTE'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: FilledButton(
                        key: const Key('restore-button'),
                        style: bigFill(
                          background: const Color(0xFF243044),
                          foreground: paper,
                        ),
                        onPressed: controller.canRestore
                            ? controller.restore
                            : null,
                        child: const Text('RESTORE'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 92,
                child: FilledButton(
                  key: const Key('go-button'),
                  style: bigFill(background: goYellow, foreground: goInk)
                      .copyWith(
                        textStyle: WidgetStateProperty.all(
                          const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                  onPressed: controller.canGo ? controller.go : null,
                  child: const Text('GO'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
