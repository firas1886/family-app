import 'package:family_app/core/chores.dart';
import 'package:family_app/core/dates.dart';
import 'package:flutter_test/flutter_test.dart';

// September 2026: the 1st is a Tuesday; Sundays are 6, 13, 20, 27. 1 October is a Thursday.
DateTime d(String key) => parseDateKey(key);

Chore chore({
  String id = 'c1',
  String title = 'Chore',
  String? icon,
  String? assignee = 'u2',
  String? time,
  Repeat repeat = Repeat.daily,
  int every = 1,
  List<int> weekdays = const [],
  int? monthDay,
  String start = '2026-09-01',
  String? end,
  bool remind = false,
  String createdBy = 'u1',
}) =>
    Chore(
      id: id,
      title: title,
      icon: icon,
      assignee: assignee,
      time: time,
      repeat: repeat,
      every: every,
      weekdays: weekdays,
      monthDay: monthDay,
      startDate: start,
      endDate: end,
      remind: remind,
      createdBy: createdBy,
    );

ChoreDone doneOn(Chore c, String date, {String doneBy = 'u2', String? title}) => ChoreDone(
      choreId: c.id,
      date: date,
      choreTitle: title ?? c.title,
      assignee: c.assignee,
      doneBy: doneBy,
      doneByName: doneBy == 'u1' ? 'Dad' : 'Sara',
      doneAt: d(date).add(const Duration(hours: 8)),
      dayNumber: dayNumberOf(d(date)),
    );

/// The dates in [from]..[to] (inclusive) on which [c] occurs.
List<String> occurrences(Chore c, String from, String to) => [
      for (var day = d(from); !day.isAfter(d(to)); day = addDays(day, 1))
        if (occursOn(c, day)) dateKey(day),
    ];

List<String> ids(List<ChoreStatus> items) => [for (final s in items) s.chore.id];

void main() {
  group('occursOn', () {
    test('once occurs only on its date, whatever the time of day', () {
      final c = chore(repeat: Repeat.once, start: '2026-09-28');
      expect(occurrences(c, '2026-09-20', '2026-10-10'), ['2026-09-28']);
      expect(occursOn(c, DateTime(2026, 9, 28, 23, 59)), isTrue);
    });

    test('daily occurs every day from the start date', () {
      final c = chore(start: '2026-09-28');
      expect(occurrences(c, '2026-09-26', '2026-10-01'), ['2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01']);
    });

    test('every 3 days counts from the start date', () {
      final c = chore(every: 3, start: '2026-09-29');
      expect(occurrences(c, '2026-09-25', '2026-10-10'), ['2026-09-29', '2026-10-02', '2026-10-05', '2026-10-08']);
    });

    test('every 2 days runs across a year end', () {
      final c = chore(every: 2, start: '2026-12-30');
      expect(occurrences(c, '2026-12-28', '2027-01-04'), ['2026-12-30', '2027-01-01', '2027-01-03']);
    });

    test('nothing before the start date; the end date is inclusive', () {
      final c = chore(start: '2026-09-28', end: '2026-09-30');
      expect(occurrences(c, '2026-09-25', '2026-10-05'), ['2026-09-28', '2026-09-29', '2026-09-30']);
    });

    test('an end date equal to the start date gives a single day', () {
      expect(occurrences(chore(start: '2026-09-28', end: '2026-09-28'), '2026-09-01', '2026-10-31'), ['2026-09-28']);
    });

    test('weekly occurs on the chosen weekdays only', () {
      final c = chore(repeat: Repeat.weekly, weekdays: [1, 4]); // Mon, Thu
      expect(occurrences(c, '2026-09-27', '2026-10-10'), ['2026-09-28', '2026-10-01', '2026-10-05', '2026-10-08']);
    });

    test('weekly Sun–Thu covers a whole school week', () {
      final c = chore(repeat: Repeat.weekly, weekdays: [7, 1, 2, 3, 4]);
      expect(
        occurrences(c, '2026-09-26', '2026-10-03'),
        ['2026-09-27', '2026-09-28', '2026-09-29', '2026-09-30', '2026-10-01'],
      );
    });

    test('every 2 weeks: weeks start on Sunday', () {
      // Starts Saturday 5 Sep; its week began Sunday 30 Aug. Sunday 6 Sep is already week 1 (off).
      final c = chore(repeat: Repeat.weekly, every: 2, weekdays: [6, 7], start: '2026-09-05');
      expect(occurrences(c, '2026-08-30', '2026-10-03'), ['2026-09-05', '2026-09-13', '2026-09-19', '2026-09-27', '2026-10-03']);
    });

    test('every 2 weeks counts from the week containing the start date', () {
      // Starts Wednesday 2 Sep: Monday 31 Aug is before the start, Monday 7 Sep is in week 1.
      final c = chore(repeat: Repeat.weekly, every: 2, weekdays: [1], start: '2026-09-02');
      expect(occurrences(c, '2026-08-30', '2026-10-04'), ['2026-09-14', '2026-09-28']);
    });

    test('every 3 weeks runs across a year end', () {
      final c = chore(repeat: Repeat.weekly, every: 3, weekdays: [5], start: '2026-12-18'); // Fridays
      expect(occurrences(c, '2026-12-01', '2027-02-10'), ['2026-12-18', '2027-01-08', '2027-01-29']);
    });

    test('weekly without weekdays never occurs', () {
      expect(occurrences(chore(repeat: Repeat.weekly), '2026-09-01', '2026-10-31'), isEmpty);
    });

    test('monthly occurs on its day of the month', () {
      final c = chore(repeat: Repeat.monthly, monthDay: 15);
      expect(occurrences(c, '2026-09-01', '2026-12-31'), ['2026-09-15', '2026-10-15', '2026-11-15', '2026-12-15']);
    });

    test('every 2 months counts from the start month; a day before the start is skipped', () {
      final c = chore(repeat: Repeat.monthly, every: 2, monthDay: 10, start: '2026-09-20');
      expect(occurrences(c, '2026-09-01', '2027-03-31'), ['2026-11-10', '2027-01-10', '2027-03-10']);
    });

    test('monthly on the 31st falls on the last day of short months', () {
      final c = chore(repeat: Repeat.monthly, monthDay: 31, start: '2026-01-01');
      expect(occurrences(c, '2026-01-01', '2026-12-31'), [
        '2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31', '2026-06-30',
        '2026-07-31', '2026-08-31', '2026-09-30', '2026-10-31', '2026-11-30', '2026-12-31',
      ]);
      // Leap year: 29 February, not the 28th; exactly once in the month.
      expect(occurrences(c, '2028-02-01', '2028-03-01'), ['2028-02-29']);
      // 30-day month: exactly once, on the 30th.
      expect(occurrences(c, '2026-04-01', '2026-04-30'), ['2026-04-30']);
      expect(occursOn(c, d('2026-04-29')), isFalse);
    });

    test('monthly on the 29th and 30th in February, leap and non-leap', () {
      final on29 = chore(repeat: Repeat.monthly, monthDay: 29, start: '2027-01-01');
      expect(occurrences(on29, '2027-02-01', '2027-03-31'), ['2027-02-28', '2027-03-29']);
      expect(occurrences(on29, '2028-02-01', '2028-02-29'), ['2028-02-29']);
      final on30 = chore(repeat: Repeat.monthly, monthDay: 30, start: '2027-01-01');
      expect(occurrences(on30, '2027-02-01', '2027-03-31'), ['2027-02-28', '2027-03-30']);
      expect(occurrences(on30, '2028-02-01', '2028-02-29'), ['2028-02-29']);
      expect(occurrences(on30, '2027-04-01', '2027-04-30'), ['2027-04-30']);
    });

    test('monthly stops after its end date', () {
      final c = chore(repeat: Repeat.monthly, monthDay: 1, start: '2026-09-01', end: '2026-11-01');
      expect(occurrences(c, '2026-09-01', '2027-01-31'), ['2026-09-01', '2026-10-01', '2026-11-01']);
    });

    test('monthly without a day never occurs', () {
      expect(occurrences(chore(repeat: Repeat.monthly), '2026-09-01', '2026-12-31'), isEmpty);
    });

    test('every below 1 is treated as 1; a malformed start date never occurs', () {
      expect(occurrences(chore(every: 0, start: '2026-09-28'), '2026-09-28', '2026-09-30'),
          ['2026-09-28', '2026-09-29', '2026-09-30']);
      expect(occursOn(chore(start: 'soon'), d('2026-09-28')), isFalse);
    });
  });

  group('Chore and ChoreDone', () {
    test('isAnyone when there is no assignee', () {
      expect(chore(assignee: null).isAnyone, isTrue);
      expect(chore(assignee: 'u2').isAnyone, isFalse);
    });

    test('Chore round-trips through toMap and fromMap', () {
      final c = chore(
        id: 'bins', title: 'Take out bins', icon: '🗑️', assignee: 'u1', time: '19:30',
        repeat: Repeat.weekly, every: 2, weekdays: [4, 1], start: '2026-09-01', end: '2027-06-30',
        remind: true, createdBy: 'u1',
      );
      final map = c.toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
      expect(map['repeat'], 'weekly');
      final back = Chore.fromMap('bins', map);
      expect(back.id, 'bins');
      expect(back.title, 'Take out bins');
      expect(back.icon, '🗑️');
      expect(back.assignee, 'u1');
      expect(back.time, '19:30');
      expect(back.repeat, Repeat.weekly);
      expect(back.every, 2);
      expect(back.weekdays, [1, 4]);
      expect(back.monthDay, isNull);
      expect(back.startDate, '2026-09-01');
      expect(back.endDate, '2027-06-30');
      expect(back.remind, isTrue);
      expect(back.createdBy, 'u1');
    });

    test('toMap trims the title and clears fields that do not apply to the repeat', () {
      final map = chore(title: '  Make bed ', repeat: Repeat.daily, weekdays: [1], monthDay: 5).toMap();
      expect(map['title'], 'Make bed');
      expect(map['weekdays'], isEmpty);
      expect(map['monthDay'], isNull);
      expect(chore(repeat: Repeat.once, every: 3).toMap()['every'], 1);
      expect(chore(repeat: Repeat.monthly, monthDay: 31).toMap()['monthDay'], 31);
    });

    test('fromMap tolerates missing fields and Firestore number types', () {
      final c = Chore.fromMap('x', {'title': 'Tidy', 'startDate': '2026-09-01', 'every': 2.0, 'weekdays': [1.0, 3]});
      expect(c.repeat, Repeat.once);
      expect(c.every, 2);
      expect(c.weekdays, [1, 3]);
      expect(c.assignee, isNull);
      expect(c.remind, isFalse);
      expect(c.createdBy, '');
      expect(Chore.fromMap('y', {'repeat': 'fortnightly'}).repeat, Repeat.once);
    });

    test('copyWith changes given fields and can set nullable fields to null', () {
      final c = chore(icon: '🪥', assignee: 'u2', time: '07:00', repeat: Repeat.monthly, monthDay: 5, end: '2026-12-31');
      final same = c.copyWith();
      expect(same.icon, '🪥');
      expect(same.assignee, 'u2');
      expect(same.time, '07:00');
      expect(same.monthDay, 5);
      expect(same.endDate, '2026-12-31');

      final cleared = c.copyWith(icon: null, assignee: null, time: null, monthDay: null, endDate: null);
      expect(cleared.icon, isNull);
      expect(cleared.assignee, isNull);
      expect(cleared.isAnyone, isTrue);
      expect(cleared.time, isNull);
      expect(cleared.monthDay, isNull);
      expect(cleared.endDate, isNull);
      expect(cleared.title, c.title);

      final changed = c.copyWith(
        id: 'c2', title: 'New', icon: '🧹', assignee: 'u1', time: '08:15', repeat: Repeat.weekly,
        every: 3, weekdays: [2], monthDay: 7, startDate: '2026-10-01', endDate: '2027-01-01',
        remind: true, createdBy: 'u2',
      );
      expect(changed.id, 'c2');
      expect(changed.title, 'New');
      expect(changed.icon, '🧹');
      expect(changed.assignee, 'u1');
      expect(changed.time, '08:15');
      expect(changed.repeat, Repeat.weekly);
      expect(changed.every, 3);
      expect(changed.weekdays, [2]);
      expect(changed.monthDay, 7);
      expect(changed.startDate, '2026-10-01');
      expect(changed.endDate, '2027-01-01');
      expect(changed.remind, isTrue);
      expect(changed.createdBy, 'u2');
    });

    test('choreDoneId joins the chore id and the date', () {
      expect(choreDoneId('brush', '2026-09-30'), 'brush_2026-09-30');
    });

    test('ChoreDone round-trips and has the chore-and-date id', () {
      final at = DateTime(2026, 9, 30, 7, 5);
      final done = ChoreDone(
        choreId: 'brush', date: '2026-09-30', choreTitle: 'Brush teeth', assignee: 'u2',
        doneBy: 'u2', doneByName: 'Sara', doneAt: at, dayNumber: dayNumberOf(DateTime(2026, 9, 30)),
      );
      expect(done.id, 'brush_2026-09-30');
      final back = ChoreDone.fromMap(done.toMap());
      expect(back.id, 'brush_2026-09-30');
      expect(back.choreId, 'brush');
      expect(back.date, '2026-09-30');
      expect(back.choreTitle, 'Brush teeth');
      expect(back.assignee, 'u2');
      expect(back.doneBy, 'u2');
      expect(back.doneByName, 'Sara');
      expect(back.doneAt, at);
      expect(back.dayNumber, 20726);
      final anyone = ChoreDone.fromMap({...done.toMap(), 'assignee': null, 'doneAt': null});
      expect(anyone.assignee, isNull);
      expect(anyone.doneAt, isNull);
    });

    test('Chore.fromMap ignores fields of the wrong type', () {
      final bad = Chore.fromMap('bad', {
        'title': 42,
        'icon': 1,
        'assignee': true,
        'time': 7,
        'repeat': 3,
        'every': 'x',
        'weekdays': 'mon',
        'monthDay': 'x',
        'startDate': 20260901,
        'endDate': [],
        'remind': 'yes',
        'createdBy': 5,
      });
      expect(bad.id, 'bad');
      expect(bad.title, '');
      expect(bad.icon, isNull);
      expect(bad.assignee, isNull);
      expect(bad.time, isNull);
      expect(bad.repeat, Repeat.once);
      expect(bad.every, 1);
      expect(bad.weekdays, isEmpty);
      expect(bad.monthDay, isNull);
      expect(bad.startDate, '');
      expect(bad.endDate, isNull);
      expect(bad.remind, isFalse);
      expect(bad.createdBy, '');

      for (final every in <Object>[0, -2, 2.5, double.nan]) {
        expect(Chore.fromMap('e', {'every': every}).every, 1, reason: '$every');
      }
      for (final monthDay in <Object>[0, 32, 2.5]) {
        expect(Chore.fromMap('m', {'monthDay': monthDay}).monthDay, isNull, reason: '$monthDay');
      }
      expect(Chore.fromMap('w', {'weekdays': [2, 'x', 0, 8, 3.0, 2.5, null]}).weekdays, [2, 3]);
      expect(Chore.fromMap('r', {'repeat': 'fortnightly'}).repeat, Repeat.once);

      // Neither a missing start date nor an impossible one ever occurs, and neither throws.
      expect(occurrences(bad, '2026-01-01', '2026-12-31'), isEmpty);
      final impossible = chore(start: '2026-02-30');
      expect(occurrences(impossible, '2026-02-01', '2026-12-31'), isEmpty);
    });

    test('ChoreDone.fromMap ignores fields of the wrong type', () {
      final bad = ChoreDone.fromMap({
        'choreId': 1,
        'date': 2,
        'choreTitle': [],
        'assignee': 3,
        'doneBy': true,
        'doneByName': {},
        'doneAt': 'yesterday',
        'dayNumber': 'x',
      });
      expect(bad.choreId, '');
      expect(bad.date, '');
      expect(bad.choreTitle, '');
      expect(bad.assignee, isNull);
      expect(bad.doneBy, '');
      expect(bad.doneByName, '');
      expect(bad.doneAt, isNull);
      expect(bad.dayNumber, 0);

      expect(ChoreDone.fromMap({'doneAt': 42}).doneAt, isNull);
      expect(ChoreDone.fromMap({'dayNumber': 2.5}).dayNumber, 0);
      expect(ChoreDone.fromMap({'dayNumber': 20726.0}).dayNumber, 20726);
    });
  });

  group('choresForDay', () {
    final monday = d('2026-09-28');
    final chores = [
      chore(id: 'brush', title: 'Brush teeth', time: '07:00'),
      chore(id: 'bed', title: 'Make bed'),
      chore(id: 'wake', title: 'Wake up', time: '06:30'),
      chore(id: 'cat', title: 'Feed cat'),
      chore(id: 'plants', title: 'Water plants', assignee: null),
      chore(id: 'bins', title: 'Take out bins', assignee: 'u1', repeat: Repeat.weekly, weekdays: [1]),
      chore(id: 'old', title: 'Old chore', assignee: 'u9'),
      chore(id: 'party', title: 'Party prep', repeat: Repeat.once, start: '2026-09-27'),
      chore(id: 'swim', title: 'Swim', assignee: 'u1', repeat: Repeat.weekly, weekdays: [3]),
    ];

    test('groups by member, anyone and former members; only chores of that day', () {
      final view = choresForDay(chores: chores, done: const [], memberUids: {'u1', 'u2'}, day: monday);
      expect(view.byMember.keys.toSet(), {'u1', 'u2'});
      expect(ids(view.byMember['u2']!), ['wake', 'brush', 'cat', 'bed']);
      expect(ids(view.byMember['u1']!), ['bins']);
      expect(ids(view.anyone), ['plants']);
      expect(ids(view.formerMember), ['old']);
    });

    test('every member has an entry, even without chores', () {
      final view = choresForDay(chores: chores, done: const [], memberUids: {'u1', 'u2', 'u3'}, day: monday);
      expect(view.byMember['u3'], isEmpty);
      final empty = choresForDay(chores: const [], done: const [], memberUids: {'u1'}, day: monday);
      expect(empty.byMember, {'u1': isEmpty});
      expect(empty.anyone, isEmpty);
      expect(empty.formerMember, isEmpty);
    });

    test('timed chores first by time, then untimed by title; ties by title', () {
      final list = [
        chore(id: 'b', title: 'Beta', time: '08:00'),
        chore(id: 'a', title: 'alpha', time: '08:00'),
        chore(id: 'z', title: 'Zebra', time: '06:05'),
        chore(id: 'n2', title: 'نوم'),
        chore(id: 'n1', title: 'apple'),
      ];
      final en = choresForDay(chores: list, done: const [], memberUids: {'u2'}, day: monday);
      expect(ids(en.byMember['u2']!), ['z', 'a', 'b', 'n1', 'n2']);
      final ar = choresForDay(chores: list, done: const [], memberUids: {'u2'}, day: monday, languageCode: 'ar');
      expect(ids(ar.byMember['u2']!), ['z', 'a', 'b', 'n2', 'n1']);
    });

    test('done status comes from the record for that day only', () {
      final brush = chores.first;
      final bed = chores[1];
      final done = [doneOn(brush, '2026-09-28'), doneOn(bed, '2026-09-27')];
      final u2 = choresForDay(chores: chores, done: done, memberUids: {'u1', 'u2'}, day: monday).byMember['u2']!;
      final brushStatus = u2.firstWhere((s) => s.chore.id == 'brush');
      expect(brushStatus.isDone, isTrue);
      expect(brushStatus.done!.doneBy, 'u2');
      expect(u2.firstWhere((s) => s.chore.id == 'bed').isDone, isFalse);
      expect(progressOf(u2), (done: 1, total: 4));
    });

    test('a done record whose chore was deleted still shows on its day with its copied title', () {
      final gone = chore(id: 'gone', title: 'Old title');
      final done = [doneOn(gone, '2026-09-27')];
      final sunday = choresForDay(chores: const [], done: done, memberUids: {'u2'}, day: d('2026-09-27'));
      final status = sunday.byMember['u2']!.single;
      expect(status.chore.id, 'gone');
      expect(status.chore.title, 'Old title');
      expect(status.isDone, isTrue);
      expect(choresForDay(chores: const [], done: done, memberUids: {'u2'}, day: monday).byMember['u2'], isEmpty);
    });

    test('editing the rule keeps past done records', () {
      final before = chore(id: 'brush', title: 'Brush teeth', repeat: Repeat.daily, start: '2026-09-01');
      final done = [doneOn(before, '2026-09-26'), doneOn(before, '2026-09-27')];
      final after = before.copyWith(title: 'Brush teeth well', repeat: Repeat.weekly, weekdays: [1]);

      // Today (Monday) follows the new rule and has no record yet.
      final today = choresForDay(chores: [after], done: done, memberUids: {'u2'}, day: monday).byMember['u2']!;
      expect(today.single.chore.title, 'Brush teeth well');
      expect(today.single.isDone, isFalse);
      // Tuesday no longer has it.
      expect(choresForDay(chores: [after], done: done, memberUids: {'u2'}, day: d('2026-09-29')).byMember['u2'], isEmpty);
      // Past days that no longer match the rule still show their done records, with the copied title.
      for (final day in ['2026-09-26', '2026-09-27']) {
        final past = choresForDay(chores: [after], done: done, memberUids: {'u2'}, day: d(day)).byMember['u2']!;
        expect(past.single.chore.id, 'brush', reason: day);
        expect(past.single.isDone, isTrue, reason: day);
        expect(past.single.done!.choreTitle, 'Brush teeth', reason: day);
      }
      // The records themselves are untouched.
      expect(done.map((x) => x.choreTitle), everyElement('Brush teeth'));
      expect(done.map((x) => x.date), ['2026-09-26', '2026-09-27']);
    });
  });

  group('progressOf', () {
    test('counts done over total', () {
      final a = chore(id: 'a');
      final b = chore(id: 'b');
      final c = chore(id: 'c');
      expect(progressOf(const []), (done: 0, total: 0));
      expect(
        progressOf([
          ChoreStatus(a, doneOn(a, '2026-09-28')),
          ChoreStatus(b, null),
          ChoreStatus(c, doneOn(c, '2026-09-28')),
        ]),
        (done: 2, total: 3),
      );
    });
  });

  group('lateChores', () {
    final today = d('2026-10-01'); // Thursday

    List<String> lateOf(List<Chore> chores, [List<ChoreDone> done = const [], int lookBackDays = 60]) => [
          for (final l in lateChores(chores: chores, done: done, today: today, lookBackDays: lookBackDays))
            '${l.chore.id}@${l.date}',
        ];

    test('a missed one-time chore stays late until done', () {
      final blinds = chore(id: 'blinds', repeat: Repeat.once, start: '2026-09-28');
      expect(lateOf([blinds]), ['blinds@2026-09-28']);
      expect(lateOf([blinds], [doneOn(blinds, '2026-09-28')]), isEmpty);
    });

    test('one-time chores for today or later are not late', () {
      expect(lateOf([
        chore(id: 'a', repeat: Repeat.once, start: '2026-10-01'),
        chore(id: 'b', repeat: Repeat.once, start: '2026-10-05'),
      ]), isEmpty);
    });

    test('a repeating anyone chore is late only for its most recent missed occurrence', () {
      final daily = chore(id: 'daily', assignee: null, start: '2026-09-20');
      final plants = chore(id: 'plants', assignee: null, repeat: Repeat.weekly, weekdays: [6]); // Saturdays
      expect(lateOf([daily, plants]), ['plants@2026-09-26', 'daily@2026-09-30']);
    });

    test('a done record on the most recent occurrence clears earlier misses', () {
      final daily = chore(id: 'daily', assignee: null, start: '2026-09-20');
      expect(lateOf([daily], [doneOn(daily, '2026-09-30')]), isEmpty);
    });

    test('done later (up to and including today) suppresses the miss', () {
      final daily = chore(id: 'daily', assignee: null, start: '2026-09-20');
      expect(lateOf([daily], [doneOn(daily, '2026-10-01')]), isEmpty);
      // A record after today does not count.
      expect(lateOf([daily], [doneOn(daily, '2026-10-02')]), ['daily@2026-09-30']);
    });

    test('never lists a repeating chore that has an assignee', () {
      expect(lateOf([
        chore(id: 'brush', assignee: 'u2'),
        chore(id: 'bins', assignee: 'u1', repeat: Repeat.weekly, weekdays: [1]),
        chore(id: 'rent', assignee: 'u1', repeat: Repeat.monthly, monthDay: 1, start: '2026-01-01'),
      ]), isEmpty);
    });

    test('the look-back window limits how far back', () {
      final at60 = chore(id: 'a', repeat: Repeat.once, start: dateKey(addDays(today, -60)));
      final at61 = chore(id: 'b', repeat: Repeat.once, start: dateKey(addDays(today, -61)));
      expect(lateOf([at60, at61]), ['a@2026-08-02']);
      final at8 = chore(id: 'c', repeat: Repeat.once, start: dateKey(addDays(today, -8)));
      expect(lateOf([at8], const [], 7), isEmpty);
      expect(lateOf([at8], const [], 8), ['c@2026-09-23']);
    });

    test('an anyone chore that has not started yet is not late', () {
      expect(lateOf([chore(id: 'x', assignee: null, start: '2026-10-05')]), isEmpty);
    });

    test('sorted by date, then title', () {
      final result = lateOf([
        chore(id: 'y', title: 'Beta', repeat: Repeat.once, start: '2026-09-28'),
        chore(id: 'daily', title: 'Anything', assignee: null, start: '2026-09-20'),
        chore(id: 'x', title: 'alpha', repeat: Repeat.once, start: '2026-09-28'),
        chore(id: 'z', title: 'Zed', repeat: Repeat.once, start: '2026-09-25'),
      ]);
      expect(result, ['z@2026-09-25', 'x@2026-09-28', 'y@2026-09-28', 'daily@2026-09-30']);
    });
  });

  group('canToggle', () {
    final today = d('2026-10-01');
    final mine = chore(assignee: 'u2');
    final anyone = chore(assignee: null);
    final dads = chore(assignee: 'u1');

    bool child(Chore c, String day) => canToggle(chore: c, isParent: false, me: 'u2', day: d(day), today: today);

    test('parents can toggle any chore on any day', () {
      for (final c in [mine, anyone, dads]) {
        for (final day in ['2026-09-01', '2026-09-30', '2026-10-01', '2026-10-10']) {
          expect(canToggle(chore: c, isParent: true, me: 'u1', day: d(day), today: today), isTrue);
        }
      }
    });

    test('children toggle their own chores today and yesterday only', () {
      expect(child(mine, '2026-10-01'), isTrue);
      expect(child(mine, '2026-09-30'), isTrue);
      expect(child(mine, '2026-09-29'), isFalse);
      expect(child(mine, '2026-10-02'), isFalse);
    });

    test('children toggle anyone chores today and yesterday only', () {
      expect(child(anyone, '2026-10-01'), isTrue);
      expect(child(anyone, '2026-09-30'), isTrue);
      expect(child(anyone, '2026-09-20'), isFalse);
      expect(child(anyone, '2026-10-02'), isFalse);
    });

    test("children never toggle someone else's chore", () {
      expect(child(dads, '2026-10-01'), isFalse);
      expect(child(dads, '2026-09-30'), isFalse);
    });

    test('the time of day does not matter', () {
      expect(canToggle(chore: mine, isParent: false, me: 'u2', day: DateTime(2026, 9, 30, 23, 59), today: DateTime(2026, 10, 1, 0, 5)), isTrue);
      expect(canToggle(chore: mine, isParent: false, me: 'u2', day: DateTime(2026, 9, 29, 23, 59), today: DateTime(2026, 10, 1, 0, 5)), isFalse);
    });
  });

  group('validateChore', () {
    test('a good chore has no problems', () {
      expect(validateChore(chore(title: 'Brush teeth')), isEmpty);
      expect(validateChore(chore(repeat: Repeat.weekly, weekdays: [1])), isEmpty);
      expect(validateChore(chore(repeat: Repeat.monthly, monthDay: 31)), isEmpty);
      expect(validateChore(chore(start: '2026-09-28', end: '2026-09-28')), isEmpty);
    });

    test('blank titles are refused', () {
      expect(validateChore(chore(title: '')), {ChoreProblem.blankTitle});
      expect(validateChore(chore(title: '   ')), {ChoreProblem.blankTitle});
    });

    test('titles longer than 80 characters after trimming are refused', () {
      expect(validateChore(chore(title: 'a' * 80)), isEmpty);
      expect(validateChore(chore(title: '  ${'a' * 80}  ')), isEmpty);
      expect(validateChore(chore(title: 'ب' * 80)), isEmpty);
      expect(validateChore(chore(title: 'a' * 81)), {ChoreProblem.titleTooLong});
    });

    test('weekly needs at least one weekday', () {
      expect(validateChore(chore(repeat: Repeat.weekly)), {ChoreProblem.weeklyNoDays});
      expect(validateChore(chore(repeat: Repeat.weekly, weekdays: [0, 8])), {ChoreProblem.weeklyNoDays});
      expect(validateChore(chore(repeat: Repeat.daily)), isEmpty);
    });

    test('monthly needs a day between 1 and 31', () {
      expect(validateChore(chore(repeat: Repeat.monthly)), {ChoreProblem.badMonthDay});
      expect(validateChore(chore(repeat: Repeat.monthly, monthDay: 0)), {ChoreProblem.badMonthDay});
      expect(validateChore(chore(repeat: Repeat.monthly, monthDay: 32)), {ChoreProblem.badMonthDay});
      expect(validateChore(chore(repeat: Repeat.monthly, monthDay: 1)), isEmpty);
    });

    test('the end date cannot be before the start date', () {
      expect(validateChore(chore(start: '2026-09-28', end: '2026-09-27')), {ChoreProblem.endBeforeStart});
    });

    test('several problems are reported together', () {
      expect(
        validateChore(chore(title: ' ', repeat: Repeat.weekly, start: '2026-09-28', end: '2026-01-01')),
        {ChoreProblem.blankTitle, ChoreProblem.weeklyNoDays, ChoreProblem.endBeforeStart},
      );
    });
  });
}
