import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/features/lists/list_screen.dart';
import 'package:family_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../support/pump.dart';
import '../support/seed.dart';

/// Adds a second list with one item that is due again (bought 6 days ago, expiry 3)
/// and one item bought recently with no expiry (not to buy).
Future<void> addWeekendList(FakeFirebaseFirestore db, {String name = 'Weekend'}) async {
  await db.doc('families/f1/lists/l2').set({'name': name, 'createdBy': 'u1', 'createdAt': DateTime(2026, 2, 1)});
  await db.doc('families/f1/items/eggs').set(const Item(id: 'eggs', name: 'Eggs', categoryId: 'other', expiryDays: 3).toMap());
  await db.doc('families/f1/lists/l2/entries/eggs').set(Entry(
    itemId: 'eggs', status: EntryStatus.bought, boughtBy: 'u1', boughtAt: DateTime(2026, 9, 25),
  ).toMap());
  await db.doc('families/f1/lists/l2/entries/bread').set(Entry(
    itemId: 'bread', status: EntryStatus.bought, boughtBy: 'u1', boughtAt: DateTime(2026, 9, 30),
  ).toMap());
  await db.doc('families/f1/lists/l2/entries/milk').set(const Entry(itemId: 'milk', status: EntryStatus.toBuy).toMap());
}

void main() {
  testWidgets('shows today\'s date in the header', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const TodayScreen());
    expect(
      find.descendant(
        of: find.byKey(const Key('todayHeader')),
        matching: find.text(DateFormat.MMMMEEEEd('en').format(testNow)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows one card per list with its To buy count', (tester) async {
    final db = await seedFamily();
    await addWeekendList(db);
    await pumpWithFamily(tester, db: db, child: const TodayScreen());

    final shopping = find.byKey(const Key('todayShopping'));
    expect(find.descendant(of: shopping, matching: find.text('Shopping')), findsOneWidget);

    final home = find.byKey(const ValueKey('todayList-l1'));
    expect(find.descendant(of: home, matching: find.text('Home')), findsOneWidget);
    expect(find.descendant(of: home, matching: find.text('1 item to buy')), findsOneWidget);

    // Eggs are due again and milk is on To buy; bread (no expiry) is not.
    final weekend = find.byKey(const ValueKey('todayList-l2'));
    expect(find.descendant(of: weekend, matching: find.text('2 items to buy')), findsOneWidget);
  });

  testWidgets('a list with nothing to buy says so', (tester) async {
    final db = await seedFamily();
    await db.doc('families/f1/lists/l1/entries/milk').delete();
    await pumpWithFamily(tester, db: db, child: const TodayScreen());
    expect(
      find.descendant(of: find.byKey(const ValueKey('todayList-l1')), matching: find.text('Nothing to buy')),
      findsOneWidget,
    );
  });

  testWidgets('no lists shows a friendly line', (tester) async {
    final db = await seedFamily();
    await db.doc('families/f1/lists/l1').delete();
    await pumpWithFamily(tester, db: db, child: const TodayScreen());
    expect(find.text('No lists yet'), findsOneWidget);
  });

  testWidgets('tapping a list card opens that list', (tester) async {
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const TodayScreen());
    await tester.tap(find.byKey(const ValueKey('todayList-l1')));
    await settle(tester);
    expect(find.byType(ListScreen), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
  });

  const sizes = [Size(360, 740), Size(320, 640)];
  const scales = [1.0, 1.3];
  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets('long Arabic list names fit at $size, text x$scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final db = await seedFamily();
        await addWeekendList(db, name: 'قائمة مشتريات نهاية الأسبوع الطويلة جداً للعائلة');
        await pumpWithFamily(tester, db: db, child: const TodayScreen());
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('todayList-l2')), findsOneWidget);
      });
    }
  }
}
