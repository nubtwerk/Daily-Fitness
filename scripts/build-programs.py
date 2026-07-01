#!/usr/bin/env python3
"""Author Resources/Programs/programs.json — the PRD §9.2 suggested catalog.

Deterministic: program/day ids are stable uuid5 values so regenerating never
changes them. Day `routineName`s are validated against the routine names seeded by
RoutineSeeder.swift (ROUTINES below). Weekday numbers follow Calendar.weekday
(1=Sunday … 7=Saturday), matching ProgramScheduleResolver.

Run:  python3 scripts/build-programs.py
"""

from __future__ import annotations

import json
import uuid
from pathlib import Path

NS = uuid.NAMESPACE_DNS

# Routine names seeded by RoutineSeeder.swift — programs may only reference these.
ROUTINES = {
    "Full Body A", "Full Body B", "Upper Body A", "Lower Body A", "Upper Body B",
    "Lower Body B", "Push Day", "Pull Day", "Leg Day", "Beginner Full Body A",
    "Beginner Full Body B", "Daily Mobility Flow", "Post-Lift Stretch",
    "Hip & Ankle Opener", "Shoulder Recovery", "Morning Yoga Flow", "Recovery Yoga",
}

MON, TUE, WED, THU, FRI, SAT, SUN = 2, 3, 4, 5, 6, 7, 1


def pid(slug):
    return str(uuid.uuid5(NS, f"dailyfitness.program.{slug}"))


def did(slug, i):
    return str(uuid.uuid5(NS, f"dailyfitness.programday.{slug}.{i}"))


# (slug, name, category, level, weeks, daysPerWeek, equipment, description,
#  [(weekday, routineName)])
PROGRAMS = [
    ("upper-lower", "Upper / Lower Split", "strength", "intermediate", None, 4,
     ["barbell", "dumbbell", "cable", "machine"],
     "A classic 4-day split alternating upper- and lower-body sessions for balanced strength and hypertrophy.",
     [(MON, "Upper Body A"), (TUE, "Lower Body A"), (THU, "Upper Body B"), (FRI, "Lower Body B")]),

    ("ppl", "Push / Pull / Legs", "strength", "intermediate", None, 3,
     ["barbell", "dumbbell", "cable", "machine", "pull_up_bar"],
     "Organise training by movement pattern — push, pull, and legs. Run it 3 or 6 days a week.",
     [(MON, "Push Day"), (WED, "Pull Day"), (FRI, "Leg Day")]),

    ("full-body-3x", "Full Body 3×", "strength", "intermediate", None, 3,
     ["barbell", "cable", "pull_up_bar"],
     "Hit every major muscle group three times a week. Efficient and great for busy schedules.",
     [(MON, "Full Body A"), (WED, "Full Body B"), (FRI, "Full Body A")]),

    ("beginner-strength", "Beginner Strength Foundation", "strength", "beginner_intermediate", 8, 3,
     ["barbell", "machine", "cable"],
     "An 8-week on-ramp to the main barbell lifts with simple full-body sessions and steady progression.",
     [(MON, "Beginner Full Body A"), (WED, "Beginner Full Body B"), (FRI, "Beginner Full Body A")]),

    ("daily-mobility-10", "Daily Mobility 10", "mobility", "all", None, 7,
     ["bodyweight", "mat"],
     "A 10-minute daily flow to keep your hips, spine, and ankles moving well. Do it any day.",
     [(d, "Daily Mobility Flow") for d in (SUN, MON, TUE, WED, THU, FRI, SAT)]),

    ("post-lift-stretch", "Post-Lift Stretch Routine", "flexibility", "all", None, 3,
     ["bodyweight", "mat"],
     "Wind down after training with targeted static stretches for the muscles you just worked.",
     [(TUE, "Post-Lift Stretch"), (THU, "Post-Lift Stretch"), (SAT, "Post-Lift Stretch")]),

    ("hip-ankle-opener", "Hip & Ankle Opener", "mobility", "all", 4, 3,
     ["bodyweight", "mat", "bands"],
     "A 4-week plan to build hip and ankle range of motion for deeper, stronger squats.",
     [(MON, "Hip & Ankle Opener"), (WED, "Hip & Ankle Opener"), (FRI, "Hip & Ankle Opener")]),

    ("shoulder-recovery", "Shoulder Recovery Flow", "flexibility", "all", 4, 2,
     ["bodyweight", "bands"],
     "Restore healthy shoulder mobility and posture with gentle CARs, slides, and stretches.",
     [(TUE, "Shoulder Recovery"), (SAT, "Shoulder Recovery")]),

    ("morning-flow-20", "Morning Flow 20", "yoga", "beginner", None, 3,
     ["mat"],
     "Start the day with a gentle 20-minute yoga flow to wake up the body and mind.",
     [(MON, "Morning Yoga Flow"), (WED, "Morning Yoga Flow"), (FRI, "Morning Yoga Flow")]),

    ("recovery-yoga", "Recovery Yoga", "yoga", "all", None, 2,
     ["mat", "block"],
     "Slow, restorative yoga to aid recovery on rest days and ease tight muscles.",
     [(WED, "Recovery Yoga"), (SUN, "Recovery Yoga")]),

    ("strength-yoga-hybrid", "Strength + Yoga Hybrid", "hybrid", "intermediate", 6, 4,
     ["barbell", "dumbbell", "cable", "mat"],
     "A 6-week hybrid blending strength training with yoga flows for power and suppleness.",
     [(MON, "Upper Body A"), (TUE, "Morning Yoga Flow"), (THU, "Lower Body A"), (SAT, "Recovery Yoga")]),
]

# Reuse the three legacy program ids so upgraded installs don't get duplicates.
LEGACY = {
    "full-body-3x": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1",
    "daily-mobility-10": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2",
    "beginner-strength": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3",
}


def main():
    programs = []
    for slug, name, category, level, weeks, dpw, equipment, desc, days in PROGRAMS:
        for _, routine in days:
            assert routine in ROUTINES, f"unknown routine {routine!r} in {name}"
        day_items = []
        for i, (weekday, routine) in enumerate(days):
            day_items.append({
                "id": did(slug, i), "weekIndex": 0, "dayOfWeek": weekday,
                "routineName": routine, "sortOrder": i,
            })
        program = {
            "id": LEGACY.get(slug, pid(slug)),
            "name": name,
            "category": category,
            "level": level,
            "weeks": weeks,
            "daysPerWeek": dpw,
            "equipment": equipment,
            "description": desc,
            "days": day_items,
        }
        programs.append(program)

    out = Path(__file__).resolve().parents[1] / "DailyFitness" / "Resources" / "Programs" / "programs.json"
    out.write_text(json.dumps({"programs": programs}, indent=2) + "\n")
    cats = {}
    for p in programs:
        cats[p["category"]] = cats.get(p["category"], 0) + 1
    print(f"Wrote {len(programs)} programs to {out}")
    print(f"  by category: {cats}")


if __name__ == "__main__":
    main()
