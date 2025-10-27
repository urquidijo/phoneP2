import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: const String.fromEnvironment(
            'FIREBASE_ANDROID_API_KEY',
            defaultValue: 'demo-android-api-key',
          ),
          appId: const String.fromEnvironment(
            'FIREBASE_ANDROID_APP_ID',
            defaultValue: '1:000000000000:android:demo',
          ),
          messagingSenderId: const String.fromEnvironment(
            'FIREBASE_SENDER_ID',
            defaultValue: '000000000000',
          ),
          projectId: const String.fromEnvironment(
            'FIREBASE_PROJECT_ID',
            defaultValue: 'demo-project',
          ),
          storageBucket: const String.fromEnvironment(
            'FIREBASE_STORAGE_BUCKET',
            defaultValue: 'demo-project.appspot.com',
          ),
        );
      case TargetPlatform.iOS:
        return FirebaseOptions(
          apiKey: const String.fromEnvironment(
            'FIREBASE_IOS_API_KEY',
            defaultValue: 'demo-ios-api-key',
          ),
          appId: const String.fromEnvironment(
            'FIREBASE_IOS_APP_ID',
            defaultValue: '1:000000000000:ios:demo',
          ),
          messagingSenderId: const String.fromEnvironment(
            'FIREBASE_SENDER_ID',
            defaultValue: '000000000000',
          ),
          projectId: const String.fromEnvironment(
            'FIREBASE_PROJECT_ID',
            defaultValue: 'demo-project',
          ),
          storageBucket: const String.fromEnvironment(
            'FIREBASE_STORAGE_BUCKET',
            defaultValue: 'demo-project.appspot.com',
          ),
          iosBundleId: const String.fromEnvironment(
            'FIREBASE_IOS_BUNDLE_ID',
            defaultValue: 'com.example.phone',
          ),
        );
      default:
        return FirebaseOptions(
          apiKey: const String.fromEnvironment(
            'FIREBASE_API_KEY',
            defaultValue: 'demo-api-key',
          ),
          appId: const String.fromEnvironment(
            'FIREBASE_APP_ID',
            defaultValue: '1:000000000000:web:demo',
          ),
          messagingSenderId: const String.fromEnvironment(
            'FIREBASE_SENDER_ID',
            defaultValue: '000000000000',
          ),
          projectId: const String.fromEnvironment(
            'FIREBASE_PROJECT_ID',
            defaultValue: 'demo-project',
          ),
        );
    }
  }
}
