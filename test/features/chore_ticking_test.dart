import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:family_app/features/chores/chore_card.dart';
import 'package:family_app/features/chores/chores_board.dart';
import 'package:family_app/features/chores/chores_screen.dart';
import 'package:family_app/features/chores/late_strip.dart';
import 'package:family_app/features/common/empty_state.dart';
import 'package:family_app/features/today/today_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Emoji in the celebration burst on screen now (0 when there is none).
int burstSize(WidgetTester tester) => find
    .descendant(of: find.byKey(const Key('celebration')), matching: find.byType(Text))
    .evaluate()
    .length;

/// An "anyone" chore that starts today, so it is never late in these tests.
const dishes = Chore(
  id: 'dishes',
  title: 'Wash dishes',
  repeat: Repeat.daily,
  startDate: '2026-10-01',
  createdBy: 'u1',
);

/// A second chore for Sara, so ticking one is not yet "all done".
const readBook = Chore(
  id: 'read',
  title: 'Read a book',
  assignee: 'u2',
  repeat: Repeat.daily,
  startDate: '2026-09-01',
  createdBy: 'u2',
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

ChoreCard cardOf(WidgetTester tester, String choreId) =>
    tester.widget<ChoreCard>(find.byKey(ValueKey('chore-$choreId'), skipOffstage: false));

/// A landscape tablet: 1280 × 800 dp.
void useTablet(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('a parent ticking an anyone chore picks who did it', (tester) async {
    final db = await seeded();
    await addChore(db, dishes);
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-dishes'));
    expect(find.text('Who did it?'), findsOneWidget);
    expect(find.byKey(const ValueKey('whoDid-u1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('whoDid-u2')));
    await settle(tester);

    final data = (await db.doc('families/f1/choreDone/dishes_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
    expect(data['choreTitle'], 'Wash dishes');
    expect(data['assignee'], isNull);
  });

  testWidgets('closing "who did it?" ticks nothing', (tester) async {
    final db = await seeded();
    await addChore(db, dishes);
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-dishes'));
    await tester.tapAt(const Offset(400, 10)); // the dimmed area above the sheet
    await settle(tester);
    expect(find.text('Who did it?'), findsNothing);
    expect(await isDone(db, 'dishes_2026-10-01'), isFalse);
  });

  testWidgets('a child ticking an anyone chore is recorded as themselves without asking', (tester) async {
    final db = await seeded();
    await addChore(db, dishes);
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-dishes'));
    expect(find.text('Who did it?'), findsNothing);
    final data = (await db.doc('families/f1/choreDone/dishes_2026-10-01').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
  });

  testWidgets("ticking celebrates; finishing a person's day celebrates big; unticking does not", (tester) async {
    final db = await seeded();
    await addChore(db, readBook);
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-brush')); // one of Sara's two chores
    expect(burstSize(tester), 8);
    await tester.pump(const Duration(seconds: 1)); // the burst lasts ~900 ms
    await settle(tester);
    expect(find.byKey(const Key('celebration')), findsNothing);

    await tapKey(tester, const ValueKey('tick-read')); // her last one for today
    expect(burstSize(tester), 24);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    await tapKey(tester, const ValueKey('tick-read')); // untick
    expect(find.byKey(const Key('celebration')), findsNothing);
    expect(await isDone(db, 'read_2026-10-01'), isFalse);
  });

  testWidgets('with animations off there is no burst, only a vibration', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());
    await tapKey(tester, const ValueKey('tick-brush')); // Sara's only chore: the big one
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('celebration')), findsNothing);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    expect(await isDone(db, 'brush_2026-10-01'), isTrue);
  });

  testWidgets('the Chores tab shows late chores only when viewing today', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(find.byType(LateStrip), findsOneWidget);
    final strip = find.byKey(const Key('lateStrip'), skipOffstage: false);
    for (final title in ['Order blinds', 'Water plants']) {
      expect(
        find.descendant(of: strip, matching: find.text(title, skipOffstage: false), skipOffstage: false),
        findsOneWidget,
      );
    }
    await tapKey(tester, const Key('dayPrev'));
    expect(find.byKey(const Key('lateStrip'), skipOffstage: false), findsNothing);
  });

  testWidgets('a parent ticks a late anyone chore for its own date', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-plants')); // late since Saturday 26 Sep
    await tester.tap(find.byKey(const ValueKey('whoDid-u2')));
    await settle(tester);

    final data = (await db.doc('families/f1/choreDone/plants_2026-09-26').get()).data()!;
    expect(data['doneBy'], 'u2');
    expect(data['doneByName'], 'Sara');
    expect(find.byKey(const ValueKey('lateChore-plants'), skipOffstage: false), findsNothing);
  });

  // Extra E1 (Extra 1): the chore Undo lasts as long as shopping's, 5 seconds.
  testWidgets('the chore Undo stays for 5 seconds', (tester) async {
    final db = await seeded();
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const ChoresScreen());

    await tapKey(tester, const ValueKey('tick-brush'));
    expect(find.text('Undo'), findsOneWidget);

    // The SnackBar's timer starts when its entrance animation ends, and its
    // exit starts on a later frame, so the time is moved on in two steps.
    await tester.pump(const Duration(milliseconds: 4100));
    await settle(tester); // about 4.9 s after the tap
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text('Undo'), findsNothing); // it closed by itself
    expect(await isDone(db, 'brush_2026-10-01'), isTrue); // closing is not Undo
  });

  // Extra M2 (must confirm 2): the name shown is never the record's copy.
  testWidgets('who did it never shows the copied name', (tester) async {
    final db = await seeded();
    await addChore(db, dishes);
    // Sara ticked both, but the records carry a forged name: no member is Mum.
    await addDone(db, choreId: 'dishes', title: 'Wash dishes', date: '2026-10-01', doneBy: 'u2', doneByName: 'Mum');
    await addDone(
      db,
      choreId: 'brush',
      title: 'Brush teeth',
      assignee: 'u2',
      date: '2026-10-01',
      doneBy: 'u2',
      doneByName: 'Mum',
    );

    void expectMemberColourNoCopiedName(String label) {
      expect(find.textContaining('Mum', skipOffstage: false), findsNothing, reason: label);
      expect(cardOf(tester, 'dishes').status.isDone, isTrue, reason: label);
      // Sara's colour (brush is her chore), not Dad's (bins).
      expect(cardOf(tester, 'dishes').color.fill, cardOf(tester, 'brush').color.fill, reason: label);
      expect(cardOf(tester, 'dishes').color.fill, isNot(cardOf(tester, 'bins').color.fill), reason: label);
    }

    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expectMemberColourNoCopiedName('phone');

    await tester.pumpWidget(const SizedBox());
    useTablet(tester);
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());
    expect(find.byType(ChoresBoard), findsOneWidget);
    expectMemberColourNoCopiedName('board');

    await tester.pumpWidget(const SizedBox());
    await pumpWithFamily(tester, db: db, uid: 'u2', child: const TodayScreen());
    expect(find.textContaining('Mum', skipOffstage: false), findsNothing);
    expect(cardOf(tester, 'brush').status.isDone, isTrue);
  });

  // Extra K1 (must keep 5 with the late strip).
  testWidgets('on a tablet the late strip sits above the board, and above the empty state on an empty day',
      (tester) async {
    useTablet(tester);
    final db = await seeded();
    await pumpWithFamily(tester, db: db, child: const ChoresScreen());

    expect(find.byType(ChoresBoard), findsOneWidget);
    final strip = find.byKey(const Key('lateStrip'));
    expect(strip, findsOneWidget);
    // Tops, because the strip may be taller than its 200 dp box.
    expect(
      tester.getTopLeft(strip).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('boardColumn-u1'))).dy),
    );

    await tapKey(tester, const ValueKey('tick-blinds'));
    await tester.tap(find.byKey(const ValueKey('whoDid-u2')));
    await settle(tester);
    final data = (await db.doc('families/f1/choreDone/blinds_2026-09-28').get()).data()!;
    expect(data['doneBy'], 'u2'); // a parent ticks the late date
    expect(find.byKey(const ValueKey('lateChore-blinds'), skipOffstage: false), findsNothing);

    // An empty day with a late chore: the late strip, then the empty state.
    await tester.pumpWidget(const SizedBox());
    final quiet = await seedFamily();
    await addChore(quiet, const Chore(id: 'blinds', title: 'Order blinds', startDate: '2026-09-28', createdBy: 'u1'));
    await pumpWithFamily(tester, db: quiet, child: const ChoresScreen());

    expect(find.byType(ChoresBoard), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No chores today'), findsOneWidget);
    final quietStrip = find.byKey(const Key('lateStrip'));
    expect(find.descendant(of: quietStrip, matching: find.text('Order blinds')), findsOneWidget);
    expect(tester.getTopLeft(quietStrip).dy, lessThan(tester.getTopLeft(find.byType(EmptyState)).dy));
  });
}
