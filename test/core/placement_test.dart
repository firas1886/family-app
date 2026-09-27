import 'package:family_app/core/models.dart';
import 'package:family_app/core/placement.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 1, 12);
const other = ItemCategory(id: 'other', name: 'Other', isDefault: true);
const dairy = ItemCategory(id: 'dairy', name: 'Dairy', isDefault: false);
const bakery = ItemCategory(id: 'bakery', name: 'Bakery', isDefault: false);
final categories = {for (final c in [other, dairy, bakery]) c.id: c};

Item item(String id, {String? name, String cat = 'other', int? expiry}) =>
    Item(id: id, name: name ?? id, categoryId: cat, expiryDays: expiry);
Entry toBuy(String id) => Entry(itemId: id, status: EntryStatus.toBuy);
Entry bought(String id, Duration ago) =>
    Entry(itemId: id, status: EntryStatus.bought, boughtAt: now.subtract(ago));

ListSections build(List<Item> items, List<Entry> entries,
        {SortMode sort = SortMode.category, String lang = 'en'}) =>
    buildSections(
      entries: entries,
      items: {for (final i in items) i.id: i},
      categories: categories,
      now: now,
      sort: sort,
      languageCode: lang,
    );

List<String> toBuyIds(ListSections s) =>
    [for (final g in s.toBuy) for (final t in g.members) t.item.id];
List<String> recentIds(ListSections s) =>
    [for (final t in s.recentlyUsed) t.item.id];

void main() {
  group('placement', () {
    test('toBuy entries appear in To buy', () {
      final s = build([item('milk')], [toBuy('milk')]);
      expect(toBuyIds(s), ['milk']);
      expect(s.recentlyUsed, isEmpty);
    });

    test('bought and not yet due appears in Recently used with days left', () {
      final s = build([item('milk', expiry: 7)], [bought('milk', const Duration(days: 2))]);
      expect(recentIds(s), ['milk']);
      expect(s.recentlyUsed.single.daysLeft, 5);
    });

    test('partial days round up', () {
      final s = build([item('milk', expiry: 3)], [bought('milk', const Duration(hours: 36))]);
      expect(s.recentlyUsed.single.daysLeft, 2);
    });

    test('returns to To buy exactly when due', () {
      final s = build([item('milk', expiry: 7)], [bought('milk', const Duration(days: 7))]);
      expect(toBuyIds(s), ['milk']);
      expect(s.recentlyUsed, isEmpty);
    });

    test('returns to To buy after due', () {
      final s = build([item('milk', expiry: 7)], [bought('milk', const Duration(days: 8))]);
      expect(toBuyIds(s), ['milk']);
    });

    test('no expiry stays in Recently used without countdown', () {
      final s = build([item('salt')], [bought('salt', const Duration(days: 90))]);
      expect(recentIds(s), ['salt']);
      expect(s.recentlyUsed.single.daysLeft, isNull);
    });

    test('zero or negative expiry is treated as no expiry', () {
      final s = build(
        [item('a', expiry: 0), item('b', expiry: -3)],
        [bought('a', const Duration(days: 1)), bought('b', const Duration(days: 1))],
      );
      expect(toBuyIds(s), isEmpty);
      expect(recentIds(s).toSet(), {'a', 'b'});
      expect(s.recentlyUsed.every((t) => t.daysLeft == null), isTrue);
    });

    test('countdown items first, soonest due first; then no-expiry newest first', () {
      final s = build(
        [item('a', expiry: 10), item('b', expiry: 3), item('c'), item('d')],
        [
          bought('a', const Duration(days: 1)), // due in 9 days
          bought('b', const Duration(days: 1)), // due in 2 days
          bought('c', const Duration(days: 5)),
          bought('d', const Duration(days: 1)),
        ],
      );
      expect(recentIds(s), ['b', 'a', 'd', 'c']);
    });

    test('Recently used is capped at 12', () {
      final items = [for (var i = 0; i < 15; i++) item('i$i', expiry: 30)];
      final entries = [for (var i = 0; i < 15; i++) bought('i$i', Duration(hours: i + 1))];
      expect(build(items, entries).recentlyUsed.length, 12);
    });

    test('entries whose item was deleted are skipped', () {
      final s = build(
        [item('milk')],
        [toBuy('milk'), toBuy('ghost'), bought('ghost2', const Duration(days: 1))],
      );
      expect(toBuyIds(s), ['milk']);
      expect(s.recentlyUsed, isEmpty);
    });

    test('changing expiry days takes effect immediately', () {
      final entry = bought('milk', const Duration(days: 5));
      expect(recentIds(build([item('milk', expiry: 7)], [entry])), ['milk']);
      expect(toBuyIds(build([item('milk', expiry: 3)], [entry])), ['milk']);
    });

    test('isOnToBuy reports items on To buy', () {
      final s = build([item('milk'), item('salt')], [toBuy('milk'), bought('salt', const Duration(days: 1))]);
      expect(s.isOnToBuy('milk'), isTrue);
      expect(s.isOnToBuy('salt'), isFalse);
    });
  });

  group('grouping', () {
    final shop = [
      item('cheese', cat: 'dairy'),
      item('milk', cat: 'dairy'),
      item('bread', cat: 'bakery'),
      item('zaatar'),
      item('apples'),
    ];
    final allToBuy = [for (final i in shop) toBuy(i.id)];

    test('To buy is grouped by category, Other last, names A–Z', () {
      final s = build(shop, allToBuy);
      expect(s.toBuy.map((g) => g.category!.id).toList(), ['bakery', 'dairy', 'other']);
      expect(toBuyIds(s), ['bread', 'cheese', 'milk', 'apples', 'zaatar']);
    });

    test('items with an unknown category fall into Other', () {
      final s = build([item('x', cat: 'deleted')], [toBuy('x')]);
      expect(s.toBuy.single.category!.id, 'other');
    });

    test('alphabetical mode is one flat group without a category', () {
      final s = build(shop, allToBuy, sort: SortMode.alphabetical);
      expect(s.toBuy.length, 1);
      expect(s.toBuy.single.category, isNull);
      expect(toBuyIds(s), ['apples', 'bread', 'cheese', 'milk', 'zaatar']);
    });

    test('Arabic names sort first in the Arabic UI', () {
      final s = build(
        [item('m', name: 'Milk'), item('h', name: 'حليب')],
        [toBuy('m'), toBuy('h')],
        sort: SortMode.alphabetical,
        lang: 'ar',
      );
      expect(toBuyIds(s), ['h', 'm']);
    });

    test('catalogGroups includes empty categories, Other last', () {
      final groups = catalogGroups(
        items: [item('milk', cat: 'dairy')],
        categories: categories,
        languageCode: 'en',
      );
      expect(groups.map((g) => g.category!.id).toList(), ['bakery', 'dairy', 'other']);
      expect(groups.first.members, isEmpty);
      expect(groups[1].members.single.id, 'milk');
    });
  });
}
