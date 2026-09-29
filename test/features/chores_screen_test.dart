import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/features/chores/chore_card.dart';
import 'package:family_app/features/chores/chore_groups.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/chores/repeat_label.dart';
import 'package:family_app/features/common/empty_state.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

Future<void> addChore(FakeFirebaseFirestore db, Chore chore) =>
    db.doc('families/f1/chores/${chore.id}').set(chore.toMap());

Future<bool> isDone(FakeFirebaseFirestore db, String doneId) async =>
    (await db.doc('families/f1/choreDone/$doneId').get()).exists;

/// Scrolls the widget into view (clear of the add button) before tapping it.
Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

Future<void> longPressKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.longPress(find.byKey(key));
  await settle(tester);
}

ChoreCard cardOf(WidgetTester tester, String choreId) =>
    tester.widget<ChoreCard>(find.byKey(ValueKey('chore-$choreId'), skipOffstage: false));

Finder section(String groupId) => find.byKey(ValueKey('choreSection-$groupId'), skipOffstage: false);

Finder inside(Finder parent, String text) => find.descendant(
      of: parent,
      matching: find.text(text, skipOffstage: false),
      skipOffstage: false,
    );

/// Shows [child] in Arabic (right to left) inside the test app.
Widget arabic(Widget child) => Builder(
      builder: (context) =>
          Localizations.override(context: context, locale: const Locale('ar'), child: child),
    );

/// Sara's own chore (she created it for herself).
const readBook = Chore(
  id: 'read',
  title: 'Read a book',
  assignee: 'u2',
  repeat: Repeat.daily,
  startDate: '2026-09-01',
  createdBy: 'u2',
);

/// An Anyone chore (no assignee), every day.
const dishes = Chore(id: 'dishes', title: 'Wash dishes', repeat: Repeat.daily, startDate: '2026-09-01', createdBy: 'u1');

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

void main() {
  testWidgets('a parent sees everyone: own section first, then children, then Anyone', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    expect(inside(section('u1'), 'Dad'), findsOneWidget);
    expect(inside(section('u1'), 'Take out bins'), findsOneWidget);
    expect(inside(section('u1'), '✓ 0/1'), findsOneWidget);
    expect(inside(section('u2'), 'Sara'), findsOneWidget);
    expect(inside(section('u2'), 'Brush teeth'), findsOneWidget);
    expect(tester.getTopLeft(section('u1')).dy, lessThan(tester.getTopLeft(section('u2')).dy));

    // Nothing is "anyone" on Thursday 1 Oct, but parents still see the Anyone section.
    await tester.ensureVisible(section('anyone'));
    await settle(tester);
    expect(inside(section('anyone'), 'Anyone'), findsOneWidget);
    expect(tester.getTopLeft(section('anyone')).dy, greaterThan(tester.getTopLeft(section('u2')).dy));
    expect(section('former'), findsNothing);
  });

  testWidgets('a child opens on Me and can switch to Everyone', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    expect(tester.widget<SegmentedButton<bool>>(find.byKey(const Key('choresScope'))).selected, {true});
    expect(section('u2'), findsOneWidget);
    expect(section('u1'), findsNothing);
    expect(section('anyone'), findsNothing); // Me hides an empty Anyone section

    await tester.tap(find.text('Everyone'));
    await settle(tester);
    expect(section('u1'), findsOneWidget);
    expect(section('anyone'), findsOneWidget);
  });

  testWidgets('cards show the emoji, time and repeat', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    final brush = find.byKey(const ValueKey('chore-brush'), skipOffstage: false);
    expect(inside(brush, '🪥'), findsOneWidget);
    expect(inside(brush, '7:00 AM · Daily'), findsOneWidget);
    expect(inside(find.byKey(const ValueKey('chore-bins'), skipOffstage: false), 'Mon, Thu'), findsOneWidget);
  });

  testWidgets('ticking writes a done record; Undo and a second tap remove it', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-brush'));
    final data = (await db.doc('families/f1/choreDone/brush_2026-10-01').get()).data()!;
    expect(data['choreId'], 'brush');
    expect(data['date'], '2026-10-01');
    expect(data['choreTitle'], 'Brush teeth');
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
    expect(data['dayNumber'], dayNumberOf(DateTime(2026, 10, 1)));
    expect(cardOf(tester, 'brush').status.isDone, isTrue);
    expect(find.text('Brush teeth done'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await isDone(db, 'brush_2026-10-01'), isFalse);
    expect(cardOf(tester, 'brush').status.isDone, isFalse);

    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-10-01'), isTrue);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-10-01'), isFalse);
  });

  testWidgets("a parent ticking a child's chore records the child", (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await tapKey(tester, const ValueKey('tick-brush'));
    final data = (await db.doc('families/f1/choreDone/brush_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
  });

  testWidgets("a child cannot tick someone else's chore", (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    await tester.tap(find.text('Everyone'));
    await settle(tester);
    expect(cardOf(tester, 'bins').onToggle, isNull);
    await tapKey(tester, const ValueKey('tick-bins'));
    expect(await isDone(db, 'bins_2026-10-01'), isFalse);
  });

  testWidgets('past days: a child can change yesterday but not the day before', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    expect(find.text('Today'), findsOneWidget);

    await tapKey(tester, const Key('dayPrev'));
    expect(find.text('Wed 30 Sep'), findsOneWidget);
    expect(cardOf(tester, 'brush').status.isDone, isTrue); // seeded done record
    expect(cardOf(tester, 'brush').onToggle, isNotNull);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-09-30'), isFalse);

    await tapKey(tester, const Key('dayPrev'));
    expect(find.text('Tue 29 Sep'), findsOneWidget);
    expect(cardOf(tester, 'brush').onToggle, isNull);

    await tapKey(tester, const Key('dayNext'));
    await tapKey(tester, const Key('dayNext'));
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('parents can correct any past day', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    for (var i = 0; i < 3; i++) {
      await tapKey(tester, const Key('dayPrev'));
    }
    expect(find.text('Mon 28 Sep'), findsOneWidget);
    await tapKey(tester, const ValueKey('tick-brush'));
    final data = (await db.doc('families/f1/choreDone/brush_2026-09-28').get()).data()!;
    expect(data['doneBy'], 'u2');
  });

  testWidgets('tapping the date opens a date picker', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await tapKey(tester, const Key('dayLabel'));
    await tester.tap(find.text('3'));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Sat 3 Oct'), findsOneWidget);
    // Water plants repeats on Saturdays.
    await tester.ensureVisible(section('anyone'));
    await settle(tester);
    expect(inside(section('anyone'), 'Water plants'), findsOneWidget);
  });

  testWidgets("long-press edits for parents and for a child's own chore only", (tester) async {
    final db = await seeded(); // brush was created by Dad
    await addChore(db, readBook);
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await longPressKey(tester, const ValueKey('chore-brush'));
    expect(find.byKey(const Key('choreTitle')), findsNothing);
    expect(await isDone(db, 'brush_2026-10-01'), isFalse); // a long press is not a tap

    await longPressKey(tester, const ValueKey('chore-read'));
    expect(find.byKey(const Key('choreTitle')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('choreTitle'))).controller!.text, 'Read a book');
  });

  testWidgets("a parent's long-press opens the sheet for any chore", (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    await longPressKey(tester, const ValueKey('chore-brush'));
    expect(tester.widget<TextField>(find.byKey(const Key('choreTitle'))).controller!.text, 'Brush teeth');
  });

  testWidgets("a deleted chore's done day still shows, read-only, with its copied title", (tester) async {
    final db = await seeded();
    await db.doc('families/f1/chores/brush').delete(); // brush_2026-09-30 stays as history
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(find.byKey(const ValueKey('chore-brush'), skipOffstage: false), findsNothing); // gone from today

    await tapKey(tester, const Key('dayPrev'));
    expect(inside(section('u2'), 'Brush teeth'), findsOneWidget);
    expect(cardOf(tester, 'brush').status.isDone, isTrue);
    expect(cardOf(tester, 'brush').onToggle, isNull);
    expect(cardOf(tester, 'brush').onLongPress, isNull);
    await longPressKey(tester, const ValueKey('chore-brush'));
    expect(find.byKey(const Key('choreTitle')), findsNothing);
    expect((await db.doc('families/f1/chores/brush').get()).exists, isFalse);
  });

  testWidgets('the add button opens an empty chore sheet', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    await tester.tap(find.byKey(const Key('addChore')));
    await settle(tester);
    expect(find.text('Add chore'), findsWidgets);
    expect(tester.widget<TextField>(find.byKey(const Key('choreTitle'))).controller!.text, isEmpty);
  });

  testWidgets('a day without chores shows a friendly empty state', (tester) async {
    final db = await seedFamily(); // no chores at all
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No chores today'), findsOneWidget);
  });

  testWidgets('picture tiles show big emoji tiles for that member only', (tester) async {
    final db = await seeded();
    await db.doc('families/f1/members/u2').update({'pictureTiles': true});
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(cardOf(tester, 'brush').pictureTile, isTrue);
    expect(cardOf(tester, 'bins').pictureTile, isFalse);
    final emoji = tester.widget<Text>(inside(find.byKey(const ValueKey('chore-brush'), skipOffstage: false), '🪥'));
    expect(emoji.style!.fontSize, 44);
  });

  testWidgets('long Arabic titles do not overflow on small phones', (tester) async {
    const title = 'ترتيب غرفة النوم وتنظيف المكتب وجمع الألعاب قبل موعد النوم';
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final scale in const [1.0, 1.3]) {
        for (final pictureTiles in const [false, true]) {
          final label = '$size, text x$scale, picture tiles $pictureTiles';
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final db = await seeded();
          await db.doc('families/f1/chores/brush').update({'title': title}); // keeps its 🪥
          await db.doc('families/f1/members/u2').update({'pictureTiles': pictureTiles});
          await pumpWithFamily(tester, db: db, uid: 'u2', child: arabic(const ChoresScreen()));
          expect(tester.takeException(), isNull, reason: label);

          // The title is cut to its lines with an ellipsis.
          final titleText = inside(find.byKey(const ValueKey('chore-brush'), skipOffstage: false), title);
          expect(tester.renderObject<RenderParagraph>(titleText).didExceedMaxLines, isTrue, reason: label);

          // The tick keeps a 48 dp target and still works.
          final tick = find.byKey(const ValueKey('tick-brush'), skipOffstage: false);
          await tester.ensureVisible(tick);
          await settle(tester);
          expect(tester.getSize(tick).width, greaterThanOrEqualTo(48), reason: label);
          expect(tester.getSize(tick).height, greaterThanOrEqualTo(48), reason: label);
          await tester.tap(tick);
          await settle(tester);
          expect(await isDone(db, 'brush_2026-10-01'), isTrue, reason: label);
          expect(tester.takeException(), isNull, reason: label);

          await tester.pumpWidget(const SizedBox()); // a fresh ProviderScope for the next case
        }
      }
    }
  });

  testWidgets('long English titles fit small phones in the family view', (tester) async {
    const long = 'Take the recycling and the garden waste bins out to the street';
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final scale in const [1.0, 1.3]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final db = await seeded();
        await db.doc('families/f1/chores/bins').update({'title': long});
        await db.doc('families/f1/chores/brush').update({'title': long});
        await db.doc('families/f1/members/u2').update({'pictureTiles': true});
        await pumpWithFamily(tester, db: db, child: const ChoresScreen());
        expect(tester.takeException(), isNull, reason: '$size, text x$scale');
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('the Chores tab sits between Today and Lists', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const HomeShell());
    final labels = [
      for (final d in tester.widgetList<NavigationDestination>(find.byType(NavigationDestination))) d.label,
    ];
    expect(labels, ['Today', 'Chores', 'Lists', 'Family']);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chores')));
    await settle(tester);
    expect(find.byKey(const Key('dayLabel')), findsOneWidget);
  });

  group('buildChoreGroups', () {
    const dad = Member(uid: 'u1', name: 'Dad', role: Role.parent);
    const sara = Member(uid: 'u2', name: 'Sara', role: Role.child);
    const mum = Member(uid: 'u3', name: 'Mum', role: Role.parent);
    const adam = Member(uid: 'u4', name: 'Adam', role: Role.child);
    const members = [sara, dad, adam, mum];

    ChoreStatus item(String id, {String? assignee}) => ChoreStatus(
          Chore(id: id, title: id, assignee: assignee, startDate: '2026-10-01', createdBy: 'u1'),
          null,
        );

    DayView view({List<ChoreStatus> anyone = const [], List<ChoreStatus> former = const []}) => DayView(
          byMember: {
            for (final m in members) m.uid: [item('c-${m.uid}', assignee: m.uid)],
          },
          anyone: anyone,
          formerMember: former,
        );

    List<String> ids(List<ChoreGroup> groups) => [for (final g in groups) g.id];

    test('me first, then parents, then children, each by name; then Anyone', () {
      expect(
        ids(buildChoreGroups(view: view(), members: members, me: 'u2', isParent: false, onlyMe: false)),
        ['u2', 'u1', 'u3', 'u4', 'anyone'],
      );
      expect(
        ids(buildChoreGroups(view: view(), members: members, me: 'u3', isParent: true, onlyMe: false)),
        ['u3', 'u1', 'u4', 'u2', 'anyone'],
      );
    });

    test('only me: my own group, plus Anyone when it has chores', () {
      expect(ids(buildChoreGroups(view: view(), members: members, me: 'u2', isParent: false, onlyMe: true)), ['u2']);
      expect(
        ids(buildChoreGroups(
          view: view(anyone: [item('dishes')]),
          members: members,
          me: 'u2',
          isParent: false,
          onlyMe: true,
        )),
        ['u2', 'anyone'],
      );
    });

    test('former members show to parents only, and only when they have chores', () {
      final withFormer = view(former: [item('old', assignee: 'u9')]);
      final forParent =
          buildChoreGroups(view: withFormer, members: members, me: 'u1', isParent: true, onlyMe: false);
      expect(forParent.last.id, 'former');
      expect(forParent.last.isFormer, isTrue);
      expect(
        ids(buildChoreGroups(view: withFormer, members: members, me: 'u2', isParent: false, onlyMe: false)),
        isNot(contains('former')),
      );
      expect(
        ids(buildChoreGroups(view: view(), members: members, me: 'u1', isParent: true, onlyMe: false)),
        isNot(contains('former')),
      );
    });
  });

  testWidgets('repeat labels read naturally', (tester) async {
    late AppLocalizations l;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l = AppLocalizations.of(context)!;
        return const SizedBox();
      }),
    ));
    Chore c({Repeat repeat = Repeat.daily, int every = 1, List<int> weekdays = const [], int? monthDay, String? endDate}) =>
        Chore(
          id: 'x',
          title: 'x',
          repeat: repeat,
          every: every,
          weekdays: weekdays,
          monthDay: monthDay,
          startDate: '2026-09-28',
          endDate: endDate,
          createdBy: 'u1',
        );
    expect(repeatLabel(l, c(repeat: Repeat.once)), 'Once · 28 Sep');
    expect(repeatLabel(l, c()), 'Daily');
    expect(repeatLabel(l, c(every: 2)), 'Every 2 days');
    expect(repeatLabel(l, c(repeat: Repeat.weekly, weekdays: [7, 1, 2, 3, 4])), 'Sun–Thu');
    expect(repeatLabel(l, c(repeat: Repeat.weekly, every: 2, weekdays: [4, 1])), 'Every 2 weeks · Mon, Thu');
    expect(repeatLabel(l, c(repeat: Repeat.monthly, monthDay: 15)), 'Monthly · day 15');
    expect(repeatLabel(l, c(repeat: Repeat.monthly, every: 3, monthDay: 31)), 'Every 3 months · day 31');
    expect(repeatLabel(l, c(endDate: '2027-06-30')), 'Daily · until 30 Jun');
  });

  testWidgets('a child can untick only a tick they made; parents can untick any', (tester) async {
    final db = await seeded();
    await addChore(db, dishes);
    // Dad's tick on Sara's own chore, and Dad's tick on an Anyone chore, today.
    await addDone(db, choreId: 'brush', title: 'Brush teeth', assignee: 'u2', date: '2026-10-01', doneBy: 'u1', doneByName: 'Dad');
    await addDone(db, choreId: 'dishes', title: 'Wash dishes', date: '2026-10-01', doneBy: 'u1', doneByName: 'Dad');
    // Sara's own tick on the Anyone chore, yesterday.
    await addDone(db, choreId: 'dishes', title: 'Wash dishes', date: '2026-09-30', doneBy: 'u2', doneByName: 'Sara');
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    // Me view; Anyone shows because it has a chore.
    expect(cardOf(tester, 'brush').status.isDone, isTrue);
    expect(cardOf(tester, 'brush').onToggle, isNull);
    expect(cardOf(tester, 'dishes').status.isDone, isTrue);
    expect(cardOf(tester, 'dishes').onToggle, isNull);
    await tapKey(tester, const ValueKey('tick-brush'));
    await tapKey(tester, const ValueKey('tick-dishes'));
    expect(await isDone(db, 'brush_2026-10-01'), isTrue);
    expect(await isDone(db, 'dishes_2026-10-01'), isTrue);

    // Wed 30 Sep: the seeded brush record is Sara's own tick, so she can untick it.
    await tapKey(tester, const Key('dayPrev'));
    expect(find.text('Wed 30 Sep'), findsOneWidget);
    expect(cardOf(tester, 'brush').onToggle, isNotNull);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-09-30'), isFalse);

    // Parents are unchanged: Dad can untick Sara's tick.
    await tester.pumpWidget(const SizedBox());
    await pumpWithFamily(tester, db: db, uid: 'u1', child: const ChoresScreen());
    await tapKey(tester, const Key('dayPrev'));
    expect(find.text('Wed 30 Sep'), findsOneWidget);
    expect(cardOf(tester, 'dishes').onToggle, isNotNull);
    await tapKey(tester, const ValueKey('tick-dishes'));
    expect(await isDone(db, 'dishes_2026-09-30'), isFalse);
  });

  testWidgets("a child can't tick the day before yesterday or tomorrow", (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await tapKey(tester, const Key('dayPrev'));
    await tapKey(tester, const Key('dayPrev'));
    expect(find.text('Tue 29 Sep'), findsOneWidget);
    expect(cardOf(tester, 'brush').status.isDone, isFalse);
    expect(cardOf(tester, 'brush').onToggle, isNull);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-09-29'), isFalse);

    for (var i = 0; i < 3; i++) {
      await tapKey(tester, const Key('dayNext'));
    }
    expect(find.text('Fri 2 Oct'), findsOneWidget);
    expect(cardOf(tester, 'brush').onToggle, isNull);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-10-02'), isFalse);
  });

  testWidgets('who did it comes from the member list, never from the copied name', (tester) async {
    final db = await seeded();
    await addChore(db, dishes);
    // Sara ticked it, but the record carries a forged name.
    await addDone(db, choreId: 'dishes', title: 'Wash dishes', date: '2026-10-01', doneBy: 'u2', doneByName: 'Dad');
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    expect(cardOf(tester, 'dishes').status.isDone, isTrue);
    // Sara's colour (brush sits in Sara's section), not Dad's (bins).
    expect(cardOf(tester, 'dishes').color.fill, cardOf(tester, 'brush').color.fill);
    expect(cardOf(tester, 'dishes').color.fill, isNot(cardOf(tester, 'bins').color.fill));
    expect(inside(section('anyone'), 'Dad'), findsNothing);
  });
}
