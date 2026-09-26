import 'demo_nav.dart';

/// Copy shown beside the iPhone mockup on desktop Chrome.
class DemoGuideContent {
  const DemoGuideContent({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.tips,
  });

  final String eyebrow;
  final String title;
  final String body;
  final List<String> tips;
}

DemoGuideContent guideFor({
  required String? overlayRoute,
  required int tabIndex,
  required bool showCaregiverTab,
  required bool signedIn,
  required bool showAuth,
  required bool loading,
}) {
  if (loading) {
    return const DemoGuideContent(
      eyebrow: 'Starting',
      title: 'Loading Verifi',
      body: 'Restoring your session and today’s schedule.',
      tips: [
        'This demo runs in a phone frame so the mobile UI stays true to size.',
        'Use the tabs and the mic button just like on a real device.',
      ],
    );
  }

  switch (overlayRoute) {
    case DemoRoutes.alarm:
      return const DemoGuideContent(
        eyebrow: 'Alarm',
        title: 'It’s time to take a dose',
        body:
            'Full-screen reminder with Take and Snooze — the same flow the OS opens over the lock screen on Android.',
        tips: [
          'Tap Take to log the dose for today.',
          'Snooze reschedules a short follow-up reminder.',
          'On a real phone this can appear even if the app was closed.',
        ],
      );
    case DemoRoutes.voice:
      return const DemoGuideContent(
        eyebrow: 'Voice mode',
        title: 'Talk to Verifi',
        body:
            'Ask what’s due, confirm a dose, or start a package check — hands-free.',
        tips: [
          'Allow microphone access when Chrome asks.',
          'Try: “What do I take now?”',
          'Try: “Show me how to verify this medication.”',
          'Close with the X when you’re done.',
        ],
      );
    case DemoRoutes.visualVerify:
      return const DemoGuideContent(
        eyebrow: 'Camera check',
        title: 'Verify the package',
        body:
            'Point the camera at the box or bottle. Verifi checks it against what’s scheduled — match, mismatch, or uncertain.',
        tips: [
          'Allow camera access in Chrome.',
          'Hold the label steady and well lit.',
          'Uncertain never becomes a guess — try again or ask someone.',
        ],
      );
    case DemoRoutes.addMedication:
      return const DemoGuideContent(
        eyebrow: 'Add medication',
        title: 'Scan or enter manually',
        body: 'Start from a photo of the package, or fill in the details yourself.',
        tips: [
          'Manual entry covers name, dosage, times, and pill color.',
          'Meal anchors like “after breakfast” resolve to sensible clock times.',
        ],
      );
    case DemoRoutes.manualMedication:
      return const DemoGuideContent(
        eyebrow: 'Manual form',
        title: 'Build the schedule',
        body: 'Name, dosage, instructions, frequency, and reminder times.',
        tips: [
          'Add multiple times if you take it more than once a day.',
          'Pick a pill color so it stands out on Home and Schedule.',
          'Save to put it on today’s checklist.',
        ],
      );
    case DemoRoutes.medicationDetail:
      return const DemoGuideContent(
        eyebrow: 'Medication',
        title: 'Details & history',
        body: 'Dosage, schedule, notes, and quick actions for this medication.',
        tips: [
          'Edit if the prescription changed.',
          'Pause or finish when you no longer need reminders.',
        ],
      );
    case DemoRoutes.settings:
      return const DemoGuideContent(
        eyebrow: 'Settings',
        title: 'Profile & preferences',
        body: 'Language, display name, caregiver tab, and sign out.',
        tips: [
          'Switch between English and Portuguese.',
          'Hide the Caregiver tab if you only manage your own meds.',
        ],
      );
    case DemoRoutes.caregiver:
    case DemoRoutes.careRecipient:
      return const DemoGuideContent(
        eyebrow: 'Caregiver',
        title: 'People you care for',
        body: 'Invite someone, accept a link, and see whether doses were taken.',
        tips: [
          'Open a recipient for adherence and today’s status.',
          'Permission is always explicit — no silent watching.',
        ],
      );
    case DemoRoutes.auth:
      return const DemoGuideContent(
        eyebrow: 'Account',
        title: 'Sign in to sync',
        body:
            'Email and password unlock cloud sync for medications and dose history.',
        tips: [
          'Create an account if you’re new.',
          'Or tap “Open as demo user” on sign-up to try a random persona with sample meds — no account needed.',
          'Without Supabase config the app still runs on local demo data.',
        ],
      );
  }

  if (!signedIn && showAuth) {
    return const DemoGuideContent(
      eyebrow: 'Account',
      title: 'Sign in to sync',
      body:
          'Email and password unlock cloud sync for medications and dose history.',
      tips: [
        'Create an account if you’re new.',
        'Or tap “Open as demo user” on sign-up to try a random persona with sample meds — no account needed.',
        'Without Supabase config the app still runs on local demo data.',
      ],
    );
  }

  if (!signedIn) {
    return const DemoGuideContent(
      eyebrow: 'Welcome',
      title: 'Meet Verifi',
      body:
          'A calm medication reminder with voice and camera verification — try the full phone UI in this frame.',
        tips: [
          'Tap Get started to enter the app.',
          'Download the real Android APK from GitHub Releases if you want it on your phone.',
          'Then explore Home, Meds, Schedule, and the mic.',
          'Chrome desktop keeps everything in an iPhone-sized canvas.',
        ],
    );
  }

  switch (tabIndex.clamp(0, 3)) {
    case 0:
      return const DemoGuideContent(
        eyebrow: 'Home',
        title: 'Today’s checklist',
        body:
            'See what’s due now, expand a reminder to take or snooze, and glance at the rest of the day.',
        tips: [
          'Expand a due card for Take now / Snooze.',
          'Empty state? Add your first medication.',
          'Tap the mic for voice — or Settings via the gear.',
        ],
      );
    case 1:
      return const DemoGuideContent(
        eyebrow: 'My medications',
        title: 'Everything you take',
        body: 'Filter All / Active / Paused / Finished and open any med for details.',
        tips: [
          'Use + to add a medication.',
          'Tap a card to see schedule and notes.',
          'Paused meds stop alarms without deleting history.',
        ],
      );
    case 2:
      return const DemoGuideContent(
        eyebrow: 'Schedule',
        title: 'Day by day',
        body:
            'Swipe the day strip, then review Morning, Afternoon, and Evening sections.',
        tips: [
          'Jump across months with the strip separators.',
          'Mark doses taken from here too.',
          'Open a medication for full detail.',
        ],
      );
    case 3:
    default:
      if (showCaregiverTab) {
        return const DemoGuideContent(
          eyebrow: 'Caregiver',
          title: 'Care circle',
          body: 'Manage invites and see adherence for people who shared access with you.',
          tips: [
            'Send or accept an invite to link accounts.',
            'Open a person for today’s doses and heatmaps.',
            'Hide this tab anytime in Settings.',
          ],
        );
      }
      return const DemoGuideContent(
        eyebrow: 'Settings',
        title: 'Profile & preferences',
        body: 'Language, display name, caregiver tab, and sign out.',
        tips: [
          'Switch between English and Portuguese.',
          'Turn the Caregiver tab back on if you need it.',
        ],
      );
  }
}
