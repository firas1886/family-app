import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/models.dart';

class PurchaseRepository {
  PurchaseRepository(this._db, this.familyId);

  final FirebaseFirestore _db;
  final String familyId;

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _db.collection('families').doc(familyId).collection('purchases');

  /// Newest first. List filtering happens in the UI to avoid a composite index.
  Stream<List<Purchase>> watchPurchases() => _purchases
      .orderBy('boughtAt', descending: true)
      .limit(500)
      .snapshots()
      .map((q) => [for (final d in q.docs) Purchase.fromMap(d.id, d.data())]);

  Future<void> setPrice(String purchaseId, double? price) =>
      _purchases.doc(purchaseId).update({'price': price});

  Future<void> delete(String purchaseId) => _purchases.doc(purchaseId).delete();
}
