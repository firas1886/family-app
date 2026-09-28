import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/features/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<void> addPurchase(FakeFirebaseFirestore db, String id, String item, String listId,
    String listName, DateTime at, {double? price}) {
  return db.doc('families/f1/purchases/$id').set(Purchase(
        id: id, itemId: item.toLowerCase(), itemName: item, categoryName: '',
        listId: listId, listName: listName, quantity: 2, unit: 'L', price: price,
        boughtBy: 'u2', boughtByName: 'Sara', boughtAt: at,
      ).toMap());
}

Future<FakeFirebaseFirestore> seedHistory() async {
  final db = await seedFamily();
  await db.doc('families/f1/lists/l2').set({'name': 'Weekend', 'createdAt': DateTime(2026, 2, 1)});
  await addPurchase(db, 'p1', 'Milk', 'l1', 'Home', DateTime(2026, 9, 30, 10));
  await addPurchase(db, 'p2', 'Bread', 'l2', 'Weekend', DateTime(2026, 9, 30, 18), price: 4.5);
  await addPurchase(db, 'p3', 'Cheese', 'l1', 'Home', DateTime(2026, 9, 28, 9));
  return db;
}

void main() {
  testWidgets('shows purchases grouped by day with prices', (tester) async {
    final db = await seedHistory();
    await pumpWithFamily(tester, db: db, child: const HistoryScreen());
    expect(find.text(DateFormat.yMMMMEEEEd('en').format(DateTime(2026, 9, 30))), findsOneWidget);
    expect(find.text(DateFormat.yMMMMEEEEd('en').format(DateTime(2026, 9, 28))), findsOneWidget);
    expect(find.text('4.50 SAR'), findsOneWidget);
    expect(find.text('Add price'), findsNWidgets(2));
  });

  testWidgets('a price can be added later', (tester) async {
    final db = await seedHistory();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const HistoryScreen());
    await tester.tap(find.text('Add price').first);
    await settle(tester);
    await tester.enterText(find.byKey(const Key('promptField')), '١٢٫٥');
    await tester.tap(find.byKey(const Key('promptConfirm')));
    await settle(tester);
    expect((await db.doc('families/f1/purchases/p1').get()).data()!['price'], 12.5);
  });

  testWidgets('filtering by list hides other lists', (tester) async {
    final db = await seedHistory();
    await pumpWithFamily(tester, db: db, child: const HistoryScreen());
    await tester.tap(find.byKey(const Key('historyFilter')));
    await settle(tester);
    await tester.tap(find.text('Weekend').last);
    await settle(tester);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Cheese'), findsNothing);
  });

  testWidgets('parents can delete a record; children cannot', (tester) async {
    final db = await seedHistory();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const HistoryScreen());
    await tester.longPress(find.text('Milk'));
    await settle(tester);
    expect(find.byKey(const Key('confirmYes')), findsNothing);

    await pumpWithFamily(tester, db: db, child: const HistoryScreen());
    await tester.longPress(find.text('Milk'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    expect((await db.doc('families/f1/purchases/p1').get()).exists, isFalse);
  });
}
