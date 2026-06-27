# DailyFitness — Product Requirements Document

**Version:** 0.3 (Draft)  
**Last updated:** June 27, 2026  
**Status:** In review  
**Parent brand:** Dailybase  
**Visual identity:** Calm Strength  
**Repository:** `/Users/jharaldsen/Projects/dailyfitness`

---

## 1. Executive Summary

**DailyFitness** is a Dailybase-family iOS workout app for intermediate trainees who lift, stretch, and move consistently. It combines **MacroFactor-style smart progression** for strength work with **Hevy/Lyfta-grade logging speed**, plus **guided programs** across strength, mobility, yoga, and flexibility — not just barbell sessions.

Users can follow **suggested programs** (curated splits, yoga flows, mobility routines) or build **fully custom programs** from a large exercise library. During a workout, **Lock Screen Live Activities** show the rest timer and let users tick off sets without unlocking the phone.

**Positioning:** *Your daily training — strength, mobility, and yoga in one calm app.*

**Business model:** Freemium. Core logging, programs, and basic progress are free. Premium unlocks full progression, advanced analytics, and export.

**Explicitly not in scope:** AI coaching, social/community, nutrition tracking.

---

## 2. Problem Statement

### User pain

| Pain | Evidence from market |
|------|---------------------|
| Logging breaks flow between sets | Users abandon apps that require unlocking and navigating mid-set |
| Strength apps ignore mobility/yoga | Lifters use 2–3 apps for gym + stretching + yoga |
| Static programs don't adapt | Fixed templates stall when performance or schedule varies |
| Smart apps feel prescriptive | MacroFactor excels at progression but limits custom program freedom |
| Trackers don't coach progression | Hevy/Lyfta excel at logging but progression is manual |
| Bro-gym branding alienates half the market | Many fitness apps feel male-coded; women report switching apps for tone and inclusivity |

### Opportunity

No Dailybase-aligned iOS app combines **fast logging + lock-screen control**, **adaptive strength progression**, **suggested + custom programs**, and **mobility/yoga/flexibility** in one inclusive, social-free experience.

---

## 3. Goals & Success Metrics

### North star

**Weekly active loggers who complete ≥3 sessions/week** — strength, mobility, or yoga counts equally.

### v1 launch targets (90 days post-launch)

| Metric | Target |
|--------|--------|
| D7 retention (signed-up users) | ≥35% |
| Median time to log one set | ≤3 seconds |
| Sessions completed / WAU | ≥2.5 |
| Free → Premium conversion (30d) | ≥4% |
| App Store rating | ≥4.6 |
| Lock Screen Live Activity adoption | ≥60% of active lifters enable it |

### Non-goals for v1

- Android, Web, or Wear OS
- Apple Watch companion (v2+)
- Social feed, follows, leaderboards, or public profiles
- Nutrition / macro tracking
- AI chat coach or AI program generation
- Coach/client multi-tenant accounts
- Strava / HealthKit export (v1.1 candidate)

---

## 4. Target Users

### Primary persona: **Jordan — The Structured Mover**

- **Age:** 26–38  
- **Experience:** 1–5 years consistent training (gym + occasional yoga/mobility)  
- **Behavior:** Runs upper/lower or PPL, tracks main lifts, does recovery work 1–2×/week  
- **Goals:** Progressive overload, stay mobile, train without app-hopping  
- **Frustrations:** Hevy feels manual for progression; yoga apps don't track strength; mobility is an afterthought  
- **Quote:** *"I want one app for my lifting and my stretching — and I don't want to unlock my phone every rest period."*

### Secondary persona: **Alex — The Consistency-First Trainer**

- Trains 3–4×/week mix of strength + yoga/mobility  
- Values calm UX and inclusive design over gym-bro aesthetics  
- May not track RIR; wants simple rep/weight logging with optional depth  

### Out of scope v1

- Complete beginners needing form-first video courses  
- Competitive powerlifters needing meet prep tooling  
- Personal trainers managing client rosters  

---

## 5. Naming & Dailybase Family

### Chosen name: **DailyFitness**

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| **DailyFitness** | Broadest scope; covers strength, yoga, mobility equally; clear Dailybase lineage | Generic keyword; crowded App Store; trademark search needed | **Chosen** |
| DailyLifts | Distinctive for lifters | Underplays yoga/mobility positioning | Not selected |
| DailyReps | Neutral | Gym-coded; less memorable | Not selected |
| DailyMotion | Dailybase rhyme | **Trademark conflict** with Dailymotion | **Do not use** |

**Why DailyFitness works for this product:** The app is intentionally multi-modal (strength + yoga + mobility + flexibility). A lift-specific name would undersell half the catalog. Paired with the **Calm Strength** visual identity and **Dailybase** parent brand, the generic name becomes an asset — Dailybase owns the personality; DailyFitness owns the category.

**Mitigations for genericness:**

- App Store listing: **"DailyFitness by Dailybase"**  
- Distinct app icon (Calm Strength palette — not a dumbbell clip-art)  
- Strong subtitle: *Track workouts. Build programs. Move daily.*  
- Run trademark + App Store name availability check before finalizing bundle ID  

### Brand architecture

```
Dailybase          ← parent brand (habit, daily practice, calm consistency)
└── DailyFitness   ← this app (training tracker + programs)
    └── Visual: Calm Strength
    └── Tagline: "Your daily training — tracked."
```

---

## 6. Branding & Visual Identity

### Brand personality

| Attribute | Is | Is not |
|-----------|-----|--------|
| Tone | Calm, capable, welcoming | Aggressive, bro-culture, punitive |
| Energy | Steady daily practice | "Beast mode", guilt/streak shaming |
| Audience | Everyone who trains | Male-only lifters |
| Feel | Apple Health meets calm studio | Hardcore gym poster |

**One-line brand promise:** *Training that fits your day — not your gender.*

### Gender-inclusive design principles

1. **Neutral-first UI** — No default avatar gendering; avoid "guys/girls" copy; use "you/your" and "trainee/athlete" sparingly if at all.  
2. **Diverse representation** — Marketing and in-app photography: mixed bodies, ages, and presentation; strength and yoga shown equally.  
3. **Avoid clichés** — No pink-for-women programs; no hyper-masculine dark-red "PR or die" palette.  
4. **Program naming** — "Lower Body Strength", "Morning Mobility", "Hip Opener Flow" — not "Booty Burn" or "Arm Day for Bros".  
5. **Iconography** — Abstract movement marks ( arcs, balance, flow lines ) over flexed biceps or barbell-only marks.

### Visual direction — **Calm Strength** (chosen)

- **Palette:** Warm stone neutrals (`#F5F2ED` background), deep forest or slate primary (`#2D4A3E` / `#3D4F5F`), single accent in muted terracotta or sage (`#C4785A` / `#7A9E8E`) — works on light and dark mode  
- **Typography:** SF Pro; medium weight headings, generous line height for readability  
- **Imagery:** Soft natural light, real environments (home, studio, gym), motion blur over posed flex shots  
- **Motion:** Gentle springs; rest timer uses smooth countdown, not urgent flashing red  
- **App icon:** Abstract flow/balance mark — not a barbell or yoga silhouette alone  
- **Dailybase tie-in:** Shared wordmark treatment ("Daily" prefix); Calm Strength palette may extend to Dailybase sibling apps over time  

### Content categories (equal visual weight)

Programs and library are organized by **training type**, not gender:

| Category | Examples | Logging model |
|----------|----------|---------------|
| **Strength** | PPL, Upper/Lower, Full Body | Weight × reps, progression engine |
| **Mobility** | Hip flow, shoulder prep, desk reset | Duration, reps, or hold time |
| **Flexibility / Stretching** | Post-workout stretch, split progression | Hold duration, side L/R |
| **Yoga** | Vinyasa foundations, recovery yoga | Duration, flow completion, optional notes |

Same app chrome, same completion UX — category affects exercise fields and whether progression engine applies.

---

## 7. Competitive Landscape

| Capability | Hevy | Lyfta | MacroFactor Workouts | **DailyFitness (target)** |
|------------|------|-------|----------------------|-------------------------|
| Fast set logging | Strong | Strong | Good | **Best-in-class** |
| Lock Screen workout control | Limited | Limited | Unknown | **Live Activity (P0)** |
| Suggested + custom programs | Templates | Strong programs | Generated + custom | **Both (P0)** |
| Exercise library | 400+ | 5000+ | Hundreds | **2000+ launch target** |
| Mobility / yoga programs | Minimal | Minimal | Minimal | **Core differentiator** |
| Smart auto-progression | Limited | Limited | **Core** | **Core (strength only)** |
| RIR tracking | Optional | Optional | Core | **Optional (off by default)** |
| Social / community | Strong | Strong | None | **None — by design** |
| AI features | HevyGPT (2026) | — | — | **None (v1+)** |
| Gender-inclusive brand | Mixed | Mixed | Neutral | **Explicit design goal** |
| iOS | Yes | Yes | Yes | **v1 only** |

### Differentiation pillars

1. **Lock-screen-first workouts** — Complete sets and watch rest timer from Lock Screen / Dynamic Island.  
2. **Whole-body training hub** — Strength + mobility + yoga + stretching in one library and program system.  
3. **Suggested AND custom programs** — Curated paths for people who want guidance; full builder for people who don't.  
4. **Adaptive progression (strength)** — Evidence-based load/rep recommendations when users opt in.  
5. **Inclusive Dailybase aesthetic** — Calm, gender-neutral, daily-habit positioning.

---

## 8. Product Principles

1. **Gym-first** — One-handed, between-sets usability; Lock Screen reduces unlock friction.  
2. **Log now, analyze later** — Never block logging for sync or analytics.  
3. **Same app, many modalities** — Strength, yoga, and mobility share one logging UX with modality-aware fields.  
4. **Guidance without gatekeeping** — Suggested programs are starting points; everything is editable.  
5. **Progressive disclosure** — RIR, RPE, advanced set types off by default; enable in Settings.  
6. **No social pressure** — No feed, no comparison, no streak guilt copy.  
7. **Offline by default** — Full sessions work without network.

---

## 9. Feature Requirements

### 9.1 Must-have (MVP — v1.0)

#### A. Workout logging (P0)

| ID | Requirement | Acceptance criteria |
|----|-------------|---------------------|
| LOG-01 | Start workout from program, routine, or blank | ≤2 taps from Home |
| LOG-02 | Log strength sets (weight + reps) | Pre-filled from last session |
| LOG-03 | Log mobility/yoga (duration, holds, reps) | Field types match exercise category |
| LOG-04 | Mark set / interval complete | Haptic + check; advance to next |
| LOG-05 | Rest timer | Auto-start on strength set complete; configurable 30–300s |
| LOG-06 | Previous performance visible | "Last time: 80kg × 8" or "Last: 45s hold" |
| LOG-07 | Set types (strength) | Normal, warmup, failure, drop set |
| LOG-08 | Supersets | Pair 2–4 exercises |
| LOG-09 | Exercise & workout notes | Persist across sessions |
| LOG-10 | End & save workout | Summary: duration, volume/duration, PRs |
| LOG-11 | Offline logging | Local save; sync on reconnect |

#### B. Lock Screen & Live Activities (P0)

| ID | Requirement | Acceptance criteria |
|----|-------------|---------------------|
| LOCK-01 | Live Activity during active workout | Shows on Lock Screen + Dynamic Island (supported devices) |
| LOCK-02 | Rest timer on Lock Screen | Countdown visible without opening app |
| LOCK-03 | Complete set from Lock Screen | Tap action marks current set done; advances workout state |
| LOCK-04 | Current exercise display | Exercise name + set progress (e.g. "Set 2 of 4") |
| LOCK-05 | End workout from Live Activity | End action with confirmation |
| LOCK-06 | Fallback | If Live Activities disabled, in-app timer + notification at rest end |

*Implementation: ActivityKit + WidgetKit; interactive buttons where iOS version supports.*

#### C. Programs — suggested & custom (P0)

| ID | Requirement | Acceptance criteria |
|----|-------------|---------------------|
| PRG-01 | Suggested program catalog | Browse by goal: Strength, Mobility, Yoga, Flexibility, Hybrid |
| PRG-02 | Program detail | Duration (weeks), days/week, equipment, description |
| PRG-03 | Start suggested program | Adds scheduled workouts to user's plan |
| PRG-04 | Custom program builder | Name, weeks, assign workouts/routines per day |
| PRG-05 | Custom routine builder | Exercises, sets/reps/duration, order, rest |
| PRG-06 | Fork suggested → custom | "Duplicate & edit" any suggested program |
| PRG-07 | Launch suggested programs | See §9.4 Program catalog (v1) |

#### D. Exercise library (P0)

| ID | Requirement | Acceptance criteria |
|----|-------------|---------------------|
| LIB-01 | Large seeded library | **≥2,000 exercises** at launch |
| LIB-02 | Categories | Strength, mobility, flexibility, yoga, cardio (duration-only) |
| LIB-03 | Search & filter | Name, muscle, equipment, category |
| LIB-04 | Custom exercises | User-created with category-appropriate fields |
| LIB-05 | Media | Illustration or photo per exercise; video deferred to v1.1 |
| LIB-06 | Muscle & equipment tags | Consistent taxonomy for analytics |

*Source strategy: license open dataset (e.g. ExerciseDB) + manual curation for yoga/mobility gaps.*

#### E. Smart progression — strength only (P0, Premium)

| ID | Requirement | Acceptance criteria |
|----|-------------|---------------------|
| PROG-01 | Performance-based recommendations | Next-session targets from logged working sets |
| PROG-02 | RIR-aware progression | **Only when user enables RIR in Settings** |
| PROG-03 | Progression explanation | Plain-language reason shown in UI |
| PROG-04 | Deload suggestion | After repeated failed progressions |
| PROG-05 | Per-exercise toggle | Disable auto for specific lifts |
| PROG-06 | Free tier preview | 2 exercises per workout; full unlock = Premium |
| PROG-07 | Scope | Does not auto-progress yoga/mobility holds (manual progression only v1) |

#### F. Progress & analytics (P0)

| ID | Requirement | Free | Premium |
|----|-------------|------|---------|
| AN-01 | Workout history | ✓ | ✓ |
| AN-02 | Exercise history | 90 days | All time |
| AN-03 | Personal records (strength) | ✓ | ✓ |
| AN-04 | Estimated 1RM | ✓ | ✓ |
| AN-05 | Volume per muscle group | 30-day | All time + trends |
| AN-06 | Session calendar | ✓ | ✓ |
| AN-07 | Mobility/yoga time tracked | ✓ | ✓ |

#### G. Account & data (P0)

| ID | Requirement | Acceptance criteria |
|----|-------------|---------------------|
| ACC-01 | Sign in with Apple | Required for cloud sync |
| ACC-02 | Cloud backup | Restore on new device |
| ACC-03 | Export CSV | Premium |

---

### 9.2 Suggested program catalog (v1 launch)

**Strength (suggested)**

| Program | Days/wk | Duration | Level |
|---------|---------|----------|-------|
| Upper / Lower Split | 4 | Ongoing | Intermediate |
| Push / Pull / Legs | 3–6 | Ongoing | Intermediate |
| Full Body 3× | 3 | Ongoing | Intermediate |
| Beginner Strength Foundation | 3 | 8 weeks | Beginner–Intermediate |

**Mobility & flexibility (suggested)**

| Program | Days/wk | Duration | Level |
|---------|---------|----------|-------|
| Daily Mobility 10 | 5–7 | Ongoing | All |
| Post-Lift Stretch Routine | 2–3 | Ongoing | All |
| Hip & Ankle Opener | 3 | 4 weeks | All |
| Shoulder Recovery Flow | 2 | 4 weeks | All |

**Yoga (suggested)**

| Program | Days/wk | Duration | Level |
|---------|---------|----------|-------|
| Morning Flow 20 | 3–5 | Ongoing | Beginner |
| Recovery Yoga | 2 | Ongoing | All |
| Strength + Yoga Hybrid | 4 | 6 weeks | Intermediate |

All suggested programs are **fully editable** after import.

---

### 9.3 Should-have (v1.1 — within 8 weeks of launch)

| ID | Feature | Notes |
|----|---------|-------|
| SH-01 | Exercise video demos | Top 200 exercises first |
| SH-02 | HealthKit integration | Workout minutes → Apple Health |
| SH-03 | Plate calculator | Bar + plates from target weight |
| SH-04 | Home Screen widgets | Next workout, streak-free "this week" summary |
| SH-05 | Multi-week periodization | Deload weeks in custom programs |
| SH-06 | Progress photos | Private, local-first option |

---

### 9.4 Could-have (v2+)

- Apple Watch companion  
- Android app  
- Gym profiles (home vs commercial equipment)  
- Integration with Dailybase sibling apps (if any)  
- Coach mode + client sharing (private, not social feed)  

---

## 10. User Flows

### 10.1 Strength workout with Lock Screen

```
Home → "Upper A" → Start workout
  → Log bench 80×8 → Complete set
  → Live Activity: rest 90s countdown on Lock Screen
  → Tap "Complete" on Lock Screen for next set without unlocking
  → Finish → Summary
```

### 10.2 Start a suggested mobility program

```
Programs → "Daily Mobility 10" → Start program
  → Day 1 assigned to Home → Start → Log holds/durations → Complete
```

### 10.3 Build custom hybrid program

```
Programs → Create custom → 4 weeks, 4 days/week
  → Mon: Upper Strength (routine) | Wed: Yoga Flow | Fri: Lower | Sun: Stretch
  → Save → Appears on Home schedule
```

### 10.4 Onboarding (≤90 seconds)

1. Welcome — Dailybase family, calm training  
2. What do you train? (multi-select: Strength / Mobility / Yoga / Stretching)  
3. Optional: pick one suggested program or skip  
4. Optional: enable Lock Screen workout controls  
5. Home — "Start first session"

---

## 11. Information Architecture

```
Tab bar (4 tabs)
├── Home
│   ├── Today's scheduled workout(s)
│   ├── Continue active workout
│   └── This week summary (no streak guilt)
├── Programs
│   ├── Suggested (catalog by category)
│   ├── My programs (custom + active suggested)
│   └── Create program / routine
├── Progress
│   ├── Calendar
│   ├── PRs & strength charts
│   ├── Mobility/yoga time
│   └── Muscle volume (Premium)
└── Profile
    ├── Settings (units, rest timer, RIR toggle OFF by default)
    ├── Lock Screen preferences
    ├── Subscription
    └── Export / Account
```

**Live workout** = full-screen modal. **Live Activity** mirrors state on Lock Screen.

---

## 12. Progression Engine — Logic Spec (v1)

*Applies to **strength** exercises only when progression is enabled.*

### Inputs per set

- Weight, reps, set type  
- **RIR (0–5): only if user enabled in Settings**  
- RPE (6–10): optional, v1.1

### Rules (simplified v1)

1. **Baseline:** User targets in routine or last completed working set.  
2. **Without RIR:** Hit top of rep range on all working sets → increase weight (2.5kg upper / 5kg lower default).  
3. **With RIR enabled:** Performance ≥ predicted max at target RIR → progress load or reps.  
4. **Hold / regress / missed session:** Same as v0.1 spec.  

### Transparency

Every recommendation includes a `reason` string for UI.

---

## 13. Monetization

### Free tier

- Unlimited workout logging (all modalities)  
- Up to 5 custom programs / routines  
- All suggested programs (v1 catalog)  
- Full exercise library access  
- 90-day history  
- Lock Screen Live Activities  
- 2 exercises per workout with progression preview  

### Premium — **DailyFitness Pro** (~$6.99/mo or $49.99/yr)

- Unlimited custom programs  
- Full smart progression (strength)  
- All-time history & advanced analytics  
- CSV export  
- Multi-week periodization (v1.1)  

### Trial

- 7-day Premium trial on first subscribe  

---

## 14. Technical Considerations

See **[TDD.md](./TDD.md)** for full architecture. Summary:

| Area | Decision |
|------|----------|
| Platform | Native iOS (SwiftUI), **iOS 17+** |
| Lock Screen | **ActivityKit** Live Activities + App Intents |
| Local storage | **SwiftData**, offline-first |
| Backend | **Supabase** (Postgres + RLS + Auth) |
| Exercise data | Bulk import pipeline; 2000+ seed records |
| Subscriptions | StoreKit 2 + **RevenueCat** |
| Analytics | **TelemetryDeck** |

---

## 15. MVP Scope & Phases

### Phase 0 — Foundation (Weeks 1–2)

- Design system (Calm Strength + Dailybase alignment)  
- Data models (strength + duration/hold exercises)  
- Exercise library import (2000+ seed)  
- Auth (Sign in with Apple)  

### Phase 1 — Core logging (Weeks 3–6)

- Routines & custom programs  
- Live workout flow + rest timer  
- **Live Activity / Lock Screen (parallel track)**  
- Offline save + sync  

### Phase 2 — Programs + progression (Weeks 7–9)

- Suggested program catalog  
- Progression engine v1 (strength)  
- PR detection + charts  
- Onboarding  
- TestFlight beta  

### Phase 3 — Launch (Weeks 10–12)

- StoreKit / Premium  
- App Store assets (inclusive marketing shots)  
- Soft launch  

---

## 16. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Live Activity iOS version fragmentation | Some users miss Lock Screen UX | Graceful in-app fallback + notification |
| 2000+ exercise QA burden | Bad metadata | Automated validation + spot-check top 500 |
| Generic name gets lost in App Store search | Discovery | "By Dailybase" branding; ASO on specific features; strong icon |
| Lift-heavy brand scares yoga users | Split audience | Equal catalog prominence; Calm Strength creative |
| Progression wrong for casual yogis | Confusion | Progression only on strength; clear scope |
| DailyFitness trademark conflict | Rebrand cost | Run USPTO + App Store name check in Phase 0 |

---

## 17. Open Questions

| # | Question | Status |
|---|----------|--------|
| 1 | App name | **Decided: DailyFitness** |
| 2 | Branding direction | **Decided: Calm Strength** |
| 3 | RIR default | **Decided: optional, off by default** |
| 4 | Apple Watch | **Decided: v2+** |
| 5 | Repository | **Decided: `dailyfitness`** |
| 6 | Metric vs imperial default from locale? | TBD Phase 0 |
| 7 | Supabase vs Firebase? | **Decided: Supabase** — see [TDD.md](./TDD.md) |
| 8 | DailyFitness trademark / App Store name availability? | TBD Phase 0 |

---

## 18. Appendix

### A. Glossary

- **RIR** — Reps in Reserve (optional advanced input)  
- **Live Activity** — iOS Lock Screen / Dynamic Island persistent workout UI  
- **Suggested program** — Curated, editable template from catalog  
- **Custom program** — User-built multi-week schedule  
- **Routine** — Single reusable workout template  

### B. Reference apps

- [Hevy](https://www.hevyapp.com/) — logging UX (not social for us)  
- [Lyfta](https://www.lyfta.app/) — programs, large library  
- [MacroFactor Workouts](https://macrofactor.com/workouts/) — progression model (not AI for us)  

### C. Document history

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-06-27 | Initial draft (Repforge) |
| 0.2 | 2026-06-27 | Dailybase naming, branding, Lock Screen, programs, mobility/yoga, library scale, decisions |
| 0.3 | 2026-06-27 | **DailyFitness** name locked; **Calm Strength** branding; repo renamed |

---

*Next step: Brand Guidelines one-pager, then Phase 0 scaffold.*

**Technical design:** [TDD.md](./TDD.md)  
**User stories:** [USER_STORIES.md](./USER_STORIES.md) — 60 stories across 15 epics, 40 P0 for MVP.
