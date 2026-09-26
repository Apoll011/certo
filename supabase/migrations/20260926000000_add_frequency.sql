-- Schedule frequency support: every N days.
-- `times` may now also contain meal anchors ("breakfast", "lunch", "dinner")
-- in addition to clock times like "9:00 AM" — no schema change needed there.
alter table public.medications
  add column if not exists frequency_days integer not null default 1;
