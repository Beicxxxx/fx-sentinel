import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AlertStore {
  static const _key = 'fx_alerts_v1';
  static const cooldownMs = 4 * 60 * 60 * 1000;

  Future<List<AlertRule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => AlertRule.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> save(List<AlertRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(rules.map((e) => e.toJson()).toList()));
  }
}

class SettingsStore {
  Future<String> getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? '';
  }

  Future<void> setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
