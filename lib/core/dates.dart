// Local calendar dates for chores. A chore belongs to a day, not a moment,
// so every date here is a local date at midnight or a "YYYY-MM-DD" key.

final _dateKeyPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// The same local day at midnight.
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [n] calendar days later (or earlier when negative), at local midnight.
/// Works on the date parts, so daylight-saving changes never skip or repeat a day.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

String _two(int v) => v.toString().padLeft(2, '0');

/// "YYYY-MM-DD" for the local date of [d].
String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// Local midnight of a "YYYY-MM-DD" key. Throws [FormatException] for anything else.
DateTime parseDateKey(String key) {
  final match = _dateKeyPattern.firstMatch(key);
  if (match == null) throw FormatException('Not a YYYY-MM-DD date', key);
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('No such date', key);
  }
  return date;
}

/// Whole days since 1970-01-01 for the local date of [d] (time of day ignored).
int dayNumberOf(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

/// The Sunday on or before [d], at local midnight. Weeks start on Sunday.
DateTime startOfWeek(DateTime d) => addDays(d, -(d.weekday % DateTime.daysPerWeek));
