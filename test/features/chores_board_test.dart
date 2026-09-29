import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/palette.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/features/chores/chores_board.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

/// A landscape tablet: 1280 × 800 dp.
void useTablet(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> addDailyChores(FakeFirebaseFirestore db, String assignee, int count) async {
  for (var i = 0; i < count; i++) {
    final chore = Chore(
      id: 'extra-$assignee-$i',
      title: 'Extra chore $i',
      assignee: assignee,
      repeat: Repeat.daily,
      startDate: '2026-09-01',
      createdBy: 'u1',
    );
    await db.doc('families/f1/chores/${chore.id}').set(chore.toMap());
  }
}

Finder column(String groupId) => find.byKey(ValueKey('boardColumn-$groupId'), skipOffstage: false);

/// How far one column's own list has scrolled.
double listOffset(WidgetTester tester, String groupId) {
  final scrollable = find
      .descendant(
        of: find.byKey(ValueKey('boardList-$groupId'), skipOffstage: false),
        matching: find.byType(Scrollable, skipOffstage: false),
        skipOffstage: false,
      )
      .first;
  return tester.state<ScrollableState>(scrollable).position.pixels;
}

void main() {
  testWidgets('on a landscape tablet every member gets a column, side by side', (tester) async {
    useTablet(tester);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    expect(find.byKey(const Key('boardScroll')), findsNothing); // three columns fit
    expect(find.byKey(const ValueKey('choreSection-u1'), skipOffstage: false), findsNothing);
    final rects = [for (final id in ['u1', 'u2', 'anyone']) tester.getRect(column(id))];
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].top, rects[0].top);
      expect(rects[i].left, greaterThan(rects[i - 1].left));
      expect(rects[i].width, moreOrLessEquals(rects[0].width));
    }
    expect(rects[0].width, greaterThan(ChoresBoard.minColumnWidth));
    expect(rects.last.right, lessThanOrEqualTo(1280));
    expect(find.descendant(of: column('u1'), matching: find.text('Take out bins')), findsOneWidget);
    expect(find.descendant(of: column('u2'), matching: find.text('Brush teeth')), findsOneWidget);
    expect(find.descendant(of: column('u2'), matching: find.text('✓ 0/1')), findsOneWidget);
    // The day switcher and the scope toggle stay on top.
    expect(find.byKey(const Key('dayLabel')), findsOneWidget);
    expect(find.byKey(const Key('choresScope')), findsOneWidget);
  });

  testWidgets('ticking on the board works as on the phone', (tester) async {
    useTablet(tester);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await tester.tap(find.byKey(const ValueKey('tick-brush')));
    await settle(tester);
    final data = (await db.doc('families/f1/choreDone/brush_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
  });

  testWidgets('scrolling one column does not move the others', (tester) async {
    useTablet(tester);
    final db = await seeded();
    await addDailyChores(db, 'u2', 20);
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    await tester.drag(find.byKey(const ValueKey('boardList-u2')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(listOffset(tester, 'u2'), greaterThan(0));
    expect(listOffset(tester, 'u1'), 0);
    expect(listOffset(tester, 'anyone'), 0);
  });

  testWidgets('nine members: board scrolls sideways and columns scroll independently', (tester) async {
    useTablet(tester);
    final db = await seeded();
    for (var i = 3; i <= 9; i++) {
      await db.doc('families/f1/members/m$i').set({'name': 'Kid $i', 'role': 'child'});
    }
    await addDailyChores(db, 'u1', 20);
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    // Nine members share the eight palette colours: the colours wrap around.
    final container = ProviderScope.containerOf(tester.element(find.byType(ChoresScreen)));
    final colors = container.read(memberColorsProvider);
    expect(colors, hasLength(9));
    expect(colors.values.every((i) => i >= 0 && i < personPaletteSize), isTrue);
    expect(colors.values.toSet(), hasLength(personPaletteSize));

    // Ten columns (nine members and Anyone) of 260 dp do not fit in 1280 dp.
    expect(find.byKey(const Key('boardScroll')), findsOneWidget);
    for (final id in ['u1', 'm3', 'm9', 'u2', 'anyone']) {
      expect(tester.getSize(column(id)).width, ChoresBoard.minColumnWidth);
    }

    // Dad's long list scrolls; the next column stays where it was.
    await tester.drag(find.byKey(const ValueKey('boardList-u1')), const Offset(0, -300));
    await tester.pumpAndSettle();
    final dadOffset = listOffset(tester, 'u1');
    expect(dadOffset, greaterThan(0));
    expect(listOffset(tester, 'm3'), 0);

    // The board scrolls sideways to the Anyone column; Dad's list keeps its place.
    final dadLeft = tester.getTopLeft(column('u1')).dx;
    await tester.drag(find.byKey(const Key('boardScroll')), const Offset(-1500, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(column('u1')).dx, lessThan(dadLeft));
    final anyone = tester.getRect(column('anyone'));
    expect(anyone.left, greaterThanOrEqualTo(0));
    expect(anyone.right, lessThanOrEqualTo(1280));
    expect(listOffset(tester, 'u1'), dadOffset);
    expect(listOffset(tester, 'm3'), 0);
  });

  testWidgets('below 840 dp the phone sections are used', (tester) async {
    tester.view.physicalSize = const Size(839, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(find.byKey(const ValueKey('choreSection-u1'), skipOffstage: false), findsOneWidget);
    expect(column('u1'), findsNothing);
  });
}
