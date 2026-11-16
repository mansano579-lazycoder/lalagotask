import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

abstract final class AppConfig {
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const bucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static bool get configured =>
      kIsWeb ||
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  static FirebaseOptions get options => useEmulators
      ? const FirebaseOptions(
          apiKey: 'demo-key',
          appId: '1:1234567890:web:lalagoemulator',
          messagingSenderId: '1234567890',
          projectId: 'demo-lalago-work',
          authDomain: 'localhost',
        )
      : apiKey.isEmpty
      ? DefaultFirebaseOptions.currentPlatform
      : const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: 'dormfinder-sulu',
          authDomain: 'dormfinder-sulu.firebaseapp.com',
          storageBucket: bucket,
        );
}
