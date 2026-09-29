import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart' show ReminderSync;
import 'package:family_app/app/providers.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:family_app/features/chores/chore_card.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/chores/late_strip.dart';
import 'package:family_app/features/today/today_screen.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_scheduler.dart';
import '../support/pump.dart';
import '../support/seed.dart';

Future<FakeFirebaseFirestore> seeded() async {
  final db = await seedFamily();
  await seedChores(db);
  return db;
}

Future<bool> isDone(FakeFirebaseFirestore db, String doneId) async =>
    (await db.doc('families/f1/choreDone/$doneId').get()).exists;

Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key, skipOffstage: false));
  await settle(tester);
  await tester.tap(find.byKey(key));
  await settle(tester);
}

Finder byKey(Key key) => find.byKey(key, skipOffstage: false);

Finder inside(Finder parent, String text) => find.descendant(
      of: parent,
      matching: find.text(text, skipOffstage: false),
      skipOffstage: false,
    );

ChoreCard cardOf(WidgetTester tester, String choreId) =>
    tester.widget<ChoreCard>(byKey(ValueKey('chore-$choreId')));

Widget arabic(Widget child) => Builder(
      builder: (context) =>
          Localizations.override(context: context, locale: const Locale('ar'), child: child),
    );

/// Tells the app it went to the background or came back, as Android does.
Future<void> sendLifecycle(WidgetTester tester, AppLifecycleState state) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      (_) {},
    );

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
  testWidgets("Today shows everyone's progress, late chores and my chores", (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());

    expect(inside(byKey(const ValueKey('todayMember-u1')), '✓ 0/1'), findsOneWidget); // Dad: bins
    expect(inside(byKey(const ValueKey('todayMember-u2')), '✓ 0/1'), findsOneWidget); // Sara: brush
    expect(inside(byKey(const Key('todayMembers')), '✓ 0/1'), findsNWidgets(2));

    final strip = byKey(const Key('lateStrip'));
    expect(inside(strip, 'Water plants'), findsOneWidget);
    expect(inside(strip, 'Anyone · Late since 26 Sep'), findsOneWidget);
    expect(inside(strip, 'Order blinds'), findsOneWidget);
    expect(inside(strip, 'Anyone · Late since 28 Sep'), findsOneWidget);
    expect(
      tester.getTopLeft(byKey(const ValueKey('lateChore-plants'))).dy,
      lessThan(tester.getTopLeft(byKey(const ValueKey('lateChore-blinds'))).dy),
    );

    final mine = byKey(const Key('todayMyChores'));
    expect(inside(mine, 'Your chores'), findsOneWidget);
    expect(inside(mine, 'Brush teeth'), findsOneWidget);
    expect(find.text('Take out bins', skipOffstage: false), findsNothing);
  });

  testWidgets('ticking on Today updates my progress and says all done', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());

    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-10-01'), isTrue);
    expect(find.text('All done for today! 🎉', skipOffstage: false), findsOneWidget);
    expect(inside(byKey(const ValueKey('todayMember-u2')), '✓ 1/1'), findsOneWidget);
    expect(cardOf(tester, 'brush').status.isDone, isTrue);
  });

  testWidgets('a child clears an old late chore; it is recorded for today', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());

    await tapKey(tester, const ValueKey('tick-blinds')); // late since 28 Sep: too old for a child's own date
    final data = (await db.doc('families/f1/choreDone/blinds_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(await isDone(db, 'blinds_2026-09-28'), isFalse);
    expect(byKey(const ValueKey('lateChore-blinds')), findsNothing);
    expect(byKey(const ValueKey('lateChore-plants')), findsOneWidget);
  });

  testWidgets('the late strip is hidden when nothing is late', (tester) async {
    final db = await seeded();
    for (final done in [
      ChoreDone(
        choreId: 'plants',
        date: '2026-09-26',
        choreTitle: 'Water plants',
        doneBy: 'u1',
        doneByName: 'Dad',
        dayNumber: dayNumberOf(DateTime(2026, 9, 26)),
      ),
      ChoreDone(
        choreId: 'blinds',
        date: '2026-09-28',
        choreTitle: 'Order blinds',
        doneBy: 'u1',
        doneByName: 'Dad',
        dayNumber: dayNumberOf(DateTime(2026, 9, 28)),
      ),
    ]) {
      await db.doc('families/f1/choreDone/${done.id}').set(done.toMap());
    }
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());
    expect(byKey(const Key('lateStrip')), findsNothing);
    expect(byKey(const Key('todayMyChores')), findsOneWidget);
  });

  testWidgets('coming back to the app after midnight shows the new day', (tester) async {
    final db = await seeded();
    var now = DateTime(2026, 10, 1, 20);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        currentUidProvider.overrideWithValue('u2'),
        authReadyProvider.overrideWithValue(true),
        authPhotoUrlProvider.overrideWithValue(null),
        clockProvider.overrideWithValue(() => now), // a clock this test can move
        sharedPreferencesProvider.overrideWithValue(prefs),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ReminderSync(child: TodayScreen()),
      ),
    ));
    await settle(tester);
    expect(find.text('Thursday, October 1'), findsOneWidget);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(find.text('All done for today! 🎉', skipOffstage: false), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // let the burst finish
    await settle(tester);

    // The phone slept past midnight and the midnight timer has not fired yet.
    now = DateTime(2026, 10, 2, 7, 30);
    await sendLifecycle(tester, AppLifecycleState.paused);
    await sendLifecycle(tester, AppLifecycleState.resumed);
    await settle(tester);
    expect(find.text('Friday, October 2'), findsOneWidget);
    expect(find.text('All done for today! 🎉', skipOffstage: false), findsNothing);
    expect(cardOf(tester, 'brush').status.isDone, isFalse); // 2 Oct's brush is not done yet
  });

  testWidgets('Today fits small phones in Arabic', (tester) async {
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
          await db.doc('families/f1/chores/brush').update({
            'title': 'ترتيب غرفة النوم وتنظيف المكتب وجمع الألعاب قبل موعد النوم',
          });
          await db.doc('families/f1/members/u2').update({'pictureTiles': pictureTiles});
          await pumpWithFamily(tester, db: db, uid: 'u2', child: arabic(const TodayScreen()));
          expect(tester.takeException(), isNull, reason: label);
          expect(byKey(const Key('todayMyChores')), findsOneWidget, reason: label);
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  });

  // Extra M1 (must confirm 1): today or yesterday only, measured with todayProvider.
  testWidgets("a child can't tick the day before yesterday from the late strip", (tester) async {
    const vacuum = Chore(id: 'vacuum', title: 'Vacuum the hall', startDate: '2026-09-29', createdBy: 'u1');
    const laundry = Chore(id: 'laundry', title: 'Fold laundry', startDate: '2026-09-30', createdBy: 'u1');
    const call = Chore(
      id: 'call',
      title: 'Call the plumber',
      assignee: 'u1',
      startDate: '2026-09-29',
      createdBy: 'u1',
    );

    final today = DateTime(2026, 10, 1);
    expect(
      lateTickDay(chore: vacuum, date: '2026-09-29', isParent: false, me: 'u2', today: today),
      DateTime(2026, 10, 1),
    );
    expect(
      lateTickDay(chore: laundry, date: '2026-09-30', isParent: false, me: 'u2', today: today),
      DateTime(2026, 9, 30),
    );
    expect(lateTickDay(chore: call, date: '2026-09-29', isParent: false, me: 'u2', today: today), isNull);
    expect(
      lateTickDay(chore: vacuum, date: '2026-09-29', isParent: true, me: 'u1', today: today),
      DateTime(2026, 9, 29),
    );

    final db = await seeded();
    for (final chore in const [vacuum, laundry, call]) {
      await db.doc('families/f1/chores/${chore.id}').set(chore.toMap());
    }
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());
    expect(byKey(const ValueKey('lateChore-vacuum')), findsOneWidget);
    expect(byKey(const ValueKey('lateChore-laundry')), findsOneWidget);
    expect(byKey(const ValueKey('lateChore-call')), findsNothing); // onlyMine: Dad's chore

    await tapKey(tester, const ValueKey('tick-vacuum')); // the day before yesterday: recorded for today
    final vacuumDone = (await db.doc('families/f1/choreDone/vacuum_2026-10-01').get()).data()!;
    expect(vacuumDone['doneBy'], 'u2');
    expect(await isDone(db, 'vacuum_2026-09-29'), isFalse);

    ScaffoldMessenger.of(tester.element(find.byType(TodayScreen))).removeCurrentSnackBar();
    await settle(tester);
    await tapKey(tester, const ValueKey('tick-laundry')); // yesterday: recorded for yesterday
    expect(await isDone(db, 'laundry_2026-09-30'), isTrue);
    expect(await isDone(db, 'laundry_2026-10-01'), isFalse);

    await tester.pumpWidget(const SizedBox());
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    await tester.tap(find.text('Everyone'));
    await settle(tester);
    expect(tester.widget<ChoreCard>(byKey(const ValueKey('lateChore-call'))).onToggle, isNull);
    await tapKey(tester, const ValueKey('tick-call'));
    expect(await isDone(db, 'call_2026-09-29'), isFalse);
    expect(await isDone(db, 'call_2026-10-01'), isFalse);
  });

  // Extra M3 (must confirm 3, Extra 3): the Today untick guard.
  testWidgets('on Today a child can untick only their own tick', (tester) async {
    final db = await seeded();
    await db.doc('families/f1/chores/read').set(const Chore(
      id: 'read',
      title: 'Read a book',
      assignee: 'u2',
      repeat: Repeat.daily,
      startDate: '2026-09-01',
      createdBy: 'u2',
    ).toMap());
    // Dad ticked Sara's chore; Sara ticked her own.
    await addDone(
      db,
      choreId: 'brush',
      title: 'Brush teeth',
      assignee: 'u2',
      date: '2026-10-01',
      doneBy: 'u1',
      doneByName: 'Dad',
    );
    await addDone(
      db,
      choreId: 'read',
      title: 'Read a book',
      assignee: 'u2',
      date: '2026-10-01',
      doneBy: 'u2',
      doneByName: 'Sara',
    );
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());

    expect(cardOf(tester, 'brush').status.isDone, isTrue);
    expect(cardOf(tester, 'brush').onToggle, isNull);
    await tapKey(tester, const ValueKey('tick-brush'));
    expect(await isDone(db, 'brush_2026-10-01'), isTrue);

    expect(cardOf(tester, 'read').onToggle, isNotNull);
    await tapKey(tester, const ValueKey('tick-read'));
    expect(await isDone(db, 'read_2026-10-01'), isFalse);

    // The late strip's cards are never done, so they never offer an untick.
    final lateCards = find.byWidgetPredicate(
      (w) =>
          w is ChoreCard &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('lateChore-'),
      skipOffstage: false,
    );
    expect(lateCards, findsWidgets);
    for (final element in lateCards.evaluate()) {
      expect((element.widget as ChoreCard).status.isDone, isFalse);
    }
  });
}
