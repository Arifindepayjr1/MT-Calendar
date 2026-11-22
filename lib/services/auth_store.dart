import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trader_log/model/auth.model.dart';

const String _tokenKey = 'traderlog_jwt_token';
const String _userKey = 'traderlog_jwt_user';

/// Holds the current JWT session and optionally persists it locally.
///
/// The app creates an instance with SharedPreferences; tests can use
/// [AuthStore.inMemory] to avoid platform channels.
class AuthStore extends ChangeNotifier {
  final SharedPreferences? preferences;
  final bool persist;

  AuthStore({this.preferences, this.persist = true});

  factory AuthStore.inMemory() => AuthStore(persist: false);

  String? _token;
  AuthUser? _user;
  bool _initialized = false;

  String? get token => _token;
  AuthUser? get user => _user;
  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!persist) return;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      final storedUser = prefs.getString(_userKey);
      if (storedUser != null) {
        final decoded = jsonDecode(storedUser) as Map<String, dynamic>;
        _user = AuthUser.fromJson(decoded);
      }
    } catch (_) {
      // Platform channels are unavailable in some environments; the in-memory
      // session still works for the current app run.
    }
    notifyListeners();
  }

  Future<void> saveSession(AuthSession session) async {
    _token = session.accessToken;
    _user = session.user;
    notifyListeners();
    await _persistSession();
  }

  Future<void> clear() async {
    _token = null;
    _user = null;
    notifyListeners();
    if (!persist) return;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (_) {
      // Ignore storage failures; the in-memory session is already cleared.
    }
  }

  Future<void> _persistSession() async {
    if (!persist || _token == null || _user == null) return;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      await prefs.setString(_userKey, jsonEncode(_user!.toJson()));
    } catch (_) {
      // Ignore storage failures; the in-memory session remains active.
    }
  }
}
