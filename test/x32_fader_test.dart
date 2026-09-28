import 'package:flutter_test/flutter_test.dart';
import 'package:unmute/osc/x32.dart';

void main() {
  test('breakpoints match the X32 fader law', () {
    expect(unitIntervalToDb(0), -90);
    expect(unitIntervalToDb(0.0625), closeTo(-60, 1e-9));
    expect(unitIntervalToDb(0.25), closeTo(-30, 1e-9));
    expect(unitIntervalToDb(0.5), closeTo(-10, 1e-9));
    expect(unitIntervalToDb(0.75), closeTo(0, 1e-9));
    expect(unitIntervalToDb(1), 10);

    expect(dbToUnitInterval(-90), 0);
    expect(dbToUnitInterval(-60), closeTo(0.0625, 1e-12));
    expect(dbToUnitInterval(-30), closeTo(0.25, 1e-12));
    expect(dbToUnitInterval(-10), closeTo(0.5, 1e-12));
    expect(dbToUnitInterval(0), closeTo(0.75, 1e-12));
    expect(dbToUnitInterval(10), 1);
  });

  test('dB outside the fader range clamps', () {
    expect(dbToUnitInterval(-120), 0);
    expect(dbToUnitInterval(12), 1);
  });

  test('dB and float are inverses across the scale', () {
    for (var db = -90.0; db <= 10; db += 0.5) {
      final unit = dbToUnitInterval(db);
      expect(unit, inInclusiveRange(0, 1));
      expect(unitIntervalToDb(unit), closeTo(db <= -90 ? -90 : db, 1e-6));
    }
  });

  test('bottom of the scale formats as infinity', () {
    expect(formatDb(-90), '−∞ dB');
    expect(formatDb(unitIntervalToDb(0)), '−∞ dB');
    expect(formatDb(0), '0.0 dB');
    expect(formatDb(10), '+10.0 dB');
  });

  test('paths are zero padded and reject channel 0 and 33', () {
    expect(X32.onPath(1), '/ch/01/mix/on');
    expect(X32.faderPath(32), '/ch/32/mix/fader');
    expect(() => X32.onPath(0), throwsArgumentError);
    expect(() => X32.faderPath(33), throwsArgumentError);
  });
}
