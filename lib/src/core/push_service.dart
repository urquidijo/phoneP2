import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // background init best-effort
  }
}

class PushService {
  PushService._internal();

  static final PushService instance = PushService._internal();

  final StreamController<RemoteMessage> _messages = StreamController.broadcast();
  bool _initialized = false;
  bool _permissionGranted = false;
  String? _token;

  Stream<RemoteMessage> get stream => _messages.stream;
  String? get token => _token;
  bool get permissionGranted => _permissionGranted;

  Future<bool> initialize() async {
    if (_initialized) return _permissionGranted;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (error) {
      debugPrint('Firebase init skipped: $error');
      return false;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    _permissionGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (_permissionGranted) {
      try {
        _token = await messaging.getToken();
        debugPrint('FCM token: $_token');
      } catch (error) {
        debugPrint('No pudimos obtener el token de FCM: $error');
      }
    }

    FirebaseMessaging.onMessage.listen(_messages.add);
    FirebaseMessaging.onMessageOpenedApp.listen(_messages.add);
    _initialized = true;
    return _permissionGranted;
  }

  void dispose() {
    _messages.close();
  }
}
