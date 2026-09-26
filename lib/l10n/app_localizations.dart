import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

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
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @onboardingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Your medication,\nmade simple.'**
  String get onboardingHeadline;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear guidance. Easy identification.\nBuilt for everyone.'**
  String get onboardingSubtitle;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greeting(String name);

  /// No description provided for @timeForMedication.
  ///
  /// In en, this message translates to:
  /// **'It\'s time for your medication'**
  String get timeForMedication;

  /// No description provided for @medicationCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} medication} other{{count} medications}}'**
  String medicationCount(int count);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @voiceComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Voice assistant is coming soon'**
  String get voiceComingSoon;

  /// No description provided for @cameraComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Camera scanning is coming soon'**
  String get cameraComingSoon;

  /// No description provided for @manualComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Manual entry is coming soon'**
  String get manualComingSoon;

  /// No description provided for @editMedication.
  ///
  /// In en, this message translates to:
  /// **'Edit medication'**
  String get editMedication;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @meds.
  ///
  /// In en, this message translates to:
  /// **'Meds'**
  String get meds;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @caregiver.
  ///
  /// In en, this message translates to:
  /// **'Caregiver'**
  String get caregiver;

  /// No description provided for @voiceMode.
  ///
  /// In en, this message translates to:
  /// **'Voice mode'**
  String get voiceMode;

  /// No description provided for @myMedications.
  ///
  /// In en, this message translates to:
  /// **'My medications'**
  String get myMedications;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// No description provided for @filterPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get filterPaused;

  /// No description provided for @filterFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get filterFinished;

  /// No description provided for @addMedication.
  ///
  /// In en, this message translates to:
  /// **'Add medication'**
  String get addMedication;

  /// No description provided for @scanPackage.
  ///
  /// In en, this message translates to:
  /// **'Scan package'**
  String get scanPackage;

  /// No description provided for @scanPackageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your camera to identify'**
  String get scanPackageSubtitle;

  /// No description provided for @addManually.
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get addManually;

  /// No description provided for @addManuallySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the information yourself'**
  String get addManuallySubtitle;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @medicationDetail.
  ///
  /// In en, this message translates to:
  /// **'Medication detail'**
  String get medicationDetail;

  /// No description provided for @medicationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Medication not found'**
  String get medicationNotFound;

  /// No description provided for @dosage.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get dosage;

  /// No description provided for @takeDosage.
  ///
  /// In en, this message translates to:
  /// **'Take {dosage}'**
  String takeDosage(String dosage);

  /// No description provided for @scheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleLabel;

  /// No description provided for @started.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get started;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @markAsTaken.
  ///
  /// In en, this message translates to:
  /// **'Mark as taken'**
  String get markAsTaken;

  /// No description provided for @taken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get taken;

  /// No description provided for @markedAsTaken.
  ///
  /// In en, this message translates to:
  /// **'Marked as taken ✓'**
  String get markedAsTaken;

  /// No description provided for @morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get morning;

  /// No description provided for @afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get afternoon;

  /// No description provided for @evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get evening;

  /// No description provided for @caregiverSupport.
  ///
  /// In en, this message translates to:
  /// **'Caregiver support'**
  String get caregiverSupport;

  /// No description provided for @caregiverBody.
  ///
  /// In en, this message translates to:
  /// **'Invite a family member or care team to help you stay on track with your medication. This feature is coming soon.'**
  String get caregiverBody;

  /// No description provided for @alarmRinging.
  ///
  /// In en, this message translates to:
  /// **'MEDICATION ALARM · RINGING'**
  String get alarmRinging;

  /// No description provided for @alarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to take your medicine'**
  String get alarmTitle;

  /// No description provided for @scheduledFor.
  ///
  /// In en, this message translates to:
  /// **'Scheduled for {time}'**
  String scheduledFor(String time);

  /// No description provided for @takeAfterBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Take after breakfast'**
  String get takeAfterBreakfast;

  /// No description provided for @swallowWithWater.
  ///
  /// In en, this message translates to:
  /// **'Swallow {dosage} with water'**
  String swallowWithWater(String dosage);

  /// No description provided for @alarmSoundPlaying.
  ///
  /// In en, this message translates to:
  /// **'Alarm sound is playing until you respond'**
  String get alarmSoundPlaying;

  /// No description provided for @snooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze 10 minutes'**
  String get snooze;

  /// No description provided for @snoozed.
  ///
  /// In en, this message translates to:
  /// **'Snoozed for 10 minutes'**
  String get snoozed;

  /// No description provided for @snoozeMinutes.
  ///
  /// In en, this message translates to:
  /// **'Snooze {minutes} min'**
  String snoozeMinutes(int minutes);

  /// No description provided for @snoozedFor.
  ///
  /// In en, this message translates to:
  /// **'Snoozed for {minutes} minutes'**
  String snoozedFor(int minutes);

  /// No description provided for @takeDose.
  ///
  /// In en, this message translates to:
  /// **'Take dose'**
  String get takeDose;

  /// No description provided for @alarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get alarm;

  /// No description provided for @alarmSound.
  ///
  /// In en, this message translates to:
  /// **'Alarm sound'**
  String get alarmSound;

  /// No description provided for @alarmSoundDefault.
  ///
  /// In en, this message translates to:
  /// **'Default alarm sound'**
  String get alarmSoundDefault;

  /// No description provided for @alarmSoundCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom sound'**
  String get alarmSoundCustom;

  /// No description provided for @alarmSoundSaved.
  ///
  /// In en, this message translates to:
  /// **'Alarm sound saved'**
  String get alarmSoundSaved;

  /// No description provided for @alarmFullScreen.
  ///
  /// In en, this message translates to:
  /// **'Full-screen alarms'**
  String get alarmFullScreen;

  /// No description provided for @alarmFullScreenOn.
  ///
  /// In en, this message translates to:
  /// **'On — alarms open over the lock screen'**
  String get alarmFullScreenOn;

  /// No description provided for @alarmFullScreenOff.
  ///
  /// In en, this message translates to:
  /// **'Off — tap to enable'**
  String get alarmFullScreenOff;

  /// No description provided for @alarmFullScreenEnabled.
  ///
  /// In en, this message translates to:
  /// **'Full-screen alarms enabled'**
  String get alarmFullScreenEnabled;

  /// No description provided for @addedToday.
  ///
  /// In en, this message translates to:
  /// **'Added today'**
  String get addedToday;

  /// No description provided for @addedYesterday.
  ///
  /// In en, this message translates to:
  /// **'Added yesterday'**
  String get addedYesterday;

  /// No description provided for @addedDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'Added {count} days ago'**
  String addedDaysAgo(int count);

  /// No description provided for @authWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcome;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateAccount;

  /// No description provided for @authSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your medications.'**
  String get authSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get passwordHint;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get nameHint;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUp;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign up'**
  String get noAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @authConfirmationSent.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm your account.'**
  String get authConfirmationSent;

  /// No description provided for @authFillAll.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email and password.'**
  String get authFillAll;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out of Verifi?'**
  String get signOutConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get languagePortuguese;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Notification settings are coming soon'**
  String get notificationsComingSoon;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Verifi — medication reminders made simple.'**
  String get aboutBody;

  /// No description provided for @editName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get editName;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @nameSaved.
  ///
  /// In en, this message translates to:
  /// **'Name saved ✓'**
  String get nameSaved;

  /// No description provided for @medicationName.
  ///
  /// In en, this message translates to:
  /// **'Medication name'**
  String get medicationName;

  /// No description provided for @medicationNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Amoxicillin 500mg'**
  String get medicationNameHint;

  /// No description provided for @dosageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1 tablet'**
  String get dosageHint;

  /// No description provided for @instruction.
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get instruction;

  /// No description provided for @instructionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. After meal'**
  String get instructionHint;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Antibiotic · Oral tablet'**
  String get categoryHint;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional notes'**
  String get notesHint;

  /// No description provided for @times.
  ///
  /// In en, this message translates to:
  /// **'Times'**
  String get times;

  /// No description provided for @addTime.
  ///
  /// In en, this message translates to:
  /// **'Add time'**
  String get addTime;

  /// No description provided for @pillColor.
  ///
  /// In en, this message translates to:
  /// **'Pill color'**
  String get pillColor;

  /// No description provided for @saveMedication.
  ///
  /// In en, this message translates to:
  /// **'Save medication'**
  String get saveMedication;

  /// No description provided for @medicationSaved.
  ///
  /// In en, this message translates to:
  /// **'Medication saved ✓'**
  String get medicationSaved;

  /// No description provided for @fillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the medication name.'**
  String get fillRequired;

  /// No description provided for @addAtLeastOneTime.
  ///
  /// In en, this message translates to:
  /// **'Add at least one time.'**
  String get addAtLeastOneTime;

  /// No description provided for @missedDose.
  ///
  /// In en, this message translates to:
  /// **'Missed medication'**
  String get missedDose;

  /// No description provided for @wasDueAt.
  ///
  /// In en, this message translates to:
  /// **'was due at {time}'**
  String wasDueAt(String time);

  /// No description provided for @noMedicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No medications yet'**
  String get noMedicationsTitle;

  /// No description provided for @noMedicationsBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first medication to get started.'**
  String get noMedicationsBody;

  /// No description provided for @noActiveMedicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No active medications'**
  String get noActiveMedicationsTitle;

  /// No description provided for @noActiveMedicationsBody.
  ///
  /// In en, this message translates to:
  /// **'Medications you\'re currently taking will appear here.'**
  String get noActiveMedicationsBody;

  /// No description provided for @emptyFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get emptyFilterTitle;

  /// No description provided for @emptyFilterBody.
  ///
  /// In en, this message translates to:
  /// **'No medications match this filter.'**
  String get emptyFilterBody;

  /// No description provided for @noScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get noScheduleTitle;

  /// No description provided for @noScheduleBody.
  ///
  /// In en, this message translates to:
  /// **'No medications scheduled for this day.'**
  String get noScheduleBody;

  /// No description provided for @mealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'After breakfast'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In en, this message translates to:
  /// **'After lunch'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In en, this message translates to:
  /// **'After dinner'**
  String get mealDinner;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @everyNDays.
  ///
  /// In en, this message translates to:
  /// **'Every {n} days'**
  String everyNDays(int n);

  /// No description provided for @takeNow.
  ///
  /// In en, this message translates to:
  /// **'Take now'**
  String get takeNow;

  /// No description provided for @nothingDueToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today'**
  String get nothingDueToday;

  /// No description provided for @nothingDueTodayBody.
  ///
  /// In en, this message translates to:
  /// **'You have no doses scheduled for today.'**
  String get nothingDueTodayBody;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get statusPaused;

  /// No description provided for @statusFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get statusFinished;

  /// No description provided for @statusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Status updated ✓'**
  String get statusUpdated;

  /// No description provided for @medicationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Medication updated ✓'**
  String get medicationUpdated;
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
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
