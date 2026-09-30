import 'dart:math';

import 'package:family_app/core/text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nameKey', () {
    test('trims, lowercases and collapses spaces', () {
      expect(nameKey('  Olive   OIL '), 'olive oil');
    });
    test('removes Arabic diacritics', () {
      expect(nameKey('حَلِيب'), 'حليب');
    });
    test('unifies alef forms', () {
      expect(nameKey('أرز'), 'ارز');
      expect(nameKey('إناء'), 'اناء');
      expect(nameKey('آيس كريم'), 'ايس كريم');
    });
    test('treats taa marbuta as haa and alef maqsura as yaa', () {
      expect(nameKey('قهوة'), nameKey('قهوه'));
      expect(nameKey('مستشفى'), 'مستشفي');
    });
  });

  group('tileLetter', () {
    test('uppercases the first Latin letter', () {
      expect(tileLetter('milk'), 'M');
    });
    test('skips leading spaces and keeps Arabic letters', () {
      expect(tileLetter('   حليب'), 'ح');
    });
    test('keeps a whole emoji', () {
      expect(tileLetter('🍎 apples'), '🍎');
    });
    test('returns ? for blank names', () {
      expect(tileLetter('   '), '?');
    });
  });

  group('firstName', () {
    test('takes the first word of a full name', () {
      expect(firstName('Firas Alhalabi'), 'Firas');
    });
    test('ignores spaces around the name', () {
      expect(firstName('  Sara '), 'Sara');
    });
    test('works for Arabic names', () {
      expect(firstName('محمد علي'), 'محمد');
    });
    test('splits on a no-break space', () {
      expect(firstName('Firas\u00A0Alhalabi'), 'Firas');
      expect(firstName('\u00A0Sara\u00A0\u00A0Alhalabi'), 'Sara');
    });
    test('returns an empty string for a blank name', () {
      expect(firstName(''), '');
      expect(firstName('   '), '');
      expect(firstName(' \u00A0\t '), '');
    });
    test('keeps a single word as it is', () {
      expect(firstName('Sara'), 'Sara');
    });
  });

  group('join codes', () {
    test('are 6 unambiguous characters', () {
      final code = generateJoinCode(Random(1));
      expect(code, matches(RegExp(r'^[A-HJ-NP-Z2-9]{6}$')));
    });
    test('normalize removes spaces and uppercases', () {
      expect(normalizeJoinCode(' ab c23 4 '), 'ABC234');
    });
  });

  group('compareNames', () {
    List<String> sorted(List<String> names, String lang) =>
        [...names]..sort((a, b) => compareNames(a, b, lang));

    test('ignores case', () {
      expect(sorted(['banana', 'Apple'], 'en'), ['Apple', 'banana']);
    });
    test('puts Latin first in English and Arabic first in Arabic', () {
      expect(sorted(['حليب', 'Milk', 'apple'], 'en'), ['apple', 'Milk', 'حليب']);
      expect(sorted(['Milk', 'حليب', 'apple'], 'ar'), ['حليب', 'apple', 'Milk']);
    });
  });

  group('numbers', () {
    test('formatNumber drops a trailing .0', () {
      expect(formatNumber(2), '2');
      expect(formatNumber(1.5), '1.5');
    });
    test('parseNumber accepts Western and Arabic digits and separators', () {
      expect(parseNumber('2.5'), 2.5);
      expect(parseNumber('1,5'), 1.5);
      expect(parseNumber('٢٫٥'), 2.5);
      expect(parseNumber('۳'), 3);
    });
    test('parseNumber returns null for blank or non-numeric input', () {
      expect(parseNumber(''), isNull);
      expect(parseNumber('  '), isNull);
      expect(parseNumber('abc'), isNull);
    });
  });

  group('hardening', () {
    test('invisible direction marks are ignored', () {
      expect(nameKey('‏حليب‎'), 'حليب');
      expect(nameKey('﻿ Milk'), nameKey('Milk'));
      expect(tileLetter('‏ حليب'), 'ح');
      expect(tileLetter('​'), '?');
    });
    test('parseNumber rejects non-finite and negative values', () {
      expect(parseNumber('NaN'), isNull);
      expect(parseNumber('Infinity'), isNull);
      expect(parseNumber('-1'), isNull);
      expect(parseNumber('0'), 0);
    });
  });
}
