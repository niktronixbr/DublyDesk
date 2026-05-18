import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/entitlement_service.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _rememberKey = 'auth_remember_me';
  static const _avatarUrlKey = 'user_avatar_url';
  static const _savedPasswordKey = 'auth_saved_password';

  static Future<void> saveSession({
    required String token,
    required String name,
    required String email,
    bool rememberMe = true,
    String? avatarUrl,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userEmailKey, email);
    await prefs.setBool(_rememberKey, rememberMe);
    if (avatarUrl == null) {
      await prefs.remove(_avatarUrlKey);
    } else {
      await prefs.setString(_avatarUrlKey, avatarUrl);
    }
    if (rememberMe && password != null && password.isNotEmpty) {
      await prefs.setString(_savedPasswordKey, password);
    } else if (!rememberMe) {
      await prefs.remove(_savedPasswordKey);
    }
  }

  static Future<String?> getAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarUrlKey);
  }

  static Future<void> saveAvatarUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(_avatarUrlKey);
    } else {
      await prefs.setString(_avatarUrlKey, url);
    }
  }

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberKey) ?? false;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<bool> hasSavedToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  static Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedPasswordKey);
  }

  static Future<void> clearSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPasswordKey);
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, value);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await EntitlementService.clear();
    await prefs.remove(_userNameKey);
    await prefs.remove(_avatarUrlKey);
    await prefs.remove('schedules_cache');
    await prefs.remove(_savedPasswordKey);
    await prefs.remove(_rememberKey);
    // _userEmailKey mantido para preencher o campo no relogin manual
  }

  static String? parseErrorBody(String body) {
    try {
      final json = jsonDecode(body);
      return json['error']?.toString();
    } catch (_) {
      return null;
    }
  }
}