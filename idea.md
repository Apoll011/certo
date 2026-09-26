# Certo — Product Requirements Document

**Tagline:** The safety check between "it's time" and "it's in your hand."

**Status:** Hackathon MVP → early startup validation
**Version:** 2.0
**Stack:** Flutter, Supabase, ElevenLabs, AI APIs (LLM + OCR/CV), Cursor/DeepSeek for dev acceleration

---

## 1. Problem Statement

Medication management tools solve "remembering it's time" (reminders) or "what is this pill" (identification), but nothing verifies that the specific medication a person is about to take matches what their schedule expects, at the moment they're holding it.

This gap shows up everywhere medication is self-administered or given by someone else: a person managing five prescriptions at home, someone with low vision who can't read a label, a person with cognitive difficulty who mixes up look-alike boxes, and a home-care aide juggling multiple clients on one shift. Look-alike/sound-alike (LASA) medication confusion is estimated to account for a meaningful share of all medication errors, and it hits hardest wherever reading, remembering, or seeing the label clearly isn't easy.

Certo closes that specific gap for anyone in that position: schedule → expected item → physical verification → confirm/reject/uncertain → action logged.

---

## 2. Who Certo Is For

Certo is built first as something a person manages for **themselves** — a daily safety check that removes the guesswork of "is this really what I'm supposed to take right now." The caregiver and institutional use cases are the same product, used by someone helping another person instead of themselves.

### Individuals (core, self-serve)
- People managing multiple medications or a complicated schedule.
- Elderly users who want a second check they can trust.
- Blind or low-vision users who can't verify a label by sight.
- People with low health literacy or cognitive load who find medication instructions hard to parse.
- Anyone who just wants one less thing to worry about getting wrong.

This is the group the everyday experience is designed around, and where trust in the product has to be earned first — before it makes sense to anyone helping someone else.

### Family caregivers
- A spouse, adult child, or family member helping someone manage their medication, with that person's explicit permission.
- Wants visibility into whether medication was taken, missed, or mismatched — without taking over the whole process.

### Professional caregivers and small care facilities (business wedge)
- Home-care aides and small elder-care facility staff administering medication to multiple clients per shift.
- Real liability and training cost today; genuine willingness to pay via their employer.
- Validates the same core mechanic at higher stakes and volume, and is where a sustainable business model comes from — but it's built on top of a product that already has to work well for one person managing their own medication.

---

## 3. Core Product Principle

> When the system is confident, simplify the interaction. When it isn't, expose the uncertainty — never guess.

Three states only for any verification: **Confirmed match / Confirmed mismatch / Uncertain.** Uncertain never resolves to a best guess.

This principle matters just as much for an individual double-checking their own pillbox as it does for an aide administering medication to someone else — the cost of a false "match" is the same either way.

---

## 4. Core User Journey (MVP)

The everyday flow is written for a single person managing their own medication; a caregiver or aide runs the identical flow on someone else's behalf.

1. User asks: *"What do I take now?"*
2. Deterministic schedule engine identifies the one expected medication for the current time slot.
3. System (voice) names that single expected medication and asks the user to show the package.
4. User points the camera at the package.
5. Computer vision layer checks the scanned package **against that one expected item only** (closed-set match, not open pill identification):
   - **Match** → confirm aloud, read the saved instruction, offer to mark as taken/given.
   - **Mismatch** → state plainly it doesn't match, name what's actually expected.
   - **Uncertain** → say so, ask the user to try again or check with someone else; never guess.
6. Action (taken / given / skipped / mismatch flagged) is logged to medication history.

**Example — individual user:**
> "What do I need to take now?"
> *"You need to take your Amoxicillin now."*
> *(user scans the box)*
> *"This is your Amoxicillin. It matches what's scheduled for now. Take one capsule after food."*
> User marks it as taken. No label reading, no remembering the schedule, no second-guessing.

**Example — professional caregiver:**
> Aide asks: "What does Mrs. Silva take now?"
> Same flow, same three states, same confirm-before-acting rule — just running against a different client's schedule.

---

## 5. Feature List

### 5.1 MVP Features (build for the 8-hour hackathon)

| Feature | Description | Layer |
|---|---|---|
| Medication registration (manual) | Add name, dosage, instructions, schedule, meal timing | Deterministic |
| Medication schedule | Time-based schedule per medication; determines "what's due now" | Deterministic |
| "What do I take now?" query | Natural-language request resolved by AI, answered by deterministic engine | AI + Deterministic |
| Camera-based verification | Match scanned package (OCR/barcode/visual features) against the one expected item | Computer Vision |
| Three-state confidence output | Match / Mismatch / Uncertain, exposed explicitly, never silently resolved | Deterministic |
| Voice output (ElevenLabs) | Speaks schedule info and verification result, tone matched to safety state | Voice |
| Instruction read-aloud | Reads the stored, verified instruction text as-is (no rewriting of medically relevant content) | AI (constrained) + Voice |
| Mark as taken/given | Only enabled after a confirmed match | Deterministic |
| Medication history log | Records taken / mismatched / uncertain events with timestamps | Deterministic |
| Accessible UI | Large text, high contrast, large touch targets, screen-reader support | Flutter |
| Bilingual support (PT/EN) | Interface and voice output in Portuguese and English | AI + Voice |

### 5.2 Roadmap Features (explicitly NOT in MVP)

| Feature | Description | Notes |
|---|---|---|
| Family/caregiver sharing with consent | Permissioned visibility into missed/mismatched events for a supported person | Requires consent model, deferred |
| Multi-medication detection in one frame | Identify several packages at once | Harder CV problem, deferred |
| Prescription scanning / auto-registration | OCR a prescription slip to auto-populate schedule | Deferred, accuracy risk |
| Offline mode | Local-only operation without connectivity | Deferred |
| Institutional dashboard (for care agencies) | Per-staff, per-client mismatch/incident reporting | Post-MVP, built once individual product is validated |
| Pharmacy/insurer integrations | Data-sharing partnerships for adherence and safety reporting | Long-term, requires validation and legal review |
| Advanced multi-pill / loose-pill identification | Open-set pill recognition beyond packaged items | Explicitly out of scope; unreliable and higher regulatory risk |

### 5.3 Explicitly Out of Scope (any version)

- Diagnosing disease or conditions
- Prescribing or recommending starting/stopping any medication
- Modifying, inventing, or altering dosage or medically relevant instructions
- Guaranteeing identification of unlabeled/loose pills
- Replacing a doctor or pharmacist

---

## 6. System Architecture

### 6.1 Layer Separation (non-negotiable safety boundary)

```
┌─────────────────────────────────────────────┐
│  Deterministic Safety Layer (source of truth)│
│  - Medication list & schedule                │
│  - Verified dosage/instructions              │
│  - Matching logic & confidence thresholds    │
│  - Permissions & history                     │
│  - Escalation rules (never overridden by AI) │
└─────────────────────────────────────────────┘
              ▲                    ▲
              │                    │
┌─────────────────────┐  ┌─────────────────────┐
│   AI / LLM Layer     │  │  Computer Vision     │
│  - NL request parsing│  │  - Closed-set match  │
│  - Instruction        │  │    of scanned item   │
│    simplification     │  │    vs. expected item │
│    (never invents/    │  │  - OCR / barcode      │
│    alters content)    │  │  - Returns match/     │
│  - Orchestrates calls │  │    mismatch/uncertain │
│    to deterministic   │  │    only               │
│    layer               │  └─────────────────────┘
└─────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│         Voice Layer (ElevenLabs)             │
│  Renders deterministic layer's output as     │
│  speech only. Tone preset selected by safety │
│  state (confirm / mismatch / uncertain).     │
│  Never makes or alters a safety decision.    │
└─────────────────────────────────────────────┘
```

**Hard rule:** the AI and voice layers can only *render and orchestrate*. Only the deterministic layer decides confirmed / mismatch / uncertain, and only the deterministic layer can permit a "mark as taken" action.

### 6.2 Component Responsibilities

- **Flutter (client):** UI, accessibility features (screen reader hooks, large text/contrast, haptics), camera capture, local state, calls to Supabase and AI/voice services.
- **Supabase:** auth, Postgres database (medications, schedules, history, permissions), storage for reference package images, row-level security for family/caregiver permissioning.
- **AI API (LLM):** natural-language request parsing ("what do I take now" → structured query), instruction simplification (rewording only, source text remains system of record), conversational orchestration.
- **Computer vision / OCR:** closed-set verification of a scanned package against one expected reference (stored image/barcode/OCR text), returns one of three states with a confidence score; no open-set identification.
- **ElevenLabs:** text-to-speech rendering of deterministic-layer output; distinct voice/tone presets for confirm, mismatch, and uncertain states.
- **Deterministic safety engine (application logic, not an AI model):** schedule resolution, matching decision, thresholds, permissions, history logging, escalation rules.

---

## 7. Integrations

| Integration | Purpose | Notes |
|---|---|---|
| ElevenLabs | Text-to-speech for all spoken output | Tone/voice preset varies by safety state, never by content the AI generates freely |
| LLM API (e.g., Claude/OpenAI-class model) | NL understanding, instruction simplification, orchestration | Constrained: cannot write to medication/dosage records |
| OCR / barcode recognition | Reads package text/codes for matching | Off-the-shelf OCR + barcode libraries; no custom model training in MVP |
| Computer vision matching | Confirms/rejects scanned package against one expected reference | Closed-set, not general pill/package classification |
| Supabase Auth | User accounts, family/caregiver permissioning (roadmap) | Row-level security for any shared data |
| Supabase Postgres + Storage | Medication data, schedules, history, reference images | Source-of-truth database |
| Screen reader APIs (iOS/Android via Flutter) | Native accessibility support | Required for blind/low-vision usability, not optional |

**Roadmap integrations (not MVP):** pharmacy dispensing systems, national e-medication formats (relevant to EU markets), care-agency incident/reporting systems, insurer data-sharing pipelines. None of these are built or assumed working before real institutional pilots and legal review.

---

## 8. Data Model (high level)

- **User** — id, role (individual / family caregiver / professional staff), locale (PT/EN), accessibility preferences
- **Medication** — id, owner_user_id, name, dosage, instructions (verified source text), meal timing, notes
- **Schedule** — id, medication_id, time slots, recurrence
- **ReferenceImage/Code** — id, medication_id, stored image and/or barcode/OCR text used for matching
- **VerificationEvent** — id, medication_id, timestamp, result (match/mismatch/uncertain), confidence score
- **MedicationHistory** — id, medication_id, timestamp, action (taken/given/skipped), verification_event_id
- **Permission** (roadmap) — grantor_user_id, grantee_user_id, scope (e.g., view missed/mismatch events only)

---

## 9. Non-Functional Requirements

- **Safety:** system must never present an uncertain result as a match; default behavior on any doubt is to say so.
- **Accessibility:** WCAG-aligned contrast and touch-target sizing; full screen-reader compatibility; voice-first interaction path that requires no reading.
- **Localization:** Portuguese and English at launch, UI and voice both.
- **Latency:** verification response (camera scan → spoken result) should feel immediate in-demo; target well under a few seconds for the closed-set match.
- **Privacy:** medication and health data stored per-user with strict access control; family/caregiver visibility only via explicit, revocable permission (roadmap).

---

## 10. Regulatory & Compliance Notes (not legal advice)

- Framing matters: Certo is positioned as an **identity/logistics confirmation aid**, not a diagnostic or treatment-decision tool, to stay clear of higher EU MDR software classification tiers. This wording needs real legal review before any deployment beyond a prototype.
- GDPR (and Portuguese data protection law) applies to any stored health-adjacent data; production version needs a data processing assessment before handling real patient data.
- No claims of clinical validation should ever be made about a hackathon or early-stage prototype build.

---

## 11. Success Metrics (post-MVP validation)

- Verification accuracy: false-positive rate (system says match when it's actually a mismatch) must be effectively zero in testing; false "uncertain" is acceptable, false "match" is not.
- Time-to-verify per interaction.
- Individual users: adoption and continued daily use as a personal safety habit — the strongest signal the core loop actually works.
- Family/caregiver users: reported confidence that a loved one's medication was taken correctly.
- Professional/institutional pilots: reduction in reported medication mismatch incidents per shift/staff member.
- User-reported trust in the system's uncertainty communication (does "I don't know" read as helpful, not broken).

---

## 12. Business Model Summary

- **Primary product:** free or low-cost self-serve tier for individuals and family caregivers — this is where the core experience gets proven and where most users will actually live.
- **Business wedge:** home-care agencies and small elder-care facilities (B2B license per caregiver/facility), sold on top of a product individuals already trust.
- **Long-term:** pharmacy and insurer partnerships once safety data accumulates; not assumed or built into the MVP.

---

## 13. Open Questions

- What's the minimum reference data (photos/barcodes) needed per medication to make closed-set matching reliable across common Portuguese pharmacy packaging?
- What's the right escalation path when "uncertain" occurs repeatedly for the same medication (packaging wear, lighting, etc.)?
- What consent/permission model is appropriate for family and professional caregiver visibility, and does it differ between the two?
- At what point does "verification aid" framing risk being reclassified as a higher-tier medical device under MDR, and what wording avoids that ambiguity?
- What would make an individual user trust and stick with a daily verification habit, independent of whether anyone else ever sees their data?
