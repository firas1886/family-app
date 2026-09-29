import 'dart:math';

import 'dates.dart';
import 'text.dart';

enum Repeat { once, daily, weekly, monthly }

const maxChoreTitleLength = 80;

/// Lets [Chore.copyWith] tell "not given" apart from "set to null".
const Object _unset = Object();

// Tolerant readers for [Chore.fromMap] and [ChoreDone.fromMap]. The security
// rules can't guarantee every field's type, so a value of the wrong type falls
// back to its default instead of breaking the chores stream for the whole family.

String? _readString(Object? value) => value is String ? value : null;

/// An int, or a finite double with no fractional part (Firestore may return
/// either); anything else is null.
int? _wholeNumber(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite && value == value.truncateToDouble()) return value.toInt();
  return null;
}

/// A DateTime, or a Firestore Timestamp (anything whose `toDate()` returns a
/// DateTime); anything else is null.
DateTime? _readDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  try {
    final date = (value as dynamic).toDate();
    return date is DateTime ? date : null;
  } on NoSuchMethodError {
    return null;
  }
}

class Chore {
  const Chore({
    required this.id,
    required this.title,
    this.icon,
    this.assignee,
    this.time,
    this.repeat = Repeat.once,
    this.every = 1,
    this.weekdays = const [],
    this.monthDay,
    required this.startDate,
    this.endDate,
    this.remind = false,
    required this.createdBy,
  });

  final String id;
  final String title;

  /// A single emoji, or null.
  final String? icon;

  /// Member uid, or null for an "anyone" chore.
  final String? assignee;

  /// "HH:mm", or null for no time.
  final String? time;
  final Repeat repeat;

  /// Repeat every N days, weeks or months (1 for once).
  final int every;

  /// 1 = Monday … 7 = Sunday; used by weekly chores only.
  final List<int> weekdays;

  /// 1–31; used by monthly chores only.
  final int? monthDay;

  /// "YYYY-MM-DD"; for a one-time chore, its date.
  final String startDate;

  /// "YYYY-MM-DD" (inclusive), or null for never.
  final String? endDate;
  final bool remind;
  final String createdBy;

  bool get isAnyone => assignee == null;

  /// Never throws: a field of the wrong type gets its default.
  factory Chore.fromMap(String id, Map<String, dynamic> m) {
    final every = _wholeNumber(m['every']);
    final weekdays = m['weekdays'];
    final monthDay = _wholeNumber(m['monthDay']);
    return Chore(
      id: id,
      title: _readString(m['title']) ?? '',
      icon: _readString(m['icon']),
      assignee: _readString(m['assignee']),
      time: _readString(m['time']),
      repeat: Repeat.values.asNameMap()[m['repeat']] ?? Repeat.once,
      every: every != null && every >= 1 ? every : 1,
      weekdays: weekdays is List
          ? [for (final w in weekdays.map(_wholeNumber)) if (w != null && w >= 1 && w <= 7) w]
          : const [],
      monthDay: monthDay != null && monthDay >= 1 && monthDay <= 31 ? monthDay : null,
      startDate: _readString(m['startDate']) ?? '',
      endDate: _readString(m['endDate']),
      remind: m['remind'] == true,
      createdBy: _readString(m['createdBy']) ?? '',
    );
  }

  /// Every field except [id] (and never `createdAt`). The title is trimmed, and
  /// fields that don't apply to the repeat are cleared, as the data model requires.
  Map<String, dynamic> toMap() => {
        'title': title.trim(),
        'icon': icon,
        'assignee': assignee,
        'time': time,
        'repeat': repeat.name,
        'every': repeat == Repeat.once ? 1 : every,
        'weekdays': repeat == Repeat.weekly ? (weekdays.toSet().toList()..sort()) : <int>[],
        'monthDay': repeat == Repeat.monthly ? monthDay : null,
        'startDate': startDate,
        'endDate': endDate,
        'remind': remind,
        'createdBy': createdBy,
      };

  Chore copyWith({
    String? id,
    String? title,
    Object? icon = _unset,
    Object? assignee = _unset,
    Object? time = _unset,
    Repeat? repeat,
    int? every,
    List<int>? weekdays,
    Object? monthDay = _unset,
    String? startDate,
    Object? endDate = _unset,
    bool? remind,
    String? createdBy,
  }) =>
      Chore(
        id: id ?? this.id,
        title: title ?? this.title,
        icon: identical(icon, _unset) ? this.icon : icon as String?,
        assignee: identical(assignee, _unset) ? this.assignee : assignee as String?,
        time: identical(time, _unset) ? this.time : time as String?,
        repeat: repeat ?? this.repeat,
        every: every ?? this.every,
        weekdays: weekdays ?? this.weekdays,
        monthDay: identical(monthDay, _unset) ? this.monthDay : monthDay as int?,
        startDate: startDate ?? this.startDate,
        endDate: identical(endDate, _unset) ? this.endDate : endDate as String?,
        remind: remind ?? this.remind,
        createdBy: createdBy ?? this.createdBy,
      );
}

String choreDoneId(String choreId, String date) => '${choreId}_$date';

/// One chore done on one day. Keeps its own copy of the title and assignee,
/// so history survives edits and deletes.
class ChoreDone {
  const ChoreDone({
    required this.choreId,
    required this.date,
    required this.choreTitle,
    this.assignee,
    required this.doneBy,
    required this.doneByName,
    this.doneAt,
    required this.dayNumber,
  });

  final String choreId;

  /// "YYYY-MM-DD" of the day the chore was for (not when it was ticked).
  final String date;
  final String choreTitle;
  final String? assignee;
  final String doneBy;
  final String doneByName;
  final DateTime? doneAt;

  /// [dayNumberOf] the [date]; lets the security rules check "today or yesterday".
  final int dayNumber;

  String get id => choreDoneId(choreId, date);

  /// Never throws: a field of the wrong type gets its default.
  factory ChoreDone.fromMap(Map<String, dynamic> m) => ChoreDone(
        choreId: _readString(m['choreId']) ?? '',
        date: _readString(m['date']) ?? '',
        choreTitle: _readString(m['choreTitle']) ?? '',
        assignee: _readString(m['assignee']),
        doneBy: _readString(m['doneBy']) ?? '',
        doneByName: _readString(m['doneByName']) ?? '',
        doneAt: _readDate(m['doneAt']),
        dayNumber: _wholeNumber(m['dayNumber']) ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'choreId': choreId,
        'date': date,
        'choreTitle': choreTitle,
        'assignee': assignee,
        'doneBy': doneBy,
        'doneByName': doneByName,
        'doneAt': doneAt,
        'dayNumber': dayNumber,
      };
}

DateTime? _tryParseDateKey(String? key) {
  if (key == null) return null;
  try {
    return parseDateKey(key);
  } on FormatException {
    return null;
  }
}

int _daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Whether chore [c] falls on the local calendar day of [day].
bool occursOn(Chore c, DateTime day) {
  final start = _tryParseDateKey(c.startDate);
  if (start == null) return false;
  final d = dayNumberOf(day);
  final s = dayNumberOf(start);
  if (d < s) return false;
  final end = _tryParseDateKey(c.endDate);
  if (end != null && d > dayNumberOf(end)) return false;
  final every = max(1, c.every);
  switch (c.repeat) {
    case Repeat.once:
      return d == s;
    case Repeat.daily:
      return (d - s) % every == 0;
    case Repeat.weekly:
      if (!c.weekdays.contains(day.weekday)) return false;
      final weeks = (dayNumberOf(startOfWeek(day)) - dayNumberOf(startOfWeek(start))) ~/ DateTime.daysPerWeek;
      return weeks % every == 0;
    case Repeat.monthly:
      final monthDay = c.monthDay;
      if (monthDay == null || monthDay < 1) return false;
      final months = (day.year - start.year) * 12 + day.month - start.month;
      if (months % every != 0) return false;
      return day.day == min(monthDay, _daysInMonth(day.year, day.month));
  }
}

class ChoreStatus {
  const ChoreStatus(this.chore, this.done);
  final Chore chore;
  final ChoreDone? done;
  bool get isDone => done != null;
}

class DayView {
  const DayView({required this.byMember, required this.anyone, required this.formerMember});

  /// One entry (possibly empty) for every current member uid.
  final Map<String, List<ChoreStatus>> byMember;
  final List<ChoreStatus> anyone;

  /// Chores assigned to someone who is no longer a member.
  final List<ChoreStatus> formerMember;
}

int _compareStatus(ChoreStatus a, ChoreStatus b, String languageCode) {
  final ta = a.chore.time;
  final tb = b.chore.time;
  if (ta != null && tb == null) return -1;
  if (ta == null && tb != null) return 1;
  if (ta != null && tb != null) {
    final byTime = ta.compareTo(tb);
    if (byTime != 0) return byTime;
  }
  final byTitle = compareNames(a.chore.title, b.chore.title, languageCode);
  return byTitle != 0 ? byTitle : a.chore.id.compareTo(b.chore.id);
}

/// The chores of [day], grouped by person, with done status.
///
/// Also lists that day's done records whose chore no longer occurs on it (the
/// rule was edited) or no longer exists (deleted, shown with the record's copied
/// title), so past days keep their history.
DayView choresForDay({
  required List<Chore> chores,
  required List<ChoreDone> done,
  required Set<String> memberUids,
  required DateTime day,
  String languageCode = 'en',
}) {
  final key = dateKey(day);
  final doneToday = {for (final d in done) if (d.date == key) d.choreId: d};
  final byId = {for (final c in chores) c.id: c};
  final byMember = {for (final uid in memberUids) uid: <ChoreStatus>[]};
  final anyone = <ChoreStatus>[];
  final former = <ChoreStatus>[];

  void place(ChoreStatus status) {
    final assignee = status.chore.assignee;
    if (assignee == null) {
      anyone.add(status);
    } else if (byMember.containsKey(assignee)) {
      byMember[assignee]!.add(status);
    } else {
      former.add(status);
    }
  }

  final shown = <String>{};
  for (final c in chores) {
    if (!occursOn(c, day)) continue;
    shown.add(c.id);
    place(ChoreStatus(c, doneToday[c.id]));
  }
  for (final record in doneToday.values) {
    if (shown.contains(record.choreId)) continue;
    final chore = byId[record.choreId] ??
        Chore(
          id: record.choreId,
          title: record.choreTitle,
          assignee: record.assignee,
          startDate: record.date,
          createdBy: record.doneBy,
        );
    place(ChoreStatus(chore, record));
  }

  int compare(ChoreStatus a, ChoreStatus b) => _compareStatus(a, b, languageCode);
  for (final list in byMember.values) {
    list.sort(compare);
  }
  anyone.sort(compare);
  former.sort(compare);
  return DayView(byMember: byMember, anyone: anyone, formerMember: former);
}

class LateChore {
  const LateChore(this.chore, this.date);
  final Chore chore;
  final String date;
}

/// One-time and "anyone" chores whose most recent occurrence before [today]
/// (within [lookBackDays]) was missed, and that nobody has done since.
List<LateChore> lateChores({
  required List<Chore> chores,
  required List<ChoreDone> done,
  required DateTime today,
  int lookBackDays = 60,
  String languageCode = 'en',
}) {
  final todayKey = dateKey(today);
  final doneDates = <String, Set<String>>{};
  for (final d in done) {
    doneDates.putIfAbsent(d.choreId, () => <String>{}).add(d.date);
  }
  final result = <LateChore>[];
  for (final c in chores) {
    if (c.repeat != Repeat.once && !c.isAnyone) continue;
    final dates = doneDates[c.id] ?? const <String>{};
    for (var back = 1; back <= lookBackDays; back++) {
      final day = addDays(today, -back);
      if (!occursOn(c, day)) continue;
      final key = dateKey(day);
      final doneSince = dates.any((x) => x.compareTo(key) >= 0 && x.compareTo(todayKey) <= 0);
      if (!doneSince) result.add(LateChore(c, key));
      break;
    }
  }
  result.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byTitle = compareNames(a.chore.title, b.chore.title, languageCode);
    return byTitle != 0 ? byTitle : a.chore.id.compareTo(b.chore.id);
  });
  return result;
}

({int done, int total}) progressOf(List<ChoreStatus> items) =>
    (done: items.where((s) => s.isDone).length, total: items.length);

/// Parents may tick or untick anything. Children only their own and "anyone"
/// chores, and only for today or yesterday.
bool canToggle({
  required Chore chore,
  required bool isParent,
  required String me,
  required DateTime day,
  required DateTime today,
}) {
  if (isParent) return true;
  if (chore.assignee != me && !chore.isAnyone) return false;
  final daysAgo = dayNumberOf(today) - dayNumberOf(day);
  return daysAgo == 0 || daysAgo == 1;
}

enum ChoreProblem { blankTitle, titleTooLong, weeklyNoDays, badMonthDay, endBeforeStart }

Set<ChoreProblem> validateChore(Chore c) {
  final problems = <ChoreProblem>{};
  final title = c.title.trim();
  if (title.isEmpty) {
    problems.add(ChoreProblem.blankTitle);
  } else if (title.length > maxChoreTitleLength) {
    problems.add(ChoreProblem.titleTooLong);
  }
  if (c.repeat == Repeat.weekly && !c.weekdays.any((w) => w >= 1 && w <= 7)) {
    problems.add(ChoreProblem.weeklyNoDays);
  }
  final monthDay = c.monthDay;
  if (c.repeat == Repeat.monthly && (monthDay == null || monthDay < 1 || monthDay > 31)) {
    problems.add(ChoreProblem.badMonthDay);
  }
  final end = c.endDate;
  if (end != null && end.compareTo(c.startDate) < 0) {
    problems.add(ChoreProblem.endBeforeStart);
  }
  return problems;
}
