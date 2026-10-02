import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/links.dart';
import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/member_names.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../data/family_repository.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/app_card.dart';
import '../common/dialogs.dart';
import '../common/member_avatar.dart';
import '../common/offline_chip.dart';
import 'invite.dart';

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
    final colors = ref.watch(memberColorsProvider);
    final lang = user?.language ?? Localizations.localeOf(context).languageCode;
    final themeMode = switch (user?.themeMode) {
      'light' => 'light',
      'dark' => 'dark',
      _ => 'system',
    };
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
                    key: const Key('inviteFamily'),
                    tooltip: l.inviteFamily,
                    icon: const Icon(Icons.share),
                    onPressed: () => ref.read(shareTextProvider)(
                          inviteText(l, code: family.joinCode, link: appDownloadUrl),
                        ),
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
                for (final m in members) ...[
                  ListTile(
                    leading: MemberAvatar(member: m),
                    title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      _subtitle(m, m.role == Role.parent ? l.parent : l.child),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // At most two 48 dp controls, so the name keeps ~80 dp at
                    // 320 dp wide: a parent edits their own name here, and
                    // everyone else's from the top of the ⋮ menu.
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isParent && m.uid == uid && family != null)
                          IconButton(
                            key: ValueKey('editName-${m.uid}'),
                            tooltip: l.editName,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editName(context, ref, family.id, m),
                          ),
                        _ColorDot(
                          member: m,
                          index: colors[m.uid] ?? m.color ?? 0,
                          familyId: isParent ? family?.id : null,
                        ),
                        if (isParent && m.uid != uid && family != null)
                          PopupMenuButton<String>(
                            key: ValueKey('memberMenu-${m.uid}'),
                            onSelected: (action) => _onMemberAction(context, ref, family.id, m, action),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                key: ValueKey('editName-${m.uid}'),
                                value: 'name',
                                child: Text(l.editName),
                              ),
                              PopupMenuItem(
                                value: 'role',
                                child: Text(m.role == Role.parent ? l.makeChild : l.makeParent),
                              ),
                              PopupMenuItem(value: 'remove', child: Text(l.removeMember)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (isParent && m.role == Role.child && family != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(72, 0, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.pictureTiles,
                              style: text.bodyMedium?.copyWith(color: context.tokens.mutedText),
                            ),
                          ),
                          Switch(
                            key: ValueKey('pictureTiles-${m.uid}'),
                            value: m.pictureTiles,
                            onChanged: (on) => fireAndForget(
                              ref.read(familyRepositoryProvider).setPictureTiles(family.id, m.uid, on),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                _SettingRow(
                  icon: Icons.language,
                  label: l.language,
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
                _SettingRow(
                  icon: Icons.brightness_6_outlined,
                  label: l.theme,
                  child: SegmentedButton<String>(
                    key: const Key('themeMode'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'system', label: Text(l.themeSystem)),
                      ButtonSegment(value: 'light', label: Text(l.themeLight)),
                      ButtonSegment(value: 'dark', label: Text(l.themeDark)),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) {
                      final choice = selection.first;
                      if (uid != null) {
                        fireAndForget(ref
                            .read(familyRepositoryProvider)
                            .setThemeMode(uid, choice == 'system' ? null : choice));
                      }
                    },
                  ),
                ),
                if (isParent)
                  SwitchListTile(
                    key: const Key('remindEveryone'),
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(l.remindEveryone),
                    value: ref.watch(remindEveryoneProvider),
                    onChanged: (on) {
                      ref.read(remindEveryoneProvider.notifier).setOn(on);
                      if (on) askReminderPermission(context, ref.read(reminderSchedulerProvider), ref.read(sharedPreferencesProvider));
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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

  /// The role, plus the name shown on chores when a parent chose one that
  /// differs from the full name.
  static String _subtitle(Member m, String role) {
    final chosen = m.displayName?.trim();
    if (chosen == null || chosen.isEmpty || chosen == m.name.trim()) return role;
    return '$role · $chosen';
  }

  /// Parents only: the name [m] is shown by on chores. Empty clears it back
  /// to the first name. Saving the first name a member is already shown by,
  /// when no name was chosen for them, writes nothing.
  Future<void> _editName(BuildContext context, WidgetRef ref, String familyId, Member m) async {
    final l = AppLocalizations.of(context)!;
    final repo = ref.read(familyRepositoryProvider);
    final value = await promptText(
      context,
      title: l.displayNameTitle,
      helper: l.displayNameHint,
      initial: memberLabel(m),
      confirmLabel: l.save,
      maxLength: 40, // the security rules' limit, checked by String.length
    );
    if (value == null) return;
    final name = value.trim();
    if (name.isEmpty) {
      fireAndForget(repo.setDisplayName(familyId, m.uid, null));
      return;
    }
    if (m.displayName == null && name == firstName(m.name)) return; // no real choice
    fireAndForget(repo.setDisplayName(familyId, m.uid, name));
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
    if (action == 'name') return _editName(context, ref, familyId, m);
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
        padding: const EdgeInsetsDirectional.fromSTEB(4, 16, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

/// A setting's icon and label on their own line, with its control full width
/// underneath. The control is never scaled down, so its segments keep their
/// 48 dp tap targets; a label that doesn't fit wraps and the control grows taller.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.label, required this.child});
  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Decorative: the visible label names the setting.
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            // Full width; the segments share it evenly.
            child,
          ],
        ),
      );
}

/// The member's colour. Parents tap it to pick another colour.
class _ColorDot extends ConsumerWidget {
  const _ColorDot({required this.member, required this.index, required this.familyId});
  final Member member;
  final int index;

  /// Null when the viewer can't change colours.
  final String? familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final key = ValueKey('memberColor-${member.uid}');
    final dot = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: personColor(index, Theme.of(context).brightness).fill,
        shape: BoxShape.circle,
      ),
    );
    final id = familyId;
    if (id == null) {
      return Semantics(
        key: key,
        label: l.color,
        child: SizedBox.square(dimension: 48, child: Center(child: dot)),
      );
    }
    return IconButton(
      key: key,
      tooltip: l.pickColor,
      icon: dot,
      onPressed: () async {
        final picked = await _pickColor(context, index);
        if (picked != null && picked != member.color) {
          fireAndForget(ref.read(familyRepositoryProvider).setColor(id, member.uid, picked));
        }
      },
    );
  }

  Future<int?> _pickColor(BuildContext context, int current) {
    final l = AppLocalizations.of(context)!;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final brightness = Theme.of(dialogContext).brightness;
        return AlertDialog(
          title: Text(l.pickColor),
          content: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < personPaletteSize; i++)
                IconButton(
                  key: ValueKey('paletteColor-$i'),
                  iconSize: 36,
                  onPressed: () => Navigator.of(dialogContext).pop(i),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: personColor(i, brightness).fill,
                      shape: BoxShape.circle,
                    ),
                    child: i == current
                        ? Icon(Icons.check, color: personColor(i, brightness).onFill)
                        : null,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l.cancel)),
          ],
        );
      },
    );
  }
}
