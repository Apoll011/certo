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
  String get addedToday => 'Added today';

  @override
  String get addedYesterday => 'Added yesterday';

  @override
  String addedDaysAgo(int count) {
    return 'Added $count days ago';
  }
}
