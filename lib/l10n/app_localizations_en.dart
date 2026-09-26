// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get onboardingHeadline => 'Your medication,\nmade simple.';

  @override
  String get onboardingSubtitle =>
      'Clear guidance. Easy identification.\nBuilt for everyone.';

  @override
  String get getStarted => 'Get started';

  @override
  String get downloadAndroidApp => 'Download the Android app';

  @override
  String get downloadAndroidAppHint =>
      'Get the real APK from the latest GitHub release.';

  @override
  String greeting(String name) {
    return 'Good morning, $name';
  }

  @override
  String get timeForMedication => 'It\'s time for your medication';

  @override
  String medicationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medications',
      one: '$count medication',
    );
    return '$_temp0';
  }

  @override
  String get today => 'Today';

  @override
  String get settings => 'Settings';

  @override
  String get voiceComingSoon => 'Voice assistant is coming soon';

  @override
  String get cameraComingSoon => 'Camera scanning is coming soon';

  @override
  String get manualComingSoon => 'Manual entry is coming soon';

  @override
  String get editMedication => 'Edit medication';

  @override
  String get home => 'Home';

  @override
  String get meds => 'Meds';

  @override
  String get schedule => 'Schedule';

  @override
  String get caregiver => 'Caregiver';

  @override
  String get voiceMode => 'Voice mode';

  @override
  String get myMedications => 'My medications';

  @override
  String get filterAll => 'All';

  @override
  String get filterActive => 'Active';

  @override
  String get filterPaused => 'Paused';

  @override
  String get filterFinished => 'Finished';

  @override
  String get addMedication => 'Add medication';

  @override
  String get scanPackage => 'Scan package';

  @override
  String get scanPackageSubtitle => 'Use your camera to identify';

  @override
  String get addManually => 'Add manually';

  @override
  String get addManuallySubtitle => 'Enter the information yourself';

  @override
  String get recent => 'Recent';

  @override
  String get medicationDetail => 'Medication detail';

  @override
  String get medicationNotFound => 'Medication not found';

  @override
  String get dosage => 'Dosage';

  @override
  String takeDosage(String dosage) {
    return 'Take $dosage';
  }

  @override
  String get scheduleLabel => 'Schedule';

  @override
  String get started => 'Started';

  @override
  String get notes => 'Notes';

  @override
  String get markAsTaken => 'Mark as taken';

  @override
  String get taken => 'Taken';

  @override
  String get markedAsTaken => 'Marked as taken ✓';

  @override
  String get morning => 'Morning';

  @override
  String get afternoon => 'Afternoon';

  @override
  String get evening => 'Evening';

  @override
  String get caregiverSupport => 'Caregiver support';

  @override
  String get caregiverBody =>
      'Invite a family member or care team to help you stay on track with your medication. This feature is coming soon.';

  @override
  String get alarmRinging => 'MEDICATION ALARM · RINGING';

  @override
  String get alarmTitle => 'Time to take your medicine';

  @override
  String scheduledFor(String time) {
    return 'Scheduled for $time';
  }

  @override
  String get takeAfterBreakfast => 'Take after breakfast';

  @override
  String swallowWithWater(String dosage) {
    return 'Swallow $dosage with water';
  }

  @override
  String get alarmSoundPlaying => 'Alarm sound is playing until you respond';

  @override
  String get snooze => 'Snooze 10 minutes';

  @override
  String get snoozed => 'Snoozed for 10 minutes';

  @override
  String snoozeMinutes(int minutes) {
    return 'Snooze $minutes min';
  }

  @override
  String snoozedFor(int minutes) {
    return 'Snoozed for $minutes minutes';
  }

  @override
  String get takeDose => 'Take dose';

  @override
  String get alarm => 'Alarm';

  @override
  String get alarmSound => 'Alarm sound';

  @override
  String get alarmSoundDefault => 'Default alarm sound';

  @override
  String get alarmSoundCustom => 'Custom sound';

  @override
  String get alarmSoundSaved => 'Alarm sound saved';

  @override
  String get alarmFullScreen => 'Full-screen alarms';

  @override
  String get alarmFullScreenOn => 'On — alarms open over the lock screen';

  @override
  String get alarmFullScreenOff => 'Off — tap to enable';

  @override
  String get alarmFullScreenEnabled => 'Full-screen alarms enabled';

  @override
  String get addedToday => 'Added today';

  @override
  String get addedYesterday => 'Added yesterday';

  @override
  String addedDaysAgo(int count) {
    return 'Added $count days ago';
  }

  @override
  String get authWelcome => 'Welcome back';

  @override
  String get authCreateAccount => 'Create your account';

  @override
  String get authSubtitle => 'Sign in to see your medications.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'you@example.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Your password';

  @override
  String get nameLabel => 'Name';

  @override
  String get nameHint => 'Your name';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create account';

  @override
  String get noAccount => 'Don\'t have an account? Sign up';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get authConfirmationSent =>
      'Check your email to confirm your account.';

  @override
  String get authFillAll => 'Please enter your email and password.';

  @override
  String get openAsDemoUser => 'Open as demo user';

  @override
  String get openAsDemoUserHint =>
      'Skip sign-up — try a random person with sample medications.';

  @override
  String get demoAccountLabel => 'Demo account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm => 'Sign out of Verifi?';

  @override
  String get cancel => 'Cancel';

  @override
  String get profile => 'Profile';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsComingSoon => 'Notification settings are coming soon';

  @override
  String get account => 'Account';

  @override
  String get about => 'About';

  @override
  String get aboutBody => 'Verifi — medication reminders made simple.';

  @override
  String get editName => 'Edit name';

  @override
  String get save => 'Save';

  @override
  String get nameSaved => 'Name saved ✓';

  @override
  String get medicationName => 'Medication name';

  @override
  String get medicationNameHint => 'e.g. Amoxicillin 500mg';

  @override
  String get dosageHint => 'e.g. 1 tablet';

  @override
  String get instruction => 'Instruction';

  @override
  String get instructionHint => 'e.g. After meal';

  @override
  String get category => 'Category';

  @override
  String get categoryHint => 'e.g. Antibiotic · Oral tablet';

  @override
  String get notesHint => 'Optional notes';

  @override
  String get times => 'Times';

  @override
  String get addTime => 'Add time';

  @override
  String get pillColor => 'Pill color';

  @override
  String get saveMedication => 'Save medication';

  @override
  String get medicationSaved => 'Medication saved ✓';

  @override
  String get fillRequired => 'Please enter the medication name.';

  @override
  String get addAtLeastOneTime => 'Add at least one time.';

  @override
  String get missedDose => 'Missed medication';

  @override
  String wasDueAt(String time) {
    return 'was due at $time';
  }

  @override
  String get noMedicationsTitle => 'No medications yet';

  @override
  String get noMedicationsBody => 'Add your first medication to get started.';

  @override
  String get noActiveMedicationsTitle => 'No active medications';

  @override
  String get noActiveMedicationsBody =>
      'Medications you\'re currently taking will appear here.';

  @override
  String get emptyFilterTitle => 'Nothing here';

  @override
  String get emptyFilterBody => 'No medications match this filter.';

  @override
  String get noScheduleTitle => 'Nothing scheduled';

  @override
  String get noScheduleBody => 'No medications scheduled for this day.';

  @override
  String get mealBreakfast => 'After breakfast';

  @override
  String get mealLunch => 'After lunch';

  @override
  String get mealDinner => 'After dinner';

  @override
  String get frequency => 'Frequency';

  @override
  String get everyDay => 'Every day';

  @override
  String everyNDays(int n) {
    return 'Every $n days';
  }

  @override
  String get takeNow => 'Take now';

  @override
  String get nothingDueToday => 'Nothing due today';

  @override
  String get nothingDueTodayBody => 'You have no doses scheduled for today.';

  @override
  String get status => 'Status';

  @override
  String get statusActive => 'Active';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusFinished => 'Finished';

  @override
  String get statusUpdated => 'Status updated ✓';

  @override
  String get medicationUpdated => 'Medication updated ✓';
}
