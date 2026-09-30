import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../l10n/app_localizations.dart';
import '../common/member_avatar.dart';

/// One section of the Chores tab (phone) or one column of the board (tablet).
class ChoreGroup {
  const ChoreGroup({
    required this.id,
    required this.items,
    this.member,
    this.isAnyone = false,
    this.isFormer = false,
  });

  /// The member's uid, `'anyone'` or `'former'`.
  final String id;
  final Member? member;
  final List<ChoreStatus> items;
  final bool isAnyone;
  final bool isFormer;
}

/// Parents before children, then by name.
int compareMembers(Member a, Member b) {
  if (a.role != b.role) return a.role == Role.parent ? -1 : 1;
  final byName = nameKey(a.name).compareTo(nameKey(b.name));
  return byName != 0 ? byName : a.uid.compareTo(b.uid);
}

Member? memberById(List<Member> members, String? uid) {
  for (final m in members) {
    if (m.uid == uid) return m;
  }
  return null;
}

/// Me first, then parents, then children (each by name), then Anyone (when it
/// has chores, or always when showing everyone), then Former member (parents
/// only, when it has chores). With [onlyMe]: my group plus Anyone.
List<ChoreGroup> buildChoreGroups({
  required DayView view,
  required List<Member> members,
  required String me,
  required bool isParent,
  required bool onlyMe,
}) {
  ChoreGroup forMember(Member m) =>
      ChoreGroup(id: m.uid, member: m, items: view.byMember[m.uid] ?? const <ChoreStatus>[]);
  final mine = memberById(members, me);
  final others = [
    for (final m in members)
      if (m.uid != me) m,
  ]..sort(compareMembers);
  return [
    if (mine != null) forMember(mine),
    if (!onlyMe)
      for (final m in others) forMember(m),
    if (view.anyone.isNotEmpty || !onlyMe) ChoreGroup(id: 'anyone', items: view.anyone, isAnyone: true),
    if (!onlyMe && isParent && view.formerMember.isNotEmpty)
      ChoreGroup(id: 'former', items: view.formerMember, isFormer: true),
  ];
}

/// Avatar, first name and "✓ done/total": the head of a phone section or a
/// board column.
class ChoreGroupHeader extends StatelessWidget {
  const ChoreGroupHeader({super.key, required this.group});

  final ChoreGroup group;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = progressOf(group.items);
    final member = group.member;
    return Row(
      children: [
        if (member != null)
          MemberAvatar(member: member, size: 36)
        else
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              group.isAnyone ? Icons.groups_outlined : Icons.person_off_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            member != null ? firstName(member.name) : (group.isAnyone ? l.anyone : l.formerMember),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          l.doneCount(progress.done, progress.total),
          style: theme.textTheme.labelLarge?.copyWith(color: context.tokens.mutedText),
        ),
      ],
    );
  }
}
