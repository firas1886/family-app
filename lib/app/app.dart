import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../core/member_colors.dart';
import '../core/models.dart';
import '../core/reminders.dart';
import '../data/write.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/chores/chores_screen.dart';
import '../features/common/dialogs.dart';
import '../features/family/family_screen.dart';
import '../features/family/onboarding_screen.dart';
import '../features/lists/lists_screen.dart';
import '../features/today/today_screen.dart';
import '../l10n/app_localizations.dart';
import 'providers.dart';
import 'theme.dart';

class FamilyApp extends ConsumerWidget {
  const FamilyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Family',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RootGate(),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(authReadyProvider)) return const _Loading();
    final uid = ref.watch(currentUidProvider);
    if (uid == null || uid.isEmpty) return const SignInScreen();
    return ref.watch(appUserProvider).when(
          loading: () => const _Loading(),
          error: (_, __) => const _Loading(),
          data: (user) => user?.familyId == null
              ? const OnboardingScreen()
              : const _MembershipGuard(child: ProfileSync(child: ReminderSync(child: HomeShell()))),
        );
  }
}

/// If this user was removed from the family on another phone, clear their familyId.
class _MembershipGuard extends ConsumerWidget {
  const _MembershipGuard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myMemberProvider).when(
          loading: () => const _Loading(),
          error: (_, __) => const _Loading(),
          data: (member) {
            if (member != null) return child;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final uid = ref.read(currentUidProvider);
              if (uid != null) fireAndForget(ref.read(familyRepositoryProvider).clearFamily(uid));
            });
            return const _Loading();
          },
        );
  }
}

/// Keeps member profiles tidy once the family has loaded:
/// saves my Google photo on my member doc, fills in my name from my Google
/// account when it is blank (on my member doc and my user doc), and (parents
/// only) gives a colour to every member who has none yet.
class ProfileSync extends ConsumerStatefulWidget {
  const ProfileSync({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ProfileSync> createState() => _ProfileSyncState();
}

class _ProfileSyncState extends ConsumerState<ProfileSync> {
  /// Blank-name repairs already sent from this screen. Each is sent at most
  /// once, so a write the server refuses (for example before the new rules
  /// are deployed) is not retried in a loop.
  final _nameRepairsSent = <String>{};

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(membersProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);
    final familyId = ref.watch(familyIdProvider);
    final photoUrl = ref.watch(authPhotoUrlProvider);
    final authName = ref.watch(authDisplayNameProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final isParent = ref.watch(isParentProvider);
    if (members != null && uid != null && familyId != null &&
        (_needsSync(members, uid, photoUrl, isParent) ||
            _memberNameToRepair(members, familyId, uid, authName) ||
            _userNameToRepair(user, uid, authName))) {
      // Writes happen after the frame, never during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latest = ref.read(membersProvider).valueOrNull;
        if (latest == null) return;
        final repo = ref.read(familyRepositoryProvider);
        final me = latest.where((m) => m.uid == uid).firstOrNull;
        if (me != null && photoUrl != null && me.photoUrl != photoUrl) {
          fireAndForget(repo.setPhotoUrl(familyId, uid, photoUrl));
        }
        if (authName != null && _memberNameToRepair(latest, familyId, uid, authName)) {
          _nameRepairsSent.add(_memberKey(familyId, uid));
          fireAndForget(repo.setMemberName(familyId, uid, authName));
        }
        if (authName != null && _userNameToRepair(ref.read(appUserProvider).valueOrNull, uid, authName)) {
          _nameRepairsSent.add(_userKey(uid));
          fireAndForget(repo.setUserName(uid, authName));
        }
        if (isParent) {
          for (final entry in missingColorAssignments(latest).entries) {
            fireAndForget(repo.setColor(familyId, entry.key, entry.value));
          }
        }
      });
    }
    return widget.child;
  }

  static String _memberKey(String familyId, String uid) => 'member:$familyId/$uid';
  static String _userKey(String uid) => 'user:$uid';

  /// My member doc's name is blank, the account has a name, and no repair
  /// has been sent yet. A name that isn't blank is never overwritten.
  bool _memberNameToRepair(List<Member> members, String familyId, String uid, String? authName) {
    final me = members.where((m) => m.uid == uid).firstOrNull;
    return authName != null &&
        me != null &&
        me.name.trim().isEmpty &&
        !_nameRepairsSent.contains(_memberKey(familyId, uid));
  }

  /// The same for my user doc.
  bool _userNameToRepair(AppUser? user, String uid, String? authName) =>
      authName != null &&
      user != null &&
      user.uid == uid &&
      user.name.trim().isEmpty &&
      !_nameRepairsSent.contains(_userKey(uid));

  static bool _needsSync(List<Member> members, String uid, String? photoUrl, bool isParent) {
    final me = members.where((m) => m.uid == uid).firstOrNull;
    final photoChanged = me != null && photoUrl != null && me.photoUrl != photoUrl;
    final colorsMissing = isParent && members.any((m) => m.color == null);
    return photoChanged || colorsMissing;
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [TodayScreen(), ChoresScreen(), ListsScreen(), FamilyScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l.tabToday),
          NavigationDestination(icon: const Icon(Icons.task_alt), label: l.tabChores),
          NavigationDestination(icon: const Icon(Icons.checklist), label: l.tabLists),
          NavigationDestination(icon: const Icon(Icons.group), label: l.tabFamily),
        ],
      ),
    );
  }
}

/// Keeps this phone's chore reminders in step with the chores while the app
/// runs: on start, and whenever chores, done records, the signed-in person or
/// the "remind me about everyone" choice change.
class ReminderSync extends ConsumerStatefulWidget {
  const ReminderSync({super.key, required this.child});
  final Widget child;

  /// Set once this phone has been asked for the notification permission.
  static const askedKey = notificationsAskedKey;

  @override
  ConsumerState<ReminderSync> createState() => _ReminderSyncState();
}

class _ReminderSyncState extends ConsumerState<ReminderSync> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The midnight timer can fire late on a sleeping phone, so check the date
    // again whenever the app comes back to the foreground. This is the app's
    // only resume listener: it lives as long as the signed-in session, while
    // Today's widgets can be scrolled away and disposed.
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(todayProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUidProvider);
    final today = ref.watch(todayProvider);
    final chores = ref.watch(choresProvider).valueOrNull;
    final done = ref
        .watch(choreDoneProvider((from: dateKey(today), to: dateKey(addDays(today, 7)))))
        .valueOrNull;
    final everyone = ref.watch(isParentProvider) && ref.watch(remindEveryoneProvider);
    final scheduler = ref.watch(reminderSchedulerProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final now = ref.watch(clockProvider)();
    if (me != null && me.isNotEmpty && chores != null && done != null) {
      final plan = planReminders(chores: chores, done: done, me: me, everyone: everyone, now: now);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fireAndForget(scheduler.replaceAll(plan));
        // Ask once, the first time this phone has something to remind about
        // (for example a child whose parent switched a reminder on). Same
        // flow as the chore sheet: a "no" gets the explanation.
        if (plan.isNotEmpty && mounted) {
          unawaited(askReminderPermission(context, scheduler, prefs, firstTimeOnly: true));
        }
      });
    }
    return widget.child;
  }
}
