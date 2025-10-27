import 'package:flutter/foundation.dart';

import '../core/api_service.dart';
import '../core/models.dart';
import '../core/session_storage.dart';

class SessionController extends ChangeNotifier {
  SessionController({
    ApiService? apiService,
    SessionStorage? storage,
  })  : _api = apiService ?? ApiService.instance,
        _storage = storage ?? SessionStorage.instance;

  final ApiService _api;
  final SessionStorage _storage;

  User? _user;
  String? _token;
  bool _loading = true;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _loading;
  bool get isAuthenticated => _user != null && _token != null;

  Future<void> bootstrap() async {
    _loading = true;
    notifyListeners();
    final storedToken = await _storage.readToken();
    if (storedToken == null) {
      _loading = false;
      notifyListeners();
      return;
    }
    _token = storedToken;
    _api.attachAuthToken(storedToken);
    try {
      _user = await _api.me();
    } catch (_) {
      await _storage.clearToken();
      _token = null;
      _user = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> login(LoginPayload payload) async {
    try {
      final response = await _api.login(payload);
      await _setSession(response.token, response.user);
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (error) {
      return 'No pudimos iniciar sesion: $error';
    }
  }

  Future<String?> register(RegisterPayload payload) async {
    try {
      await _api.register(payload);
      final loginError = await login(
        LoginPayload(username: payload.username, password: payload.password),
      );
      return loginError;
    } on ApiException catch (error) {
      return error.message;
    } catch (error) {
      return 'No pudimos registrar la cuenta: $error';
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // ignore
    }
    await _storage.clearToken();
    _token = null;
    _user = null;
    _api.attachAuthToken(null);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_token == null) return;
    try {
      _user = await _api.me();
      notifyListeners();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _setSession(String token, User user) async {
    _token = token;
    _user = user;
    _api.attachAuthToken(token);
    await _storage.saveToken(token);
    notifyListeners();
  }
}
