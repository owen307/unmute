import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/show.dart';

abstract class ShowRepository {
  Future<ShowData?> load();

  Future<void> save(ShowData show);
}

class MemoryShowRepository implements ShowRepository {
  MemoryShowRepository([ShowData? initial]) : _show = initial;

  ShowData? _show;

  @override
  Future<ShowData?> load() async => _show;

  @override
  Future<void> save(ShowData show) async {
    _show = show;
  }
}

/// On-device JSON. Android stores this in SharedPreferences. No account.
class PrefsShowRepository implements ShowRepository {
  PrefsShowRepository(this.prefs);

  final SharedPreferences prefs;

  static const storageKey = 'unmute.show.v1';
  static const backupKey = 'unmute.show.v1.bak';

  @override
  Future<ShowData?> load() async {
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Show file is not an object.');
      }
      return ShowData.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      await prefs.setString(backupKey, raw);
      return null;
    }
  }

  @override
  Future<void> save(ShowData show) async {
    final encoded = const JsonEncoder.withIndent('  ').convert(show.toJson());
    await prefs.setString(storageKey, encoded);
  }
}
