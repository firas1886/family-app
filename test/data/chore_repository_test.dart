import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:family_app/app/providers.dart';
import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:family_app/data/chore_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/seed.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ChoreRepository repo;

  setUp(() async {
    db = await seedFamily();
    await seedChores(db);
    repo = ChoreRepository(db, 'f1');
  });

  Future<Chore> choreById(String id) async => (await repo.watchChores().first).firstWhere((c) => c.id == id);

  Future<List<ChoreDone>> doneIn(String from, String to) => repo.watchDone(fromDate: from, toDate: to).first;

  test('watchChores reads the seeded chores', () async {
    final chores = await repo.watchChores().first;
    expect(chores.map((c) => c.id).toSet(), {'brush', 'bins', 'plants', 'blinds'});
    final brush = chores.firstWhere((c) => c.id == 'brush');
    expect(brush.title, 'Brush teeth');
    expect(brush.icon, '🪥');
    expect(brush.assignee, 'u2');
    expect(brush.time, '07:00');
    expect(brush.repeat, Repeat.daily);
    expect(brush.remind, isTrue);
    final bins = chores.firstWhere((c) => c.id == 'bins');
    expect(bins.weekdays, [1, 4]);
    expect(chores.firstWhere((c) => c.id == 'plants').isAnyone, isTrue);
    expect(chores.firstWhere((c) => c.id == 'blinds').repeat, Repeat.once);
  });

  test('addChore writes the chore with createdAt and returns the new id', () async {
    const chore = Chore(
      id: '', title: ' Feed cat ', icon: '🐱', assignee: 'u2', time: '18:00',
      repeat: Repeat.monthly, every: 2, monthDay: 31, startDate: '2026-10-01',
      endDate: '2027-06-30', remind: true, createdBy: 'u2',
    );
    final id = await repo.addChore(chore);
    expect(id, isNotEmpty);
    final raw = (await db.doc('families/f1/chores/$id').get()).data()!;
    expect(raw['createdAt'], isNotNull);
    expect(raw['title'], 'Feed cat');
    expect(raw['repeat'], 'monthly');
    final back = await choreById(id);
    expect(back.title, 'Feed cat');
    expect(back.icon, '🐱');
    expect(back.assignee, 'u2');
    expect(back.time, '18:00');
    expect(back.every, 2);
    expect(back.monthDay, 31);
    expect(back.startDate, '2026-10-01');
    expect(back.endDate, '2027-06-30');
    expect(back.remind, isTrue);
    expect(back.createdBy, 'u2');
  });

  test('updateChore rewrites the rule, can clear fields and keeps createdAt', () async {
    final brush = await choreById('brush');
    await repo.updateChore(brush.copyWith(
      title: 'Brush teeth well', icon: null, time: null, repeat: Repeat.weekly, weekdays: [1, 3],
      assignee: null, remind: false,
    ));
    final back = await choreById('brush');
    expect(back.title, 'Brush teeth well');
    expect(back.icon, isNull);
    expect(back.time, isNull);
    expect(back.isAnyone, isTrue);
    expect(back.repeat, Repeat.weekly);
    expect(back.weekdays, [1, 3]);
    expect(back.remind, isFalse);
    expect(back.startDate, '2026-09-01');
    final raw = (await db.doc('families/f1/chores/brush').get()).data()!;
    expect(raw['createdAt'], isNotNull);
  });

  test('deleteChore removes the chore but keeps its done records', () async {
    await repo.deleteChore('brush');
    expect((await repo.watchChores().first).map((c) => c.id), isNot(contains('brush')));
    final done = await doneIn('2026-09-01', '2026-10-31');
    expect(done.single.choreId, 'brush');
    expect(done.single.choreTitle, 'Brush teeth');
  });

  test('tick writes a record with copied title, assignee and day number', () async {
    final at = DateTime(2026, 10, 1, 7, 10);
    await repo.tick(chore: await choreById('brush'), date: '2026-10-01', doneBy: 'u2', doneByName: 'Sara', now: at);
    final raw = (await db.doc('families/f1/choreDone/brush_2026-10-01').get()).data()!;
    final record = ChoreDone.fromMap(raw);
    expect(record.id, 'brush_2026-10-01');
    expect(record.choreId, 'brush');
    expect(record.date, '2026-10-01');
    expect(record.choreTitle, 'Brush teeth');
    expect(record.assignee, 'u2');
    expect(record.doneBy, 'u2');
    expect(record.doneByName, 'Sara');
    expect(record.doneAt, at);
    expect(record.dayNumber, dayNumberOf(DateTime(2026, 10, 1)));
    expect(raw['dayNumber'], isA<int>());
  });

  test('an anyone chore records who did it and no assignee', () async {
    await repo.tick(chore: await choreById('plants'), date: '2026-09-26', doneBy: 'u1', doneByName: 'Dad');
    final record = (await doneIn('2026-09-26', '2026-09-26')).single;
    expect(record.assignee, isNull);
    expect(record.doneBy, 'u1');
    expect(record.doneAt, isNotNull);
  });

  test('ticking twice gives one record; untick deletes it', () async {
    final brush = await choreById('brush');
    await repo.tick(chore: brush, date: '2026-10-01', doneBy: 'u2', doneByName: 'Sara');
    await repo.tick(chore: brush, date: '2026-10-01', doneBy: 'u1', doneByName: 'Dad');
    expect((await doneIn('2026-10-01', '2026-10-01')).length, 1);
    await repo.untick(choreId: 'brush', date: '2026-10-01');
    expect(await doneIn('2026-10-01', '2026-10-01'), isEmpty);
    expect((await doneIn('2026-09-30', '2026-09-30')).single.id, 'brush_2026-09-30');
  });

  test('watchDone returns only records dated within the range, both ends included', () async {
    final brush = await choreById('brush');
    for (final date in ['2026-09-27', '2026-09-28', '2026-10-01', '2026-10-02']) {
      await repo.tick(chore: brush, date: date, doneBy: 'u2', doneByName: 'Sara');
    }
    final inRange = await doneIn('2026-09-28', '2026-10-01');
    expect(inRange.map((d) => d.date).toSet(), {'2026-09-28', '2026-09-30', '2026-10-01'});
  });

  test('editing a chore keeps past done records and their copied titles', () async {
    final brush = await choreById('brush');
    await repo.tick(chore: brush, date: '2026-09-29', doneBy: 'u2', doneByName: 'Sara');
    await repo.updateChore(brush.copyWith(title: 'Floss', repeat: Repeat.weekly, weekdays: [1]));
    final done = await doneIn('2026-09-01', '2026-10-31');
    expect(done.map((d) => d.date).toSet(), {'2026-09-29', '2026-09-30'});
    expect(done.map((d) => d.choreTitle), everyElement('Brush teeth'));
  });

  test('providers expose chores, done records and today', () async {
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      currentUidProvider.overrideWithValue('u1'),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 1, 12)),
    ]);
    addTearDown(container.dispose);
    await container.read(appUserProvider.future);
    expect(container.read(todayProvider), DateTime(2026, 10, 1));
    expect(container.read(choreRepositoryProvider).familyId, 'f1');
    final chores = await container.read(choresProvider.future);
    expect(chores.length, 4);
    final done = await container.read(choreDoneProvider((from: '2026-09-30', to: '2026-10-01')).future);
    expect(done.single.id, 'brush_2026-09-30');
    expect(await container.read(choreDoneProvider((from: '2026-10-01', to: '2026-10-07')).future), isEmpty);
  });

  group('todayProvider', () {
    // testWidgets runs in fake time: tester.pump(duration) fires due timers, and the
    // test fails if any timer is still pending when it ends.
    testWidgets('is the local date and moves on just after local midnight', (tester) async {
      var now = DateTime(2026, 10, 1, 23, 59, 30);
      final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
      final seen = <DateTime>[];
      container.listen<DateTime>(todayProvider, (_, next) => seen.add(next));
      expect(container.read(todayProvider), DateTime(2026, 10, 1));

      await tester.pump(const Duration(seconds: 30)); // 00:00:00, timer not due yet
      expect(container.read(todayProvider), DateTime(2026, 10, 1));

      now = DateTime(2026, 10, 2, 0, 0, 1);
      await tester.pump(const Duration(seconds: 1)); // midnight + 1 s
      expect(container.read(todayProvider), DateTime(2026, 10, 2));

      now = DateTime(2026, 10, 3, 0, 0, 1);
      await tester.pump(const Duration(days: 1)); // the next timer was scheduled
      expect(container.read(todayProvider), DateTime(2026, 10, 3));
      expect(seen, [DateTime(2026, 10, 2), DateTime(2026, 10, 3)]);

      container.dispose();
    });

    testWidgets('disposing cancels the midnight timer', (tester) async {
      final container = ProviderContainer(overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 1, 12)),
      ]);
      expect(container.read(todayProvider), DateTime(2026, 10, 1));
      container.dispose();
      // No pending timer may remain: testWidgets fails the test otherwise.
      await tester.pump(const Duration(days: 2));
    });
  });
}
