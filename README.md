# DailyFitness

A Dailybase-family iOS workout app — track strength, mobility, yoga, and flexibility with smart progression and Lock Screen workout controls.

**Status:** Phase 0 scaffold  
**Brand:** Calm Strength  
**Docs:** [PRD](docs/PRD.md) · [User Stories](docs/USER_STORIES.md) · [Technical Design](docs/TDD.md) · [Technical Design](docs/TDD.md)

## Requirements

- Xcode 16+ with iOS 17 SDK
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Setup

```bash
cd ~/Projects/dailyfitness

# 1. Configure secrets
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
# Edit Config/Secrets.xcconfig with Supabase + RevenueCat keys

# 2. Generate Xcode project
xcodegen generate

# 3. Open in Xcode
open DailyFitness.xcodeproj
```

Set your **Development Team** in Xcode for the DailyFitness and WorkoutLiveActivityExtension targets.

## Project structure

```
DailyFitness/                 # Main app (SwiftUI + SwiftData)
WorkoutLiveActivityExtension/ # Lock Screen Live Activity
DailyFitnessTests/            # Unit tests (progression engine, PRs)
supabase/migrations/          # Postgres schema + RLS
scripts/                      # Exercise import tooling
```

## Run in Simulator (from Cursor terminal)

Requires **Xcode.app** installed (not just Command Line Tools):

```bash
./scripts/run-simulator.sh "iPhone 17"
```

This builds, opens **Simulator.app**, installs, and launches DailyFitness.

Or open `DailyFitness.xcodeproj` in Xcode and press **⌘R** (recommended for Live Activity extension testing).

```bash
xcodebuild test \
  -scheme DailyFitness \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Supabase

```bash
cd supabase
supabase link --project-ref YOUR_REF
supabase db push
```

## What's implemented (Phase 0)

- Calm Strength design system + tab shell
- SwiftData models (exercises, routines, programs, workouts)
- Onboarding flow
- Live workout logging (weight × reps, rest timer, set complete)
- Live Activity manager (Lock Screen extension scaffold)
- Progression engine + unit tests
- 10-exercise seed JSON + import script placeholder
- Initial Supabase migration

## Phase 1A (in progress)

- Exercise picker (search + category filter)
- Routine builder (add exercises, sets/reps/rest, reorder, edit)
- Add exercises during live blank workouts

## Next (Phase 1)

- Custom exercise creation
- Supabase auth + SyncEngine
- Live Activity interactive complete-set intents
- Expand exercise library to 2000+
