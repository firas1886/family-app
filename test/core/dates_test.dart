import 'package:family_app/core/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dayOnly drops the time of day', () {
    expect(dayOnly(DateTime(2026, 9, 28, 23, 59, 59)), DateTime(2026, 9, 28));
    expect(dayOnly(DateTime(2026, 9, 28)), DateTime(2026, 9, 28));
  });

  test('dateKey is zero-padded YYYY-MM-DD of the local date', () {
    expect(dateKey(DateTime(2026, 3, 5)), '2026-03-05');
    expect(dateKey(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    expect(dateKey(DateTime(987, 1, 9)), '0987-01-09');
  });

  test('parseDateKey gives local midnight and round-trips every day of a leap year', () {
    final d = parseDateKey('2026-09-28');
    expect(d, DateTime(2026, 9, 28));
    expect(d.isUtc, isFalse);
    for (var day = DateTime(2028, 1, 1); day.year == 2028; day = addDays(day, 1)) {
      expect(dateKey(parseDateKey(dateKey(day))), dateKey(day));
    }
  });

  test('parseDateKey rejects malformed keys and impossible dates', () {
    for (final bad in ['', '2026-9-28', '2026/09/28', '28-09-2026', '2026-09-28T00:00', '2026-02-30', '2026-13-01']) {
      expect(() => parseDateKey(bad), throwsFormatException, reason: bad);
    }
  });

  test('addDays crosses month, year and leap-day boundaries', () {
    expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
    expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    expect(addDays(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
    expect(addDays(DateTime(2026, 9, 28, 18, 30), 3), DateTime(2026, 10, 1));
  });

  test('addDays never skips or repeats a day (daylight-saving safe)', () {
    final start = DateTime(2026, 1, 1);
    for (var i = -400; i <= 400; i++) {
      expect(dayNumberOf(addDays(start, i)), dayNumberOf(start) + i, reason: '$i');
    }
  });

  test('dayNumberOf counts whole days since 1970-01-01 and ignores the time', () {
    expect(dayNumberOf(DateTime(1970, 1, 1)), 0);
    expect(dayNumberOf(DateTime(1970, 1, 2, 23, 59)), 1);
    expect(dayNumberOf(DateTime(2026, 1, 1)), 20454);
    expect(dayNumberOf(DateTime(2026, 9, 28)), 20724);
    expect(dayNumberOf(DateTime(2026, 9, 28, 23, 59)), 20724);
    expect(dayNumberOf(DateTime.utc(2026, 9, 28)), 20724);
  });

  test('startOfWeek is the Sunday on or before the date', () {
    expect(startOfWeek(DateTime(2026, 9, 27)), DateTime(2026, 9, 27)); // Sunday
    expect(startOfWeek(DateTime(2026, 9, 28)), DateTime(2026, 9, 27)); // Monday
    expect(startOfWeek(DateTime(2026, 10, 1, 15)), DateTime(2026, 9, 27)); // Thursday
    expect(startOfWeek(DateTime(2026, 10, 3)), DateTime(2026, 9, 27)); // Saturday
    expect(startOfWeek(DateTime(2026, 10, 4)), DateTime(2026, 10, 4)); // next Sunday
    expect(startOfWeek(DateTime(2027, 1, 1)), DateTime(2026, 12, 27)); // across the year end
  });
}
