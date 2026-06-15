import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/fcm_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage _) async {
  // Firebase is already initialized by the plugin in the background isolate.
  // No work needed here — the Firestore stream updates the UI when the app resumes.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    firebaseReady = true;
  } catch (_) {
    // firebase_options.dart is still the placeholder — show the setup screen.
  }
  runApp(firebaseReady ? const ProviderScope(child: RentGoApp()) : const FirebaseSetupApp());
}

class RentGoApp extends ConsumerWidget {
  const RentGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fcmInitProvider); // activates FCM token registration on login
    return MaterialApp.router(
      title: 'RentGo',
      theme: AppTheme.light(),
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Shown when Firebase is not configured yet, instead of crashing at startup.
class FirebaseSetupApp extends StatelessWidget {
  const FirebaseSetupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department, size: 64),
                SizedBox(height: 24),
                Text('Firebase is not configured yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                SizedBox(height: 12),
                Text(
                  'Run these commands from the project root, then restart the app:\n\n'
                  'dart pub global activate flutterfire_cli\n'
                  'flutterfire configure',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
