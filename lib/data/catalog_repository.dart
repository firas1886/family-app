import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models.dart';
import '../core/text.dart';

class CatalogRepository {
  CatalogRepository(this._db, this.familyId);

  final FirebaseFirestore _db;
  final String familyId;

  DocumentReference<Map<String, dynamic>> get _family => _db.collection('families').doc(familyId);
  CollectionReference<Map<String, dynamic>> get _categories => _family.collection('categories');
  CollectionReference<Map<String, dynamic>> get _items => _family.collection('items');
  CollectionReference<Map<String, dynamic>> get _lists => _family.collection('lists');

  /// A fresh document id, generated locally (works offline).
  String newId() => _items.doc().id;

  Stream<List<ItemCategory>> watchCategories() => _categories
      .snapshots()
      .map((q) => [for (final d in q.docs) ItemCategory.fromMap(d.id, d.data())]);

  Stream<List<Item>> watchItems() => _items
      .snapshots()
      .map((q) => [for (final d in q.docs) Item.fromMap(d.id, d.data())]);

  Future<void> addCategory({required String id, required String name, required String uid}) =>
      _categories.doc(id).set({
        'name': name.trim(),
        'isDefault': false,
        'createdBy': uid,
        'createdAt': DateTime.now(),
      });

  Future<void> renameCategory(String id, String name) =>
      _categories.doc(id).update({'name': name.trim()});

  Future<void> deleteCategory({
    required String categoryId,
    required String otherCategoryId,
    required Iterable<Item> catalog,
  }) {
    final batch = _db.batch();
    for (final item in catalog.where((i) => i.categoryId == categoryId)) {
      batch.update(_items.doc(item.id), {'categoryId': otherCategoryId});
    }
    batch.delete(_categories.doc(categoryId));
    return batch.commit();
  }

  /// The existing item with the same normalized name, or null (also for blank input).
  Item? findByName(String name, Iterable<Item> catalog) {
    final key = nameKey(name);
    if (key.isEmpty) return null;
    for (final item in catalog) {
      if (item.key == key) return item;
    }
    return null;
  }

  Future<void> saveItem(Item item, {required String uid, bool isNew = false}) =>
      _items.doc(item.id).set({
        ...item.toMap(),
        if (isNew) 'createdBy': uid,
        if (isNew) 'createdAt': DateTime.now(),
      }, SetOptions(merge: true));

  Future<void> deleteItem({required String itemId, required Iterable<String> listIds}) {
    final batch = _db.batch();
    for (final listId in listIds) {
      batch.delete(_lists.doc(listId).collection('entries').doc(itemId));
    }
    batch.delete(_items.doc(itemId));
    return batch.commit();
  }
}
