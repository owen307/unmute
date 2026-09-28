import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unmute/models/show.dart';
import 'package:unmute/storage/show_repository.dart';

void main() {
  test('show JSON round-trips the example cues', () {
    final show = ShowData.seed();
    final again = ShowData.fromJson(
      jsonDecode(jsonEncode(show.toJson())) as Map<String, dynamic>,
    );
    expect(again.cues.map((cue) => cue.name), [
      'Worship team on',
      'Pastor only',
      'Band + vocal',
    ]);
    expect(again.channelNames[1], 'Pastor');
    expect(again.settings.dryRun, isTrue);
    expect(again.settings.port, 10023);
  });

  test('a corrupt save is backed up and the next load can reseed', () async {
    SharedPreferences.setMockInitialValues({'unmute.show.v1': '{not json'});
    final prefs = await SharedPreferences.getInstance();
    final repo = PrefsShowRepository(prefs);
    expect(await repo.load(), isNull);
    expect(prefs.getString(PrefsShowRepository.backupKey), '{not json');
    final seeded = ShowData.seed();
    await repo.save(seeded);
    final loaded = await repo.load();
    expect(loaded!.cues, hasLength(3));
  });
}
