import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/palette.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../core/models.dart';
import '../../core/placement.dart';
import '../../l10n/app_localizations.dart';
import '../chores/chore_card.dart';
import '../chores/chore_groups.dart';
import '../chores/chore_sheet.dart';
import '../chores/chores_screen.dart';
import '../chores/late_strip.dart';
import '../common/app_card.dart';
import '../common/member_avatar.dart';
import '../common/offline_chip.dart';
import '../lists/list_screen.dart';

/// The home tab: today's date, then (Task 8) chores, then a shopping summary.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final sections = <Widget>[
      const _TodayHeader(key: Key('todayHeader')),
      const TodayChores(),
      const _ShoppingSection(key: Key('todayShopping')),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.tabToday), actions: const [OfflineChip()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            sections[i],
          ],
        ],
      ),
    );
  }
}

class _TodayHeader extends ConsumerWidget {
  const _TodayHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Localizations.localeOf(context).languageCode;
    final today = ref.watch(todayProvider);
    return Text(
      DateFormat.MMMMEEEEd(lang).format(today),
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }
}

class _ShoppingSection extends ConsumerWidget {
  const _ShoppingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ShoppingList>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.shopping, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (lists.isEmpty)
          Text(l.noListsTitle, style: TextStyle(color: context.tokens.mutedText)),
        for (final list in lists)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ListSummaryCard(list: list),
          ),
      ],
    );
  }
}

class _ListSummaryCard extends ConsumerWidget {
  const _ListSummaryCard({required this.list});
  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final entries = ref.watch(entriesProvider(list.id)).valueOrNull ?? const <Entry>[];
    final items = {for (final i in ref.watch(itemsProvider).valueOrNull ?? const <Item>[]) i.id: i};
    final now = ref.watch(clockProvider)();
    // Same rule as the list screen's To buy section, so due-again items count too.
    final count = entries.where((e) {
      final item = items[e.itemId];
      return item != null && isOnToBuy(item, e, now);
    }).length;

    return AppCard(
      key: ValueKey('todayList-${list.id}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ListScreen(listId: list.id)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 40,
            decoration: BoxDecoration(
              color: count > 0 ? tokens.toBuy : tokens.cardBorder,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  count == 0 ? l.nothingToBuy : l.itemsToBuy(count),
                  style: TextStyle(color: tokens.mutedText),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// Today's chores: everyone's progress, my late chores and my chores for today.
class TodayChores extends ConsumerStatefulWidget {
  const TodayChores({super.key});

  @override
  ConsumerState<TodayChores> createState() => _TodayChoresState();
}

class _TodayChoresState extends ConsumerState<TodayChores> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The midnight timer can fire late on a sleeping phone, so check the date
    // again whenever the app comes back to the foreground.
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(todayProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final me = ref.watch(currentUidProvider);
    final isParent = ref.watch(isParentProvider);
    final colors = ref.watch(memberColorsProvider);
    final members = ref.watch(membersProvider).valueOrNull;
    final chores = ref.watch(choresProvider).valueOrNull;
    final key = dateKey(today);
    final done = ref.watch(choreDoneProvider((from: key, to: key))).valueOrNull;
    if (me == null || members == null || chores == null || done == null) return const SizedBox.shrink();

    final view = choresForDay(
      chores: chores,
      done: done,
      memberUids: {for (final m in members) m.uid},
      day: today,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    final people = [
      for (final g in buildChoreGroups(view: view, members: members, me: me, isParent: isParent, onlyMe: false))
        if (g.member != null) g,
    ];
    final choreIds = {for (final c in chores) c.id};
    final mine = view.byMember[me] ?? const <ChoreStatus>[];
    final myProgress = progressOf(mine);
    final myColorIndex = colors[me];
    final myColor = myColorIndex == null ? neutralPersonColor(theme) : personColor(myColorIndex, theme.brightness);
    final pictureTiles = memberById(members, me)?.pictureTiles ?? false;
    final cards = [
      for (final s in mine)
        ChoreCard(
          key: ValueKey('chore-${s.chore.id}'),
          status: s,
          color: myColor,
          pictureTile: pictureTiles,
          onToggle: choreIds.contains(s.chore.id) &&
                  (!s.isDone || isParent || s.done!.doneBy == me) &&
                  canToggle(chore: s.chore, isParent: isParent, me: me, day: today, today: today)
              ? () => toggleChore(context, ref, status: s, day: today, siblings: mine)
              : null,
          onLongPress: choreIds.contains(s.chore.id) &&
                  (isParent || (s.chore.createdBy == me && s.chore.assignee == me))
              ? () => showChoreSheet(context, chore: s.chore, day: today)
              : null,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          key: const Key('todayMembers'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              for (final g in people) _MemberProgress(member: g.member!, items: g.items),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const LateStrip(onlyMine: true),
        Column(
          key: const Key('todayMyChores'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.yourChores, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (mine.isEmpty)
              Text(l.noChoresToday, style: TextStyle(color: context.tokens.mutedText))
            else ...[
              if (myProgress.done == myProgress.total)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l.allDone, style: theme.textTheme.titleSmall),
                ),
              if (pictureTiles)
                PictureTileGrid(children: cards)
              else
                for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card),
            ],
          ],
        ),
      ],
    );
  }
}

/// One member's avatar with a progress ring and "✓ done/total" for today.
class _MemberProgress extends StatelessWidget {
  const _MemberProgress({required this.member, required this.items});

  final Member member;
  final List<ChoreStatus> items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final progress = progressOf(items);
    return Padding(
      key: ValueKey('todayMember-${member.uid}'),
      padding: const EdgeInsetsDirectional.only(end: 16),
      child: Semantics(
        label: member.name,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberAvatar(
              member: member,
              size: 48,
              progress: progress.total == 0 ? null : progress.done / progress.total,
            ),
            const SizedBox(height: 4),
            Text(l.doneCount(progress.done, progress.total), style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
