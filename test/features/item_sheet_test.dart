import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/features/lists/item_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

const milk = Item(id: 'milk', name: 'Milk', categoryId: 'dairy', quantity: 2, unit: 'L', expiryDays: 7);

Future<void> openSheet(WidgetTester tester, FakeFirebaseFirestore db, {String uid = 'u1', Entry? entry}) async {
  await pumpWithFamily(
    tester,
    db: db,
    uid: uid,
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showItemSheet(context, item: milk, listId: 'l1', entry: entry),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settle(tester);
}

Future<Map<String, dynamic>> milkDoc(FakeFirebaseFirestore db) async =>
    (await db.doc('families/f1/items/milk').get()).data()!;

void main() {
  testWidgets('edits are saved and Arabic digits are accepted', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await tester.enterText(find.byKey(const Key('sheetQuantity')), '١٫٥');
    await tester.enterText(find.byKey(const Key('sheetExpiry')), '٥');
    await tester.enterText(find.byKey(const Key('sheetNotes')), 'full fat');
    await tester.tap(find.byKey(const Key('sheetSave')));
    await settle(tester);
    final data = await milkDoc(db);
    expect(data['quantity'], 1.5);
    expect(data['expiryDays'], 5);
    expect(data['notes'], 'full fat');
    expect(find.byKey(const Key('sheetSave')), findsNothing);
  });

  testWidgets('expiry 0 is saved as no expiry', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await tester.enterText(find.byKey(const Key('sheetExpiry')), '0');
    await tester.tap(find.byKey(const Key('sheetSave')));
    await settle(tester);
    expect((await milkDoc(db))['expiryDays'], isNull);
  });

  testWidgets('a blank name is not saved and the sheet stays open', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await tester.enterText(find.byKey(const Key('sheetName')), '   ');
    await tester.tap(find.byKey(const Key('sheetSave')));
    await settle(tester);
    expect((await milkDoc(db))['name'], 'Milk');
    expect(find.byKey(const Key('sheetSave')), findsOneWidget);
  });

  testWidgets('children do not see Delete from catalog', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db, uid: 'u2');
    expect(find.byKey(const Key('sheetDelete')), findsNothing);
  });

  testWidgets('a parent can delete the item from the catalog', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await tester.tap(find.byKey(const Key('sheetDelete')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    expect((await db.doc('families/f1/items/milk').get()).exists, isFalse);
    expect((await db.doc('families/f1/lists/l1/entries/milk').get()).exists, isFalse);
  });

  testWidgets('shows who last bought it; Remove from this list deletes the entry', (tester) async {
    final db = await seedFamily();
    final entry = Entry(
      itemId: 'milk', status: EntryStatus.bought,
      boughtBy: 'u2', boughtAt: DateTime(2026, 9, 28, 10),
    );
    await openSheet(tester, db, entry: entry);
    expect(find.text('Last bought by Sara on Sep 28, 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sheetRemove')));
    await settle(tester);
    expect((await db.doc('families/f1/lists/l1/entries/milk').get()).exists, isFalse);
  });
}
