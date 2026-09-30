import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app/app.dart';
import 'app/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // reads android/app/google-services.json
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  await initTimeZone();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const FamilyApp(),
  ));
}

/// Reminders are scheduled in the phone's own time zone. If the phone doesn't
/// answer within [timeout], or names a zone the database doesn't know,
/// tz.local stays UTC, so start-up never waits on it.
Future<void> initTimeZone({
  Future<String> Function() lookup = _phoneTimeZone,
  Duration timeout = const Duration(seconds: 3),
}) async {
  tzdata.initializeTimeZones();
  try {
    final zone = await lookup().timeout(timeout);
    tz.setLocalLocation(tz.getLocation(zone));
  } catch (error) {
    // No answer in time, or an unknown zone name: tz.local stays UTC. Reminders
    // still fire at the right moment, because TZDateTime.from keeps the same instant.
    debugPrint('Could not set the local time zone: $error');
  }
}

Future<String> _phoneTimeZone() async => (await FlutterTimezone.getLocalTimezone()).identifier;
