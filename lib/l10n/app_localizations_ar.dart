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
  String get color => 'اللون';

  @override
  String get pickColor => 'اختر لوناً';

  @override
  String get pictureTiles => 'بطاقات مصوّرة';

  @override
  String get theme => 'المظهر';

  @override
  String get themeSystem => 'تلقائي';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

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

  @override
  String get tabChores => 'المهام';

  @override
  String get today => 'اليوم';

  @override
  String get everyone => 'الجميع';

  @override
  String get me => 'أنا';

  @override
  String get viewDay => 'يوم';

  @override
  String get viewWeek => 'أسبوع';

  @override
  String weekRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get anyone => 'أي شخص';

  @override
  String get formerMember => 'عضو سابق';

  @override
  String get noChoresToday => 'لا مهام اليوم';

  @override
  String get noChores => 'لا مهام';

  @override
  String get addChore => 'إضافة مهمة';

  @override
  String get editChore => 'تعديل المهمة';

  @override
  String get choreTitle => 'المهمة';

  @override
  String get choreEmoji => 'رمز تعبيري (اختياري)';

  @override
  String get who => 'لمن';

  @override
  String get time => 'الوقت';

  @override
  String get noTime => 'بلا وقت';

  @override
  String get repeat => 'التكرار';

  @override
  String get repeatOnce => 'مرة واحدة';

  @override
  String get repeatDaily => 'يوميًا';

  @override
  String get repeatWeekly => 'أسبوعيًا';

  @override
  String get repeatMonthly => 'شهريًا';

  @override
  String get every => 'كل';

  @override
  String everyNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count يوم',
      many: 'كل $count يومًا',
      few: 'كل $count أيام',
      two: 'كل يومين',
      one: 'يوميًا',
    );
    return '$_temp0';
  }

  @override
  String everyNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count أسبوع',
      many: 'كل $count أسبوعًا',
      few: 'كل $count أسابيع',
      two: 'كل أسبوعين',
      one: 'كل أسبوع',
    );
    return '$_temp0';
  }

  @override
  String everyNMonthsOnDay(int count, int day) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count شهر · يوم $day',
      many: 'كل $count شهرًا · يوم $day',
      few: 'كل $count أشهر · يوم $day',
      two: 'كل شهرين · يوم $day',
      one: 'شهريًا · يوم $day',
    );
    return '$_temp0';
  }

  @override
  String get onDays => 'في هذه الأيام';

  @override
  String get dayOfMonth => 'يوم من الشهر';

  @override
  String monthlyOnDay(int day) {
    return 'شهريًا · يوم $day';
  }

  @override
  String get startDate => 'يبدأ';

  @override
  String get endDate => 'ينتهي في';

  @override
  String get endsNever => 'لا ينتهي';

  @override
  String until(String date) {
    return 'حتى $date';
  }

  @override
  String get remind => 'ذكّرني';

  @override
  String confirmDeleteChore(String name) {
    return 'حذف المهمة $name؟ تبقى الأيام المنجزة في السجل.';
  }

  @override
  String get problemBlankTitle => 'الرجاء إدخال عنوان.';

  @override
  String get problemTitleTooLong => 'اجعل العنوان 80 حرفًا أو أقل.';

  @override
  String get problemWeeklyNoDays => 'اختر يومًا واحدًا على الأقل.';

  @override
  String get problemBadMonthDay => 'اختر يومًا بين 1 و31.';

  @override
  String get problemEndBeforeStart =>
      'لا يمكن أن يكون تاريخ الانتهاء قبل تاريخ البدء.';

  @override
  String doneCount(int done, int total) {
    return '✓ $done/$total';
  }

  @override
  String choreTicked(String title) {
    return 'تم إنجاز $title';
  }

  @override
  String get wd1 => 'إثنين';

  @override
  String get wd2 => 'ثلاثاء';

  @override
  String get wd3 => 'أربعاء';

  @override
  String get wd4 => 'خميس';

  @override
  String get wd5 => 'جمعة';

  @override
  String get wd6 => 'سبت';

  @override
  String get wd7 => 'أحد';

  @override
  String get late => 'متأخرة';

  @override
  String lateSince(String date) {
    return 'متأخرة منذ $date';
  }

  @override
  String get whoDidIt => 'من قام بها؟';

  @override
  String get yourChores => 'مهامك';

  @override
  String get allDone => 'أنجزت كل مهام اليوم! 🎉';

  @override
  String get remindersChannel => 'تذكير المهام';

  @override
  String get remindEveryone => 'ذكّرني بمهام الجميع';

  @override
  String reminderBody(String name) {
    return 'مهمة $name';
  }

  @override
  String get notificationsDenied =>
      'الإشعارات متوقفة لتطبيق Family، لذلك لن تظهر تذكيرات المهام على هذا الهاتف. لتشغيلها افتح إعدادات الهاتف، ثم التطبيقات، ثم Family، ثم الإشعارات.';
}
