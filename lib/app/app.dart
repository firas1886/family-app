import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/member_colors.dart';
import '../core/models.dart';
import '../data/write.dart';
import '../features/auth/sign_in_screen.dart';
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
              : const _MembershipGuard(child: ProfileSync(child: HomeShell())),
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
/// saves my Google photo on my member doc, and (parents only) gives a colour
/// to every member who has none yet.
class ProfileSync extends ConsumerWidget {
  const ProfileSync({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider).valueOrNull;
    final uid = ref.watch(currentUidProvider);
    final familyId = ref.watch(familyIdProvider);
    final photoUrl = ref.watch(authPhotoUrlProvider);
    final isParent = ref.watch(isParentProvider);
    if (members != null && uid != null && familyId != null &&
        _needsSync(members, uid, photoUrl, isParent)) {
      // Writes happen after the frame, never during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final latest = ref.read(membersProvider).valueOrNull;
        if (latest == null) return;
        final repo = ref.read(familyRepositoryProvider);
        final me = latest.where((m) => m.uid == uid).firstOrNull;
        if (me != null && photoUrl != null && me.photoUrl != photoUrl) {
          fireAndForget(repo.setPhotoUrl(familyId, uid, photoUrl));
        }
        if (isParent) {
          for (final entry in missingColorAssignments(latest).entries) {
            fireAndForget(repo.setColor(familyId, entry.key, entry.value));
          }
        }
      });
    }
    return child;
  }

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
        children: const [TodayScreen(), ListsScreen(), FamilyScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l.tabToday),
          NavigationDestination(icon: const Icon(Icons.checklist), label: l.tabLists),
          NavigationDestination(icon: const Icon(Icons.group), label: l.tabFamily),
        ],
      ),
    );
  }
}
