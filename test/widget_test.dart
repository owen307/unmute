import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unmute/main.dart';
import 'package:unmute/state/show_controller.dart';
import 'package:unmute/storage/show_repository.dart';

import 'mock_transport.dart';

void main() {
  testWidgets('cue list fires the standby cue in test mode', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final transport = MockTransport();
    final controller = ShowController(
      repository: MemoryShowRepository(),
      transport: transport,
      delay: (_) async {},
    );
    await controller.load();
    addTearDown(controller.dispose);

    await tester.pumpWidget(UnmuteApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Worship team on'), findsOneWidget);
    expect(find.text('Pastor only'), findsOneWidget);
    expect(find.text('Band + vocal'), findsOneWidget);
    expect(find.textContaining('TEST MODE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('go-button')));
    await tester.pumpAndSettle();

    expect(transport.sent, isEmpty);
    expect(
      controller.log.any(
        (entry) => entry.dryRun && entry.detail.contains('/ch/02/mix/on'),
      ),
      isTrue,
    );

    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    expect(find.textContaining('/ch/'), findsWidgets);
    expect(find.text('DRY'), findsWidgets);
  });
}
