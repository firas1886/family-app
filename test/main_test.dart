import 'dart:async';

import 'package:family_app/main.dart' show initTimeZone;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('a time zone lookup that never answers falls back to UTC', () async {
    final never = Completer<String>();
    await initTimeZone(lookup: () => never.future, timeout: const Duration(milliseconds: 100));
    expect(tz.local, same(tz.UTC));
  });

  test("the phone's time zone is used when the lookup answers", () async {
    await initTimeZone(lookup: () async => 'Asia/Riyadh');
    expect(tz.local.name, 'Asia/Riyadh');
  });

  test('an unknown time zone name falls back to UTC', () async {
    await initTimeZone(lookup: () async => 'Mars/Olympus_Mons');
    expect(tz.local, same(tz.UTC));
  });
}
