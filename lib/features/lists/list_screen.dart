import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/placement.dart';
import '../../core/text.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';
import '../common/offline_chip.dart';
import 'item_sheet.dart';
import 'item_tile.dart';

class ListScreen extends ConsumerStatefulWidget {
  const ListScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends ConsumerState<ListScreen> {
  TextEditingController? _typed;
  String? _flashId;
  Timer? _flashTimer;
  Timer? _snackTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _snackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ShoppingList>[];
    final list = lists.where((x) => x.id == widget.listId).firstOrNull;
    final entriesAsync = ref.watch(entriesProvider(widget.listId));
    final itemsAsync = ref.watch(itemsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final sort = ref.watch(sortModeProvider);
    final isParent = ref.watch(isParentProvider);

    if (entriesAsync.hasError || itemsAsync.hasError || categoriesAsync.hasError) {
      return Scaffold(appBar: AppBar(title: Text(list?.name ?? '')), body: Center(child: Text(l.somethingWentWrong)));
    }
    if (!entriesAsync.hasValue || !itemsAsync.hasValue || !categoriesAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text(list?.name ?? '')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final entries = entriesAsync.requireValue;
    final items = itemsAsync.requireValue;
    final categories = categoriesAsync.requireValue;
    final itemMap = {for (final i in items) i.id: i};
    final categoryMap = {for (final c in categories) c.id: c};
    final entryMap = {for (final e in entries) e.itemId: e};
    final lang = Localizations.localeOf(context).languageCode;
    final sections = buildSections(
      entries: entries,
      items: itemMap,
      categories: categoryMap,
      now: ref.watch(clockProvider)(),
      sort: sort,
      languageCode: lang,
    );
    final catalog = catalogGroups(items: items, categories: categoryMap, languageCode: lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? ''),
        actions: [
          const OfflineChip(),
          TextButton.icon(
            key: const Key('sortToggle'),
            onPressed: () => ref.read(sortModeProvider.notifier).state =
                sort == SortMode.category ? SortMode.alphabetical : SortMode.category,
            icon: const Icon(Icons.swap_vert),
            label: Text(sort == SortMode.category ? l.sortByCategory : l.sortAlphabetical),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _header(context, l.toBuy),
                if (sections.toBuy.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l.emptyToBuy, style: TextStyle(color: tokens.mutedText)),
                  ),
                for (final group in sections.toBuy) ...[
                  if (group.category != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(categoryLabel(l, group.category),
                          style: TextStyle(color: tokens.mutedText, fontWeight: FontWeight.w600)),
                    ),
                  _grid([
                    for (final t in group.members)
                      ItemTile(
                        name: t.item.name,
                        color: tokens.toBuy,
                        caption: quantityLabel(l, t.item.quantity, t.item.unit),
                        highlighted: _flashId == t.item.id,
                        onTap: list == null ? null : () => _buy(t, list, categoryMap, l),
                        onLongPress: () => _openSheet(t.item, t.entry),
                      ),
                  ]),
                ],
                if (sections.recentlyUsed.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _header(context, l.recentlyUsed),
                  _grid([
                    for (final t in sections.recentlyUsed)
                      ItemTile(
                        name: t.item.name,
                        color: tokens.recent,
                        caption: t.daysLeft != null
                            ? l.daysLeft(t.daysLeft!)
                            : quantityLabel(l, t.item.quantity, t.item.unit),
                        onTap: () => _addToBuy(t.item, sections),
                        onLongPress: () => _openSheet(t.item, t.entry),
                      ),
                  ]),
                ],
                const SizedBox(height: 12),
                _header(context, l.categories),
                for (final group in catalog)
                  ExpansionTile(
                    key: PageStorageKey('cat-${group.category?.id}'),
                    tilePadding: EdgeInsets.zero,
                    title: GestureDetector(
                      onLongPress: isParent && group.category != null && !group.category!.isDefault
                          ? () => _manageCategory(group.category!, items, categories, l)
                          : null,
                      child: Text(categoryLabel(l, group.category)),
                    ),
                    children: [
                      _grid([
                        for (final item in group.members)
                          ItemTile(
                            name: item.name,
                            color: tokens.card,
                            caption: quantityLabel(l, item.quantity, item.unit),
                            dimmed: sections.isOnToBuy(item.id),
                            highlighted: _flashId == item.id,
                            onTap: () => _addToBuy(item, sections),
                            onLongPress: () => _openSheet(item, entryMap[item.id]),
                          ),
                      ], key: PageStorageKey('grid-${group.category?.id}')),
                    ],
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _newCategory(l),
                    icon: const Icon(Icons.add),
                    label: Text(l.newCategory),
                  ),
                ),
              ],
            ),
          ),
          _inputBar(l, items, categories, sections),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );

  // The key keeps a grid's scroll-offset slot apart from its ExpansionTile's
  // expanded-state slot in PageStorage.
  // Max-extent columns: 3 per row on phones, more on wider screens.
  // Cells are taller than wide so letter, 2-line name and quantity fit.
  Widget _grid(List<Widget> tiles, {Key? key}) => GridView.extent(
        key: key,
        maxCrossAxisExtent: 130,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.8,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: tiles,
      );

  Widget _inputBar(AppLocalizations l, List<Item> items, List<ItemCategory> categories, ListSections sections) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Autocomplete<Item>(
          optionsViewOpenDirection: OptionsViewOpenDirection.up,
          displayStringForOption: (item) => item.name,
          optionsBuilder: (value) {
            final key = nameKey(value.text);
            if (key.isEmpty) return const Iterable<Item>.empty();
            return items.where((i) => i.key.contains(key)).take(6);
          },
          onSelected: (item) {
            _addToBuy(item, sections);
            _typed?.clear();
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _typed = controller;
            return Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('iNeedField'),
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: l.iNeed,
                      hintStyle: TextStyle(color: context.tokens.mutedText),
                      filled: true,
                      fillColor: context.tokens.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(context.tokens.cardRadius),
                        borderSide: BorderSide(color: context.tokens.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(context.tokens.cardRadius),
                        borderSide: BorderSide(color: context.tokens.cardBorder),
                      ),
                    ),
                    onSubmitted: (_) => _submitTyped(items, categories, sections),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const Key('iNeedAdd'),
                  onPressed: () => _submitTyped(items, categories, sections),
                  icon: const Icon(Icons.add),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _buy(TileView tile, ShoppingList list, Map<String, ItemCategory> categories, AppLocalizations l) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final userName = ref.read(appUserProvider).valueOrNull?.name ?? '';
    final repo = ref.read(listRepositoryProvider);
    final receipt = repo.prepareBuy(
      list: list,
      item: tile.item,
      category: categories[tile.item.categoryId],
      entry: tile.entry,
      uid: uid,
      userName: userName,
      now: ref.read(clockProvider)(),
    );
    fireAndForget(repo.commitBuy(receipt));

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final controller = messenger.showSnackBar(SnackBar(
      content: Text(l.boughtItem(tile.item.name)),
      action: SnackBarAction(label: l.undo, onPressed: () => fireAndForget(repo.undoBuy(receipt))),
    ));
    // Close after 5 s even if the platform keeps action snackbars open for accessibility.
    _snackTimer?.cancel();
    final timer = Timer(const Duration(seconds: 5), controller.close);
    _snackTimer = timer;
    // Undo (or a swipe) may close it first; closing twice throws.
    controller.closed.then((_) => timer.cancel());
  }

  void _addToBuy(Item item, ListSections sections) {
    if (sections.isOnToBuy(item.id)) {
      _flash(item.id);
      return;
    }
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    fireAndForget(ref.read(listRepositoryProvider).addToBuy(listId: widget.listId, itemId: item.id, uid: uid));
  }

  void _submitTyped(List<Item> items, List<ItemCategory> categories, ListSections sections) {
    final controller = _typed;
    final uid = ref.read(currentUidProvider);
    if (controller == null || uid == null) return;
    final text = controller.text;
    final catalogRepo = ref.read(catalogRepositoryProvider);
    final existing = catalogRepo.findByName(text, items);
    if (existing == null && nameKey(text).isEmpty) return;
    final other = categories.where((c) => c.isDefault).firstOrNull;
    if (existing == null && other == null) return;
    final item = existing ?? Item(id: catalogRepo.newId(), name: text.trim(), categoryId: other!.id);
    if (existing == null) {
      fireAndForget(catalogRepo.saveItem(item, uid: uid, isNew: true));
    }
    _addToBuy(item, sections);
    controller.clear();
  }

  void _flash(String itemId) {
    setState(() => _flashId = itemId);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

  void _openSheet(Item item, Entry? entry) =>
      showItemSheet(context, item: item, listId: widget.listId, entry: entry);

  Future<void> _newCategory(AppLocalizations l) async {
    final name = await promptText(context, title: l.newCategory, label: l.categoryName, confirmLabel: l.save);
    final uid = ref.read(currentUidProvider);
    if (name == null || name.trim().isEmpty || uid == null) return;
    final repo = ref.read(catalogRepositoryProvider);
    fireAndForget(repo.addCategory(id: repo.newId(), name: name, uid: uid));
  }

  Future<void> _manageCategory(
    ItemCategory category,
    List<Item> items,
    List<ItemCategory> categories,
    AppLocalizations l,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l.rename),
              onTap: () => Navigator.of(sheetContext).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(l.delete),
              onTap: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final repo = ref.read(catalogRepositoryProvider);
    if (action == 'rename') {
      final name = await promptText(context,
          title: l.rename, label: l.categoryName, initial: category.name, confirmLabel: l.save);
      if (name != null && name.trim().isNotEmpty) fireAndForget(repo.renameCategory(category.id, name));
      return;
    }
    final other = categories.where((c) => c.isDefault).firstOrNull;
    if (other == null) return;
    final ok = await confirm(context, message: l.confirmDeleteCategory(category.name), confirmLabel: l.delete);
    if (ok) {
      fireAndForget(repo.deleteCategory(categoryId: category.id, otherCategoryId: other.id, catalog: items));
    }
  }
}
