# Certo

A calm, voice-and-camera-first medication reminder app. This is the Flutter UI
shell (design system + core screens + mock data), built from `idea.md`.

## Status

Implemented (UI shell):
- Onboarding
- Home — today's checklist with notification banner and "mark as taken"
- My Medications — list with All/Active/Paused/Finished filters
- Add Medication — scan/manual entry point (+ recent list)
- Medication Detail — dosage, schedule, started date, notes
- Schedule — 7-day strip + Morning/Afternoon/Evening sections
- Medication Alarm — lock-screen style overlay
- Bottom tab bar with center mic FAB

Deferred (stubbed): Voice mode, Camera/scan flow, Caregiver.

## Stack

- Flutter (Material 3)
- [provider](https://pub.dev/packages/provider) for state
- `flutter_localizations` + `intl` for English/Portuguese (follows the system locale)

## Run

```sh
flutter pub get
flutter run          # pick a device (Android/iOS/web)
flutter test         # smoke test
```

## Design tokens

Colors and typography live in `lib/theme/`. The medication "pill" avatar and
the AI "gradient orb" are reusable widgets in `lib/widgets/`.
