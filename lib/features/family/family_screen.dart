import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../data/family_repository.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/app_card.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final family = ref.watch(familyProvider).valueOrNull;
    final isParent = ref.watch(isParentProvider);
    final uid = ref.watch(currentUidProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final lang = user?.language ?? Localizations.localeOf(context).languageCode;
    final members = [...(ref.watch(membersProvider).valueOrNull ?? const <Member>[])]
      ..sort((a, b) {
        if (a.role != b.role) return a.role == Role.parent ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(title: Text(l.tabFamily), actions: const [OfflineChip()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (family != null)
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(family.name, style: text.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          '${l.joinCode}: ${family.joinCode}',
                          style: text.bodyMedium?.copyWith(color: context.tokens.mutedText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.share,
                    icon: const Icon(Icons.share),
                    onPressed: () => Share.share(l.shareCodeMessage(family.joinCode)),
                  ),
                  if (isParent)
                    IconButton(
                      key: const Key('regenerateCode'),
                      tooltip: l.regenerateCode,
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        final ok = await confirm(context,
                            message: l.confirmRegenerateCode, confirmLabel: l.regenerateCode);
                        if (ok) await ref.read(familyRepositoryProvider).regenerateCode(family.id);
                      },
                    ),
                ],
              ),
            ),
          _SectionTitle(l.members),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final m in members)
                  ListTile(
                    leading: CircleAvatar(child: Text(tileLetter(m.name))),
                    title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(m.role == Role.parent ? l.parent : l.child),
                    trailing: isParent && m.uid != uid && family != null
                        ? PopupMenuButton<String>(
                            key: ValueKey('memberMenu-${m.uid}'),
                            onSelected: (action) => _onMemberAction(context, ref, family.id, m, action),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'role',
                                child: Text(m.role == Role.parent ? l.makeChild : l.makeParent),
                              ),
                              PopupMenuItem(value: 'remove', child: Text(l.removeMember)),
                            ],
                          )
                        : null,
                  ),
              ],
            ),
          ),
          _SectionTitle(l.language),
          AppCard(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ar', label: Text('العربية')),
                ],
                selected: {lang == 'ar' ? 'ar' : 'en'},
                onSelectionChanged: (selection) {
                  if (uid != null) {
                    fireAndForget(ref.read(familyRepositoryProvider).setLanguage(uid, selection.first));
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  key: const Key('leaveFamily'),
                  leading: const Icon(Icons.logout),
                  title: Text(l.leaveFamily),
                  onTap: family == null || uid == null ? null : () => _leave(context, ref, family.id, uid),
                ),
                ListTile(
                  key: const Key('signOut'),
                  leading: const Icon(Icons.power_settings_new),
                  title: Text(l.signOut),
                  onTap: () async {
                    await ref.read(googleSignInProvider).signOut();
                    await ref.read(firebaseAuthProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMemberAction(
    BuildContext context,
    WidgetRef ref,
    String familyId,
    Member m,
    String action,
  ) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(familyRepositoryProvider);
    try {
      if (action == 'role') {
        await repo.setRole(familyId, m.uid, m.role == Role.parent ? Role.child : Role.parent);
      } else {
        final ok = await confirm(context, message: l.confirmRemoveMember(m.name), confirmLabel: l.removeMember);
        if (ok) await repo.removeMember(familyId, m.uid);
      }
    } on LastParentException {
      messenger.showSnackBar(SnackBar(content: Text(l.lastParentError)));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, String familyId, String uid) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirm(context, message: l.confirmLeaveFamily, confirmLabel: l.leaveFamily)) return;
    try {
      await ref.read(familyRepositoryProvider).leaveFamily(familyId, uid);
    } on LastParentException {
      messenger.showSnackBar(SnackBar(content: Text(l.lastParentError)));
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}
