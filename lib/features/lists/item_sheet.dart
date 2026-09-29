import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../core/models.dart';
import '../../core/placement.dart';
import '../../core/text.dart';
import '../../data/write.dart';
import '../../l10n/app_localizations.dart';
import '../common/dialogs.dart';

const _newCategoryValue = '__new__';

Future<void> showItemSheet(
  BuildContext context, {
  required Item item,
  required String listId,
  Entry? entry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ItemSheet(item: item, listId: listId, entry: entry),
  );
}

class ItemSheet extends ConsumerStatefulWidget {
  const ItemSheet({super.key, required this.item, required this.listId, this.entry});
  final Item item;
  final String listId;
  final Entry? entry;

  @override
  ConsumerState<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<ItemSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _quantity = TextEditingController(
    text: widget.item.quantity == null ? '' : formatNumber(widget.item.quantity!),
  );
  late final _notes = TextEditingController(text: widget.item.notes);
  late final _expiry = TextEditingController(text: widget.item.expiryDays?.toString() ?? '');
  late String _categoryId = widget.item.categoryId;
  late String? _unit = units.contains(widget.item.unit) ? widget.item.unit : null;
  ItemCategory? _pendingCategory;
  int _categoryFieldVersion = 0;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _notes.dispose();
    _expiry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    ref.watch(listsProvider); // keep lists loaded so deleteItem can reach every list
    final lang = Localizations.localeOf(context).languageCode;
    final isParent = ref.watch(isParentProvider);
    final members = ref.watch(membersProvider).valueOrNull ?? const <Member>[];

    final categories = [...(ref.watch(categoriesProvider).valueOrNull ?? const <ItemCategory>[])];
    final pending = _pendingCategory;
    if (pending != null && categories.every((c) => c.id != pending.id)) categories.add(pending);
    categories.sort((a, b) => compareCategories(a, b, lang));
    final other = categories.where((c) => c.isDefault).firstOrNull;
    // If the item's category was deleted meanwhile, fall back to Other.
    final selectedCategory = categories.any((c) => c.id == _categoryId) ? _categoryId : other?.id;

    final entry = widget.entry;
    var lastBought = l.neverBought;
    if (entry != null && entry.boughtAt != null) {
      final who = members.where((m) => m.uid == entry.boughtBy).firstOrNull?.name ?? '—';
      lastBought = l.lastBought(who, DateFormat.yMMMd(lang).format(entry.boughtAt!));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('sheetName'),
              controller: _name,
              decoration: InputDecoration(labelText: l.name),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('sheetCategory-$_categoryFieldVersion'),
              value: selectedCategory,
              decoration: InputDecoration(labelText: l.category),
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(categoryLabel(l, c))),
                DropdownMenuItem(value: _newCategoryValue, child: Text(l.newCategory)),
              ],
              onChanged: (value) => _onCategoryChanged(value, l),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('sheetQuantity'),
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l.quantity),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: const Key('sheetUnit'),
                    value: _unit,
                    decoration: InputDecoration(labelText: l.unit),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(l.noUnit)),
                      for (final u in units)
                        DropdownMenuItem<String?>(value: u, child: Text(unitLabel(l, u))),
                    ],
                    onChanged: (value) => setState(() => _unit = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sheetNotes'),
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(labelText: l.notes),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('sheetExpiry'),
              controller: _expiry,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l.expiryDays, helperText: l.expiryHint),
            ),
            const SizedBox(height: 12),
            Text(lastBought, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              children: [
                if (entry != null)
                  TextButton(
                    key: const Key('sheetRemove'),
                    onPressed: _removeFromList,
                    child: Text(l.removeFromList),
                  ),
                if (isParent)
                  TextButton(
                    key: const Key('sheetDelete'),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    onPressed: () => _deleteFromCatalog(l),
                    child: Text(l.deleteFromCatalog),
                  ),
                FilledButton(
                  key: const Key('sheetSave'),
                  onPressed: () => _save(selectedCategory),
                  child: Text(l.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCategoryChanged(String? value, AppLocalizations l) async {
    if (value == null) return;
    if (value != _newCategoryValue) {
      setState(() => _categoryId = value);
      return;
    }
    final name = await promptText(context, title: l.newCategory, label: l.categoryName, confirmLabel: l.save);
    if (!mounted) return;
    if (name == null || name.trim().isEmpty) {
      setState(() => _categoryFieldVersion++); // reset the dropdown away from "New category"
      return;
    }
    final repo = ref.read(catalogRepositoryProvider);
    final id = repo.newId();
    fireAndForget(repo.addCategory(id: id, name: name, uid: ref.read(currentUidProvider)!));
    setState(() {
      _pendingCategory = ItemCategory(id: id, name: name.trim(), isDefault: false);
      _categoryId = id;
      _categoryFieldVersion++;
    });
  }

  void _save(String? categoryId) {
    final name = _name.text.trim();
    if (name.isEmpty || categoryId == null) return;
    final quantity = parseNumber(_quantity.text);
    final expiry = parseNumber(_expiry.text)?.round();
    final item = Item(
      id: widget.item.id,
      name: name,
      categoryId: categoryId,
      quantity: quantity,
      unit: quantity == null ? null : _unit,
      notes: _notes.text.trim(),
      expiryDays: (expiry != null && expiry > 0) ? expiry : null,
    );
    fireAndForget(ref.read(catalogRepositoryProvider).saveItem(item, uid: ref.read(currentUidProvider)!));
    Navigator.of(context).pop();
  }

  void _removeFromList() {
    fireAndForget(ref.read(listRepositoryProvider).removeFromList(widget.listId, widget.item.id));
    Navigator.of(context).pop();
  }

  Future<void> _deleteFromCatalog(AppLocalizations l) async {
    final ok = await confirm(context, message: l.confirmDeleteItem(widget.item.name), confirmLabel: l.delete);
    if (!ok || !mounted) return;
    final lists = ref.read(listsProvider).valueOrNull ?? const <ShoppingList>[];
    fireAndForget(ref.read(catalogRepositoryProvider).deleteItem(
          itemId: widget.item.id,
          listIds: [for (final list in lists) list.id],
        ));
    Navigator.of(context).pop();
  }
}
