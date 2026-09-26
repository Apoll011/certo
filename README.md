# Certo

A calm, voice-and-camera-first medication reminder app. Flutter client backed by
Supabase (Auth + Postgres + Row Level Security), built from `idea.md`.

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

Inject the Supabase project's **publishable (anon)** key at build time. These
are safe to ship in the client — RLS enforces access.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon/publishable key>
```

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
flutter gen-l10n      # only after editing lib/l10n/*.arb
flutter analyze
flutter test
flutter run           # add --dart-define for a real Supabase project
```

## Design tokens

Colors and typography live in `lib/theme/`. The medication "pill" avatar and
the AI "gradient orb" are reusable widgets in `lib/widgets/`.
