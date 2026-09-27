import 'dart:math';

import 'package:characters/characters.dart';

final _spaces = RegExp(r'\s+');
final _arabicDiacritics = RegExp('[ً-ْٰ]');
final _alefVariants = RegExp('[أإآ]'); // أ إ آ

/// Normalized form used to decide whether two item names are the same item.
String nameKey(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(_spaces, ' ')
      .replaceAll(_arabicDiacritics, '')
      .replaceAll(_alefVariants, 'ا') // ا
      .replaceAll('ة', 'ه') // ة → ه
      .replaceAll('ى', 'ي'); // ى → ي
}

/// The single character shown large on an item tile.
String tileLetter(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String generateJoinCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(
    6,
    (_) => _codeAlphabet[r.nextInt(_codeAlphabet.length)],
  ).join();
}

String normalizeJoinCode(String input) =>
    input.replaceAll(_spaces, '').toUpperCase();

bool _isArabicScript(String s) {
  if (s.isEmpty) return false;
  final c = s.codeUnitAt(0);
  return c >= 0x0600 && c <= 0x06FF;
}

/// Sorts names case-insensitively; the UI language's script sorts first.
int compareNames(String a, String b, String languageCode) {
  final ka = nameKey(a);
  final kb = nameKey(b);
  final aArabic = _isArabicScript(ka);
  final bArabic = _isArabicScript(kb);
  if (aArabic != bArabic) {
    final arabicFirst = languageCode == 'ar';
    return aArabic == arabicFirst ? -1 : 1;
  }
  return ka.compareTo(kb);
}

String formatNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

/// Parses user-typed numbers, accepting Arabic-Indic digits and , or ٫ as the decimal separator.
double? parseNumber(String input) {
  final buffer = StringBuffer();
  for (final rune in input.trim().runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(0x30 + rune - 0x06F0);
    } else if (rune == 0x066B || rune == 0x2C) {
      buffer.write('.');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  final text = buffer.toString();
  if (text.isEmpty) return null;
  return double.tryParse(text);
}
