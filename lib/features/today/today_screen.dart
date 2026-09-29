import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/placement.dart';
import '../../l10n/app_localizations.dart';
import '../common/app_card.dart';
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
      // Chores sections go here (between the header and shopping).
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
    final now = ref.watch(clockProvider)();
    return Text(
      DateFormat.MMMMEEEEd(lang).format(now),
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
