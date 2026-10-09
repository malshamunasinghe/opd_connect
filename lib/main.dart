import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/app_settings.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    // Offline persistence: the last known queue position stays on screen
    // when the hospital Wi-Fi drops (M02 recommendation, Priority 3).
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  } catch (e) {
    runApp(SetupErrorApp(message: e.toString()));
    return;
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: const OpdApp(),
    ),
  );
}

/// Shown only if Firebase has not been configured on this build.
class SetupErrorApp extends StatelessWidget {
  final String message;
  const SetupErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings_suggest, size: 64),
                  const SizedBox(height: 16),
                  const Text('Firebase setup required', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
}
