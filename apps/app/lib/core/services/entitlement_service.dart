import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entitlement_model.dart';
import 'api_service.dart';
import 'pro_notifications_service.dart';

class EntitlementService {
  static const _cacheKey = 'entitlement_cache';
  static const _cacheTtl = Duration(minutes: 15);

  static final ValueNotifier<EntitlementModel> _current =
      ValueNotifier(const EntitlementModel.free());
  static DateTime? _lastFetched;

  static ValueListenable<EntitlementModel> get current => _current;

  static bool get isPro => _current.value.pro;

  static Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _current.value = EntitlementModel.fromJson(json);
    } catch (e) {
      debugPrint('EntitlementService.loadCached parse error: $e');
    }
  }

  static Future<EntitlementModel> refresh({bool force = false}) async {
    if (!force &&
        _lastFetched != null &&
        DateTime.now().difference(_lastFetched!) < _cacheTtl) {
      return _current.value;
    }
    final response = await ApiService.get('/me/entitlements');
    if (response['success'] == true && response['data'] is Map) {
      await updateFromJson(response['data'] as Map<String, dynamic>);
      _lastFetched = DateTime.now();
    }
    return _current.value;
  }

  static Future<void> updateFromJson(Map<String, dynamic> json) async {
    final model = EntitlementModel.fromJson(json);
    _current.value = model;
    ProNotificationsService.scheduleTrialReminders(model); // fire-and-forget
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(json));
  }

  static Future<void> clear() async {
    _current.value = const EntitlementModel.free();
    _lastFetched = null;
    await ProNotificationsService.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  @visibleForTesting
  static void resetForTesting() {
    _current.value = const EntitlementModel.free();
    _lastFetched = null;
  }
}
