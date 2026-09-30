import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/data/reminder_scheduler.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_scheduler.dart';

final testNow = DateTime(2026, 10, 1, 12);

/// Lets fake Firestore streams deliver without waiting for SnackBar timers.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pumpWithFamily(
  WidgetTester tester, {
  required FakeFirebaseFirestore db,
  required Widget child,
  String uid = 'u1',
  String? photoUrl,
  String? authName,
  Locale locale = const Locale('en'),
  ReminderScheduler? scheduler,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      currentUidProvider.overrideWithValue(uid),
      authReadyProvider.overrideWithValue(true),
      clockProvider.overrideWithValue(() => testNow),
      sharedPreferencesProvider.overrideWithValue(prefs),
      reminderSchedulerProvider.overrideWithValue(scheduler ?? FakeReminderScheduler()),
      // Tests have no FirebaseAuth; the Google photo comes from here instead.
      authPhotoUrlProvider.overrideWithValue(photoUrl),
      // The Google account's name, for ProfileSync's blank-name repair.
      authDisplayNameProvider.overrideWithValue(authName),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  ));
  await settle(tester);
}
