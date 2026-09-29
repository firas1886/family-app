// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Family';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInFailed => 'Sign-in didn\'t work. Please try again.';

  @override
  String get createFamily => 'Create a family';

  @override
  String get joinFamily => 'Join a family';

  @override
  String get familyName => 'Family name';

  @override
  String get joinCode => 'Join code';

  @override
  String get create => 'Create';

  @override
  String get join => 'Join';

  @override
  String get joinCodeNotFound => 'That code doesn\'t match any family.';

  @override
  String get needsConnection => 'This needs an internet connection.';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get tabLists => 'Lists';

  @override
  String get tabToday => 'Today';

  @override
  String get tabFamily => 'Family';

  @override
  String get newList => 'New list';

  @override
  String get listName => 'List name';

  @override
  String get rename => 'Rename';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get noListsParent => 'Create one to get started.';

  @override
  String get noListsChild => 'Ask a parent to create one.';

  @override
  String get noListsTitle => 'No lists yet';

  @override
  String get history => 'History';

  @override
  String get shopping => 'Shopping';

  @override
  String itemsToBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items to buy',
      one: '1 item to buy',
    );
    return '$_temp0';
  }

  @override
  String get nothingToBuy => 'Nothing to buy';

  @override
  String get color => 'Colour';

  @override
  String get pickColor => 'Pick a colour';

  @override
  String get pictureTiles => 'Picture tiles';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get toBuy => 'To buy';

  @override
  String get emptyToBuy => 'Nothing to buy right now.';

  @override
  String get recentlyUsed => 'Recently used';

  @override
  String get categories => 'Categories';

  @override
  String get newCategory => 'New category';

  @override
  String get categoryName => 'Category name';

  @override
  String get otherCategory => 'Other';

  @override
  String get sortByCategory => 'By category';

  @override
  String get sortAlphabetical => 'A–Z';

  @override
  String get iNeed => 'I need…';

  @override
  String boughtItem(String name) {
    return '$name bought';
  }

  @override
  String get undo => 'Undo';

  @override
  String daysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
      zero: 'today',
    );
    return '$_temp0';
  }

  @override
  String get offline => 'Offline';

  @override
  String get name => 'Name';

  @override
  String get category => 'Category';

  @override
  String get quantity => 'Quantity';

  @override
  String get unit => 'Unit';

  @override
  String get noUnit => '—';

  @override
  String get notes => 'Notes';

  @override
  String get expiryDays => 'Expiry days';

  @override
  String get expiryHint => 'Leave empty so it never comes back by itself';

  @override
  String lastBought(String name, String date) {
    return 'Last bought by $name on $date';
  }

  @override
  String get neverBought => 'Not bought yet';

  @override
  String get removeFromList => 'Remove from this list';

  @override
  String get deleteFromCatalog => 'Delete from catalog';

  @override
  String confirmDeleteItem(String name) {
    return 'Delete $name from every list? Purchase history is kept.';
  }

  @override
  String confirmDeleteList(String name) {
    return 'Delete the list $name? Purchase history is kept.';
  }

  @override
  String confirmDeleteCategory(String name) {
    return 'Delete $name? Its items move to Other.';
  }

  @override
  String get allLists => 'All lists';

  @override
  String get addPrice => 'Add price';

  @override
  String get price => 'Price (SAR)';

  @override
  String get currencySar => 'SAR';

  @override
  String get noPurchases => 'No purchases yet.';

  @override
  String get members => 'Members';

  @override
  String get parent => 'Parent';

  @override
  String get child => 'Child';

  @override
  String get makeParent => 'Make parent';

  @override
  String get makeChild => 'Make child';

  @override
  String get removeMember => 'Remove from family';

  @override
  String confirmRemoveMember(String name) {
    return 'Remove $name from the family?';
  }

  @override
  String get share => 'Share';

  @override
  String get regenerateCode => 'New code';

  @override
  String get confirmRegenerateCode =>
      'Make a new join code? The old one will stop working.';

  @override
  String get language => 'Language';

  @override
  String get signOut => 'Sign out';

  @override
  String get leaveFamily => 'Leave family';

  @override
  String get confirmLeaveFamily => 'Leave this family?';

  @override
  String get lastParentError => 'The family needs at least one parent.';

  @override
  String shareCodeMessage(String code) {
    return 'Join our family in the Family app with code $code';
  }

  @override
  String get unitPcs => 'pcs';

  @override
  String get unitKg => 'kg';

  @override
  String get unitG => 'g';

  @override
  String get unitL => 'L';

  @override
  String get unitMl => 'ml';

  @override
  String get unitPack => 'pack';

  @override
  String get tabChores => 'Chores';

  @override
  String get today => 'Today';

  @override
  String get everyone => 'Everyone';

  @override
  String get me => 'Me';

  @override
  String get anyone => 'Anyone';

  @override
  String get formerMember => 'Former member';

  @override
  String get noChoresToday => 'No chores today';

  @override
  String get noChores => 'No chores';

  @override
  String get addChore => 'Add chore';

  @override
  String get editChore => 'Edit chore';

  @override
  String get choreTitle => 'Chore';

  @override
  String get choreEmoji => 'Emoji (optional)';

  @override
  String get who => 'Who';

  @override
  String get time => 'Time';

  @override
  String get noTime => 'No time';

  @override
  String get repeat => 'Repeat';

  @override
  String get repeatOnce => 'Once';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get repeatMonthly => 'Monthly';

  @override
  String get every => 'Every';

  @override
  String everyNDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count days',
      one: 'Daily',
    );
    return '$_temp0';
  }

  @override
  String everyNWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String everyNMonthsOnDay(int count, int day) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Every $count months · day $day',
      one: 'Monthly · day $day',
    );
    return '$_temp0';
  }

  @override
  String get onDays => 'On these days';

  @override
  String get dayOfMonth => 'Day of the month';

  @override
  String monthlyOnDay(int day) {
    return 'Monthly · day $day';
  }

  @override
  String get startDate => 'Starts';

  @override
  String get endDate => 'Ends on';

  @override
  String get endsNever => 'Never ends';

  @override
  String until(String date) {
    return 'until $date';
  }

  @override
  String get remind => 'Remind me';

  @override
  String confirmDeleteChore(String name) {
    return 'Delete the chore $name? Days already done stay in the history.';
  }

  @override
  String get problemBlankTitle => 'Please enter a title.';

  @override
  String get problemTitleTooLong => 'Keep the title to 80 characters or fewer.';

  @override
  String get problemWeeklyNoDays => 'Pick at least one day.';

  @override
  String get problemBadMonthDay => 'Pick a day between 1 and 31.';

  @override
  String get problemEndBeforeStart =>
      'The end date can\'t be before the start date.';

  @override
  String doneCount(int done, int total) {
    return '✓ $done/$total';
  }

  @override
  String choreTicked(String title) {
    return '$title done';
  }

  @override
  String get wd1 => 'Mon';

  @override
  String get wd2 => 'Tue';

  @override
  String get wd3 => 'Wed';

  @override
  String get wd4 => 'Thu';

  @override
  String get wd5 => 'Fri';

  @override
  String get wd6 => 'Sat';

  @override
  String get wd7 => 'Sun';

  @override
  String get late => 'Late';

  @override
  String lateSince(String date) {
    return 'Late since $date';
  }

  @override
  String get whoDidIt => 'Who did it?';

  @override
  String get yourChores => 'Your chores';

  @override
  String get allDone => 'All done for today! 🎉';
}
