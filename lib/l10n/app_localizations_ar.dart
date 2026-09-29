// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'العائلة';

  @override
  String get signInWithGoogle => 'تسجيل الدخول عبر Google';

  @override
  String get signInFailed => 'تعذّر تسجيل الدخول. حاول مرة أخرى.';

  @override
  String get createFamily => 'إنشاء عائلة';

  @override
  String get joinFamily => 'الانضمام إلى عائلة';

  @override
  String get familyName => 'اسم العائلة';

  @override
  String get joinCode => 'رمز الانضمام';

  @override
  String get create => 'إنشاء';

  @override
  String get join => 'انضمام';

  @override
  String get joinCodeNotFound => 'هذا الرمز لا يطابق أي عائلة.';

  @override
  String get needsConnection => 'يتطلب هذا اتصالاً بالإنترنت.';

  @override
  String get somethingWentWrong => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get tabLists => 'القوائم';

  @override
  String get tabToday => 'اليوم';

  @override
  String get tabFamily => 'العائلة';

  @override
  String get newList => 'قائمة جديدة';

  @override
  String get listName => 'اسم القائمة';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get noListsParent => 'أنشئ قائمة للبدء.';

  @override
  String get noListsChild => 'اطلب من أحد الوالدين إنشاء قائمة.';

  @override
  String get noListsTitle => 'لا توجد قوائم بعد';

  @override
  String get history => 'السجل';

  @override
  String get shopping => 'التسوق';

  @override
  String itemsToBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غرض للشراء',
      many: '$count غرضًا للشراء',
      few: '$count أغراض للشراء',
      two: 'غرضان للشراء',
      one: 'غرض واحد للشراء',
      zero: 'لا شيء للشراء',
    );
    return '$_temp0';
  }

  @override
  String get nothingToBuy => 'لا شيء للشراء';

  @override
  String get toBuy => 'للشراء';

  @override
  String get emptyToBuy => 'لا شيء للشراء الآن.';

  @override
  String get recentlyUsed => 'مستخدم مؤخراً';

  @override
  String get categories => 'الفئات';

  @override
  String get newCategory => 'فئة جديدة';

  @override
  String get categoryName => 'اسم الفئة';

  @override
  String get otherCategory => 'أخرى';

  @override
  String get sortByCategory => 'حسب الفئة';

  @override
  String get sortAlphabetical => 'أ–ي';

  @override
  String get iNeed => 'أحتاج…';

  @override
  String boughtItem(String name) {
    return 'تم شراء $name';
  }

  @override
  String get undo => 'تراجع';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String get offline => 'غير متصل';

  @override
  String get name => 'الاسم';

  @override
  String get category => 'الفئة';

  @override
  String get quantity => 'الكمية';

  @override
  String get unit => 'الوحدة';

  @override
  String get noUnit => '—';

  @override
  String get notes => 'ملاحظات';

  @override
  String get expiryDays => 'أيام الصلاحية';

  @override
  String get expiryHint => 'اتركه فارغاً كي لا يعود تلقائياً';

  @override
  String lastBought(String name, String date) {
    return 'آخر شراء بواسطة $name في $date';
  }

  @override
  String get neverBought => 'لم يُشترَ بعد';

  @override
  String get removeFromList => 'إزالة من هذه القائمة';

  @override
  String get deleteFromCatalog => 'حذف من الكتالوج';

  @override
  String confirmDeleteItem(String name) {
    return 'حذف $name من كل القوائم؟ يبقى سجل المشتريات.';
  }

  @override
  String confirmDeleteList(String name) {
    return 'حذف القائمة $name؟ يبقى سجل المشتريات.';
  }

  @override
  String confirmDeleteCategory(String name) {
    return 'حذف $name؟ تنتقل عناصرها إلى أخرى.';
  }

  @override
  String get allLists => 'كل القوائم';

  @override
  String get addPrice => 'أضف السعر';

  @override
  String get price => 'السعر (ريال)';

  @override
  String get currencySar => 'ر.س';

  @override
  String get noPurchases => 'لا توجد مشتريات بعد.';

  @override
  String get members => 'الأعضاء';

  @override
  String get parent => 'ولي أمر';

  @override
  String get child => 'طفل';

  @override
  String get makeParent => 'اجعله ولي أمر';

  @override
  String get makeChild => 'اجعله طفلاً';

  @override
  String get removeMember => 'إزالة من العائلة';

  @override
  String confirmRemoveMember(String name) {
    return 'إزالة $name من العائلة؟';
  }

  @override
  String get share => 'مشاركة';

  @override
  String get regenerateCode => 'رمز جديد';

  @override
  String get confirmRegenerateCode =>
      'إنشاء رمز انضمام جديد؟ سيتوقف الرمز القديم عن العمل.';

  @override
  String get language => 'اللغة';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get leaveFamily => 'مغادرة العائلة';

  @override
  String get confirmLeaveFamily => 'مغادرة هذه العائلة؟';

  @override
  String get lastParentError => 'يجب أن يكون للعائلة ولي أمر واحد على الأقل.';

  @override
  String shareCodeMessage(String code) {
    return 'انضم إلى عائلتنا في تطبيق العائلة بالرمز $code';
  }

  @override
  String get unitPcs => 'قطعة';

  @override
  String get unitKg => 'كغ';

  @override
  String get unitG => 'غ';

  @override
  String get unitL => 'لتر';

  @override
  String get unitMl => 'مل';

  @override
  String get unitPack => 'عبوة';
}
