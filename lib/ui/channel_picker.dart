import 'package:flutter/material.dart';

import '../models/channel_list.dart';
import '../models/show.dart';
import '../osc/x32.dart';
import '../theme.dart';

class ChannelPicker extends StatefulWidget {
  const ChannelPicker({
    super.key,
    required this.show,
    required this.channels,
    required this.onChanged,
    this.single = false,
  });

  final ShowData show;
  final List<int> channels;
  final ValueChanged<List<int>> onChanged;
  final bool single;

  @override
  State<ChannelPicker> createState() => _ChannelPickerState();
}

class _ChannelPickerState extends State<ChannelPicker> {
  late final TextEditingController _text = TextEditingController(
    text: formatChannelList(widget.channels),
  );
  String? _error;

  @override
  void didUpdateWidget(ChannelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = formatChannelList(widget.channels);
    final previous = formatChannelList(oldWidget.channels);
    if (next != previous && _text.text == previous) {
      _text.text = next;
      _error = null;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    try {
      final parsed = parseChannelList(raw);
      setState(() => _error = null);
      widget.onChanged(
        widget.single ? (parsed.isEmpty ? const [] : [parsed.last]) : parsed,
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  void _toggle(int channel) {
    if (widget.single) {
      widget.onChanged([channel]);
      return;
    }
    final next = [...widget.channels];
    if (next.contains(channel)) {
      next.remove(channel);
    } else {
      next.add(channel);
    }
    widget.onChanged(next);
  }

  void _addRange(int start, int end) {
    final next = [...widget.channels];
    for (var n = start; n <= end; n++) {
      if (!next.contains(n)) next.add(n);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final named = widget.show.channelNames.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (named.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in named)
                _chip(
                  label: '${entry.value} ${entry.key}',
                  selected: widget.channels.contains(entry.key),
                  onSelected: () => _toggle(entry.key),
                ),
            ],
          ),
        if (!widget.single) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final range in const [(1, 8), (9, 16), (17, 24), (25, 32)])
                ActionChip(
                  label: Text('${range.$1}–${range.$2}'),
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  onPressed: () => _addRange(range.$1, range.$2),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _text,
          keyboardType: TextInputType.text,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontSize: 18, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: widget.single ? 'Channel number' : 'Channels',
            hintText: widget.single ? '1' : '1-4, 8',
            errorText: _error,
          ),
          onChanged: _commit,
        ),
        if (widget.channels.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.channels.map(widget.show.labelFor).join(', '),
            style: const TextStyle(color: dim, fontSize: 14),
          ),
        ],
        if (widget.single)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Inputs 1–${X32.channelCount}.',
              style: const TextStyle(color: dim, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? goInk : paper,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return goYellow;
        return panelRaised;
      }),
      side: BorderSide(color: selected ? goYellow : line),
      onSelected: (_) => onSelected(),
    );
  }
}
