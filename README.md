# DailyFitness

A Dailybase-family iOS workout app — track strength, mobility, yoga, and flexibility with smart progression and Lock Screen workout controls.

**Status:** Phases 0.5–6 implemented  
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

## What's implemented

- Calm Strength design system + tab shell
- SwiftData models (exercises, routines, programs, workouts, PRs, progression)
- Onboarding + live workout logging (strength, mobility, yoga, flexibility)
- Exercise picker (search, filters) + custom exercise creation
- Routine builder + program templates with Home schedule card
- Progression engine wired to live workout UI
- PR detection + Progress tab (history, charts, muscle heatmap, PR shelf)
- Live Activity extension (embedded) + App Intents scaffold
- Versioned exercise/program seeders + `scripts/import-exercises.py`
- Sign in with Apple + Supabase sync (session/routine upsert)
- RevenueCat paywall + content limits + CSV export (Pro)
- Supabase migrations including personal records

## Setup notes

- Set **Development Team** in Xcode for DailyFitness and WorkoutLiveActivityExtension
- Add real keys to `Config/Secrets.xcconfig` for Supabase + RevenueCat
- Run `python3 scripts/import-exercises.py` to expand the exercise library
- Live Activities: run from Xcode (⌘R) with Live Activities enabled
