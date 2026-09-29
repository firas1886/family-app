import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/features/chores/chore_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';
import '../support/seed.dart';

Future<void> openSheet(WidgetTester tester, FakeFirebaseFirestore db, {String uid = 'u1', Chore? chore}) async {
  await pumpWithFamily(
    tester,
    db: db,
    uid: uid,
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showChoreSheet(context, chore: chore, day: DateTime(2026, 10, 1)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await settle(tester);
}

/// The sheet scrolls: bring the widget into view first.
Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

Future<void> typeInto(WidgetTester tester, Key key, String text) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.enterText(find.byKey(key), text);
  await settle(tester);
}

Future<List<Map<String, dynamic>>> storedChores(FakeFirebaseFirestore db) async =>
    [for (final d in (await db.collection('families/f1/chores').get()).docs) d.data()];

Future<Chore> storedChore(FakeFirebaseFirestore db, String id) async =>
    Chore.fromMap(id, (await db.doc('families/f1/chores/$id').get()).data()!);

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

void main() {
  testWidgets('a parent adds a weekly chore for a child', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    // New chores from a parent start with the first child.
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('choreWho-u2'))).selected, isTrue);
    expect(find.byKey(const ValueKey('choreWho-u1')), findsOneWidget);
    expect(find.byKey(const ValueKey('choreWho-anyone')), findsOneWidget);

    await typeInto(tester, const Key('choreTitle'), '  Feed the cat ');
    await typeInto(tester, const Key('choreEmoji'), '🐱');
    await tapKey(tester, const ValueKey('choreRepeat-weekly'));
    // Weekly starts on the start day's weekday: Thursday.
    expect(tester.widget<FilterChip>(find.byKey(const ValueKey('choreWeekday-4'))).selected, isTrue);
    await tapKey(tester, const ValueKey('choreWeekday-1'));
    await typeInto(tester, const Key('choreEvery'), '2');
    expect(find.text('Every 2 weeks · Mon, Thu'), findsOneWidget); // live preview
    await tapKey(tester, const Key('choreSave'));

    final data = (await storedChores(db)).single;
    expect(data['title'], 'Feed the cat');
    expect(data['icon'], '🐱');
    expect(data['assignee'], 'u2');
    expect(data['repeat'], 'weekly');
    expect(data['every'], 2);
    expect(data['weekdays'], [1, 4]);
    expect(data['monthDay'], isNull);
    expect(data['startDate'], '2026-10-01');
    expect(data['endDate'], isNull);
    expect(data['remind'], isFalse);
    expect(data['createdBy'], 'u1');
    expect(find.byKey(const Key('choreSave')), findsNothing);
  });

  testWidgets('blank titles, weekly without days and bad month days are blocked inline', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);

    await typeInto(tester, const Key('choreTitle'), '   ');
    await tapKey(tester, const Key('choreSave'));
    expect(find.text('Please enter a title.'), findsOneWidget);

    await typeInto(tester, const Key('choreTitle'), 'Tidy up');
    expect(find.text('Please enter a title.'), findsNothing);
    await tapKey(tester, const ValueKey('choreRepeat-weekly'));
    await tapKey(tester, const ValueKey('choreWeekday-4')); // untick the only day
    await tapKey(tester, const Key('choreSave'));
    expect(find.text('Pick at least one day.'), findsOneWidget);

    await tapKey(tester, const ValueKey('choreRepeat-monthly'));
    await typeInto(tester, const Key('choreMonthDay'), '32');
    await tapKey(tester, const Key('choreSave'));
    expect(find.text('Pick a day between 1 and 31.'), findsOneWidget);

    expect(await storedChores(db), isEmpty);
    expect(find.byKey(const Key('choreSave')), findsOneWidget); // still open
  });

  testWidgets('the end date cannot be before the start date', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await typeInto(tester, const Key('choreTitle'), 'Water the garden');
    await tapKey(tester, const Key('choreEndNever')); // now ends on the start day, 1 Oct
    expect(find.byKey(const Key('choreEndDate')), findsOneWidget);

    await tapKey(tester, const Key('choreStart'));
    await tester.tap(find.text('5'));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Mon 5 Oct 2026'), findsOneWidget);

    await tapKey(tester, const Key('choreSave'));
    expect(find.text("The end date can't be before the start date."), findsOneWidget);
    expect(await storedChores(db), isEmpty);
  });

  testWidgets('a time can be picked and cleared; Remind needs a time', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);
    await typeInto(tester, const Key('choreTitle'), 'Practice piano');
    SwitchListTile remind() => tester.widget<SwitchListTile>(find.byKey(const Key('choreRemind')));
    expect(find.text('No time'), findsOneWidget);
    expect(remind().onChanged, isNull);

    await tapKey(tester, const Key('choreTime'));
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(remind().onChanged, isNotNull);

    await tapKey(tester, const Key('choreTimeClear'));
    expect(find.text('No time'), findsOneWidget);

    await tapKey(tester, const Key('choreTime'));
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tapKey(tester, const Key('choreRemind'));
    await tapKey(tester, const Key('choreSave'));
    final data = (await storedChores(db)).single;
    expect(data['time'], '08:00');
    expect(data['remind'], isTrue);
  });

  testWidgets('children only make chores for themselves', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db, uid: 'u2');
    expect(find.byKey(const ValueKey('choreWho-u2')), findsOneWidget);
    expect(find.byKey(const ValueKey('choreWho-u1')), findsNothing);
    expect(find.byKey(const ValueKey('choreWho-anyone')), findsNothing);
    await typeInto(tester, const Key('choreTitle'), 'Read a book');
    await tapKey(tester, const Key('choreSave'));
    final data = (await storedChores(db)).single;
    expect(data['assignee'], 'u2');
    expect(data['createdBy'], 'u2');
  });

  testWidgets('editing keeps the chore and changes only what was edited', (tester) async {
    final db = await seeded();
    await openSheet(tester, db, chore: await storedChore(db, 'bins'));
    expect(find.text('Edit chore'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('choreWho-u1'))).selected, isTrue);
    expect(tester.widget<FilterChip>(find.byKey(const ValueKey('choreWeekday-1'))).selected, isTrue);

    await typeInto(tester, const Key('choreTitle'), 'Take the bins out');
    await tapKey(tester, const Key('choreSave'));
    final data = (await db.doc('families/f1/chores/bins').get()).data()!;
    expect(data['title'], 'Take the bins out');
    expect(data['assignee'], 'u1');
    expect(data['repeat'], 'weekly');
    expect(data['weekdays'], [1, 4]);
    expect(data['startDate'], '2026-09-01');
    expect(await storedChores(db), hasLength(4));
  });

  testWidgets('a parent deletes a chore after confirming; its done days stay', (tester) async {
    final db = await seeded();
    await openSheet(tester, db, chore: await storedChore(db, 'brush'));
    await tapKey(tester, const Key('choreDelete'));
    expect(find.text('Delete the chore Brush teeth? Days already done stay in the history.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmYes')));
    await settle(tester);
    expect((await db.doc('families/f1/chores/brush').get()).exists, isFalse);
    expect((await db.doc('families/f1/choreDone/brush_2026-09-30').get()).exists, isTrue);
    expect(find.byKey(const Key('choreSave')), findsNothing);
  });

  testWidgets('a child can delete a chore they made for themselves', (tester) async {
    final db = await seeded();
    const own = Chore(
      id: 'read',
      title: 'Read a book',
      assignee: 'u2',
      repeat: Repeat.daily,
      startDate: '2026-09-01',
      createdBy: 'u2',
    );
    await db.doc('families/f1/chores/read').set(own.toMap());
    await openSheet(tester, db, uid: 'u2', chore: own);
    expect(find.byKey(const Key('choreDelete')), findsOneWidget);
  });

  testWidgets("a child cannot delete a parent's chore", (tester) async {
    final db = await seeded(); // brush was created by Dad
    await openSheet(tester, db, uid: 'u2', chore: await storedChore(db, 'brush'));
    expect(find.byKey(const Key('choreDelete')), findsNothing);
  });

  testWidgets('the sheet fits small phones in Arabic', (tester) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final size in const [Size(320, 640), Size(360, 740)]) {
      for (final scale in const [1.0, 1.3]) {
        final label = '$size, text x$scale';
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final db = await seedFamily();
        await pumpWithFamily(
          tester,
          db: db,
          child: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('ar'),
              child: Scaffold(body: ChoreSheet(day: DateTime(2026, 10, 1))),
            ),
          ),
        );
        await tapKey(tester, const ValueKey('choreRepeat-weekly'));
        await tapKey(tester, const Key('choreEndNever'));
        await tapKey(tester, const Key('choreSave')); // shows the inline messages too
        expect(tester.takeException(), isNull, reason: label);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  // Extra E2 (Extra 2): an emoji is 2 of the 80, as Save counts it.
  testWidgets('the title counter counts what Save checks', (tester) async {
    final db = await seedFamily();
    await openSheet(tester, db);

    await typeInto(tester, const Key('choreTitle'), '  Tidy up ');
    expect(find.text('7/80'), findsOneWidget); // the trimmed length

    await typeInto(tester, const Key('choreTitle'), '😀' * 45);
    expect(find.text('90/80'), findsOneWidget);
    expect(find.text('45/80'), findsNothing);

    await tapKey(tester, const Key('choreSave'));
    expect(find.text('Keep the title to 80 characters or fewer.'), findsOneWidget);
    expect(await storedChores(db), isEmpty);
    expect(find.byKey(const Key('choreSave')), findsOneWidget); // the sheet stays open
  });
}
