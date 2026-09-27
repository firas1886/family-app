import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/data/list_repository.dart';
import 'package:family_app/data/purchase_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/seed.dart';

const home = ShoppingList(id: 'l1', name: 'Home');
const milk = Item(id: 'milk', name: 'Milk', categoryId: 'dairy', quantity: 2, unit: 'L', expiryDays: 7);
const bread = Item(id: 'bread', name: 'Bread', categoryId: 'other');
const dairy = ItemCategory(id: 'dairy', name: 'Dairy', isDefault: false);

void main() {
  late FakeFirebaseFirestore db;
  late ListRepository lists;
  late PurchaseRepository purchases;

  setUp(() async {
    db = await seedFamily();
    lists = ListRepository(db, 'f1');
    purchases = PurchaseRepository(db, 'f1');
  });

  Future<Entry> entry(String itemId) async =>
      (await lists.watchEntries('l1').first).firstWhere((e) => e.itemId == itemId);

  test('buy marks the entry bought and records a purchase snapshot', () async {
    final at = DateTime(2026, 10, 1, 12);
    final receipt = lists.prepareBuy(
      list: home, item: milk, category: dairy, entry: await entry('milk'),
      uid: 'u2', userName: 'Sara', now: at,
    );
    await lists.commitBuy(receipt);

    final e = await entry('milk');
    expect(e.status, EntryStatus.bought);
    expect(e.boughtBy, 'u2');
    expect(e.boughtAt, at);
    expect(e.addedBy, 'u1');

    final p = (await purchases.watchPurchases().first).single;
    expect(p.id, receipt.purchaseId);
    expect(p.itemName, 'Milk');
    expect(p.categoryName, 'Dairy');
    expect(p.listName, 'Home');
    expect(p.quantity, 2.0);
    expect(p.unit, 'L');
    expect(p.price, isNull);
    expect(p.currency, 'SAR');
    expect(p.boughtByName, 'Sara');
    expect(p.boughtAt, at);
  });

  test('undo restores the entry and deletes the purchase', () async {
    final receipt = lists.prepareBuy(
      list: home, item: milk, category: dairy, entry: await entry('milk'),
      uid: 'u2', userName: 'Sara',
    );
    await lists.commitBuy(receipt);
    await lists.undoBuy(receipt);

    final e = await entry('milk');
    expect(e.status, EntryStatus.toBuy);
    expect(e.addedBy, 'u1');
    expect(e.boughtAt, isNull);
    expect(await purchases.watchPurchases().first, isEmpty);
  });

  test('addToBuy on a bought entry keeps its last purchase details', () async {
    await lists.commitBuy(lists.prepareBuy(
      list: home, item: milk, category: dairy, entry: await entry('milk'),
      uid: 'u2', userName: 'Sara',
    ));
    await lists.addToBuy(listId: 'l1', itemId: 'milk', uid: 'u1');
    final e = await entry('milk');
    expect(e.status, EntryStatus.toBuy);
    expect(e.boughtBy, 'u2');
    expect(e.boughtAt, isNotNull);
  });

  test('addToBuy creates a new entry; removeFromList deletes it', () async {
    await lists.addToBuy(listId: 'l1', itemId: 'bread', uid: 'u2');
    expect((await entry('bread')).status, EntryStatus.toBuy);
    await lists.removeFromList('l1', 'bread');
    expect((await lists.watchEntries('l1').first).map((e) => e.itemId), ['milk']);
  });

  test('createList trims; lists are ordered by creation; rename works', () async {
    await lists.createList(name: ' Pharmacy ', uid: 'u1');
    var all = await lists.watchLists().first;
    expect(all.map((l) => l.name).toList(), ['Home', 'Pharmacy']);
    await lists.renameList(all.last.id, 'Chemist');
    all = await lists.watchLists().first;
    expect(all.last.name, 'Chemist');
  });

  test('deleteList removes the list and its entries', () async {
    await lists.deleteList('l1');
    expect(await lists.watchLists().first, isEmpty);
    expect((await db.doc('families/f1/lists/l1/entries/milk').get()).exists, isFalse);
  });

  test('purchases are newest first; price can be set and cleared; records deleted', () async {
    await lists.addToBuy(listId: 'l1', itemId: 'bread', uid: 'u1');
    final first = lists.prepareBuy(
      list: home, item: milk, category: dairy, entry: await entry('milk'),
      uid: 'u1', userName: 'Dad', now: DateTime(2026, 9, 1),
    );
    final second = lists.prepareBuy(
      list: home, item: bread, category: null, entry: await entry('bread'),
      uid: 'u1', userName: 'Dad', now: DateTime(2026, 9, 2),
    );
    await lists.commitBuy(first);
    await lists.commitBuy(second);

    var all = await purchases.watchPurchases().first;
    expect(all.map((p) => p.itemName).toList(), ['Bread', 'Milk']);
    expect(all.first.categoryName, '');

    await purchases.setPrice(first.purchaseId, 12.5);
    all = await purchases.watchPurchases().first;
    expect(all.firstWhere((p) => p.id == first.purchaseId).price, 12.5);

    await purchases.setPrice(first.purchaseId, null);
    all = await purchases.watchPurchases().first;
    expect(all.firstWhere((p) => p.id == first.purchaseId).price, isNull);

    await purchases.delete(second.purchaseId);
    expect((await purchases.watchPurchases().first).single.id, first.purchaseId);
  });
}
