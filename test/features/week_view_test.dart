import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:family_app/features/chores/chore_card.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/chores/late_strip.dart';
import 'package:family_app/features/chores/week_board.dart';
import 'package:family_app/features/common/empty_state.dart';
import 'package:family_app/features/family/family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

// Release 2a.1: the Day | Week toggle and the week view on the landscape
// tablet, and first names on the Chores tab. testNow is Thursday 2026-10-01.

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

Future<void> addChore(FakeFirebaseFirestore db, Chore chore) =>
    db.doc('families/f1/chores/${chore.id}').set(chore.toMap());

Future<bool> isDone(FakeFirebaseFirestore db, String doneId) async =>
    (await db.doc('families/f1/choreDone/$doneId').get()).exists;

/// Writes a done record for [choreId] on [date] ("YYYY-MM-DD").
Future<void> addDone(
  FakeFirebaseFirestore db, {
  required String choreId,
  required String title,
  String? assignee,
  required String date,
  required String doneBy,
  required String doneByName,
}) =>
    db.doc('families/f1/choreDone/${choreId}_$date').set(ChoreDone(
          choreId: choreId,
          date: date,
          choreTitle: title,
          assignee: assignee,
          doneBy: doneBy,
          doneByName: doneByName,
          doneAt: DateTime(2026, 9, 30, 8),
          dayNumber: dayNumberOf(parseDateKey(date)),
        ).toMap());

/// An Anyone chore (no assignee), every day.
const dishes = Chore(id: 'dishes', title: 'Wash dishes', repeat: Repeat.daily, startDate: '2026-09-01', createdBy: 'u1');

/// Sara's own chore (she created it for herself).
const readBook = Chore(
  id: 'read',
  title: 'Read a book',
  assignee: 'u2',
  repeat: Repeat.daily,
  startDate: '2026-09-01',
  createdBy: 'u2',
);

/// A chore of someone who has left the family.
const formerChore = Chore(
  id: 'old',
  title: 'Feed the fish',
  assignee: 'u9',
  repeat: Repeat.daily,
  startDate: '2026-09-01',
  createdBy: 'u1',
);

const tablet = Size(1280, 800);

/// The week of testNow: Sunday 27 Sep … Saturday 3 Oct 2026.
const week = ['2026-09-27', '2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03'];

void useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder viewToggle() => find.byKey(const Key('choresView'));

ChoresView selectedView(WidgetTester tester) =>
    tester.widget<SegmentedButton<ChoresView>>(viewToggle()).selected.single;

/// Switches to Week with the Day | Week toggle ([label] is the Week segment).
Future<void> showWeek(WidgetTester tester, {String label = 'Week'}) async {
  await tester.tap(find.descendant(of: viewToggle(), matching: find.text(label)));
  await settle(tester);
}

Finder weekColumn(String date) => find.byKey(ValueKey('weekColumn-$date'), skipOffstage: false);

Finder chip(String choreId, String date) => find.byKey(ValueKey('weekChip-$choreId-$date'), skipOffstage: false);

WeekChip chipOf(WidgetTester tester, String choreId, String date) => tester.widget<WeekChip>(chip(choreId, date));

Finder inside(Finder parent, String text) =>
    find.descendant(of: parent, matching: find.text(text, skipOffstage: false), skipOffstage: false);

Finder dayLabelText(String text) => inside(find.byKey(const Key('dayLabel')), text);

Future<void> tapChip(WidgetTester tester, String choreId, String date) async {
  await tester.tap(chip(choreId, date));
  await settle(tester);
}

/// The dates of the week columns, in the order they were built.
List<String> weekColumnDates(WidgetTester tester) => [
      for (final e in find
          .byWidgetPredicate(
            (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('weekColumn-'),
            skipOffstage: false,
          )
          .evaluate())
        (e.widget.key! as ValueKey<String>).value.substring('weekColumn-'.length),
    ];

/// The chore ids of one day's chips, top to bottom.
List<String> chipIdsIn(WidgetTester tester, String date) => [
      for (final w in tester.widgetList<WeekChip>(find.descendant(
        of: weekColumn(date),
        matching: find.byType(WeekChip, skipOffstage: false),
        skipOffstage: false,
      )))
        w.status.chore.id,
    ];

/// One day's own scroll position.
ScrollPosition weekListPosition(WidgetTester tester, String date) => tester
    .state<ScrollableState>(find
        .descendant(
          of: find.byKey(ValueKey('weekList-$date'), skipOffstage: false),
          matching: find.byType(Scrollable, skipOffstage: false),
          skipOffstage: false,
        )
        .first)
    .position;

ChoreCard cardOf(WidgetTester tester, String choreId) =>
    tester.widget<ChoreCard>(find.byKey(ValueKey('chore-$choreId'), skipOffstage: false));

void main() {
  group('1. the Day | Week toggle', () {
    testWidgets('shows on the landscape tablet and starts on Day (the board)', (tester) async {
      useSize(tester, tablet);
      final db = await seeded();
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());

      expect(viewToggle(), findsOneWidget);
      expect(selectedView(tester), ChoresView.day);
      expect(find.byKey(const ValueKey('boardColumn-u1')), findsOneWidget);
      expect(find.byType(WeekBoard), findsNothing);
      // It sits in the top bar, beside Everyone / Me.
      final scope = tester.getRect(find.byKey(const Key('choresScope')));
      final toggle = tester.getRect(viewToggle());
      expect(toggle.center.dy, moreOrLessEquals(scope.center.dy, epsilon: 1));
      expect(toggle.left, greaterThanOrEqualTo(scope.right));
    });

    for (final size in const [Size(800, 1280), Size(360, 740)]) {
      testWidgets('is hidden at ${size.width.toInt()}×${size.height.toInt()}: the phone layout shows', (tester) async {
        useSize(tester, size);
        final db = await seeded();
        await pumpWithFamily(tester, db: db, child: const ChoresScreen());

        expect(viewToggle(), findsNothing);
        expect(find.byKey(const ValueKey('choreSection-u1'), skipOffstage: false), findsOneWidget);
        expect(find.byKey(const ValueKey('boardColumn-u1')), findsNothing);
        expect(find.byType(WeekBoard), findsNothing);
      });
    }
  });

  testWidgets('2. the week: seven columns Sunday to Saturday, with the right chores on each day', (tester) async {
    useSize(tester, tablet);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await showWeek(tester);

    expect(selectedView(tester), ChoresView.week);
    expect(weekColumnDates(tester), week);
    final rects = [for (final d in week) tester.getRect(weekColumn(d))];
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].left, greaterThan(rects[i - 1].left));
      expect(rects[i].top, rects[0].top);
      expect(rects[i].width, moreOrLessEquals(rects[0].width)); // they share the width evenly
    }
    expect(rects.first.left, greaterThanOrEqualTo(0));
    expect(rects.last.right, lessThanOrEqualTo(1280));

    // The label shows the range; day titles are short; today is highlighted.
    expect(dayLabelText('27 Sep – 3 Oct'), findsOneWidget);
    expect(inside(find.byKey(const ValueKey('weekDayTitle-2026-09-30')), 'Wed 30'), findsOneWidget);
    expect(inside(find.byKey(const ValueKey('weekDayTitle-2026-10-01')), 'Thu 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('weekToday')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('weekDayTitle-2026-10-01')),
        matching: find.byKey(const ValueKey('weekToday')),
      ),
      findsOneWidget,
    );

    // brush every day; bins Mon and Thu; plants Sat; blinds only on 28 Sep.
    final byDay = {for (final d in week) d: chipIdsIn(tester, d)};
    List<String> daysWith(String id) => [
          for (final d in week)
            if (byDay[d]!.contains(id)) d,
        ];
    expect(daysWith('brush'), week);
    expect(daysWith('bins'), ['2026-09-28', '2026-10-01']);
    expect(daysWith('plants'), ['2026-10-03']);
    expect(daysWith('blinds'), ['2026-09-28']);
    // Group order within a day, as on the board: me (Dad), Sara, then Anyone.
    expect(byDay['2026-09-28'], ['bins', 'brush', 'blinds']);

    // brush on 30 Sep is done (seeded): filled with a ✓.
    expect(chipOf(tester, 'brush', '2026-09-30').status.isDone, isTrue);
    expect(inside(chip('brush', '2026-09-30'), '✓'), findsOneWidget);
    expect(chipOf(tester, 'brush', '2026-09-29').status.isDone, isFalse);
    expect(inside(chip('brush', '2026-09-29'), '✓'), findsNothing);

    // A chip: the emoji, the title, the owner's initial.
    expect(inside(chip('brush', '2026-09-29'), '🪥'), findsOneWidget);
    expect(inside(chip('brush', '2026-09-29'), 'Brush teeth'), findsOneWidget);
    expect(inside(chip('brush', '2026-09-29'), 'S'), findsOneWidget);
    expect(inside(chip('bins', '2026-09-28'), 'D'), findsOneWidget);

    // No late strip in the week (blinds and plants are late today).
    expect(find.byType(LateStrip), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2b. week chips wear the same colours as the day cards', (tester) async {
    useSize(tester, tablet);
    final db = await seeded();
    await addChore(db, dishes);
    await addDone(db, choreId: 'dishes', title: 'Wash dishes', date: '2026-10-01', doneBy: 'u2', doneByName: 'Sara');
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    // The board's cards for today.
    final dayColors = {for (final id in ['brush', 'bins', 'dishes']) id: cardOf(tester, id).color};
    await showWeek(tester);
    for (final id in dayColors.keys) {
      expect(chipOf(tester, id, '2026-10-01').color, dayColors[id], reason: id);
    }
    // The Anyone chore takes the colour of whoever did it (Sara), and is
    // neutral on a day nobody did it.
    expect(chipOf(tester, 'dishes', '2026-10-01').color, chipOf(tester, 'brush', '2026-10-01').color);
    final theme = Theme.of(tester.element(find.byType(WeekBoard)));
    expect(chipOf(tester, 'dishes', '2026-10-02').color, neutralPersonColor(theme));
    expect(inside(chip('dishes', '2026-10-01'), 'S'), findsOneWidget);

    // Done chips are filled, the rest tinted.
    final done = chipOf(tester, 'dishes', '2026-10-01');
    final notDone = chipOf(tester, 'bins', '2026-10-01');
    expect(tester.widget<Text>(inside(chip('dishes', '2026-10-01'), 'Wash dishes')).style!.color, done.color.onFill);
    expect(tester.widget<Text>(inside(chip('bins', '2026-10-01'), 'Take out bins')).style!.color, notDone.color.onTint);
  });

  group('3. Arabic, right to left', () {
    for (final size in const [Size(1280, 800), Size(1024, 768)]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('Sunday is the right-most column; nothing overflows (${size.width.toInt()}×${size.height.toInt()}, text x$scale)',
            (tester) async {
          useSize(tester, size);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final db = await seeded();
          await db.doc('families/f1/chores/brush').update({'title': 'ترتيب غرفة النوم وتنظيف المكتب وجمع الألعاب قبل موعد النوم'});
          await db.doc('families/f1/members/u2').update({'name': 'سارة الحلبي'});
          await pumpWithFamily(tester, db: db, child: const ChoresScreen(), locale: const Locale('ar'));
          expect(tester.takeException(), isNull);

          await showWeek(tester, label: 'أسبوع');
          expect(tester.takeException(), isNull);
          expect(selectedView(tester), ChoresView.week);

          final rects = [for (final d in week) tester.getRect(weekColumn(d))];
          for (var i = 1; i < rects.length; i++) {
            expect(rects[i].right, lessThan(rects[i - 1].right), reason: '${week[i]} sits left of ${week[i - 1]}');
          }
          expect(rects.first.right, lessThanOrEqualTo(size.width));
          expect(rects.last.left, greaterThanOrEqualTo(0));
          // The first name's initial, in Arabic.
          expect(inside(chip('brush', '2026-10-01'), 'س'), findsOneWidget);
        });
      }
    }
  });

  group('4. ticking from the week', () {
    testWidgets('a parent ticks, undoes and unticks', (tester) async {
      useSize(tester, tablet);
      final db = await seeded();
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());
      await showWeek(tester);

      await tapChip(tester, 'bins', '2026-10-01');
      final data = (await db.doc('families/f1/choreDone/bins_2026-10-01').get()).data()!;
      expect(data['date'], '2026-10-01');
      expect(data['doneBy'], 'u1');
      expect(chipOf(tester, 'bins', '2026-10-01').status.isDone, isTrue);
      expect(find.text('Take out bins done'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(await isDone(db, 'bins_2026-10-01'), isFalse);
      expect(chipOf(tester, 'bins', '2026-10-01').status.isDone, isFalse);

      await tapChip(tester, 'bins', '2026-10-01');
      expect(await isDone(db, 'bins_2026-10-01'), isTrue);
      await tapChip(tester, 'bins', '2026-10-01');
      expect(await isDone(db, 'bins_2026-10-01'), isFalse);

      // A past day, as parents may correct any day.
      await tapChip(tester, 'brush', '2026-09-28');
      expect((await db.doc('families/f1/choreDone/brush_2026-09-28').get()).data()!['doneBy'], 'u2');
    });

    testWidgets("a parent's tick on an Anyone chore asks who did it", (tester) async {
      useSize(tester, tablet);
      final db = await seeded();
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());
      await showWeek(tester);

      await tapChip(tester, 'plants', '2026-10-03');
      expect(find.text('Who did it?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('whoDid-u2')));
      await settle(tester);
      final data = (await db.doc('families/f1/choreDone/plants_2026-10-03').get()).data()!;
      expect(data['doneBy'], 'u2');
      expect(data['doneByName'], 'Sara');
      expect(chipOf(tester, 'plants', '2026-10-03').status.isDone, isTrue);
    });
  });

  group('5. a child in the week', () {
    testWidgets('ticks today and yesterday only', (tester) async {
      useSize(tester, tablet);
      final db = await seeded();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
      await showWeek(tester);

      expect(chipOf(tester, 'brush', '2026-10-01').onTap, isNotNull);
      expect(chipOf(tester, 'brush', '2026-09-30').onTap, isNotNull);
      expect(chipOf(tester, 'brush', '2026-09-29').onTap, isNull);
      expect(chipOf(tester, 'brush', '2026-10-02').onTap, isNull);

      await tapChip(tester, 'brush', '2026-10-01');
      expect((await db.doc('families/f1/choreDone/brush_2026-10-01').get()).data()!['doneBy'], 'u2');
      await tapChip(tester, 'brush', '2026-09-30'); // her own tick: she may untick it
      expect(await isDone(db, 'brush_2026-09-30'), isFalse);
      await tapChip(tester, 'brush', '2026-09-29');
      expect(await isDone(db, 'brush_2026-09-29'), isFalse);
      await tapChip(tester, 'brush', '2026-10-02');
      expect(await isDone(db, 'brush_2026-10-02'), isFalse);
    });

    testWidgets("can't untick a parent's tick on her chore", (tester) async {
      useSize(tester, tablet);
      final db = await seeded();
      await addDone(db, choreId: 'brush', title: 'Brush teeth', assignee: 'u2', date: '2026-10-01', doneBy: 'u1', doneByName: 'Dad');
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
      await showWeek(tester);

      expect(chipOf(tester, 'brush', '2026-10-01').status.isDone, isTrue);
      expect(chipOf(tester, 'brush', '2026-10-01').onTap, isNull);
      await tapChip(tester, 'brush', '2026-10-01');
      expect(await isDone(db, 'brush_2026-10-01'), isTrue);
    });

    testWidgets('long-press edits under the same rule as the day cards; stand-ins are read-only', (tester) async {
      useSize(tester, tablet);
      final db = await seeded(); // brush was created by Dad
      await addChore(db, readBook);
      // A deleted chore of Sara's, done on 30 Sep: a read-only stand-in.
      await addDone(db, choreId: 'gone', title: 'Old job', assignee: 'u2', date: '2026-09-30', doneBy: 'u2', doneByName: 'Sara');
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
      await showWeek(tester);

      expect(inside(chip('gone', '2026-09-30'), 'Old job'), findsOneWidget);
      expect(chipOf(tester, 'gone', '2026-09-30').onTap, isNull);
      expect(chipOf(tester, 'gone', '2026-09-30').onLongPress, isNull);
      expect(chipOf(tester, 'brush', '2026-10-01').onLongPress, isNull);

      await tester.longPress(chip('brush', '2026-10-01'));
      await settle(tester);
      expect(find.byKey(const Key('choreTitle')), findsNothing);
      expect(await isDone(db, 'brush_2026-10-01'), isFalse); // a long press is not a tap

      await tester.longPress(chip('read', '2026-10-02'));
      await settle(tester);
      expect(tester.widget<TextField>(find.byKey(const Key('choreTitle'))).controller!.text, 'Read a book');
    });
  });

  testWidgets("6. tapping a day's title opens that day", (tester) async {
    useSize(tester, tablet);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await showWeek(tester);

    await tester.tap(find.byKey(const ValueKey('weekDayTitle-2026-09-29')));
    await settle(tester);
    expect(selectedView(tester), ChoresView.day);
    expect(find.byType(WeekBoard), findsNothing);
    expect(dayLabelText('Tue 29 Sep'), findsOneWidget);
    expect(find.byKey(const ValueKey('boardColumn-u2')), findsOneWidget);
    expect(find.byKey(const ValueKey('chore-brush')), findsOneWidget);
  });

  testWidgets('7. the arrows move a week at a time; the date picker picks a week', (tester) async {
    useSize(tester, tablet);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await showWeek(tester);
    expect(dayLabelText('27 Sep – 3 Oct'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dayNext')));
    await settle(tester);
    expect(dayLabelText('4 Oct – 10 Oct'), findsOneWidget);
    expect(weekColumnDates(tester).first, '2026-10-04');
    expect(weekColumnDates(tester).last, '2026-10-10');

    await tester.tap(find.byKey(const Key('dayPrev')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('dayPrev')));
    await settle(tester);
    expect(dayLabelText('20 Sep – 26 Sep'), findsOneWidget);
    expect(weekColumnDates(tester), ['2026-09-20', '2026-09-21', '2026-09-22', '2026-09-23', '2026-09-24', '2026-09-25', '2026-09-26']);

    // The label still opens the date picker; the picked day selects its week.
    await tester.tap(find.byKey(const Key('dayLabel')));
    await settle(tester);
    await tester.tap(find.text('9'));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(selectedView(tester), ChoresView.week);
    expect(dayLabelText('6 Sep – 12 Sep'), findsOneWidget);
    expect(weekColumnDates(tester).first, '2026-09-06');
  });

  testWidgets('8. the week follows Everyone / Me; former-member chores show to parents only', (tester) async {
    useSize(tester, tablet);
    final db = await seeded();
    await addChore(db, formerChore);

    // A child starts on Me: her own chores and Anyone chores.
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    await showWeek(tester);
    expect(chipIdsIn(tester, '2026-09-28'), ['brush', 'blinds']);
    expect(chipIdsIn(tester, '2026-10-01'), ['brush']);
    expect(chipIdsIn(tester, '2026-10-03'), ['brush', 'plants']);
    // Everyone: Dad's chores too, but never a former member's.
    await tester.tap(find.text('Everyone'));
    await settle(tester);
    expect(chipIdsIn(tester, '2026-09-28'), ['brush', 'bins', 'blinds']);
    expect(chip('old', '2026-09-28'), findsNothing);

    // A parent starts on Everyone: everything, the former member's last.
    await tester.pumpWidget(const SizedBox());
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await showWeek(tester);
    expect(chipIdsIn(tester, '2026-09-28'), ['bins', 'brush', 'blinds', 'old']);
    expect(chipIdsIn(tester, '2026-10-02'), ['brush', 'old']);
    // Me: his own and Anyone.
    await tester.tap(find.text('Me'));
    await settle(tester);
    expect(chipIdsIn(tester, '2026-09-28'), ['bins', 'blinds']);
    expect(chipIdsIn(tester, '2026-10-02'), isEmpty);
  });

  group('9. tap targets', () {
    for (final (size, scale, locale) in const [
      (Size(1280, 800), 1.0, Locale('en')),
      (Size(1024, 768), 1.3, Locale('ar')),
    ]) {
      testWidgets('every week chip is at least 48 dp tall (${size.width.toInt()}, x$scale, ${locale.languageCode})',
          (tester) async {
        useSize(tester, size);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final db = await seeded();
        await addChore(db, dishes);
        await pumpWithFamily(tester, db: db, child: const ChoresScreen(), locale: locale);
        await showWeek(tester, label: locale.languageCode == 'ar' ? 'أسبوع' : 'Week');

        final keys = [for (final w in tester.widgetList<WeekChip>(find.byType(WeekChip))) w.key!];
        // brush and dishes every day, bins twice, plants and blinds once.
        expect(keys, hasLength(7 + 7 + 2 + 1 + 1));
        for (final key in keys) {
          expect(tester.getRect(find.byKey(key)).height, greaterThanOrEqualTo(48), reason: '$key');
        }
        // The day titles are tap targets too.
        for (final d in week) {
          expect(tester.getRect(find.byKey(ValueKey('weekDayTitle-$d'))).height, greaterThanOrEqualTo(48), reason: d);
        }
      });
    }
  });

  testWidgets('10. a busy day scrolls on its own and its last chip clears the add button', (tester) async {
    useSize(tester, tablet);
    final db = await seeded();
    const busy = '2026-10-03'; // Saturday: the column under the add button
    for (var i = 0; i < 15; i++) {
      await addChore(
        db,
        Chore(
          id: 'sat-$i',
          title: 'Saturday job $i',
          assignee: 'u1',
          repeat: Repeat.weekly,
          weekdays: const [6],
          startDate: '2026-09-01',
          createdBy: 'u1',
        ),
      );
    }
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await showWeek(tester);
    expect(chipIdsIn(tester, '2026-10-02'), ['brush']);

    final addButton = tester.getRect(find.byKey(const Key('addChore')));
    expect(tester.getRect(weekColumn(busy)).overlaps(addButton), isTrue);
    expect(weekListPosition(tester, busy).maxScrollExtent, greaterThan(0));

    await tester.drag(find.byKey(const ValueKey('weekList-$busy')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(weekListPosition(tester, busy).pixels, greaterThan(0));
    for (final d in week) {
      if (d != busy) expect(weekListPosition(tester, d).pixels, 0, reason: d);
    }

    // At its very end, the last chip is clear of the add button and tappable.
    final position = weekListPosition(tester, busy);
    position.jumpTo(position.maxScrollExtent);
    await settle(tester);
    final last = find.descendant(of: find.byKey(const ValueKey('weekList-$busy')), matching: find.byType(WeekChip)).last;
    expect(tester.widget<WeekChip>(last).status.chore.id, 'plants'); // Anyone comes last
    final lastRect = tester.getRect(last);
    expect(lastRect.overlaps(tester.getRect(find.byKey(const Key('addChore')))), isFalse,
        reason: 'last chip $lastRect, add button $addButton');
    await tester.tapAt(lastRect.center);
    await settle(tester);
    expect(find.text('Who did it?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('11. rotating the tablet keeps the week view', (tester) async {
    useSize(tester, tablet);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await showWeek(tester);
    expect(find.byType(WeekBoard), findsOneWidget);

    tester.view.physicalSize = const Size(800, 1280);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(viewToggle(), findsNothing);
    expect(find.byType(WeekBoard), findsNothing);
    expect(find.byKey(const ValueKey('choreSection-u1'), skipOffstage: false), findsOneWidget);
    expect(dayLabelText('Today'), findsOneWidget);

    tester.view.physicalSize = tablet;
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(selectedView(tester), ChoresView.week);
    expect(find.byType(WeekBoard), findsOneWidget);
    expect(dayLabelText('27 Sep – 3 Oct'), findsOneWidget);
  });

  group('12. first names', () {
    testWidgets('the chore sheet, the board header and the week chips use first names', (tester) async {
      useSize(tester, tablet);
      final db = await seeded();
      await db.doc('families/f1/members/u2').update({'name': 'Sara Alhalabi'});
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());

      expect(inside(find.byKey(const ValueKey('boardColumn-u2')), 'Sara'), findsOneWidget);
      expect(find.text('Sara Alhalabi'), findsNothing);

      await showWeek(tester);
      expect(inside(chip('brush', '2026-10-01'), 'S'), findsOneWidget);

      await tester.tap(find.byKey(const Key('addChore')));
      await settle(tester);
      expect(inside(find.byKey(const ValueKey('choreWho-u2')), 'Sara'), findsOneWidget);
      expect(find.text('Sara Alhalabi'), findsNothing);
    });

    testWidgets('the phone sections use first names too', (tester) async {
      final db = await seeded();
      await db.doc('families/f1/members/u2').update({'name': 'Sara Alhalabi'});
      await pumpWithFamily(tester, db: db, child: const ChoresScreen());
      expect(inside(find.byKey(const ValueKey('choreSection-u2'), skipOffstage: false), 'Sara'), findsOneWidget);
      expect(find.text('Sara Alhalabi', skipOffstage: false), findsNothing);
    });

    testWidgets('the Family screen keeps full names', (tester) async {
      final db = await seeded();
      await db.doc('families/f1/members/u2').update({'name': 'Sara Alhalabi'});
      await pumpWithFamily(tester, db: db, child: const FamilyScreen());
      expect(find.text('Sara Alhalabi'), findsOneWidget);
    });
  });

  testWidgets('an empty week shows the friendly empty state', (tester) async {
    useSize(tester, tablet);
    final db = await seedFamily(); // no chores at all
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await showWeek(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No chores'), findsOneWidget);
    expect(find.byType(WeekBoard), findsNothing);
  });
}
