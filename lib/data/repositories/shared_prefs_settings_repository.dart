import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'settings_repository.dart';

class SharedPrefsSettingsRepository implements SettingsRepository {
  @override
  Future<T?> readJsonValue<T>(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) {
      return null;
    }
    return jsonDecode(raw) as T;
  }

  @override
  Future<void> writeJsonValue(String key, Object? value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }
}
