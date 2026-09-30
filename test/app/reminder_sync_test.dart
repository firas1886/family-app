import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/app.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/reminders.dart';
import 'package:family_app/data/chore_repository.dart';
import 'package:family_app/features/chores/chore_sheet.dart';
import 'package:family_app/features/family/family_screen.dart';
import 'package:family_app/features/lists/lists_screen.dart';
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

// testNow is Thursday 1 October 2026, 12:00.
const dishes = Chore(
  id: 'dishes', title: 'Dishes', assignee: 'u1', time: '18:00', repeat: Repeat.daily,
  startDate: '2026-09-01', remind: true, createdBy: 'u1',
);
const teeth = Chore(
  id: 'teeth', title: 'Brush teeth', assignee: 'u2', time: '07:00', repeat: Repeat.daily,
  startDate: '2026-09-01', remind: true, createdBy: 'u1',
);
const plants = Chore(
  id: 'plants', title: 'Water plants', time: '19:00', repeat: Repeat.daily,
  startDate: '2026-09-01', remind: true, createdBy: 'u1',
);
const bins = Chore(
  id: 'bins', title: 'Bins', assignee: 'u1', time: '20:00', repeat: Repeat.daily,
  startDate: '2026-09-01', createdBy: 'u1',
);

Future<FakeFirebaseFirestore> seedWithChores() async {
  final db = await seedFamily();
  for (final c in [dishes, teeth, plants, bins]) {
    await db.doc('families/f1/chores/${c.id}').set(c.toMap());
  }
  return db;
}

Future<FakeReminderScheduler> pumpSync(WidgetTester tester, FakeFirebaseFirestore db, {String uid = 'u1'}) async {
  final scheduler = FakeReminderScheduler();
  await pumpWithFamily(tester, db: db, uid: uid, scheduler: scheduler, child: const ReminderSync(child: SizedBox()));
  await settle(tester);
  return scheduler;
}

ProviderContainer containerOf(WidgetTester tester, Type widget) =>
    ProviderScope.containerOf(tester.element(find.byType(widget)));

/// "choreId date" for each scheduled reminder, in order.
List<String> keys(List<PlannedReminder> reminders) => [for (final r in reminders) '${r.choreId} ${r.date}'];

/// Tells the app it went to the background or came back, as Android does.
Future<void> sendLifecycle(WidgetTester tester, AppLifecycleState state) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      (_) {},
    );

void main() {
  group('ReminderSync', () {
    testWidgets('on start, schedules my reminders for the next 7 days and asks permission once', (tester) async {
      final db = await seedWithChores();
      final scheduler = await pumpSync(tester, db);
      expect(keys(scheduler.scheduled), [
        for (var day = 1; day <= 7; day++) 'dishes 2026-10-0$day',
      ]);
      expect(scheduler.scheduled.first.at, DateTime(2026, 10, 1, 18));
      expect(scheduler.permissionRequests, 1);
    });

    testWidgets('ticking today\'s chore removes today\'s reminder', (tester) async {
      final db = await seedWithChores();
      final scheduler = await pumpSync(tester, db);
      await ChoreRepository(db, 'f1').tick(chore: dishes, date: '2026-10-01', doneBy: 'u1', doneByName: 'Dad');
      await settle(tester);
      expect(scheduler.scheduled.length, 6);
      expect(scheduler.scheduled.first.date, '2026-10-02');
      expect(scheduler.permissionRequests, 1, reason: 'the phone is asked only once');
    });

    testWidgets('a parent who turns on "everyone" also gets everyone\'s reminders', (tester) async {
      final db = await seedWithChores();
      final scheduler = await pumpSync(tester, db);
      containerOf(tester, ReminderSync).read(remindEveryoneProvider.notifier).setOn(true);
      await settle(tester);
      expect(scheduler.scheduled.map((r) => r.choreId).toSet(), {'dishes', 'teeth', 'plants'});
      expect(keys(scheduler.scheduled).take(3), ['dishes 2026-10-01', 'plants 2026-10-01', 'teeth 2026-10-02']);
      expect((await SharedPreferences.getInstance()).getBool('remindEveryone'), isTrue);
    });

    testWidgets('a child gets only their own reminders, even with "everyone" on', (tester) async {
      final db = await seedWithChores();
      final scheduler = await pumpSync(tester, db, uid: 'u2');
      containerOf(tester, ReminderSync).read(remindEveryoneProvider.notifier).setOn(true);
      await settle(tester);
      expect(scheduler.scheduled.map((r) => r.choreId).toSet(), {'teeth'});
      expect(scheduler.scheduled.length, 6, reason: 'today 07:00 has already passed');
    });

    testWidgets('with nothing to remind about, clears reminders and does not ask', (tester) async {
      final db = await seedFamily();
      final scheduler = FakeReminderScheduler()
        ..scheduled = [
          PlannedReminder(id: 1, choreId: 'old', date: '2026-10-01', title: 'Old', at: DateTime(2026, 10, 1, 18)),
        ];
      await pumpWithFamily(tester, db: db, scheduler: scheduler, child: const ReminderSync(child: SizedBox()));
      await settle(tester);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.permissionRequests, 0);
    });

    testWidgets('coming back after midnight moves the day on, even when Today is not built', (tester) async {
      final db = await seedWithChores();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final scheduler = FakeReminderScheduler();
      var now = DateTime(2026, 10, 1, 20);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          currentUidProvider.overrideWithValue('u1'),
          authReadyProvider.overrideWithValue(true),
          authPhotoUrlProvider.overrideWithValue(null),
          clockProvider.overrideWithValue(() => now), // a clock this test can move
          sharedPreferencesProvider.overrideWithValue(prefs),
          reminderSchedulerProvider.overrideWithValue(scheduler),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReminderSync(child: ListsScreen()), // the Lists tab alone: no Today widgets
        ),
      ));
      await settle(tester);
      expect(find.byType(TodayScreen, skipOffstage: false), findsNothing);
      expect(find.byType(TodayChores, skipOffstage: false), findsNothing);
      final container = containerOf(tester, ReminderSync);
      expect(container.read(todayProvider), DateTime(2026, 10, 1));
      // 1 Oct 18:00 has passed at 20:00.
      expect(keys(scheduler.scheduled), [for (var day = 2; day <= 7; day++) 'dishes 2026-10-0$day']);

      // The phone slept past midnight and the midnight timer has not fired yet.
      now = DateTime(2026, 10, 2, 7, 30);
      await sendLifecycle(tester, AppLifecycleState.paused);
      await sendLifecycle(tester, AppLifecycleState.resumed);
      await settle(tester);
      expect(container.read(todayProvider), DateTime(2026, 10, 2));
      expect(keys(scheduler.scheduled), [for (var day = 2; day <= 8; day++) 'dishes 2026-10-0$day']);
    });

    testWidgets('a phone that says no when ReminderSync asks gets the explanation once', (tester) async {
      final db = await seedWithChores();
      final scheduler = FakeReminderScheduler()..permission = false;
      await pumpWithFamily(tester, db: db, uid: 'u2', scheduler: scheduler, child: const ReminderSync(child: SizedBox()));
      await settle(tester);
      expect(scheduler.permissionRequests, 1);
      expect(find.byKey(const Key('notificationsDenied')), findsOneWidget);
      expect(find.textContaining('Notifications are off for Family'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(find.byKey(const Key('notificationsDenied')), findsNothing);

      // Tomorrow's chore is ticked: the reminders are planned again, but nothing asks or explains again.
      await ChoreRepository(db, 'f1').tick(chore: teeth, date: '2026-10-02', doneBy: 'u2', doneByName: 'Sara');
      await settle(tester);
      expect(scheduler.scheduled.length, 5);
      expect(scheduler.permissionRequests, 1);
      expect(scheduler.checks, 0);
      expect(find.byKey(const Key('notificationsDenied')), findsNothing);
    });
  });

  group('asking for the notification permission', () {
    Future<void> openSheet(WidgetTester tester, FakeReminderScheduler scheduler) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final db = await seedFamily();
      await pumpWithFamily(
        tester,
        db: db,
        scheduler: scheduler,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showChoreSheet(context, day: DateTime(2026, 10, 1)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      // Remind stays off until the chore has a time (Task 6): pick 8:00 AM first.
      await tester.ensureVisible(find.byKey(const Key('choreTime'), skipOffstage: false));
      await settle(tester);
      await tester.tap(find.byKey(const Key('choreTime')));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('choreRemind')));
      await settle(tester);
    }

    testWidgets('switching Remind on in the chore sheet asks; switching it off does not', (tester) async {
      final scheduler = FakeReminderScheduler();
      await openSheet(tester, scheduler);
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(scheduler.permissionRequests, 1);
      expect(find.byKey(const Key('notificationsDenied')), findsNothing);

      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(scheduler.permissionRequests, 1);
    });

    testWidgets('when the phone says no, the sheet explains how to turn notifications on', (tester) async {
      final scheduler = FakeReminderScheduler()..permission = false;
      await openSheet(tester, scheduler);
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(find.byKey(const Key('notificationsDenied')), findsOneWidget);
      expect(find.textContaining('Notifications are off for Family'), findsOneWidget);
    });

    testWidgets('parents see "Remind me about everyone\'s chores"; turning it on saves it and asks', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final db = await seedFamily();
      final scheduler = FakeReminderScheduler();
      await pumpWithFamily(tester, db: db, scheduler: scheduler, child: const FamilyScreen());
      expect(find.text("Remind me about everyone's chores"), findsOneWidget);

      await tester.tap(find.byKey(const Key('remindEveryone')));
      await settle(tester);
      expect(containerOf(tester, FamilyScreen).read(remindEveryoneProvider), isTrue);
      expect((await SharedPreferences.getInstance()).getBool('remindEveryone'), isTrue);
      expect(scheduler.permissionRequests, 1);
    });

    testWidgets('children do not see the remind-everyone switch', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final db = await seedFamily();
      await pumpWithFamily(tester, db: db, uid: 'u2', child: const FamilyScreen());
      expect(find.byKey(const Key('leaveFamily')), findsOneWidget);
      expect(find.byKey(const Key('remindEveryone')), findsNothing);
    });

    testWidgets('after the chore sheet asked, saving a reminder does not ask again', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final db = await seedFamily();
      final scheduler = FakeReminderScheduler()..permission = false;
      await pumpWithFamily(
        tester,
        db: db,
        scheduler: scheduler,
        child: ReminderSync(
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showChoreSheet(context, day: DateTime(2026, 10, 1)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(scheduler.permissionRequests, 0, reason: 'nothing to remind about yet');
      await tester.tap(find.text('open'));
      await settle(tester);
      // Remind stays off until the chore has a time (Task 6): pick 8:00 AM first.
      await tester.ensureVisible(find.byKey(const Key('choreTime'), skipOffstage: false));
      await settle(tester);
      await tester.tap(find.byKey(const Key('choreTime')));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('choreRemind')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(scheduler.permissionRequests, 1);
      expect(find.byKey(const Key('notificationsDenied')), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);

      // The chore is saved (written here the way Save writes it): this phone now has a reminder to show.
      await db.doc('families/f1/chores/dishes').set(dishes.toMap());
      await settle(tester);
      expect(keys(scheduler.scheduled), [for (var day = 1; day <= 7; day++) 'dishes 2026-10-0$day']);
      expect(scheduler.permissionRequests, 1, reason: 'Android was already asked on this phone');
      expect(find.byKey(const Key('notificationsDenied')), findsNothing, reason: 'the explanation was already shown');
    });

    testWidgets('Android asks only once; later, turning Remind on checks and explains while notifications are off', (tester) async {
      final scheduler = FakeReminderScheduler()..permission = false;
      await openSheet(tester, scheduler);
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(scheduler.permissionRequests, 1);
      expect(find.byKey(const Key('notificationsDenied')), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);

      // Off and on again while notifications are still off: no second prompt, the same explanation.
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(scheduler.permissionRequests, 1, reason: 'Android is asked at most once per phone');
      expect(scheduler.checks, 1);
      expect(find.byKey(const Key('notificationsDenied')), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);

      // Notifications turned on in the phone's settings: no prompt and no explanation.
      scheduler.permission = true;
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('choreRemind')));
      await settle(tester);
      expect(scheduler.permissionRequests, 1);
      expect(scheduler.checks, 2);
      expect(find.byKey(const Key('notificationsDenied')), findsNothing);
      expect((await SharedPreferences.getInstance()).getBool('notificationsAsked'), isTrue);
    });
  });
}
