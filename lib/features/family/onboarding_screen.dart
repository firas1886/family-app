import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/family_repository.dart';
import '../../l10n/app_localizations.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _familyName = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _familyName.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Creating or joining needs the server, so these writes are awaited with a timeout.
  Future<void> _run(Future<void> Function(FamilyRepository repo, String uid, String name) action) async {
    final l = AppLocalizations.of(context)!;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final name = ref.read(appUserProvider).valueOrNull?.name ?? '';
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      await action(ref.read(familyRepositoryProvider), uid, name).timeout(const Duration(seconds: 20));
    } on JoinCodeNotFound {
      error = l.joinCodeNotFound;
    } on TimeoutException {
      error = l.needsConnection;
    } catch (_) {
      error = l.somethingWentWrong;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.createFamily, style: Theme.of(context).textTheme.titleMedium),
                  TextField(
                    key: const Key('familyNameField'),
                    controller: _familyName,
                    decoration: InputDecoration(labelText: l.familyName),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('createFamilyButton'),
                    onPressed: _busy
                        ? null
                        : () => _run((repo, uid, name) => repo.createFamily(
                              uid: uid,
                              userName: name,
                              familyName: _familyName.text.trim().isEmpty ? l.appTitle : _familyName.text.trim(),
                              otherCategoryName: l.otherCategory,
                            )),
                    child: Text(l.create),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.joinFamily, style: Theme.of(context).textTheme.titleMedium),
                  TextField(
                    key: const Key('joinCodeField'),
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(labelText: l.joinCode),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('joinFamilyButton'),
                    onPressed: _busy
                        ? null
                        : () => _run((repo, uid, name) =>
                            repo.joinFamily(uid: uid, userName: name, code: _code.text)),
                    child: Text(l.join),
                  ),
                ],
              ),
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}
