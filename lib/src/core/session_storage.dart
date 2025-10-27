import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class SessionStorage {
  SessionStorage._internal();

  static final SessionStorage instance = SessionStorage._internal();

  static const _tokenKey = 'session_token';
  static const _cartKey = 'cart_items';

  SharedPreferences? _prefs;

  Future<void> ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> saveToken(String token) async {
    await ensureInitialized();
    await _prefs!.setString(_tokenKey, token);
  }

  Future<String?> readToken() async {
    await ensureInitialized();
    return _prefs!.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    await ensureInitialized();
    await _prefs!.remove(_tokenKey);
  }

  Future<void> saveCart(List<CartItem> items) async {
    await ensureInitialized();
    final payload = items.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs!.setStringList(_cartKey, payload);
  }

  Future<List<CartItem>> loadCart() async {
    await ensureInitialized();
    final raw = _prefs!.getStringList(_cartKey) ?? const [];
    return raw
        .map((entry) => CartItem.fromJson(jsonDecode(entry) as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearCart() async {
    await ensureInitialized();
    await _prefs!.remove(_cartKey);
  }
}
