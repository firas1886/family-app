import '../core/models.dart';
import '../core/text.dart';
import '../l10n/app_localizations.dart';

String unitLabel(AppLocalizations l, String unit) => switch (unit) {
      'pcs' => l.unitPcs,
      'kg' => l.unitKg,
      'g' => l.unitG,
      'L' => l.unitL,
      'ml' => l.unitMl,
      'pack' => l.unitPack,
      _ => unit,
    };

/// "2 L", "1.5 kg", "3", or "" when no quantity is set.
String quantityLabel(AppLocalizations l, double? quantity, String? unit) {
  if (quantity == null) return '';
  final number = formatNumber(quantity);
  return unit == null ? number : '$number ${unitLabel(l, unit)}';
}

/// The built-in Other category is shown in the UI language, whatever name it was stored with.
String categoryLabel(AppLocalizations l, ItemCategory? category) {
  if (category == null || category.isDefault) return l.otherCategory;
  return category.name;
}
