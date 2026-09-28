import 'package:family_app/app/formatting.dart';
import 'package:family_app/core/models.dart';
import 'package:family_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('quantityLabel', () {
    expect(quantityLabel(en, 2, 'L'), '2 L');
    expect(quantityLabel(en, 1.5, 'kg'), '1.5 kg');
    expect(quantityLabel(en, 3, null), '3');
    expect(quantityLabel(en, null, 'L'), '');
    expect(quantityLabel(ar, 2, 'L'), '2 لتر');
  });

  test('unitLabel covers every unit', () {
    for (final u in units) {
      expect(unitLabel(en, u), isNotEmpty);
      expect(unitLabel(ar, u), isNotEmpty);
    }
  });

  test('categoryLabel localizes the default category only', () {
    const other = ItemCategory(id: 'o', name: 'Other', isDefault: true);
    const dairy = ItemCategory(id: 'd', name: 'Dairy', isDefault: false);
    expect(categoryLabel(ar, other), 'أخرى');
    expect(categoryLabel(ar, dairy), 'Dairy');
    expect(categoryLabel(en, null), 'Other');
  });

  test('daysLeft plural', () {
    expect(en.daysLeft(1), '1 day');
    expect(en.daysLeft(5), '5 days');
    expect(en.daysLeft(0), 'today');
  });
}
