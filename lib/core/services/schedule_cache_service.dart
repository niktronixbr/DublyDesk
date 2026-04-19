import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_model.dart';

class ScheduleCacheService {
  static const _key = 'schedules_cache';

  static Future<void> save(List<ScheduleModel> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(schedules.map((s) => s.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static Future<List<ScheduleModel>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ScheduleModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
