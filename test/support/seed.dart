import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';

Future<FakeFirebaseFirestore> seedFamily() async {
  final db = FakeFirebaseFirestore();
  await db.doc('users/u1').set({'name': 'Dad', 'email': 'dad@x.com', 'familyId': 'f1', 'language': 'en'});
  await db.doc('users/u2').set({'name': 'Sara', 'email': 'sara@x.com', 'familyId': 'f1', 'language': 'en'});
  await db.doc('families/f1').set({'name': 'Home', 'joinCode': 'ABC234', 'createdBy': 'u1'});
  await db.doc('joinCodes/ABC234').set({'familyId': 'f1'});
  await db.doc('families/f1/members/u1').set({'name': 'Dad', 'role': 'parent'});
  await db.doc('families/f1/members/u2').set({'name': 'Sara', 'role': 'child'});
  await db.doc('families/f1/categories/other').set({'name': 'Other', 'isDefault': true});
  await db.doc('families/f1/categories/dairy').set({'name': 'Dairy', 'isDefault': false});
  await db.doc('families/f1/items/milk').set(const Item(
    id: 'milk', name: 'Milk', categoryId: 'dairy', quantity: 2, unit: 'L', expiryDays: 7,
  ).toMap());
  await db.doc('families/f1/items/bread').set(const Item(id: 'bread', name: 'Bread', categoryId: 'other').toMap());
  await db.doc('families/f1/lists/l1').set({'name': 'Home', 'createdBy': 'u1', 'createdAt': DateTime(2026, 1, 1)});
  await db.doc('families/f1/lists/l1/entries/milk').set({
    'itemId': 'milk', 'status': 'toBuy', 'addedBy': 'u1', 'addedAt': DateTime(2026, 9, 30),
    'boughtBy': null, 'boughtAt': null,
  });
  return db;
}
