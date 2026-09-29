import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/chores.dart';
import '../core/dates.dart';
import '../core/member_colors.dart';
import '../core/models.dart';
import '../core/placement.dart';
import '../data/catalog_repository.dart';
import '../data/chore_repository.dart';
import '../data/family_repository.dart';
import '../data/list_repository.dart';
import '../data/purchase_repository.dart';
import '../data/reminder_scheduler.dart';
import '../l10n/app_localizations.dart';

// Platform services — overridden in tests.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final googleSignInProvider = Provider<GoogleSignIn>((ref) => GoogleSignIn());
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

// Auth.
final authUserProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);
final authReadyProvider = Provider<bool>((ref) => !ref.watch(authUserProvider).isLoading);
final currentUidProvider = Provider<String?>((ref) => ref.watch(authUserProvider).valueOrNull?.uid);

/// The signed-in user's Google profile photo (overridden with null in tests).
final authPhotoUrlProvider = Provider<String?>((ref) => ref.watch(authUserProvider).valueOrNull?.photoURL);

// User and family.
final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => FamilyRepository(ref.watch(firestoreProvider)),
);

final appUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchUser(uid);
});

final familyIdProvider = Provider<String?>((ref) => ref.watch(appUserProvider).valueOrNull?.familyId);

/// Null means "follow the phone's language".
final localeProvider = Provider<Locale?>((ref) {
  final language = ref.watch(appUserProvider).valueOrNull?.language;
  return language == null ? null : Locale(language);
});

/// The user's saved theme choice; anything else follows the phone.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(appUserProvider).valueOrNull?.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});

String _requireFamily(Ref ref) {
  final id = ref.watch(familyIdProvider);
  if (id == null) throw StateError('No family selected');
  return id;
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(firestoreProvider), _requireFamily(ref)),
);
final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(ref.watch(firestoreProvider), _requireFamily(ref)),
);
final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (ref) => PurchaseRepository(ref.watch(firestoreProvider), _requireFamily(ref)),
);

final familyProvider = StreamProvider<Family?>(
  (ref) => ref.watch(familyRepositoryProvider).watchFamily(_requireFamily(ref)),
);
final membersProvider = StreamProvider<List<Member>>(
  (ref) => ref.watch(familyRepositoryProvider).watchMembers(_requireFamily(ref)),
);
final myMemberProvider = StreamProvider<Member?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final familyId = ref.watch(familyIdProvider);
  if (uid == null || familyId == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).watchMember(familyId, uid);
});
final isParentProvider = Provider<bool>(
  (ref) => ref.watch(myMemberProvider).valueOrNull?.role == Role.parent,
);

/// uid → palette index for every current member, including members whose
/// colour has not been saved yet.
final memberColorsProvider = Provider<Map<String, int>>((ref) {
  final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
  final missing = missingColorAssignments(members);
  return {for (final m in members) m.uid: m.color ?? missing[m.uid]!};
});

// Shopping data.
final categoriesProvider = StreamProvider<List<ItemCategory>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchCategories(),
);
final itemsProvider = StreamProvider<List<Item>>(
  (ref) => ref.watch(catalogRepositoryProvider).watchItems(),
);
final listsProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(listRepositoryProvider).watchLists(),
);
final entriesProvider = StreamProvider.family<List<Entry>, String>(
  (ref, listId) => ref.watch(listRepositoryProvider).watchEntries(listId),
);
final purchasesProvider = StreamProvider<List<Purchase>>(
  (ref) => ref.watch(purchaseRepositoryProvider).watchPurchases(),
);

// Chores.
final choreRepositoryProvider = Provider<ChoreRepository>(
  (ref) => ChoreRepository(ref.watch(firestoreProvider), _requireFamily(ref)),
);

/// Today's local date at midnight. It moves on by itself just after local
/// midnight, so a screen left open (the wall tablet) never shows yesterday as today.
final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

class TodayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final clock = ref.watch(clockProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    _scheduleNextDay(clock);
    return dayOnly(clock());
  }

  /// One timer at a time, due 1 s after the next local midnight.
  void _scheduleNextDay(DateTime Function() clock) {
    _timer?.cancel();
    final now = clock();
    final next = addDays(dayOnly(now), 1).add(const Duration(seconds: 1));
    _timer = Timer(next.difference(now), () {
      final today = dayOnly(clock());
      if (today != state) state = today;
      _scheduleNextDay(clock);
    });
  }
}

final choresProvider = StreamProvider<List<Chore>>(
  (ref) => ref.watch(choreRepositoryProvider).watchChores(),
);

/// Done records with `date` in `from`..`to` ("YYYY-MM-DD", inclusive).
final choreDoneProvider = StreamProvider.family<List<ChoreDone>, ({String from, String to})>(
  (ref, range) => ref.watch(choreRepositoryProvider).watchDone(fromDate: range.from, toDate: range.to),
);

final sortModeProvider = StateProvider<SortMode>((ref) => SortMode.category);

/// True while Firestore is serving data from the local cache only.
final offlineProvider = StreamProvider<bool>((ref) {
  final familyId = ref.watch(familyIdProvider);
  if (familyId == null) return Stream.value(false);
  return ref
      .watch(firestoreProvider)
      .collection('families')
      .doc(familyId)
      .collection('members')
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.metadata.isFromCache);
});

// Reminders (kept on this phone only).

/// Opened in main() before the app starts; tests override it too.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override in main'),
);

/// A parent's choice to be reminded about everyone's chores, saved on this phone.
class RemindEveryone extends StateNotifier<bool> {
  RemindEveryone(this._prefs) : super(_prefs.getBool(key) ?? false);

  static const key = 'remindEveryone';
  final SharedPreferences _prefs;

  void setOn(bool on) {
    state = on;
    unawaited(_prefs.setBool(key, on));
  }
}

final remindEveryoneProvider = StateNotifierProvider<RemindEveryone, bool>(
  (ref) => RemindEveryone(ref.watch(sharedPreferencesProvider)),
);

/// Real notifications on the phone; tests override it with a fake.
final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  final code = ref.watch(localeProvider)?.languageCode ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l = lookupAppLocalizations(Locale(code == 'ar' ? 'ar' : 'en'));
  final names = {
    for (final m in ref.watch(membersProvider).valueOrNull ?? const <Member>[]) m.uid: m.name,
  };
  return LocalReminderScheduler(
    channelName: l.remindersChannel,
    bodyFor: (r) => l.reminderBody(
      r.assignee == null ? l.anyone : names[r.assignee] ?? l.formerMember,
    ),
  );
});
