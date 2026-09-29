import 'package:family_app/core/chores.dart';
import 'package:family_app/core/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

// Thursday 1 October 2026, noon.
final now = DateTime(2026, 10, 1, 12);

Chore chore(
  String id, {
  String? assignee = 'me',
  String? time = '18:00',
  bool remind = true,
  Repeat repeat = Repeat.daily,
  List<int> weekdays = const [],
  String start = '2026-09-01',
  String? end,
}) =>
    Chore(
      id: id,
      title: 'Chore $id',
      assignee: assignee,
      time: time,
      repeat: repeat,
      weekdays: weekdays,
      startDate: start,
      endDate: end,
      remind: remind,
      createdBy: 'parent',
    );

ChoreDone doneOn(String choreId, String date) => ChoreDone(
      choreId: choreId,
      date: date,
      choreTitle: 'Chore $choreId',
      assignee: 'me',
      doneBy: 'me',
      doneByName: 'Me',
      dayNumber: 0,
    );

List<PlannedReminder> plan(
  List<Chore> chores, {
  List<ChoreDone> done = const [],
  bool everyone = false,
  int days = 7,
}) =>
    planReminders(chores: chores, done: done, me: 'me', everyone: everyone, now: now, days: days);

/// "choreId date" for each reminder, in order.
List<String> keys(List<PlannedReminder> reminders) => [for (final r in reminders) '${r.choreId} ${r.date}'];

const week = [
  '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05', '2026-10-06', '2026-10-07',
];

void main() {
  test('only chores with the reminder on and a time', () {
    final result = plan([
      chore('a'),
      chore('noRemind', remind: false),
      chore('noTime', time: null),
    ]);
    expect(keys(result), [for (final d in week) 'a $d']);
  });

  test('a reminder carries the chore, its day, its time and whose chore it is', () {
    final first = plan([chore('a')]).first;
    expect(first.choreId, 'a');
    expect(first.date, '2026-10-01');
    expect(first.title, 'Chore a');
    expect(first.at, DateTime(2026, 10, 1, 18));
    expect(first.assignee, 'me');
    expect(first.id, reminderId('a', '2026-10-01'));
  });

  test('my chores only; everyone adds other people\'s and "anyone" chores', () {
    final chores = [
      chore('mine', time: '18:00'),
      chore('sara', assignee: 'sara', time: '18:10'),
      chore('shared', assignee: null, time: '18:20'),
    ];
    expect(plan(chores, days: 1).map((r) => r.choreId), ['mine']);
    expect(plan(chores, everyone: true, days: 1).map((r) => r.choreId), ['mine', 'sara', 'shared']);
  });

  test('skips days that are already done', () {
    final result = plan([chore('a')], done: [doneOn('a', '2026-10-02'), doneOn('other', '2026-10-03')]);
    expect(keys(result), [for (final d in week) if (d != '2026-10-02') 'a $d']);
  });

  test('skips a time that has already passed today', () {
    final morning = plan([chore('a', time: '07:00')]);
    expect(keys(morning), [for (final d in week.skip(1)) 'a $d']);
    final noon = plan([chore('b', time: '12:00')]);
    expect(noon.first.date, '2026-10-02', reason: 'exactly now is not in the future');
  });

  test('covers 7 days from today by default, or the given number of days', () {
    expect(plan([chore('a')]).length, 7);
    expect(keys(plan([chore('a')], days: 2)), ['a 2026-10-01', 'a 2026-10-02']);
    expect(plan([chore('late', repeat: Repeat.once, start: '2026-10-07')]).length, 1);
    expect(plan([chore('far', repeat: Repeat.once, start: '2026-10-08')]), isEmpty);
    expect(plan([chore('past', repeat: Repeat.once, start: '2026-09-30')]), isEmpty);
  });

  test('follows the repeat rule and the end date', () {
    // Saturday is weekday 6: 3 October 2026.
    expect(keys(plan([chore('sat', repeat: Repeat.weekly, weekdays: [6])])), ['sat 2026-10-03']);
    expect(keys(plan([chore('ends', end: '2026-10-02')])), ['ends 2026-10-01', 'ends 2026-10-02']);
  });

  test('sorted by time across days and chores', () {
    final result = plan([
      chore('evening', time: '19:00'),
      chore('morning', time: '08:00'),
      chore('dinner', time: '18:00'),
    ], days: 2);
    expect(keys(result), [
      'dinner 2026-10-01',
      'evening 2026-10-01',
      'morning 2026-10-02',
      'dinner 2026-10-02',
      'evening 2026-10-02',
    ]);
  });

  test('ignores a malformed time', () {
    expect(plan([chore('bad', time: '25:99'), chore('odd', time: 'soon')]), isEmpty);
  });

  test('reminder ids are stable, positive and differ per chore and day', () {
    expect(reminderId('a', '2026-10-01'), reminderId('a', '2026-10-01'));
    expect(reminderId('a', '2026-10-01'), isNot(reminderId('a', '2026-10-02')));
    expect(reminderId('a', '2026-10-01'), isNot(reminderId('b', '2026-10-01')));
    // FNV-1a of "brush|2026-10-01", masked to 31 bits.
    expect(reminderId('brush', '2026-10-01'), 122604501);
    for (final r in plan([chore('a'), chore('b', time: '19:00')])) {
      expect(r.id, inInclusiveRange(0, 0x7fffffff));
    }
    final ids = {for (final r in plan([chore('a'), chore('b', time: '19:00')])) r.id};
    expect(ids.length, 14);
  });

  test('reminders compare by value', () {
    PlannedReminder make(String title) =>
        PlannedReminder(id: 1, choreId: 'a', date: '2026-10-01', title: title, at: DateTime(2026, 10, 1, 18));
    expect(make('T'), make('T'));
    expect(make('T').hashCode, make('T').hashCode);
    expect(make('T'), isNot(make('T2')));
  });
}
