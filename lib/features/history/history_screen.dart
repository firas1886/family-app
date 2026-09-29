import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../core/history.dart';
import '../../core/models.dart';
import '../../core/text.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _listFilter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    final isParent = ref.watch(isParentProvider);
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ShoppingList>[];
    final purchasesAsync = ref.watch(purchasesProvider);
    // A filter on a list that has since been deleted falls back to "All lists".
    final filter = lists.any((x) => x.id == _listFilter) ? _listFilter : null;

    return Scaffold(
      // Pushed from the Lists app bar, so the AppBar shows a back button.
      appBar: AppBar(title: Text(l.history), actions: const [OfflineChip()]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String?>(
              key: const Key('historyFilter'),
              isExpanded: true,
              value: filter,
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.allLists)),
                for (final list in lists) DropdownMenuItem<String?>(value: list.id, child: Text(list.name)),
              ],
              onChanged: (value) => setState(() => _listFilter = value),
            ),
          ),
          Expanded(
            child: purchasesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text(l.somethingWentWrong)),
              data: (purchases) {
                final shown = filter == null ? purchases : purchases.where((p) => p.listId == filter);
                final groups = groupPurchasesByDay(shown);
                if (groups.isEmpty) return Center(child: Text(l.noPurchases));
                return ListView(
                  children: [
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          DateFormat.yMMMMEEEEd(lang).format(group.day),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      for (final p in group.purchases)
                        ListTile(
                          title: Text(p.itemName),
                          subtitle: Text([
                            quantityLabel(l, p.quantity, p.unit),
                            p.boughtByName,
                            p.listName,
                          ].where((s) => s.isNotEmpty).join(' · ')),
                          trailing: TextButton(
                            onPressed: () => _editPrice(p, l),
                            child: Text(p.price == null
                                ? l.addPrice
                                : '${NumberFormat('#,##0.00', 'en').format(p.price)} ${l.currencySar}'),
                          ),
                          onTap: () => _editPrice(p, l),
                          // Children get a no-op so a long press is not taken as a tap (price prompt).
                          onLongPress: isParent ? () => _delete(p, l) : () {},
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPrice(Purchase p, AppLocalizations l) async {
    final text = await promptText(
      context,
      title: p.itemName,
      label: l.price,
      initial: p.price == null ? '' : formatNumber(p.price!),
      confirmLabel: l.save,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    if (text == null) return;
    // Empty clears the price; unreadable input is ignored.
    final price = parseNumber(text);
    if (text.trim().isNotEmpty && price == null) return;
    fireAndForget(ref.read(purchaseRepositoryProvider).setPrice(p.id, price));
  }

  Future<void> _delete(Purchase p, AppLocalizations l) async {
    if (await confirm(context, message: '${l.delete} ${p.itemName}?', confirmLabel: l.delete)) {
      fireAndForget(ref.read(purchaseRepositoryProvider).delete(p.id));
    }
  }
}
