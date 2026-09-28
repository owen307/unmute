import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cue_step.dart';
import '../models/ids.dart';
import '../models/show.dart';
import '../osc/osc_message.dart';
import '../osc/x32.dart';
import '../state/show_controller.dart';
import '../theme.dart';
import 'channel_picker.dart';

class CueEditorPage extends StatelessWidget {
  const CueEditorPage({
    super.key,
    required this.controller,
    required this.cueId,
  });

  final ShowController controller;
  final String cueId;

  Cue? _cue() {
    for (final cue in controller.show.cues) {
      if (cue.id == cueId) return cue;
    }
    return null;
  }

  void _replace(Cue cue, List<CueStep> steps) =>
      controller.updateCue(cue.copyWith(steps: steps));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final cue = _cue();
        if (cue == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This cue was deleted.')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit cue'),
            actions: [
              IconButton(
                tooltip: 'Delete cue',
                icon: const Icon(Icons.delete_outline),
                iconSize: 28,
                onPressed: () => _confirmDelete(context, cue),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ReorderableListView(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  header: _header(cue),
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      height: 64,
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('add-step-button'),
                        style: bigFill(
                          background: panelRaised,
                          foreground: paper,
                        ),
                        onPressed: () => _addStep(context, cue),
                        icon: const Icon(Icons.add),
                        label: const Text('Add step'),
                      ),
                    ),
                  ),
                  onReorderItem: (oldIndex, newIndex) {
                    final steps = [...cue.steps];
                    final moved = steps.removeAt(oldIndex);
                    steps.insert(newIndex, moved);
                    _replace(cue, steps);
                  },
                  children: [
                    for (var i = 0; i < cue.steps.length; i++)
                      _StepCard(
                        key: ValueKey(cue.steps[i].id),
                        index: i,
                        step: cue.steps[i],
                        show: controller.show,
                        onChanged: (step) {
                          final steps = [...cue.steps];
                          steps[i] = step;
                          _replace(cue, steps);
                        },
                        onDelete: () {
                          final steps = [...cue.steps]..removeAt(i);
                          _replace(cue, steps);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(Cue cue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          key: ValueKey('cue-name-${cue.id}'),
          initialValue: cue.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(labelText: 'Cue name'),
          textCapitalization: TextCapitalization.sentences,
          onChanged: (value) {
            final name = value.trim().isEmpty ? 'Untitled cue' : value.trim();
            controller.updateCue(cue.copyWith(name: name));
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Auto-follow',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'When this cue finishes, including waits, fire the next cue.',
          ),
          value: cue.autoFollow,
          onChanged: (value) =>
              controller.updateCue(cue.copyWith(autoFollow: value)),
        ),
        const SizedBox(height: 8),
        Text(
          cue.steps.isEmpty
              ? 'No steps yet.'
              : '${cue.steps.length} ${cue.steps.length == 1 ? 'step' : 'steps'} · drag to reorder',
          style: const TextStyle(color: dim, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _addStep(BuildContext context, Cue cue) async {
    final step = await showModalBottomSheet<CueStep>(
      context: context,
      backgroundColor: panel,
      showDragHandle: true,
      builder: (context) {
        Widget choice(String label, String detail, CueStep step) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 84,
              width: double.infinity,
              child: FilledButton(
                style: bigFill(background: panelRaised, foreground: paper),
                onPressed: () => Navigator.pop(context, step),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: dim,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              choice(
                'Unmute',
                'Channel ON · /mix/on int 1',
                UnmuteStep(id: newId('step'), channels: const []),
              ),
              choice(
                'Mute',
                'Channel OFF · /mix/on int 0',
                MuteStep(id: newId('step'), channels: const []),
              ),
              choice(
                'Level',
                'Fader in dB or console float',
                FaderStep(
                  id: newId('step'),
                  channel: 1,
                  unit: LevelUnit.db,
                  value: 0,
                ),
              ),
              choice(
                'Wait',
                'Hold before the next step',
                WaitStep(id: newId('step'), milliseconds: 500),
              ),
              choice(
                'Custom OSC',
                'Any address, for buses and other desks',
                CustomOscStep(
                  id: newId('step'),
                  message: const OscMessage('/ch/01/mix/on', [OscArg.int32(0)]),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (step == null) return;
    _replace(cue, [...cue.steps, step]);
  }

  Future<void> _confirmDelete(BuildContext context, Cue cue) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this cue?'),
        content: Text(
          '"${cue.name}" will leave this phone. The console is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      controller.deleteCue(cue.id);
      Navigator.of(context).pop();
    }
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    super.key,
    required this.index,
    required this.step,
    required this.show,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final CueStep step;
  final ShowData show;
  final ValueChanged<CueStep> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: panel,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.drag_handle, color: dim),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${step.typeLabel}  ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete step',
                  onPressed: onDelete,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _body(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final step = this.step;
    switch (step) {
      case UnmuteStep():
        return ChannelPicker(
          show: show,
          channels: step.channels,
          onChanged: (channels) => onChanged(step.withChannels(channels)),
        );
      case MuteStep():
        return ChannelPicker(
          show: show,
          channels: step.channels,
          onChanged: (channels) => onChanged(step.withChannels(channels)),
        );
      case FaderStep():
        return _FaderEditor(step: step, show: show, onChanged: onChanged);
      case WaitStep():
        return _WaitEditor(step: step, onChanged: onChanged);
      case CustomOscStep():
        return _OscEditor(step: step, onChanged: onChanged);
    }
  }
}

class _FaderEditor extends StatelessWidget {
  const _FaderEditor({
    required this.step,
    required this.show,
    required this.onChanged,
  });

  final FaderStep step;
  final ShowData show;
  final ValueChanged<CueStep> onChanged;

  @override
  Widget build(BuildContext context) {
    final unit = step.unitInterval;
    final db = unitIntervalToDb(unit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChannelPicker(
          show: show,
          channels: [step.channel],
          single: true,
          onChanged: (channels) {
            if (channels.isEmpty) return;
            onChanged(step.copyWith(channel: channels.single));
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<LevelUnit>(
          segments: const [
            ButtonSegment(
              value: LevelUnit.db,
              label: Text('dB'),
              tooltip: 'Desk decibels',
            ),
            ButtonSegment(
              value: LevelUnit.float,
              label: Text('0–1'),
              tooltip: 'Console float',
            ),
          ],
          selected: {step.unit},
          onSelectionChanged: (next) {
            final unitChoice = next.first;
            if (unitChoice == step.unit) return;
            if (unitChoice == LevelUnit.float) {
              onChanged(
                step.copyWith(unit: LevelUnit.float, value: step.unitInterval),
              );
            } else {
              onChanged(
                step.copyWith(
                  unit: LevelUnit.db,
                  value: unitIntervalToDb(step.unitInterval),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Sends ${X32.faderPath(step.channel)}   float ${unit.toStringAsFixed(4)}   (${formatDb(db)})',
          style: const TextStyle(
            color: dim,
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
        Slider(
          value: step.unit == LevelUnit.db
              ? db.clamp(-90, 10).toDouble()
              : unit,
          min: step.unit == LevelUnit.db ? -90 : 0,
          max: step.unit == LevelUnit.db ? 10 : 1,
          onChanged: (value) => onChanged(step.copyWith(value: value)),
        ),
        Row(
          children: [
            Expanded(
              child: _preset(
                '−∞',
                () => onChanged(step.copyWith(unit: LevelUnit.db, value: -90)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _preset(
                '0 dB',
                () => onChanged(step.copyWith(unit: LevelUnit.db, value: 0)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _preset(
                '+10',
                () => onChanged(step.copyWith(unit: LevelUnit.db, value: 10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _preset(String label, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _WaitEditor extends StatefulWidget {
  const _WaitEditor({required this.step, required this.onChanged});

  final WaitStep step;
  final ValueChanged<CueStep> onChanged;

  @override
  State<_WaitEditor> createState() => _WaitEditorState();
}

class _WaitEditorState extends State<_WaitEditor> {
  late final TextEditingController _text = TextEditingController(
    text: '${widget.step.milliseconds}',
  );

  @override
  void didUpdateWidget(_WaitEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = '${widget.step.milliseconds}';
    if ('${oldWidget.step.milliseconds}' != next &&
        _text.text == '${oldWidget.step.milliseconds}') {
      _text.text = next;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _text,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 22, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            labelText: 'Milliseconds',
            suffixText: 'ms',
          ),
          onChanged: (value) {
            final ms = int.tryParse(value);
            if (ms == null || ms > 3600000) return;
            widget.onChanged(widget.step.withMs(ms));
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ms in const [250, 500, 1000, 2000])
              ActionChip(
                label: Text('$ms ms'),
                onPressed: () => widget.onChanged(widget.step.withMs(ms)),
              ),
          ],
        ),
      ],
    );
  }
}

class _OscEditor extends StatefulWidget {
  const _OscEditor({required this.step, required this.onChanged});

  final CustomOscStep step;
  final ValueChanged<CueStep> onChanged;

  @override
  State<_OscEditor> createState() => _OscEditorState();
}

class _OscEditorState extends State<_OscEditor> {
  late final TextEditingController _address = TextEditingController(
    text: widget.step.message.address,
  );
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _setMessage(OscMessage message) =>
      widget.onChanged(widget.step.withMessage(message));

  @override
  Widget build(BuildContext context) {
    final message = widget.step.message;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _address,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
          decoration: InputDecoration(
            labelText: 'OSC address',
            errorText: _error,
            hintText: '/bus/01/mix/on',
          ),
          onChanged: (value) {
            final trimmed = value.trim();
            if (trimmed.isEmpty || !trimmed.startsWith('/')) {
              setState(() => _error = 'Address must start with /');
              return;
            }
            setState(() => _error = null);
            _setMessage(OscMessage(trimmed, message.args));
          },
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < message.args.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ArgRow(
              arg: message.args[i],
              onChanged: (arg) {
                final args = [...message.args];
                args[i] = arg;
                _setMessage(OscMessage(message.address, args));
              },
              onDelete: () {
                final args = [...message.args]..removeAt(i);
                _setMessage(OscMessage(message.address, args));
              },
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _setMessage(
              OscMessage(message.address, [
                ...message.args,
                const OscArg.int32(0),
              ]),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add argument'),
          ),
        ),
        const Text(
          'X32 mute is int 0 (off) or 1 (on). Faders are float 0–1, not dB. Example: /main/st/mix/on with int 0 mutes the stereo bus.',
          style: TextStyle(color: dim, fontSize: 13, height: 1.35),
        ),
      ],
    );
  }
}

class _ArgRow extends StatefulWidget {
  const _ArgRow({
    required this.arg,
    required this.onChanged,
    required this.onDelete,
  });

  final OscArg arg;
  final ValueChanged<OscArg> onChanged;
  final VoidCallback onDelete;

  @override
  State<_ArgRow> createState() => _ArgRowState();
}

class _ArgRowState extends State<_ArgRow> {
  late final TextEditingController _value = TextEditingController(
    text: _initial(widget.arg),
  );

  static String _initial(OscArg arg) {
    switch (arg.type) {
      case OscArgType.int32:
        return '${arg.asInt}';
      case OscArgType.float32:
        return arg.asFloat.toString();
      case OscArgType.string:
        return arg.asString;
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _apply(OscArgType type) {
    final raw = _value.text;
    switch (type) {
      case OscArgType.int32:
        final parsed = int.tryParse(raw.trim());
        if (parsed == null || parsed < -2147483648 || parsed > 2147483647) {
          return;
        }
        widget.onChanged(OscArg.int32(parsed));
      case OscArgType.float32:
        final parsed = double.tryParse(raw.trim());
        if (parsed == null || parsed.isNaN || parsed.isInfinite) return;
        widget.onChanged(OscArg.float32(parsed));
      case OscArgType.string:
        widget.onChanged(OscArg.string(raw));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<OscArgType>(
            initialValue: widget.arg.type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const [
              DropdownMenuItem(value: OscArgType.int32, child: Text('int')),
              DropdownMenuItem(value: OscArgType.float32, child: Text('float')),
              DropdownMenuItem(value: OscArgType.string, child: Text('string')),
            ],
            onChanged: (type) {
              if (type == null) return;
              _apply(type);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: _value,
            decoration: const InputDecoration(labelText: 'Value'),
            onChanged: (_) => _apply(widget.arg.type),
          ),
        ),
        IconButton(
          tooltip: 'Remove argument',
          onPressed: widget.onDelete,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
