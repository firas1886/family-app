import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/write.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/family/family_screen.dart';
import '../features/family/onboarding_screen.dart';
import '../features/history/history_screen.dart';
import '../features/lists/lists_screen.dart';
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
              : const _MembershipGuard(child: HomeShell()),
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
        children: const [ListsScreen(), HistoryScreen(), FamilyScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.checklist), label: l.tabLists),
          NavigationDestination(icon: const Icon(Icons.receipt_long), label: l.tabHistory),
          NavigationDestination(icon: const Icon(Icons.group), label: l.tabFamily),
        ],
      ),
    );
  }
}
