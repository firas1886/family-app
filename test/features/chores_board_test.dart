import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/palette.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/features/chores/chore_card.dart';
import 'package:family_app/features/chores/chores_board.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/common/empty_state.dart';
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

/// A surface of [size] dp, set up as in [useTablet].
void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// [count] daily chores for Anyone (no assignee).
Future<void> addAnyoneChores(FakeFirebaseFirestore db, int count) async {
  for (var i = 0; i < count; i++) {
    final chore = Chore(
      id: 'extra-anyone-$i',
      title: 'Extra chore $i',
      repeat: Repeat.daily,
      startDate: '2026-09-01',
      createdBy: 'u1',
    );
    await db.doc('families/f1/chores/${chore.id}').set(chore.toMap());
  }
}

/// The ids of the board's columns, in board order.
List<String> boardColumnIds(WidgetTester tester) => [
      for (final e in find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('boardColumn-'),
            skipOffstage: false,
          )
          .evaluate())
        (e.widget.key! as ValueKey<String>).value.substring('boardColumn-'.length),
    ];

/// One column's own scroll position.
ScrollPosition listPosition(WidgetTester tester, String groupId) => tester
    .state<ScrollableState>(find
        .descendant(
          of: find.byKey(ValueKey('boardList-$groupId'), skipOffstage: false),
          matching: find.byType(Scrollable, skipOffstage: false),
          skipOffstage: false,
        )
        .first)
    .position;

/// The add button sits on the end side: the left in Arabic, the right in English.
void expectAddButtonOnEndSide(WidgetTester tester, Size size, Locale locale) {
  final x = tester.getCenter(find.byKey(const Key('addChore'))).dx;
  if (locale.languageCode == 'ar') {
    expect(x, lessThan(size.width / 2), reason: 'right to left: the add button is on the left');
  } else {
    expect(x, greaterThan(size.width / 2), reason: 'left to right: the add button is on the right');
  }
}

/// For every column in [columns] (board order): scroll it to its end and check
/// that its last card's tick is clear of the add button and ticks when tapped.
/// A parent's tick on an Anyone chore gets the rect check only (Task 8 asks
/// "Who did it?" there).
Future<void> expectLastTicksClearOfAddButton(
  WidgetTester tester, {
  required FakeFirebaseFirestore db,
  required String name,
  required List<String> columns,
  required bool isParent,
}) async {
  final addButton = find.byKey(const Key('addChore'));
  for (final id in columns) {
    // 1. No SnackBar, so the add button is in its normal place.
    ScaffoldMessenger.of(tester.element(find.byType(ChoresScreen))).removeCurrentSnackBar();
    await settle(tester);

    // 2. The whole column in view. With sideways scrolling the last column
    // then sits at the end, under the add button.
    await tester.ensureVisible(column(id));
    await settle(tester);

    // 3. The column's own list scrolled to its very end.
    for (var i = 0; i < 20; i++) {
      final position = listPosition(tester, id);
      position.jumpTo(position.maxScrollExtent);
      await settle(tester);
      final after = listPosition(tester, id);
      if (after.pixels == after.maxScrollExtent) break;
    }
    final position = listPosition(tester, id);
    expect(position.pixels, position.maxScrollExtent, reason: '$name: column $id did not reach its end');
    expect(position.maxScrollExtent, greaterThan(0), reason: '$name: column $id does not scroll');

    // 4. The last card's tick does not overlap the add button.
    final lastCard =
        find.descendant(of: find.byKey(ValueKey('boardList-$id')), matching: find.byType(ChoreCard)).last;
    final choreId = tester.widget<ChoreCard>(lastCard).status.chore.id;
    final tick = find.byKey(ValueKey('tick-$choreId'));
    final tickRect = tester.getRect(tick);
    final buttonRect = tester.getRect(addButton);
    if (id == columns.last) {
      debugPrint('$name: end column $id, last tick (tick-$choreId) $tickRect, add button $buttonRect');
    }
    expect(tickRect.overlaps(buttonRect), isFalse,
        reason: '$name: column $id, last tick $tickRect overlaps the add button $buttonRect');

    // 5. Tapping the tick's centre ticks the chore and doesn't open the sheet.
    if (isParent && id == 'anyone') continue;
    await tester.tapAt(tester.getCenter(tick));
    await settle(tester);
    expect(find.byKey(const Key('choreTitle')), findsNothing, reason: '$name: column $id opened the chore sheet');
    final done = await db.doc('families/f1/choreDone/${choreId}_2026-10-01').get();
    expect(done.exists, isTrue, reason: '$name: column $id, $choreId was not ticked');
    if (!isParent) expect(done.data()!['doneBy'], 'u2');
  }
  // 6. Nothing went wrong on the way.
  expect(tester.takeException(), isNull);
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

  group('the last card stays clear of the add button', () {
    const sizes = [Size(1280, 800), Size(1024, 768)];
    const locales = [Locale('en'), Locale('ar')];
    String sizeName(Size size) => '${size.width.toInt()}×${size.height.toInt()}';

    for (final size in sizes) {
      for (final locale in locales) {
        // A. The parent (u1), who opens on Everyone.
        for (final members in const [3, 9]) {
          final name = 'parent, $members members, ${sizeName(size)}, ${locale.languageCode}';
          testWidgets(name, (tester) async {
            useSize(tester, size);
            final db = await seeded();
            for (var i = 3; i <= members; i++) {
              await db.doc('families/f1/members/m$i').set({'name': 'Kid $i', 'role': 'child'});
            }
            final uids = ['u1', 'u2', for (var i = 3; i <= members; i++) 'm$i'];
            for (final uid in uids) {
              await addDailyChores(db, uid, 12);
            }
            await addAnyoneChores(db, 12);
            await pumpWithFamily(tester, db: db, child: const ChoresScreen(), locale: locale);

            expectAddButtonOnEndSide(tester, size, locale);
            final ids = boardColumnIds(tester);
            expect(ids, unorderedEquals([...uids, 'anyone']));
            expect(ids.last, 'anyone');
            await expectLastTicksClearOfAddButton(tester, db: db, name: name, columns: ids, isParent: true);
          });
        }

        // B1. A child (u2) on Me with no Anyone chores: one full-width column.
        final oneColumn = 'child, one full-width column, ${sizeName(size)}, ${locale.languageCode}';
        testWidgets(oneColumn, (tester) async {
          useSize(tester, size);
          final db = await seeded();
          await addDailyChores(db, 'u2', 12);
          await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen(), locale: locale);

          expectAddButtonOnEndSide(tester, size, locale);
          expect(boardColumnIds(tester), ['u2']);
          expect(column('anyone'), findsNothing);
          expect(tester.getSize(column('u2')).width, greaterThan(2 * ChoresBoard.minColumnWidth));
          await expectLastTicksClearOfAddButton(tester, db: db, name: oneColumn, columns: ['u2'], isParent: false);
        });

        // B2. A child (u2) on Me with Anyone chores: Me, then Anyone at the end.
        final meAndAnyone = 'child, Me and Anyone, ${sizeName(size)}, ${locale.languageCode}';
        testWidgets(meAndAnyone, (tester) async {
          useSize(tester, size);
          final db = await seeded();
          await addDailyChores(db, 'u2', 12);
          await addAnyoneChores(db, 12);
          await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen(), locale: locale);

          expectAddButtonOnEndSide(tester, size, locale);
          final ids = boardColumnIds(tester);
          expect(ids, ['u2', 'anyone']);
          await expectLastTicksClearOfAddButton(tester, db: db, name: meAndAnyone, columns: ids, isParent: false);
        });
      }
    }
  });

  testWidgets('an empty day on the board shows the friendly empty state', (tester) async {
    useTablet(tester);
    final db = await seedFamily();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No chores today'), findsOneWidget);
    expect(find.byType(ChoresBoard), findsNothing);
    expect(column('u1'), findsNothing);

    await tester.tap(find.byKey(const Key('dayNext')));
    await settle(tester);
    expect(find.descendant(of: find.byType(EmptyState), matching: find.text('No chores')), findsOneWidget);
    expect(find.byType(ChoresBoard), findsNothing);
  });
}
