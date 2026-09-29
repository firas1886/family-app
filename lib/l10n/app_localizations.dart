import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get appTitle;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in didn\'t work. Please try again.'**
  String get signInFailed;

  /// No description provided for @createFamily.
  ///
  /// In en, this message translates to:
  /// **'Create a family'**
  String get createFamily;

  /// No description provided for @joinFamily.
  ///
  /// In en, this message translates to:
  /// **'Join a family'**
  String get joinFamily;

  /// No description provided for @familyName.
  ///
  /// In en, this message translates to:
  /// **'Family name'**
  String get familyName;

  /// No description provided for @joinCode.
  ///
  /// In en, this message translates to:
  /// **'Join code'**
  String get joinCode;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @joinCodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'That code doesn\'t match any family.'**
  String get joinCodeNotFound;

  /// No description provided for @needsConnection.
  ///
  /// In en, this message translates to:
  /// **'This needs an internet connection.'**
  String get needsConnection;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get somethingWentWrong;

  /// No description provided for @tabLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get tabLists;

  /// No description provided for @tabToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tabToday;

  /// No description provided for @tabFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get tabFamily;

  /// No description provided for @newList.
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get newList;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get listName;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @noListsParent.
  ///
  /// In en, this message translates to:
  /// **'Create one to get started.'**
  String get noListsParent;

  /// No description provided for @noListsChild.
  ///
  /// In en, this message translates to:
  /// **'Ask a parent to create one.'**
  String get noListsChild;

  /// No description provided for @noListsTitle.
  ///
  /// In en, this message translates to:
  /// **'No lists yet'**
  String get noListsTitle;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @shopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// No description provided for @itemsToBuy.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item to buy} other{{count} items to buy}}'**
  String itemsToBuy(int count);

  /// No description provided for @nothingToBuy.
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy'**
  String get nothingToBuy;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get color;

  /// No description provided for @pickColor.
  ///
  /// In en, this message translates to:
  /// **'Pick a colour'**
  String get pickColor;

  /// No description provided for @pictureTiles.
  ///
  /// In en, this message translates to:
  /// **'Picture tiles'**
  String get pictureTiles;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @toBuy.
  ///
  /// In en, this message translates to:
  /// **'To buy'**
  String get toBuy;

  /// No description provided for @emptyToBuy.
  ///
  /// In en, this message translates to:
  /// **'Nothing to buy right now.'**
  String get emptyToBuy;

  /// No description provided for @recentlyUsed.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get recentlyUsed;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryName;

  /// No description provided for @otherCategory.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get otherCategory;

  /// No description provided for @sortByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get sortByCategory;

  /// No description provided for @sortAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get sortAlphabetical;

  /// No description provided for @iNeed.
  ///
  /// In en, this message translates to:
  /// **'I need…'**
  String get iNeed;

  /// No description provided for @boughtItem.
  ///
  /// In en, this message translates to:
  /// **'{name} bought'**
  String boughtItem(String name);

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{today} =1{1 day} other{{count} days}}'**
  String daysLeft(int count);

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @noUnit.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get noUnit;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @expiryDays.
  ///
  /// In en, this message translates to:
  /// **'Expiry days'**
  String get expiryDays;

  /// No description provided for @expiryHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty so it never comes back by itself'**
  String get expiryHint;

  /// No description provided for @lastBought.
  ///
  /// In en, this message translates to:
  /// **'Last bought by {name} on {date}'**
  String lastBought(String name, String date);

  /// No description provided for @neverBought.
  ///
  /// In en, this message translates to:
  /// **'Not bought yet'**
  String get neverBought;

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from this list'**
  String get removeFromList;

  /// No description provided for @deleteFromCatalog.
  ///
  /// In en, this message translates to:
  /// **'Delete from catalog'**
  String get deleteFromCatalog;

  /// No description provided for @confirmDeleteItem.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} from every list? Purchase history is kept.'**
  String confirmDeleteItem(String name);

  /// No description provided for @confirmDeleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete the list {name}? Purchase history is kept.'**
  String confirmDeleteList(String name);

  /// No description provided for @confirmDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? Its items move to Other.'**
  String confirmDeleteCategory(String name);

  /// No description provided for @allLists.
  ///
  /// In en, this message translates to:
  /// **'All lists'**
  String get allLists;

  /// No description provided for @addPrice.
  ///
  /// In en, this message translates to:
  /// **'Add price'**
  String get addPrice;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price (SAR)'**
  String get price;

  /// No description provided for @currencySar.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get currencySar;

  /// No description provided for @noPurchases.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet.'**
  String get noPurchases;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @parent.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get parent;

  /// No description provided for @child.
  ///
  /// In en, this message translates to:
  /// **'Child'**
  String get child;

  /// No description provided for @makeParent.
  ///
  /// In en, this message translates to:
  /// **'Make parent'**
  String get makeParent;

  /// No description provided for @makeChild.
  ///
  /// In en, this message translates to:
  /// **'Make child'**
  String get makeChild;

  /// No description provided for @removeMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from family'**
  String get removeMember;

  /// No description provided for @confirmRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from the family?'**
  String confirmRemoveMember(String name);

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @regenerateCode.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get regenerateCode;

  /// No description provided for @confirmRegenerateCode.
  ///
  /// In en, this message translates to:
  /// **'Make a new join code? The old one will stop working.'**
  String get confirmRegenerateCode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @leaveFamily.
  ///
  /// In en, this message translates to:
  /// **'Leave family'**
  String get leaveFamily;

  /// No description provided for @confirmLeaveFamily.
  ///
  /// In en, this message translates to:
  /// **'Leave this family?'**
  String get confirmLeaveFamily;

  /// No description provided for @lastParentError.
  ///
  /// In en, this message translates to:
  /// **'The family needs at least one parent.'**
  String get lastParentError;

  /// No description provided for @shareCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'Join our family in the Family app with code {code}'**
  String shareCodeMessage(String code);

  /// No description provided for @unitPcs.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get unitPcs;

  /// No description provided for @unitKg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitG.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitG;

  /// No description provided for @unitL.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get unitL;

  /// No description provided for @unitMl.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get unitMl;

  /// No description provided for @unitPack.
  ///
  /// In en, this message translates to:
  /// **'pack'**
  String get unitPack;

  /// No description provided for @tabChores.
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get tabChores;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @anyone.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get anyone;

  /// No description provided for @formerMember.
  ///
  /// In en, this message translates to:
  /// **'Former member'**
  String get formerMember;

  /// No description provided for @noChoresToday.
  ///
  /// In en, this message translates to:
  /// **'No chores today'**
  String get noChoresToday;

  /// No description provided for @noChores.
  ///
  /// In en, this message translates to:
  /// **'No chores'**
  String get noChores;

  /// No description provided for @addChore.
  ///
  /// In en, this message translates to:
  /// **'Add chore'**
  String get addChore;

  /// No description provided for @editChore.
  ///
  /// In en, this message translates to:
  /// **'Edit chore'**
  String get editChore;

  /// No description provided for @choreTitle.
  ///
  /// In en, this message translates to:
  /// **'Chore'**
  String get choreTitle;

  /// No description provided for @choreEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji (optional)'**
  String get choreEmoji;

  /// No description provided for @who.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get who;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @noTime.
  ///
  /// In en, this message translates to:
  /// **'No time'**
  String get noTime;

  /// No description provided for @repeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeat;

  /// No description provided for @repeatOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get repeatOnce;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get every;

  /// No description provided for @everyNDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Daily} other{Every {count} days}}'**
  String everyNDays(int count);

  /// No description provided for @everyNWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Every week} other{Every {count} weeks}}'**
  String everyNWeeks(int count);

  /// No description provided for @everyNMonthsOnDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Monthly · day {day}} other{Every {count} months · day {day}}}'**
  String everyNMonthsOnDay(int count, int day);

  /// No description provided for @onDays.
  ///
  /// In en, this message translates to:
  /// **'On these days'**
  String get onDays;

  /// No description provided for @dayOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Day of the month'**
  String get dayOfMonth;

  /// No description provided for @monthlyOnDay.
  ///
  /// In en, this message translates to:
  /// **'Monthly · day {day}'**
  String monthlyOnDay(int day);

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'Ends on'**
  String get endDate;

  /// No description provided for @endsNever.
  ///
  /// In en, this message translates to:
  /// **'Never ends'**
  String get endsNever;

  /// No description provided for @until.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String until(String date);

  /// No description provided for @remind.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remind;

  /// No description provided for @confirmDeleteChore.
  ///
  /// In en, this message translates to:
  /// **'Delete the chore {name}? Days already done stay in the history.'**
  String confirmDeleteChore(String name);

  /// No description provided for @problemBlankTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title.'**
  String get problemBlankTitle;

  /// No description provided for @problemTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the title to 80 characters or fewer.'**
  String get problemTitleTooLong;

  /// No description provided for @problemWeeklyNoDays.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one day.'**
  String get problemWeeklyNoDays;

  /// No description provided for @problemBadMonthDay.
  ///
  /// In en, this message translates to:
  /// **'Pick a day between 1 and 31.'**
  String get problemBadMonthDay;

  /// No description provided for @problemEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end date can\'t be before the start date.'**
  String get problemEndBeforeStart;

  /// No description provided for @doneCount.
  ///
  /// In en, this message translates to:
  /// **'✓ {done}/{total}'**
  String doneCount(int done, int total);

  /// No description provided for @choreTicked.
  ///
  /// In en, this message translates to:
  /// **'{title} done'**
  String choreTicked(String title);

  /// No description provided for @wd1.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get wd1;

  /// No description provided for @wd2.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get wd2;

  /// No description provided for @wd3.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wd3;

  /// No description provided for @wd4.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get wd4;

  /// No description provided for @wd5.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get wd5;

  /// No description provided for @wd6.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get wd6;

  /// No description provided for @wd7.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get wd7;

  /// No description provided for @late.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get late;

  /// No description provided for @lateSince.
  ///
  /// In en, this message translates to:
  /// **'Late since {date}'**
  String lateSince(String date);

  /// No description provided for @whoDidIt.
  ///
  /// In en, this message translates to:
  /// **'Who did it?'**
  String get whoDidIt;

  /// No description provided for @yourChores.
  ///
  /// In en, this message translates to:
  /// **'Your chores'**
  String get yourChores;

  /// No description provided for @allDone.
  ///
  /// In en, this message translates to:
  /// **'All done for today! 🎉'**
  String get allDone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
