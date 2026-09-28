import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/features/lists/list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<void> openList(WidgetTester tester, FakeFirebaseFirestore db, {String uid = 'u1'}) =>
    pumpWithFamily(tester, db: db, uid: uid, child: const ListScreen(listId: 'l1'));

/// SnackBar and flash timers must finish before the test ends.
Future<void> drainTimers(WidgetTester tester) => tester.pump(const Duration(seconds: 6));

void main() {
  testWidgets('shows To buy items with quantity', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    expect(find.text('To buy'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('2 L'), findsOneWidget);
  });

  testWidgets('tapping a To buy tile buys it, and Undo reverts', (tester) async {
    final db = await seedFamily();
    await openList(tester, db, uid: 'u2');
    await tester.tap(find.text('Milk'));
    await settle(tester);

    expect(find.text('Recently used'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
    expect(find.text('Milk bought'), findsOneWidget);
    var purchases = await db.collection('families/f1/purchases').get();
    expect(purchases.docs.single.data()['boughtByName'], 'Sara');

    await tester.tap(find.text('Undo'));
    await settle(tester);
    purchases = await db.collection('families/f1/purchases').get();
    expect(purchases.docs, isEmpty);
    final entry = await db.doc('families/f1/lists/l1/entries/milk').get();
    expect(entry.data()!['status'], 'toBuy');
    await drainTimers(tester);
  });

  testWidgets('tapping a catalog item adds it to To buy', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    await tester.tap(find.text('Other'));
    await settle(tester);
    await tester.tap(find.text('Bread'));
    await settle(tester);
    final entry = await db.doc('families/f1/lists/l1/entries/bread').get();
    expect(entry.data()!['status'], 'toBuy');
  });

  testWidgets('typing a new name creates it in Other and adds it', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    await tester.enterText(find.byKey(const Key('iNeedField')), 'Labneh');
    await tester.tap(find.byKey(const Key('iNeedAdd')));
    await settle(tester);
    final items = await db.collection('families/f1/items').where('nameKey', isEqualTo: 'labneh').get();
    final labneh = items.docs.single;
    expect(labneh.data()['categoryId'], 'other');
    final entry = await db.doc('families/f1/lists/l1/entries/${labneh.id}').get();
    expect(entry.data()!['status'], 'toBuy');
  });

  testWidgets('typing an existing name reuses the catalog item', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    await tester.enterText(find.byKey(const Key('iNeedField')), ' BREAD ');
    await tester.tap(find.byKey(const Key('iNeedAdd')));
    await settle(tester);
    expect((await db.collection('families/f1/items').get()).docs.length, 2);
    expect((await db.doc('families/f1/lists/l1/entries/bread').get()).data()!['status'], 'toBuy');
  });

  testWidgets('blank input adds nothing', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    await tester.enterText(find.byKey(const Key('iNeedField')), '   ');
    await tester.tap(find.byKey(const Key('iNeedAdd')));
    await settle(tester);
    expect((await db.collection('families/f1/items').get()).docs.length, 2);
    expect((await db.collection('families/f1/lists/l1/entries').get()).docs.length, 1);
  });

  testWidgets('sort toggle switches to A–Z', (tester) async {
    final db = await seedFamily();
    await openList(tester, db);
    expect(find.text('Dairy'), findsWidgets); // category header in To buy
    await tester.tap(find.byKey(const Key('sortToggle')));
    await settle(tester);
    expect(find.text('A–Z'), findsOneWidget);
  });
}
