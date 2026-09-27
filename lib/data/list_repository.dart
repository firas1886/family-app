import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models.dart';

/// Everything needed to write a purchase and to undo it exactly.
class BuyReceipt {
  const BuyReceipt({
    required this.listId,
    required this.itemId,
    required this.purchaseId,
    required this.previousEntry,
    required this.boughtEntry,
    required this.purchase,
  });
  final String listId;
  final String itemId;
  final String purchaseId;
  final Map<String, dynamic> previousEntry;
  final Map<String, dynamic> boughtEntry;
  final Map<String, dynamic> purchase;
}

class ListRepository {
  ListRepository(this._db, this.familyId);

  final FirebaseFirestore _db;
  final String familyId;

  DocumentReference<Map<String, dynamic>> get _family => _db.collection('families').doc(familyId);
  CollectionReference<Map<String, dynamic>> get _lists => _family.collection('lists');
  CollectionReference<Map<String, dynamic>> get _purchases => _family.collection('purchases');
  CollectionReference<Map<String, dynamic>> _entries(String listId) =>
      _lists.doc(listId).collection('entries');

  Stream<List<ShoppingList>> watchLists() => _lists
      .orderBy('createdAt')
      .snapshots()
      .map((q) => [for (final d in q.docs) ShoppingList.fromMap(d.id, d.data())]);

  Future<void> createList({required String name, required String uid}) =>
      _lists.doc().set({'name': name.trim(), 'createdBy': uid, 'createdAt': DateTime.now()});

  Future<void> renameList(String listId, String name) =>
      _lists.doc(listId).update({'name': name.trim()});

  Future<void> deleteList(String listId) async {
    final entries = await _entries(listId).get();
    final batch = _db.batch();
    for (final d in entries.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_lists.doc(listId));
    await batch.commit();
  }

  Stream<List<Entry>> watchEntries(String listId) => _entries(listId)
      .snapshots()
      .map((q) => [for (final d in q.docs) Entry.fromMap(d.id, d.data())]);

  /// Puts an item on To buy. Merging keeps the last purchase details for the item sheet.
  Future<void> addToBuy({required String listId, required String itemId, required String uid}) =>
      _entries(listId).doc(itemId).set({
        'itemId': itemId,
        'status': EntryStatus.toBuy.name,
        'addedBy': uid,
        'addedAt': DateTime.now(),
      }, SetOptions(merge: true));

  Future<void> removeFromList(String listId, String itemId) =>
      _entries(listId).doc(itemId).delete();

  BuyReceipt prepareBuy({
    required ShoppingList list,
    required Item item,
    required ItemCategory? category,
    required Entry entry,
    required String uid,
    required String userName,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final purchaseId = _purchases.doc().id;
    final bought = Entry(
      itemId: item.id,
      status: EntryStatus.bought,
      addedBy: entry.addedBy,
      addedAt: entry.addedAt,
      boughtBy: uid,
      boughtAt: at,
    );
    final purchase = Purchase(
      id: purchaseId,
      itemId: item.id,
      itemName: item.name,
      categoryName: category?.name ?? '',
      listId: list.id,
      listName: list.name,
      quantity: item.quantity,
      unit: item.unit,
      boughtBy: uid,
      boughtByName: userName,
      boughtAt: at,
    );
    return BuyReceipt(
      listId: list.id,
      itemId: item.id,
      purchaseId: purchaseId,
      previousEntry: entry.toMap(),
      boughtEntry: bought.toMap(),
      purchase: purchase.toMap(),
    );
  }

  Future<void> commitBuy(BuyReceipt r) => (_db.batch()
        ..set(_entries(r.listId).doc(r.itemId), r.boughtEntry)
        ..set(_purchases.doc(r.purchaseId), r.purchase))
      .commit();

  Future<void> undoBuy(BuyReceipt r) => (_db.batch()
        ..set(_entries(r.listId).doc(r.itemId), r.previousEntry)
        ..delete(_purchases.doc(r.purchaseId)))
      .commit();
}
