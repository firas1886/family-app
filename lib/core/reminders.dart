import 'dart:convert';

import 'chores.dart';
import 'dates.dart';

/// One notification to show on this phone: a chore on a given day at its time.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.choreId,
    required this.date,
    required this.title,
    required this.at,
    this.assignee,
  });

  /// Notification id, from [reminderId].
  final int id;
  final String choreId;

  /// The chore's day, `YYYY-MM-DD`.
  final String date;

  /// The chore's title.
  final String title;

  /// When to remind: the chore's day at its time, in the phone's local time.
  final DateTime at;

  /// Whose chore it is (member uid), or null for an "anyone" chore.
  final String? assignee;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.choreId == choreId &&
      other.date == date &&
      other.title == title &&
      other.at == at &&
      other.assignee == assignee;

  @override
  int get hashCode => Object.hash(id, choreId, date, title, at, assignee);

  @override
  String toString() => 'PlannedReminder($choreId, $date, $at)';
}

/// A stable notification id for a chore on a day: 32-bit FNV-1a of
/// `'$choreId|$date'`, kept positive because Android ids are signed 32-bit ints.
int reminderId(String choreId, String date) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode('$choreId|$date')) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// The reminders this phone should have scheduled.
///
/// Only chores with a reminder switched on and a time. Normally only chores
/// assigned to [me]; with [everyone] (a parent's choice) also everyone else's
/// and the "anyone" chores. Covers [days] days starting today, skips days
/// already done and times that have already passed, sorted by time.
List<PlannedReminder> planReminders({
  required List<Chore> chores,
  required List<ChoreDone> done,
  required String me,
  required bool everyone,
  required DateTime now,
  int days = 7,
}) {
  final doneIds = {for (final d in done) choreDoneId(d.choreId, d.date)};
  final today = dayOnly(now);
  final result = <PlannedReminder>[];
  for (final chore in chores) {
    if (!chore.remind) continue;
    if (!everyone && chore.assignee != me) continue;
    final time = _parseTime(chore.time);
    if (time == null) continue;
    for (var i = 0; i < days; i++) {
      final day = addDays(today, i);
      if (!occursOn(chore, day)) continue;
      final date = dateKey(day);
      if (doneIds.contains(choreDoneId(chore.id, date))) continue;
      final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
      if (!at.isAfter(now)) continue;
      result.add(PlannedReminder(
        id: reminderId(chore.id, date),
        choreId: chore.id,
        date: date,
        title: chore.title,
        at: at,
        assignee: chore.assignee,
      ));
    }
  }
  result.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    final byTitle = a.title.compareTo(b.title);
    return byTitle != 0 ? byTitle : a.choreId.compareTo(b.choreId);
  });
  return result;
}

/// Reads `"HH:mm"`; null when missing or malformed.
({int hour, int minute})? _parseTime(String? time) {
  if (time == null) return null;
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return (hour: hour, minute: minute);
}
