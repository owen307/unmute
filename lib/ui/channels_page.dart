import 'package:flutter/material.dart';

import '../osc/x32.dart';
import '../state/show_controller.dart';
import '../theme.dart';

class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key, required this.controller});

  final ShowController controller;

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  late final List<TextEditingController> _fields = [
    for (var channel = 1; channel <= X32.channelCount; channel++)
      TextEditingController(
        text: widget.controller.show.channelNames[channel] ?? '',
      ),
  ];

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'CHANNELS',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'Names are for this phone only. They are not written to the console. Empty rows stay “Ch 12” in cues.',
            style: TextStyle(color: dim, fontSize: 15, height: 1.35),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: X32.channelCount,
            itemBuilder: (context, index) {
              final channel = index + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: line),
                      ),
                      child: Text(
                        channel.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _fields[index],
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 18),
                        decoration: const InputDecoration(hintText: 'Name'),
                        onChanged: (value) =>
                            widget.controller.setChannelName(channel, value),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
