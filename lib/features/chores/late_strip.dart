import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';
import 'chore_card.dart';
import 'chore_groups.dart';
import 'chores_screen.dart';
import 'repeat_label.dart';

/// Late chores wear the theme's red "late" colours.
PersonColor latePersonColor(AppTokens tokens) => PersonColor(
      fill: tokens.late,
      onFill: tokens.lateTint,
      tint: tokens.lateTint,
      onTint: tokens.onLateTint,
    );

/// The day a late chore's tick is recorded for: its own late [date] when
/// allowed (parents; children when it was yesterday), otherwise today. Children
/// may only tick today or yesterday, and a record dated today also clears the
/// chore from [lateChores]. Null when the chore can't be ticked at all.
DateTime? lateTickDay({
  required Chore chore,
  required String date,
  required bool isParent,
  required String me,
  required DateTime today,
}) {
  final lateDay = parseDateKey(date);
  if (canToggle(chore: chore, isParent: isParent, me: me, day: lateDay, today: today)) return lateDay;
  if (canToggle(chore: chore, isParent: isParent, me: me, day: today, today: today)) return today;
  return null;
}

/// The red strip of late chores (one-time and "anyone" chores nobody did).
/// With [onlyMine], only my chores and "anyone" chores.
class LateStrip extends ConsumerWidget {
  const LateStrip({super.key, required this.onlyMine});

  final bool onlyMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final me = ref.watch(currentUidProvider);
    final isParent = ref.watch(isParentProvider);
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];
    final chores = ref.watch(choresProvider).valueOrNull;
    final done = ref
        .watch(choreDoneProvider((from: dateKey(addDays(today, -60)), to: dateKey(today))))
        .valueOrNull;
    if (me == null || chores == null || done == null) return const SizedBox.shrink();

    final overdue = [
      for (final item in lateChores(
        chores: chores,
        done: done,
        today: today,
        languageCode: Localizations.localeOf(context).languageCode,
      ))
        if (!onlyMine || item.chore.isAnyone || item.chore.assignee == me) item,
    ];
    if (overdue.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tokens = context.tokens;
    final color = latePersonColor(tokens);
    return Padding(
      key: const Key('lateStrip'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: tokens.late),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.late,
                  style: theme.textTheme.titleMedium?.copyWith(color: tokens.late, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in overdue)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ChoreCard(
                    key: ValueKey('lateChore-${item.chore.id}'),
                    status: ChoreStatus(item.chore, null),
                    color: color,
                    pictureTile: false,
                    late: true,
                    onToggle: _onToggle(context, ref, item, isParent: isParent, me: me, today: today),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12, top: 2),
                    child: Text(
                      '${_who(l, members, item.chore)} · '
                      '${l.lateSince(shortDate(l.localeName, parseDateKey(item.date)))}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: tokens.mutedText),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _who(AppLocalizations l, List<Member> members, Chore chore) {
    if (chore.isAnyone) return l.anyone;
    return memberById(members, chore.assignee)?.name ?? l.formerMember;
  }

  VoidCallback? _onToggle(
    BuildContext context,
    WidgetRef ref,
    LateChore item, {
    required bool isParent,
    required String me,
    required DateTime today,
  }) {
    final day = lateTickDay(chore: item.chore, date: item.date, isParent: isParent, me: me, today: today);
    if (day == null) return null;
    return () => toggleChore(context, ref, status: ChoreStatus(item.chore, null), day: day);
  }
}
