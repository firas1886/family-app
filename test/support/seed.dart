import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
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

/// Chores for family f1 (u1 Dad parent, u2 Sara child). On testNow
/// (Thursday 2026-10-01): brush and bins are due today; blinds (28 Sep) and
/// plants (Saturday 26 Sep) are late; brush was done on 30 Sep.
Future<void> seedChores(FakeFirebaseFirestore db) async {
  const chores = [
    Chore(
      id: 'brush', title: 'Brush teeth', icon: '🪥', assignee: 'u2', time: '07:00',
      repeat: Repeat.daily, startDate: '2026-09-01', remind: true, createdBy: 'u1',
    ),
    Chore(
      id: 'bins', title: 'Take out bins', assignee: 'u1',
      repeat: Repeat.weekly, weekdays: [1, 4], startDate: '2026-09-01', createdBy: 'u1',
    ),
    Chore(
      id: 'plants', title: 'Water plants',
      repeat: Repeat.weekly, weekdays: [6], startDate: '2026-09-01', createdBy: 'u1',
    ),
    Chore(id: 'blinds', title: 'Order blinds', startDate: '2026-09-28', createdBy: 'u1'),
  ];
  for (final c in chores) {
    await db.doc('families/f1/chores/${c.id}').set({...c.toMap(), 'createdAt': DateTime(2026, 9, 1)});
  }
  final done = ChoreDone(
    choreId: 'brush', date: '2026-09-30', choreTitle: 'Brush teeth', assignee: 'u2',
    doneBy: 'u2', doneByName: 'Sara', doneAt: DateTime(2026, 9, 30, 7, 5),
    dayNumber: dayNumberOf(DateTime(2026, 9, 30)),
  );
  await db.doc('families/f1/choreDone/${done.id}').set(done.toMap());
}

/// A member without a login in family f1, created by u1.
Future<String> seedNoLoginMember(
  FakeFirebaseFirestore db, {
  String id = 'nl_YUSUFabcdefghijklmno',
  String name = 'Yusuf',
  int color = 5,
}) async {
  await db.doc('families/f1/members/$id').set({
    'name': name, 'role': 'child', 'noLogin': true, 'color': color,
    'pictureTiles': false, 'joinedAt': DateTime(2026, 9, 1), 'createdBy': 'u1',
  });
  return id;
}
