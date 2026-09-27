import 'models.dart';
import 'text.dart';

const recentlyUsedCap = 12;

enum SortMode { category, alphabetical }

class TileView {
  const TileView({required this.item, required this.entry, this.daysLeft});
  final Item item;
  final Entry entry;
  final int? daysLeft;
}

class CategoryGroup<T> {
  const CategoryGroup(this.category, this.members);

  /// Null only for the single flat group in alphabetical mode.
  final ItemCategory? category;
  final List<T> members;
}

class ListSections {
  const ListSections({required this.toBuy, required this.recentlyUsed});
  final List<CategoryGroup<TileView>> toBuy;
  final List<TileView> recentlyUsed;

  bool isOnToBuy(String itemId) =>
      toBuy.any((g) => g.members.any((t) => t.item.id == itemId));
}

DateTime? dueAt(Item item, Entry entry) {
  final days = item.effectiveExpiryDays;
  final bought = entry.boughtAt;
  if (entry.status != EntryStatus.bought || days == null || bought == null) {
    return null;
  }
  return bought.add(Duration(days: days));
}

int daysLeft(DateTime due, DateTime now) =>
    (due.difference(now).inMinutes / Duration.minutesPerDay).ceil();

bool isOnToBuy(Item item, Entry entry, DateTime now) {
  if (entry.status == EntryStatus.toBuy) return true;
  final due = dueAt(item, entry);
  return due != null && !due.isAfter(now);
}

ListSections buildSections({
  required Iterable<Entry> entries,
  required Map<String, Item> items,
  required Map<String, ItemCategory> categories,
  required DateTime now,
  required SortMode sort,
  required String languageCode,
}) {
  final toBuy = <TileView>[];
  final counting = <TileView>[];
  final open = <TileView>[];

  for (final entry in entries) {
    final item = items[entry.itemId];
    if (item == null) continue; // item deleted from catalog
    if (isOnToBuy(item, entry, now)) {
      toBuy.add(TileView(item: item, entry: entry));
      continue;
    }
    final due = dueAt(item, entry);
    if (due != null) {
      counting.add(TileView(item: item, entry: entry, daysLeft: daysLeft(due, now)));
    } else {
      open.add(TileView(item: item, entry: entry));
    }
  }

  counting.sort((a, b) => dueAt(a.item, a.entry)!.compareTo(dueAt(b.item, b.entry)!));
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  open.sort((a, b) => (b.entry.boughtAt ?? epoch).compareTo(a.entry.boughtAt ?? epoch));

  return ListSections(
    toBuy: _groupTiles(toBuy, categories, sort, languageCode),
    recentlyUsed: [...counting, ...open].take(recentlyUsedCap).toList(),
  );
}

/// Other (default) last, the rest by name.
int compareCategories(ItemCategory? a, ItemCategory? b, String languageCode) {
  final aDefault = a?.isDefault ?? true;
  final bDefault = b?.isDefault ?? true;
  if (aDefault != bDefault) return aDefault ? 1 : -1;
  return compareNames(a?.name ?? '', b?.name ?? '', languageCode);
}

List<CategoryGroup<T>> _groupByCategory<T>({
  required Iterable<T> things,
  required Item Function(T) itemOf,
  required Map<String, ItemCategory> categories,
  required String languageCode,
}) {
  ItemCategory? other;
  for (final c in categories.values) {
    if (c.isDefault) other = c;
  }
  final buckets = <String, List<T>>{};
  final bucketCategory = <String, ItemCategory?>{};
  for (final thing in things) {
    final category = categories[itemOf(thing).categoryId] ?? other;
    final key = category?.id ?? '';
    bucketCategory[key] = category;
    buckets.putIfAbsent(key, () => []).add(thing);
  }
  final groups = [
    for (final e in buckets.entries)
      CategoryGroup<T>(
        bucketCategory[e.key],
        e.value..sort((a, b) => compareNames(itemOf(a).name, itemOf(b).name, languageCode)),
      ),
  ];
  groups.sort((a, b) => compareCategories(a.category, b.category, languageCode));
  return groups;
}

List<CategoryGroup<TileView>> _groupTiles(
  List<TileView> tiles,
  Map<String, ItemCategory> categories,
  SortMode sort,
  String languageCode,
) {
  if (sort == SortMode.alphabetical) {
    if (tiles.isEmpty) return [];
    final sorted = [...tiles]
      ..sort((a, b) => compareNames(a.item.name, b.item.name, languageCode));
    return [CategoryGroup<TileView>(null, sorted)];
  }
  return _groupByCategory<TileView>(
    things: tiles,
    itemOf: (t) => t.item,
    categories: categories,
    languageCode: languageCode,
  );
}

/// The full catalog for the Categories section, including empty categories.
List<CategoryGroup<Item>> catalogGroups({
  required Iterable<Item> items,
  required Map<String, ItemCategory> categories,
  required String languageCode,
}) {
  final grouped = _groupByCategory<Item>(
    things: items,
    itemOf: (i) => i,
    categories: categories,
    languageCode: languageCode,
  );
  final present = grouped.map((g) => g.category?.id).toSet();
  final all = [
    ...grouped,
    for (final c in categories.values)
      if (!present.contains(c.id)) CategoryGroup<Item>(c, <Item>[]),
  ];
  all.sort((a, b) => compareCategories(a.category, b.category, languageCode));
  return all;
}
