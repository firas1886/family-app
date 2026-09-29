import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/chores.dart';
import '../../core/dates.dart';
import '../../l10n/app_localizations.dart';

/// Weekday numbers (1 = Monday … 7 = Sunday) in the order the family's week
/// runs: Sunday first.
const weekOrder = [7, 1, 2, 3, 4, 5, 6];

String weekdayName(AppLocalizations l, int weekday) => switch (weekday) {
      1 => l.wd1,
      2 => l.wd2,
      3 => l.wd3,
      4 => l.wd4,
      5 => l.wd5,
      6 => l.wd6,
      _ => l.wd7,
    };

/// "Sun–Thu" for three or more days in a row, otherwise "Mon, Thu".
String weekdaysLabel(AppLocalizations l, List<int> weekdays) {
  final positions = {
    for (final d in weekdays)
      if (d >= 1 && d <= 7) weekOrder.indexOf(d),
  }.toList()
    ..sort();
  if (positions.isEmpty) return '';
  final isRun = positions.length >= 3 && positions.last - positions.first == positions.length - 1;
  if (isRun) {
    return '${weekdayName(l, weekOrder[positions.first])}–${weekdayName(l, weekOrder[positions.last])}';
  }
  final separator = l.localeName.startsWith('ar') ? '، ' : ', ';
  return [for (final p in positions) weekdayName(l, weekOrder[p])].join(separator);
}

/// "28 Sep".
String shortDate(String locale, DateTime day) => DateFormat('d MMM', locale).format(day);

/// "Wed 30 Sep": the Chores tab's day switcher.
String dayTitle(String locale, DateTime day) => DateFormat('EEE d MMM', locale).format(day);

/// "Thu 1 Oct 2026": dates in the chore sheet.
String longDate(String locale, DateTime day) => DateFormat('EEE d MMM y', locale).format(day);

/// "Once · 28 Sep", "Daily", "Every 2 days", "Sun–Thu", "Every 2 weeks · Mon, Thu",
/// "Monthly · day 15", "Every 3 months · day 31"; "… · until 30 Jun" when it ends.
String repeatLabel(AppLocalizations l, Chore c) {
  final locale = l.localeName;
  final base = switch (c.repeat) {
    Repeat.once => '${l.repeatOnce} · ${shortDate(locale, parseDateKey(c.startDate))}',
    Repeat.daily => c.every <= 1 ? l.repeatDaily : l.everyNDays(c.every),
    Repeat.weekly => _weeklyLabel(l, c),
    Repeat.monthly =>
      c.every <= 1 ? l.monthlyOnDay(c.monthDay ?? 1) : l.everyNMonthsOnDay(c.every, c.monthDay ?? 1),
  };
  final end = c.endDate;
  if (end == null || c.repeat == Repeat.once) return base;
  return '$base · ${l.until(shortDate(locale, parseDateKey(end)))}';
}

String _weeklyLabel(AppLocalizations l, Chore c) {
  final days = weekdaysLabel(l, c.weekdays);
  if (c.every <= 1) return days.isEmpty ? l.repeatWeekly : days;
  final every = l.everyNWeeks(c.every);
  return days.isEmpty ? every : '$every · $days';
}

/// "07:00" → 7:00, or null when the stored value is malformed.
TimeOfDay? parseChoreTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

/// 7:00 → "07:00", the stored form.
String choreTimeKey(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "7:00 AM" (or "07:00" when the phone uses 24-hour time), in the UI language.
String formatChoreTime(BuildContext context, String hhmm) {
  final time = parseChoreTime(hhmm);
  if (time == null) return hhmm;
  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// The small line under a chore's title: "7:00 AM · Daily".
String choreCaption(BuildContext context, Chore c) {
  final l = AppLocalizations.of(context)!;
  final repeat = repeatLabel(l, c);
  final time = c.time;
  return time == null ? repeat : '${formatChoreTime(context, time)} · $repeat';
}
