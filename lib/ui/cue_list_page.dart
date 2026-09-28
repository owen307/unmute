import 'package:flutter/material.dart';

import '../state/show_controller.dart';
import '../theme.dart';
import 'control_deck.dart';
import 'cue_editor_page.dart';
import 'mode_banner.dart';

class CueListPage extends StatelessWidget {
  const CueListPage({super.key, required this.controller});

  final ShowController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final cues = controller.show.cues;
        final host = controller.show.settings.host.trim();
        final target = host.isEmpty
            ? 'No X32 IP yet'
            : '$host:${controller.show.settings.port}';
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'UNMUTE',
                      style: TextStyle(
                        color: paper,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('add-cue-button'),
                    tooltip: 'Add cue',
                    iconSize: 32,
                    onPressed: () {
                      final cue = controller.addCue();
                      _openEditor(context, cue.id);
                    },
                    icon: const Icon(Icons.add_box_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  target,
                  style: const TextStyle(
                    color: dim,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            ModeBanner(dryRun: controller.show.settings.dryRun),
            Expanded(
              child: cues.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No cues yet. Add one, then stack mute, unmute, level, and wait steps.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: dim, fontSize: 18),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: cues.length,
                      onReorderItem: controller.reorderCues,
                      itemBuilder: (context, index) {
                        final cue = cues[index];
                        final selected = controller.standby == index;
                        final running = controller.runningCueId == cue.id;
                        return Material(
                          key: ValueKey(cue.id),
                          color: selected ? panelRaised : ink,
                          child: InkWell(
                            key: Key('cue-tile-${cue.id}'),
                            onTap: () => controller.select(index),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 84),
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: selected
                                        ? goYellow
                                        : Colors.transparent,
                                    width: 6,
                                  ),
                                  bottom: const BorderSide(color: line),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Icon(
                                        Icons.drag_handle,
                                        color: dim,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 36,
                                    child: Text(
                                      (index + 1).toString().padLeft(2, '0'),
                                      style: const TextStyle(
                                        color: dim,
                                        fontFamily: 'monospace',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cue.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: paper,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _subtitle(
                                            cue.steps.length,
                                            cue.autoFollow,
                                            running,
                                            selected,
                                          ),
                                          style: TextStyle(
                                            color: running ? liveGreen : dim,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit cue',
                                    iconSize: 28,
                                    onPressed: () =>
                                        _openEditor(context, cue.id),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            ControlDeck(controller: controller),
          ],
        );
      },
    );
  }

  String _subtitle(int steps, bool autoFollow, bool running, bool selected) {
    final count = '$steps ${steps == 1 ? 'step' : 'steps'}';
    final auto = autoFollow ? ' · auto-follow' : '';
    final state = running ? ' · running' : (selected ? ' · standby' : '');
    return '$count$auto$state';
  }

  void _openEditor(BuildContext context, String cueId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CueEditorPage(controller: controller, cueId: cueId),
      ),
    );
  }
}
