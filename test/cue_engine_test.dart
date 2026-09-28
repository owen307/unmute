import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:unmute/engine/cue_engine.dart';
import 'package:unmute/models/cue_step.dart';
import 'package:unmute/models/ids.dart';
import 'package:unmute/models/show.dart';
import 'package:unmute/osc/osc_codec.dart';
import 'package:unmute/osc/osc_message.dart';
import 'package:unmute/state/show_controller.dart';
import 'package:unmute/storage/show_repository.dart';

import 'mock_transport.dart';

void main() {
  test('seed cues apply mute, unmute, and dB in order', () {
    final show = ShowData.seed();
    final pastor = show.cues.singleWhere((cue) => cue.name == 'Pastor only');
    final actions = compileCue(pastor.steps).whereType<SendOsc>().toList();
    expect(actions.first.message.address, '/ch/01/mix/on');
    expect(actions.first.message.args.single.asInt, 1);
    expect(actions[1].message.address, '/ch/02/mix/on');
    expect(actions[1].message.args.single.asInt, 0);
    expect(actions[7].message.address, '/ch/08/mix/on');
    expect(actions.last.message.address, '/ch/01/mix/fader');
    expect(actions.last.message.args.single.asFloat, closeTo(0.75, 1e-9));
    expect(
      actions.any((action) => action.message.address == '/ch/09/mix/on'),
      isFalse,
    );

    final worship = compileCue(show.cues.first.steps)
        .whereType<SendOsc>()
        .map((a) => a.message)
        .toList();
    expect(worship.first.address, '/ch/01/mix/on');
    expect(worship.first.args.single.asInt, 0);
    expect(worship[1].address, '/ch/02/mix/on');
    expect(worship[1].args.single.asInt, 1);

    final band = compileCue(show.cues[2].steps)
        .whereType<SendOsc>()
        .map((a) => a.message)
        .toList();
    expect(band[0].address, '/ch/01/mix/on');
    expect(band[1].address, '/ch/02/mix/on');
    expect(band[0].args.single.asInt, 0);
    expect(band[2].address, '/ch/03/mix/on');
    expect(band[2].args.single.asInt, 1);
  });

  test('wait does not emit and empty unmute is a note', () {
    final actions = compileCue([
      WaitStep(id: 'w', milliseconds: 250),
      UnmuteStep(id: 'u', channels: const []),
    ]);
    expect(actions[0], isA<WaitAction>());
    expect(
      (actions[0] as WaitAction).duration,
      const Duration(milliseconds: 250),
    );
    expect(actions[1], isA<NoteAction>());
  });

  test('custom OSC is passed through and bad addresses are notes', () {
    final ok = compileStep(
      CustomOscStep(
        id: 'c',
        message: const OscMessage('/main/st/mix/on', [OscArg.int32(0)]),
      ),
    );
    expect((ok.single as SendOsc).message.address, '/main/st/mix/on');
    final bad = compileStep(
      CustomOscStep(id: 'b', message: const OscMessage('nope')),
    );
    expect(bad.single, isA<NoteAction>());
  });

  test('cancel during a wait does not send the following step', () async {
    final release = _Gate();
    final runner = CueRunner(delay: (_) => release.future);
    final sent = <String>[];
    final pending = runner.run(
      steps: [
        UnmuteStep(id: 'a', channels: const [1]),
        WaitStep(id: 'w', milliseconds: 5000),
        UnmuteStep(id: 'b', channels: const [2]),
      ],
      send: (message) async => sent.add(message.address),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    runner.cancel();
    release.complete();
    expect(await pending, RunStatus.cancelled);
    expect(sent, ['/ch/01/mix/on']);
  });

  test(
    'dry-run logs the cue and does not touch the transport or restore state',
    () async {
      final transport = MockTransport();
      final controller = ShowController(
        repository: MemoryShowRepository(),
        transport: transport,
        delay: (_) async {},
      );
      await controller.load();
      controller.select(1);
      await controller.go();
      expect(transport.sent, isEmpty);
      expect(controller.commanded.isEmpty, isTrue);
      expect(
        controller.log.every(
          (entry) => entry.dryRun || entry.title.startsWith('WAIT'),
        ),
        isTrue,
      );
      expect(
        controller.log.any(
          (entry) => entry.detail.contains('/ch/01/mix/on   int 1'),
        ),
        isTrue,
      );
      expect(controller.standby, 2);
      controller.dispose();
    },
  );

  test(
    'live GO, panic, and restore replay the commanded channels only',
    () async {
      final transport = MockTransport();
      final controller = ShowController(
        repository: MemoryShowRepository(),
        transport: transport,
        delay: (_) async {},
      );
      await controller.load();
      controller.updateSettings(
        controller.show.settings.copyWith(dryRun: false, host: '10.0.0.8'),
      );
      controller.select(1);
      await controller.go();
      expect(controller.commanded.on[1], isTrue);
      expect(controller.commanded.on[8], isFalse);
      expect(controller.commanded.fader[1], closeTo(0.75, 1e-6));
      expect(controller.commanded.on.containsKey(9), isFalse);

      await controller.allMute();
      expect(controller.panicked, isTrue);
      expect(controller.commanded.on[1], isFalse);
      expect(controller.commanded.on[32], isFalse);
      expect(controller.panicSnapshot!.on[1], isTrue);

      await controller.allMute();
      expect(
        controller.panicSnapshot!.on[1],
        isTrue,
        reason: 'a second panic must not overwrite the pre-mute snapshot',
      );

      final beforeRestore = transport.sent.length;
      await controller.restore();
      final restored = [
        for (final packet in transport.sent.skip(beforeRestore))
          OscCodec.decode(packet),
      ];
      expect(
        restored.any((message) => message.address == '/ch/09/mix/on'),
        isFalse,
      );
      expect(restored.last.address, '/ch/08/mix/on');
      expect(restored.first.address, '/ch/01/mix/fader');
      final pastorOn = restored
          .where((message) => message.address == '/ch/01/mix/on')
          .single;
      expect(pastorOn.args.single.asInt, 1);
      expect(controller.commanded.on[1], isTrue);
      expect(controller.panicked, isFalse);

      final muteAll = transport.sent
          .map(OscCodec.decode)
          .where((message) => message.address == '/ch/32/mix/on')
          .toList();
      expect(muteAll, isNotEmpty);
      expect(muteAll.first.args.single.asInt, 0);
      controller.dispose();
    },
  );

  test('auto-follow fires the next cue after the wait', () async {
    final transport = MockTransport();
    final show = ShowData(
      settings: const ConsoleSettings(
        host: '10.0.0.9',
        port: 10023,
        localPort: null,
        dryRun: false,
      ),
      channelNames: const {},
      cues: [
        Cue(
          id: 'a',
          name: 'First',
          autoFollow: true,
          steps: [
            UnmuteStep(id: 'a1', channels: const [1]),
            WaitStep(id: 'aw', milliseconds: 50),
          ],
        ),
        Cue(
          id: 'b',
          name: 'Second',
          autoFollow: false,
          steps: [MuteStep(id: 'b1', channels: const [2])],
        ),
      ],
    );
    final controller = ShowController(
      repository: MemoryShowRepository(show),
      transport: transport,
      delay: (_) async {},
    );
    await controller.load();
    await controller.go();
    final sent = transport.sent.map(OscCodec.decode).toList();
    expect(sent.map((message) => message.address), [
      '/ch/01/mix/on',
      '/ch/02/mix/on',
    ]);
    expect(sent[0].args.single.asInt, 1);
    expect(sent[1].args.single.asInt, 0);
    controller.dispose();
  });

  test('auto-follow fires the next cue and stop cancels the chain', () async {
    final transport = MockTransport();
    final show = ShowData(
      settings: const ConsoleSettings(
        host: '10.0.0.9',
        port: 10023,
        localPort: null,
        dryRun: false,
      ),
      channelNames: const {},
      cues: [
        Cue(
          id: 'a',
          name: 'First',
          autoFollow: true,
          steps: [
            UnmuteStep(id: 'a1', channels: const [1]),
            WaitStep(id: 'aw', milliseconds: 50),
          ],
        ),
        Cue(
          id: 'b',
          name: 'Second',
          autoFollow: false,
          steps: [
            MuteStep(id: 'b1', channels: const [1]),
          ],
        ),
      ],
    );
    final release = _Gate();
    final controller = ShowController(
      repository: MemoryShowRepository(show),
      transport: transport,
      delay: (_) => release.future,
    );
    await controller.load();
    final going = controller.go();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(transport.sent.map(OscCodec.decode).map((m) => m.address).toList(), [
      '/ch/01/mix/on',
    ]);
    controller.stop();
    release.complete();
    await going;
    expect(transport.sent, hasLength(1));
    expect(controller.runningCueId, isNull);
    controller.dispose();
  });

  test('live GO without an IP does not send', () async {
    final transport = MockTransport();
    final controller = ShowController(
      repository: MemoryShowRepository(),
      transport: transport,
      delay: (_) async {},
    );
    await controller.load();
    controller.updateSettings(controller.show.settings.copyWith(dryRun: false));
    await controller.go();
    expect(transport.sent, isEmpty);
    expect(controller.log.first.ok, isFalse);
    controller.dispose();
  });

  test('ids are unique enough for a tap', () {
    expect(newId('cue'), isNot(newId('cue')));
  });
}

class _Gate {
  final _completer = Completer<void>();

  Future<void> get future => _completer.future;

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
