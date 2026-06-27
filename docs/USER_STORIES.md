# DailyFitness — User Stories

**Version:** 1.0  
**Last updated:** June 27, 2026  
**Source:** [PRD.md](./PRD.md) v0.3  
**Personas:** **Jordan** (structured mover — strength + mobility), **Alex** (consistency-first — simple logging)

### Story format

Each story includes priority, phase, PRD traceability, and testable acceptance criteria.

**Priority:** P0 (MVP) · P1 (launch polish) · P2 (v1.1) · P3 (v2+)

---

## Epic 1: Foundation & Design System

| ID | Priority | Phase |
|----|----------|-------|
| US-001 | P0 | 0 |
| US-002 | P0 | 0 |
| US-003 | P0 | 0 |

### US-001 — Calm Strength design system

**As a** user opening DailyFitness for the first time,  
**I want** a calm, inclusive visual design,  
**so that** the app feels welcoming regardless of how I train.

**Acceptance criteria**

- [ ] Light and dark mode supported with Calm Strength palette (stone neutrals, forest/slate primary, sage or terracotta accent)
- [ ] SF Pro typography with medium-weight headings and readable body text
- [ ] No bro-culture copy, streak-shaming, or gendered program language in default UI strings
- [ ] Strength, mobility, yoga, and flexibility categories use equal visual weight in navigation

**PRD refs:** §6 Branding

---

### US-002 — Core data models

**As a** developer,  
**I want** data models that support multiple training modalities,  
**so that** strength, mobility, yoga, and flexibility can be logged in one app.

**Acceptance criteria**

- [ ] Exercise model supports categories: strength, mobility, flexibility, yoga, cardio
- [ ] Set model supports weight+reps, duration, hold time, and side (L/R) where relevant
- [ ] Routine, Program, WorkoutSession, and WorkoutSet entities defined with relationships
- [ ] Progression recommendations stored separately from user-logged performance

**PRD refs:** §9.1 LOG-03, §14 Technical

---

### US-003 — App shell & tab navigation

**As a** user,  
**I want** clear navigation between Home, Programs, Progress, and Profile,  
**so that** I can find what I need quickly mid-session or between workouts.

**Acceptance criteria**

- [ ] Four-tab bar: Home, Programs, Progress, Profile
- [ ] Active workout surfaces as full-screen modal, not a tab
- [ ] Tab bar hidden during live workout
- [ ] Deep link placeholder for future workout resume (session ID in app state)

**PRD refs:** §11 Information Architecture

---

## Epic 2: Account & Sync

| ID | Priority | Phase |
|----|----------|-------|
| US-010 | P0 | 0 |
| US-011 | P0 | 1 |
| US-012 | P1 | 1 |

### US-010 — Sign in with Apple

**As a** user,  
**I want** to sign in with Apple,  
**so that** my workouts sync across devices without creating another password.

**Acceptance criteria**

- [ ] Sign in with Apple is the primary auth method
- [ ] User can use app locally before sign-in; cloud sync prompts after first saved workout or in Profile
- [ ] Account deletion available in Profile (App Store requirement)
- [ ] Auth state persists across app restarts

**PRD refs:** ACC-01

---

### US-011 — Offline logging with cloud sync

**As Jordan**,  
**I want** to log full workouts without internet and sync later,  
**so that** poor gym signal never blocks my session.

**Acceptance criteria**

- [ ] All workout logging works offline
- [ ] Workouts saved to local storage immediately on set complete and session end
- [ ] Sync queue uploads pending workouts when connectivity returns
- [ ] Visible sync status indicator (synced / pending / error) in Profile or Home
- [ ] New device restore pulls full workout history after sign-in

**PRD refs:** LOG-11, ACC-02

---

### US-012 — Export workout history (Premium)

**As a** Premium user,  
**I want** to export my workout history as CSV,  
**so that** I own my data outside the app.

**Acceptance criteria**

- [ ] Export available in Profile for Premium subscribers only
- [ ] CSV includes date, workout name, exercise, set type, weight, reps, duration, notes
- [ ] Free users see upgrade prompt, not a broken export button
- [ ] Export completes for accounts with 1000+ logged sets without crash

**PRD refs:** ACC-03, §13 Premium

---

## Epic 3: Exercise Library

| ID | Priority | Phase |
|----|----------|-------|
| US-020 | P0 | 0 |
| US-021 | P0 | 0 |
| US-022 | P0 | 1 |
| US-023 | P1 | 1 |

### US-020 — Seeded exercise library (2000+)

**As a** user building a routine,  
**I want** a large library of exercises across all training types,  
**so that** I rarely need to create exercises from scratch.

**Acceptance criteria**

- [ ] ≥2,000 exercises seeded at launch
- [ ] Each exercise has: name, category, primary muscles, equipment tags
- [ ] Categories: strength, mobility, flexibility, yoga, cardio
- [ ] Illustration or photo attached to each exercise (placeholder acceptable for edge cases)
- [ ] Import pipeline documented for adding/updating bulk exercise data

**PRD refs:** LIB-01, LIB-02, LIB-05, LIB-06

---

### US-021 — Search and filter exercises

**As Alex**,  
**I want** to search and filter the exercise library,  
**so that** I can find movements quickly while building a routine.

**Acceptance criteria**

- [ ] Search by exercise name (partial match, case-insensitive)
- [ ] Filter by category, muscle group, and equipment
- [ ] Filters combinable (e.g. strength + chest + dumbbell)
- [ ] Results render in <300ms for full library on target devices
- [ ] Empty state shows helpful message, not a blank screen

**PRD refs:** LIB-03

---

### US-022 — Create custom exercises

**As a** user with specialty equipment,  
**I want** to create custom exercises,  
**so that** I can log movements not in the library.

**Acceptance criteria**

- [ ] User can create exercise with name, category, muscles, equipment
- [ ] Logging fields match category (weight+reps for strength; duration/hold for mobility/yoga)
- [ ] Custom exercises appear in search alongside seeded exercises
- [ ] Custom exercises persist across sync and device restore
- [ ] User can edit and delete their custom exercises

**PRD refs:** LIB-04

---

### US-023 — Exercise detail view

**As a** user,  
**I want** to see exercise details before adding it to a routine,  
**so that** I know what muscles it targets and how to perform it.

**Acceptance criteria**

- [ ] Detail screen shows name, category, muscles, equipment, illustration/photo
- [ ] "Add to routine" action from detail screen
- [ ] Personal history snippet if user has logged this exercise before ("Last: 80kg × 8")
- [ ] Video playback deferred — show photo/illustration only in v1

**PRD refs:** LIB-05, SH-01 (video v1.1)

---

## Epic 4: Onboarding

| ID | Priority | Phase |
|----|----------|-------|
| US-030 | P0 | 2 |
| US-031 | P1 | 2 |

### US-030 — First-run onboarding

**As a** new user,  
**I want** a short onboarding flow,  
**so that** I can start training in under 90 seconds.

**Acceptance criteria**

- [ ] Onboarding completable in ≤4 screens and ≤90 seconds for typical user
- [ ] Screen 1: Welcome + Dailybase family / calm training value prop
- [ ] Screen 2: Multi-select training types (Strength, Mobility, Yoga, Stretching)
- [ ] Screen 3: Optional suggested program picker filtered by selections, with Skip
- [ ] Screen 4: Optional Lock Screen workout controls opt-in
- [ ] Lands on Home with "Start first session" CTA
- [ ] Onboarding skippable; preferences editable later in Profile

**PRD refs:** §10.4 Onboarding

---

### US-031 — Units and defaults from locale

**As a** user,  
**I want** weight units to default sensibly for my region,  
**so that** I don't have to configure basics on day one.

**Acceptance criteria**

- [ ] Default kg for metric locales, lb for US locale
- [ ] User can override in Profile → Settings
- [ ] Default rest timer: 90 seconds (configurable 30–300s)
- [ ] RIR tracking off by default; toggle in Settings

**PRD refs:** §17 Open Q6, §8 Product Principles #5

---

## Epic 5: Routines

| ID | Priority | Phase |
|----|----------|-------|
| US-040 | P0 | 1 |
| US-041 | P0 | 1 |
| US-042 | P1 | 1 |

### US-040 — Create and edit routines

**As Jordan**,  
**I want** to build reusable workout routines,  
**so that** I can start consistent sessions without rebuilding each time.

**Acceptance criteria**

- [ ] Create routine with name and ordered exercise list
- [ ] Per exercise: target sets, reps or duration, default rest time
- [ ] Add exercises from library or custom exercises
- [ ] Drag to reorder exercises
- [ ] Edit and delete routines
- [ ] Free tier: up to 5 saved routines/programs combined; upgrade prompt at limit

**PRD refs:** PRG-05, RTN-01, §13 Free tier

---

### US-041 — Configure supersets in routines

**As a** user,  
**I want** to group exercises into supersets,  
**so that** my routine matches how I actually train.

**Acceptance criteria**

- [ ] Pair 2–4 exercises into a superset group
- [ ] Superset visually grouped in routine editor and live workout
- [ ] Live workout cycles sets across superset exercises in order
- [ ] User can dissolve superset back to individual exercises

**PRD refs:** LOG-08

---

### US-042 — Exercise and routine notes

**As a** user,  
**I want** to add notes to exercises and workouts,  
**so that** I remember cues, pain flags, or setup details.

**Acceptance criteria**

- [ ] Per-exercise note field in routine and live workout
- [ ] Per-workout note at session level
- [ ] Exercise notes persist and pre-fill on next session for that routine
- [ ] Notes sync across devices

**PRD refs:** LOG-09

---

## Epic 6: Live Workout Logging

| ID | Priority | Phase |
|----|----------|-------|
| US-050 | P0 | 1 |
| US-051 | P0 | 1 |
| US-052 | P0 | 1 |
| US-053 | P0 | 1 |
| US-054 | P0 | 1 |
| US-055 | P1 | 1 |

### US-050 — Start a workout

**As Jordan**,  
**I want** to start a workout in two taps,  
**so that** I'm not navigating menus between warm-up sets.

**Acceptance criteria**

- [ ] Start from Home: scheduled workout, recent routine, or blank workout
- [ ] ≤2 taps from Home to active live workout screen
- [ ] Blank workout: add exercises on the fly from library
- [ ] Session timer starts automatically
- [ ] Resume in-progress workout if app was backgrounded or killed

**PRD refs:** LOG-01

---

### US-051 — Log strength sets quickly

**As Jordan**,  
**I want** weight and reps pre-filled from my last session,  
**so that** logging each set takes seconds.

**Acceptance criteria**

- [ ] Weight and reps default to previous session values (ghost text)
- [ ] One tap to confirm unchanged values and mark set complete
- [ ] "Last time: 80kg × 8" visible on exercise card
- [ ] Median time to log one unchanged set ≤3 seconds (usability target)
- [ ] Haptic feedback on set complete

**PRD refs:** LOG-02, LOG-04, LOG-06

---

### US-052 — Log mobility, yoga, and flexibility

**As Alex**,  
**I want** to log holds and durations for mobility and yoga,  
**so that** all my training lives in one app.

**Acceptance criteria**

- [ ] Mobility/flexibility exercises show duration or hold-time fields (not weight)
- [ ] Yoga exercises support duration and optional session notes
- [ ] Left/right side logging where applicable
- [ ] Previous performance shows last duration/hold ("Last: 45s hold")
- [ ] Workout summary includes total mobility/yoga time

**PRD refs:** LOG-03, AN-07

---

### US-053 — Rest timer

**As a** user between sets,  
**I want** an automatic rest timer,  
**so that** I stay on pace without watching the clock.

**Acceptance criteria**

- [ ] Rest timer auto-starts when strength set marked complete
- [ ] Default duration from Settings (30–300s); overridable per exercise in routine
- [ ] Timer shows countdown in live workout UI
- [ ] Optional sound/haptic when rest ends
- [ ] User can skip or extend rest (+30s) inline
- [ ] Rest timer does not auto-start for yoga/mobility unless user configures it

**PRD refs:** LOG-05

---

### US-054 — Advanced set types (strength)

**As an** intermediate lifter,  
**I want** to mark warmup, failure, and drop sets,  
**so that** my log reflects how the session actually went.

**Acceptance criteria**

- [ ] Set types: normal, warmup, failure, drop set
- [ ] Set type selectable per set row (not buried in menus)
- [ ] Warmup sets excluded from volume totals and progression calculations
- [ ] Drop sets visually linked to preceding working set

**PRD refs:** LOG-07

---

### US-055 — End workout summary

**As a** user finishing a session,  
**I want** a clear summary of what I accomplished,  
**so that** I feel closure before leaving the gym.

**Acceptance criteria**

- [ ] Summary shows: total duration, exercises completed, volume (strength) or total time (mobility/yoga)
- [ ] New PRs highlighted if any
- [ ] Option to add workout-level note before save
- [ ] Save persists locally immediately; sync queued if offline
- [ ] No social share prompt (social out of scope)

**PRD refs:** LOG-10

---

## Epic 7: Lock Screen & Live Activities

| ID | Priority | Phase |
|----|----------|-------|
| US-060 | P0 | 1 |
| US-061 | P0 | 1 |
| US-062 | P0 | 1 |
| US-063 | P1 | 1 |

### US-060 — Live Activity during workout

**As Jordan**,  
**I want** my active workout visible on the Lock Screen,  
**so that** I don't unlock my phone between every set.

**Acceptance criteria**

- [ ] Live Activity starts when workout starts (if user opted in)
- [ ] Shows on Lock Screen and Dynamic Island on supported devices
- [ ] Displays: current exercise name, set progress (e.g. "Set 2 of 4")
- [ ] Live Activity ends when workout saved or discarded
- [ ] Permission prompt explains value before requesting Live Activities access

**PRD refs:** LOCK-01, LOCK-04

---

### US-061 — Rest timer on Lock Screen

**As a** user resting between sets,  
**I want** the countdown on my Lock Screen,  
**so that** I can pace rest without opening the app.

**Acceptance criteria**

- [ ] Rest countdown visible in Live Activity during rest periods
- [ ] Timer updates in real time on Lock Screen
- [ ] Transition from rest to next set reflected in Live Activity state
- [ ] Calm visual treatment — no flashing red urgency

**PRD refs:** LOCK-02, §6 Branding Motion

---

### US-062 — Complete set from Lock Screen

**As Jordan**,  
**I want** to mark a set complete from the Lock Screen,  
**so that** my phone stays in my pocket during training.

**Acceptance criteria**

- [ ] Interactive "Complete set" action on Live Activity (where iOS version supports)
- [ ] Tapping complete advances workout state in app and Live Activity
- [ ] If interactive buttons unavailable on device/iOS version, tapping Live Activity opens app to set row
- [ ] Completed set triggers rest timer on Lock Screen

**PRD refs:** LOCK-03

---

### US-063 — Live Activity fallback

**As a** user who disabled Live Activities,  
**I want** in-app rest timer and notifications,  
**so that** I'm not left without timing tools.

**Acceptance criteria**

- [ ] If Live Activities off: in-app rest timer works normally
- [ ] Optional local notification when rest period ends (user-configurable)
- [ ] End workout action available in-app; Live Activity end action with confirmation where supported
- [ ] Settings → Lock Screen preferences to re-enable

**PRD refs:** LOCK-05, LOCK-06

---

## Epic 8: Programs

| ID | Priority | Phase |
|----|----------|-------|
| US-070 | P0 | 2 |
| US-071 | P0 | 2 |
| US-072 | P0 | 2 |
| US-073 | P1 | 2 |

### US-070 — Browse suggested programs

**As Alex**,  
**I want** curated programs for strength, mobility, yoga, and flexibility,  
**so that** I can follow a plan without designing one myself.

**Acceptance criteria**

- [ ] Programs tab → Suggested catalog
- [ ] Browse by category: Strength, Mobility, Yoga, Flexibility, Hybrid
- [ ] v1 catalog includes all programs listed in PRD §9.2 (11 programs minimum)
- [ ] Program card shows: name, days/week, duration, level, category
- [ ] All suggested programs free to start

**PRD refs:** PRG-01, PRG-07, §9.2

---

### US-071 — Program detail and start

**As a** user,  
**I want** to preview a program before committing,  
**so that** I know the time commitment and equipment needed.

**Acceptance criteria**

- [ ] Detail screen: description, duration (weeks), days/week, equipment list, level
- [ ] Week/day outline showing assigned routines
- [ ] "Start program" adds schedule to Home
- [ ] Active program visible under Programs → My programs
- [ ] User can pause or leave program without losing logged history

**PRD refs:** PRG-02, PRG-03

---

### US-072 — Build custom programs

**As Jordan**,  
**I want** to build multi-week programs with mixed modalities,  
**so that** my strength and yoga days follow one schedule.

**Acceptance criteria**

- [ ] Create program: name, length in weeks, training days per week
- [ ] Assign routine to each day slot (e.g. Mon Upper, Wed Yoga, Fri Lower)
- [ ] Support hybrid schedules (strength + mobility + yoga in same program)
- [ ] Home shows today's scheduled workout from active program
- [ ] Free tier: counts toward 5 routine/program limit

**PRD refs:** PRG-04, §10.3

---

### US-073 — Duplicate and edit suggested programs

**As a** user,  
**I want** to copy a suggested program and customize it,  
**so that** I get guidance without being locked into someone else's plan.

**Acceptance criteria**

- [ ] "Duplicate & edit" on any suggested program detail screen
- [ ] Copy creates user-owned program in My programs
- [ ] All exercises, sets, and schedule editable after duplicate
- [ ] Original suggested template unchanged
- [ ] Clear label: "Based on [Program Name]"

**PRD refs:** PRG-06, §8 Product Principles #4

---

## Epic 9: Smart Progression

| ID | Priority | Phase |
|----|----------|-------|
| US-080 | P0 | 2 |
| US-081 | P0 | 2 |
| US-082 | P1 | 2 |
| US-083 | P1 | 2 |

### US-080 — Strength progression recommendations

**As Jordan**,  
**I want** suggested weight and reps for my next strength session,  
**so that** I progress without spreadsheet math.

**Acceptance criteria**

- [ ] Next-session targets shown on exercise card when starting routine workout
- [ ] Recommendations derived from last completed working sets
- [ ] Progression applies to strength exercises only — not yoga/mobility
- [ ] User can accept, edit, or ignore recommendation before logging
- [ ] Free tier: progression shown for 2 exercises per workout; Premium unlocks all

**PRD refs:** PROG-01, PROG-06, PROG-07, §12

---

### US-081 — Progression explanation

**As a** user,  
**I want** to see why the app suggested a weight change,  
**so that** I trust the recommendation.

**Acceptance criteria**

- [ ] Plain-language reason displayed (e.g. "↑ 2.5kg — you hit top of rep range last session")
- [ ] Tap reason for slightly more detail (optional expand)
- [ ] Hold and reduce recommendations also explained
- [ ] No recommendation shown if insufficient history (first session message instead)

**PRD refs:** PROG-03, §12 Transparency

---

### US-082 — Optional RIR progression

**As an** advanced user,  
**I want** to enable RIR tracking and RIR-aware progression,  
**so that** recommendations respect how hard my sets actually were.

**Acceptance criteria**

- [ ] RIR off by default in Settings
- [ ] When enabled: RIR picker (0–5) on set row after set complete
- [ ] Progression engine uses RIR model only when RIR enabled and logged
- [ ] Explanation references RIR when used ("exceeded target at 2 RIR")
- [ ] Disabling RIR reverts to rep-range-only progression model

**PRD refs:** PROG-02, §12

---

### US-083 — Progression controls

**As a** user,  
**I want** to override or disable progression per exercise,  
**so that** I'm in control of movements I manage manually.

**Acceptance criteria**

- [ ] Toggle auto-progression off per exercise in routine settings
- [ ] Deload suggestion after 3 failed progression attempts (non-blocking banner)
- [ ] Manual weight entry always overrides recommendation for that session
- [ ] Progression state resets sensibly when user changes rep targets in routine

**PRD refs:** PROG-04, PROG-05

---

## Epic 10: Progress & Analytics

| ID | Priority | Phase |
|----|----------|-------|
| US-090 | P0 | 2 |
| US-091 | P0 | 2 |
| US-092 | P1 | 2 |
| US-093 | P1 | 2 |

### US-090 — Workout history and calendar

**As a** user,  
**I want** to browse past workouts on a calendar and list,  
**so that** I can review what I did and when.

**Acceptance criteria**

- [ ] Progress tab → Calendar with completed sessions marked
- [ ] List view: newest first, filterable by category (strength/mobility/yoga)
- [ ] Tap session → full workout detail (exercises, sets, duration, notes)
- [ ] No streak guilt copy ("You missed 3 days" forbidden)

**PRD refs:** AN-01, AN-06, §8 #6

---

### US-091 — Personal records and e1RM

**As Jordan**,  
**I want** to see my PRs and estimated 1RM,  
**so that** I know when I'm getting stronger.

**Acceptance criteria**

- [ ] PR detection on set complete for strength exercises (weight, reps, volume)
- [ ] PR notification inline during workout (subtle, not gamified explosion)
- [ ] Progress tab → PR list by exercise
- [ ] Estimated 1RM calculated and shown on exercise history chart
- [ ] PRs available on free tier

**PRD refs:** AN-03, AN-04

---

### US-092 — Exercise history charts

**As a** user,  
**I want** charts of my performance over time,  
**so that** I see trends beyond single sessions.

**Acceptance criteria**

- [ ] Per-exercise chart: weight, reps, volume over time
- [ ] Free: last 90 days; Premium: all time
- [ ] Mobility/yoga: duration and frequency over time
- [ ] Upgrade prompt on chart when free user scrolls beyond 90-day window

**PRD refs:** AN-02

---

### US-093 — Muscle volume analytics (Premium)

**As a** Premium user,  
**I want** volume breakdown by muscle group,  
**so that** I can spot training imbalances.

**Acceptance criteria**

- [ ] Muscle group volume chart: 30-day free preview or summary; all-time + trends Premium
- [ ] Breakdown by week and muscle group
- [ ] Based on logged strength exercises and muscle tags
- [ ] Free users see teaser with upgrade path

**PRD refs:** AN-05, §13 Premium

---

## Epic 11: Home & Weekly Summary

| ID | Priority | Phase |
|----|----------|-------|
| US-100 | P0 | 2 |
| US-101 | P1 | 2 |

### US-100 — Home dashboard

**As a** user opening the app,  
**I want** to see today's plan and quick actions,  
**so that** I know what to do next.

**Acceptance criteria**

- [ ] Shows today's scheduled workout(s) from active program
- [ ] "Continue workout" if session in progress
- [ ] Quick start: recent routines + start blank workout
- [ ] This week summary: sessions completed, total training time (no streak counter)

**PRD refs:** §11 Home, §8 #6

---

### US-101 — Reorder and modify live workout

**As a** user mid-workout,  
**I want** to add, remove, or reorder exercises,  
**so that** my log matches what I actually did.

**Acceptance criteria**

- [ ] Add exercise from library during live workout
- [ ] Remove exercise from current session
- [ ] Reorder remaining exercises
- [ ] Changes reflect in Live Activity current exercise display
- [ ] Does not affect saved routine template unless user chooses "update routine"

**PRD refs:** RTN-04, LOG-01

---

## Epic 12: Settings & Profile

| ID | Priority | Phase |
|----|----------|-------|
| US-110 | P0 | 1 |
| US-111 | P1 | 2 |
| US-112 | P0 | 3 |

### US-110 — Training preferences

**As a** user,  
**I want** to configure units, rest defaults, and RIR,  
**so that** the app matches how I train.

**Acceptance criteria**

- [ ] Settings: weight unit (kg/lb), default rest timer, RIR toggle (off default)
- [ ] Settings: Live Activity / Lock Screen workout controls toggle
- [ ] Settings: rest-end notification toggle
- [ ] Changes apply to new sessions; active workout uses values at start

**PRD refs:** §11 Profile, US-031

---

### US-111 — Manage subscription

**As a** user,  
**I want** to view and manage my DailyFitness Pro subscription,  
**so that** I know what I have access to.

**Acceptance criteria**

- [ ] Profile shows Free vs Pro status
- [ ] Upgrade flow with feature comparison
- [ ] 7-day free trial on first subscribe
- [ ] Manage/cancel subscription links to App Store subscription settings
- [ ] Restore purchases supported

**PRD refs:** §13 Monetization

---

### US-112 — Premium paywall at limits

**As a** free user hitting a limit,  
**I want** a clear upgrade prompt,  
**so that** I understand what Premium unlocks without feeling tricked.

**Acceptance criteria**

- [ ] Paywall triggers at: 6th routine/program, 3rd progression exercise in workout, 90+ day history chart, CSV export
- [ ] Paywall lists relevant Premium benefits only (not generic marketing wall)
- [ ] User can dismiss and continue with free tier limits
- [ ] No paywall blocks basic workout logging ever

**PRD refs:** §13 Free tier, PROG-06

---

## Epic 13: Launch & Quality

| ID | Priority | Phase |
|----|----------|-------|
| US-120 | P0 | 3 |
| US-121 | P1 | 3 |
| US-122 | P1 | 2 |

### US-120 — TestFlight beta

**As a** product team,  
**I want** a TestFlight build for beta testers,  
**so that** we validate gym-floor usability before App Store launch.

**Acceptance criteria**

- [ ] TestFlight build with core loop: onboarding → program → log workout → view history
- [ ] Crash-free sessions rate ≥99% in beta
- [ ] Feedback channel linked in Profile (email or form)
- [ ] Beta includes Live Activity on physical devices

**PRD refs:** §15 Phase 2–3

---

### US-121 — App Store launch assets

**As a** new App Store visitor,  
**I want** accurate screenshots and description,  
**so that** I understand DailyFitness before downloading.

**Acceptance criteria**

- [ ] Listing title: DailyFitness (subtitle per PRD ASO)
- [ ] Screenshots show strength, mobility, and yoga equally
- [ ] Diverse representation in marketing visuals (Calm Strength)
- [ ] Privacy policy and terms URLs live
- [ ] Sign in with Apple and subscription disclosures complete

**PRD refs:** §5 Mitigations, §15 Phase 3

---

### US-122 — Accessibility basics

**As a** user with accessibility needs,  
**I want** the app to work with VoiceOver and Dynamic Type,  
**so that** I can train independently.

**Acceptance criteria**

- [ ] VoiceOver labels on all interactive elements in live workout flow
- [ ] Dynamic Type supported without layout breakage on large text sizes
- [ ] Minimum touch target 44×44pt for set complete and primary actions
- [ ] Sufficient color contrast in Calm Strength palette (WCAG AA)

**PRD refs:** §6 Inclusive design

---

## Epic 14: v1.1 Backlog (P2)

| ID | Priority | Phase |
|----|----------|-------|
| US-200 | P2 | 1.1 |
| US-201 | P2 | 1.1 |
| US-202 | P2 | 1.1 |
| US-203 | P2 | 1.1 |
| US-204 | P2 | 1.1 |
| US-205 | P2 | 1.1 |

### US-200 — Exercise video demos

**As a** user learning form,  
**I want** video demos for common exercises,  
**so that** I perform movements safely.

**Acceptance criteria:** Top 200 exercises have inline video; falls back to photo if offline.

**PRD refs:** SH-01

---

### US-201 — HealthKit workout sync

**As a** user,  
**I want** workout duration synced to Apple Health,  
**so that** my activity rings reflect gym time.

**PRD refs:** SH-02

---

### US-202 — Plate calculator

**As a** user loading a barbell,  
**I want** a plate calculator for my target weight,  
**so that** I don't do mental math between sets.

**PRD refs:** SH-03

---

### US-203 — Home Screen widgets

**As a** user,  
**I want** a widget showing this week's training summary,  
**so that** I see progress without opening the app.

**Acceptance criteria:** No streak guilt; shows sessions completed and next scheduled workout.

**PRD refs:** SH-04

---

### US-204 — Multi-week periodization

**As a** Premium user,  
**I want** deload weeks in custom programs,  
**so that** my plan includes planned recovery.

**PRD refs:** SH-05, §13 Premium

---

### US-205 — Progress photos

**As a** user,  
**I want** private progress photos,  
**so that** I can track visual changes over time.

**PRD refs:** SH-06

---

## Epic 15: v2+ Backlog (P3)

| ID | Story (summary) |
|----|-----------------|
| US-300 | Apple Watch companion — log sets and rest timer from wrist |
| US-301 | Android app with shared backend |
| US-302 | Gym profiles (home vs commercial equipment) |
| US-303 | Dailybase sibling app integration |
| US-304 | Private coach/client sharing (not social feed) |

**PRD refs:** §9.4 Could-have

---

## Backlog summary

| Phase | Epics | Story count | P0 stories |
|-------|-------|-------------|------------|
| 0 — Foundation | 1–3 | 8 | 8 |
| 1 — Core logging | 5–7, 12 (partial) | 18 | 16 |
| 2 — Programs & progression | 4, 8–11 | 18 | 14 |
| 3 — Launch | 12, 13 | 5 | 2 |
| 1.1 | 14 | 6 | 0 |
| 2+ | 15 | 5 | 0 |
| **Total** | | **60** | **40** |

---

## Suggested sprint mapping

| Sprint | Focus | Key stories |
|--------|-------|-------------|
| 1 | Foundation | US-001, US-002, US-003, US-020, US-010 |
| 2 | Library + routines | US-021, US-022, US-023, US-040, US-041 |
| 3 | Live workout core | US-050, US-051, US-052, US-053, US-054, US-055 |
| 4 | Lock Screen + offline | US-060, US-061, US-062, US-063, US-011, US-110 |
| 5 | Programs | US-070, US-071, US-072, US-073, US-100 |
| 6 | Progression + progress | US-080, US-081, US-082, US-083, US-090, US-091 |
| 7 | Analytics + onboarding | US-092, US-093, US-030, US-031, US-101 |
| 8 | Premium + beta | US-111, US-112, US-012, US-120, US-122 |
| 9 | Launch | US-121, bug burn-down, App Store submit |

---

## Document history

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-06-27 | Initial backlog from PRD v0.3 |
