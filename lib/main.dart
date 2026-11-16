import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'core/config.dart';
import 'data/workspace.dart';
import 'screens/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String? error;
  FirebaseApp? firebaseApp;
  if (AppConfig.configured) {
    try {
      final options = AppConfig.options;
      if (options.projectId != 'dormfinder-sulu' &&
          !(AppConfig.useEmulators &&
              options.projectId == 'demo-lalago-work')) {
        throw StateError(
          'This build is restricted to the approved dormfinder-sulu test project.',
        );
      }
      final app = await Firebase.initializeApp(
        name: AppConfig.useEmulators ? 'lalago-demo' : null,
        options: options,
      );
      firebaseApp = app;
      if (AppConfig.useEmulators) {
        await FirebaseAuth.instanceFor(
          app: app,
        ).useAuthEmulator('127.0.0.1', 9099);
        FirebaseFirestore.instanceFor(
          app: app,
        ).useFirestoreEmulator('127.0.0.1', 8085);
      }
    } catch (e) {
      error = 'Firebase initialization failed: $e';
      debugPrint(error);
    }
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => Workspace(
        connected: AppConfig.configured && error == null,
        firebaseApp: firebaseApp,
      ),
      child: WorkApp(setupError: error),
    ),
  );
}
