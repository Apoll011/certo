# Certo

A calm, voice-and-camera-first medication reminder app. Flutter client backed by
Supabase (Auth + Postgres + Row Level Security), built from `idea.md`.

## Status

Implemented (UI shell):
- Onboarding
- Home — today's checklist (frequency-aware), expandable "due now" reminder
  with take-now / snooze actions, and empty states
- My Medications — list with All/Active/Paused/Finished filters + empty states
- Add Medication — manual form (name, dosage, instruction, times incl. meal
  anchors, frequency, pill color) + scan stub
- Medication Detail — dosage, schedule, frequency, started date, notes
- Schedule — single-line day strip with month separators (unbounded into the
  past, +2 months ahead) + Morning/Afternoon/Evening sections
- Settings — language (EN/PT), profile name, sign out
- Medication Alarm — full-screen clock-style UI (looping alarm tone, take /
  snooze) opened by the OS alarm
- Bottom tab bar with center mic FAB

Schedule & alarms:
- Recurrence: every N days (`frequency_days`), plus meal anchors
  ("after breakfast/lunch/dinner") that resolve to 08:00 / 14:00 / 20:00.
- Real full-screen alarms via `flutter_local_notifications` + AlarmManager:
  doses are scheduled with `exactAllowWhileIdle`, a loud alarm tone, vibration,
  and a full-screen intent that opens the alarm UI over the lock screen — even
  when the app was killed (Android). Snooze reschedules a one-off reminder.
  iOS is limited to a sound notification (no background full-screen takeover).

Supabase backend:
- Email/password auth (sign in / sign up) with session restore + sign out
- Session-gated main shell (auth screen shown when signed out)
- Medications persisted via the Supabase Data API (create/read/update/delete)
- `dose_events` log when a dose is marked "taken"
- Row Level Security on every table (users only touch their own rows)
- Offline/demo fallback: without Supabase config the app runs on mock data

Deferred (stubbed): Voice mode, Camera/scan flow, Caregiver.

## Stack

- Flutter (Material 3)
- [provider](https://pub.dev/packages/provider) for state
- [supabase_flutter](https://pub.dev/packages/supabase_flutter) for auth + data
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) for OS alarms
- [audioplayers](https://pub.dev/packages/audioplayers) for the looping alarm tone
- [wakelock_plus](https://pub.dev/packages/wakelock_plus) to keep the alarm screen awake
- `flutter_localizations` + `intl` for English/Portuguese (follows the system locale)

## Architecture

```
lib/
  config/app_config.dart         # build-time secrets (--dart-define)
  services/supabase_service.dart # Supabase init + client access
  data/medication_repository.dart# medications CRUD (Data API)
  data/profile_repository.dart   # profile name
  state/app_state.dart           # ChangeNotifier: session + data + UI state
  models/medication.dart         # Medication + JSON mapping
  screens/, widgets/, theme/
```

`AppState` is the single source of truth the widgets already use. When a user
is authenticated it loads medications from Supabase; otherwise it falls back to
`lib/data/mock_data.dart` so the shell still runs offline.

## Configuration

The app reads Supabase credentials from `String.fromEnvironment`. The simplest
way to supply them is a gitignored `.env` file injected with
`--dart-define-from-file`:

```sh
cp .env.example .env    # then edit with your project's values
flutter run --dart-define-from-file=.env
```

Or pass them directly:

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon/publishable key>
```

The anon/publishable key is safe to ship in the client — RLS enforces access.
Never put the `service_role` key, database password, or any private secret in
the app. Secret-requiring work belongs in Supabase Edge Functions later.

## Database schema & migrations

The schema lives in `supabase/migrations/` and is managed with the Supabase CLI
(`supabase` v2). The Flutter app never creates tables or alters schema — it only
reads/writes rows through the Data API.

Tables: `profiles`, `medications`, `dose_events` (all RLS-protected; a trigger
auto-creates a `profiles` row on signup).

### One-time setup

```sh
npm install -g supabase            # or: npx supabase
supabase login                     # browser auth
supabase link --project-ref <ref>  # associates this repo with your project
```

### Applying migrations

```sh
supabase db push                   # apply migrations/*.sql to the linked project
```

### Optional demo seed

```sh
# 1. edit supabase/seed.sql and replace <USER_ID> with a real auth user id
# 2. apply migrations + seed on a fresh local/remote db:
supabase db reset
```

Keep `supabase/seed.sql` out of production. The Flutter mock data already covers
offline demos.

### Email confirmation

By default Supabase requires email confirmation for sign-ups. For a hackathon
demo, disable **Authentication → Providers → Email → Confirm email** in the
dashboard so `sign up` returns a session immediately. If it stays enabled, the
app shows "Check your email to confirm your account." after sign-up.

## Run

```sh
flutter pub get
cp .env.example .env  # first time only; then fill in your Supabase values
flutter gen-l10n      # only after editing lib/l10n/*.arb
flutter analyze
flutter test
flutter run --dart-define-from-file=.env
```

## Design tokens

Colors and typography live in `lib/theme/`. The medication "pill" avatar and
the AI "gradient orb" are reusable widgets in `lib/widgets/`.
