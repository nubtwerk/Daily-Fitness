#!/usr/bin/env python3
"""Normalize external exercise data into DailyFitness seed JSON."""

import json
import sys
import uuid
from pathlib import Path

CATEGORY_LOGGING = {
    "strength": "weightReps",
    "mobility": "duration",
    "flexibility": "hold",
    "yoga": "duration",
    "cardio": "duration",
}

BASE_EXERCISES = [
    ("Barbell Bench Press", "strength", ["chest", "triceps"], ["barbell", "bench"]),
    ("Barbell Back Squat", "strength", ["quads", "glutes"], ["barbell", "rack"]),
    ("Romanian Deadlift", "strength", ["hamstrings", "glutes"], ["barbell"]),
    ("Overhead Press", "strength", ["shoulders", "triceps"], ["barbell"]),
    ("Barbell Row", "strength", ["back", "biceps"], ["barbell"]),
    ("Pull-Up", "strength", ["back", "biceps"], ["pull-up bar"]),
    ("Chin-Up", "strength", ["back", "biceps"], ["pull-up bar"]),
    ("Dumbbell Lunges", "strength", ["quads", "glutes"], ["dumbbell"]),
    ("Lat Pulldown", "strength", ["back", "biceps"], ["cable"]),
    ("Leg Press", "strength", ["quads", "glutes"], ["machine"]),
    ("Cable Fly", "strength", ["chest"], ["cable"]),
    ("Incline Dumbbell Press", "strength", ["chest", "shoulders"], ["dumbbell", "bench"]),
    ("Dumbbell Shoulder Press", "strength", ["shoulders", "triceps"], ["dumbbell"]),
    ("Leg Curl", "strength", ["hamstrings"], ["machine"]),
    ("Leg Extension", "strength", ["quads"], ["machine"]),
    ("Calf Raise", "strength", ["calves"], ["machine"]),
    ("Tricep Pushdown", "strength", ["triceps"], ["cable"]),
    ("Bicep Curl", "strength", ["biceps"], ["dumbbell"]),
    ("Face Pull", "strength", ["shoulders", "back"], ["cable"]),
    ("Hip Thrust", "strength", ["glutes", "hamstrings"], ["barbell", "bench"]),
    ("90/90 Hip Switch", "mobility", ["hips"], ["bodyweight"]),
    ("World's Greatest Stretch", "mobility", ["hips", "thoracic"], ["bodyweight"]),
    ("Cat-Cow", "mobility", ["spine", "core"], ["bodyweight"]),
    ("Thoracic Rotation", "mobility", ["thoracic"], ["bodyweight"]),
    ("Ankle Mobilization", "mobility", ["calves", "ankles"], ["bodyweight"]),
    ("Standing Hamstring Stretch", "flexibility", ["hamstrings"], ["bodyweight"]),
    ("Pigeon Pose", "flexibility", ["hips"], ["bodyweight"]),
    ("Figure-Four Stretch", "flexibility", ["hips", "glutes"], ["bodyweight"]),
    ("Downward Dog", "yoga", ["shoulders", "hamstrings"], ["mat"]),
    ("Sun Salutation A", "yoga", ["full body"], ["mat"]),
    ("Child's Pose", "yoga", ["back", "hips"], ["bodyweight"]),
    ("Warrior II", "yoga", ["quads", "hips"], ["mat"]),
    ("Treadmill Run", "cardio", ["legs"], ["treadmill"]),
    ("Rowing Machine", "cardio", ["back", "legs"], ["machine"]),
    ("Assault Bike", "cardio", ["legs"], ["machine"]),
]

STRENGTH_VARIANTS = [
    ("Dumbbell", "dumbbell"),
    ("Cable", "cable"),
    ("Machine", "machine"),
    ("Kettlebell", "kettlebell"),
    ("Smith Machine", "smith machine"),
]

MUSCLE_GROUPS = [
    ("Chest Press", "strength", ["chest", "triceps"]),
    ("Row", "strength", ["back", "biceps"]),
    ("Raise", "strength", ["shoulders"]),
    ("Curl", "strength", ["biceps"]),
    ("Extension", "strength", ["triceps"]),
    ("Fly", "strength", ["chest"]),
    ("Pullover", "strength", ["back", "chest"]),
]


def stable_uuid(name: str) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, f"dailyfitness.exercise.{name.lower()}"))


def build_exercise(name, category, muscles, equipment):
    return {
        "id": stable_uuid(name),
        "name": name,
        "category": category,
        "primaryMuscles": muscles,
        "equipment": equipment,
        "imageURL": None,
        "loggingFields": CATEGORY_LOGGING[category],
    }


def dedupe_by_name(exercises):
    seen = set()
    unique = []
    for ex in exercises:
        key = ex["name"].strip().lower()
        if key in seen:
            continue
        seen.add(key)
        unique.append(ex)
    return unique


def generate_expanded_library():
    exercises = [build_exercise(n, c, m, e) for n, c, m, e in BASE_EXERCISES]

    for label, _category, muscles in MUSCLE_GROUPS:
        for equip_label, equip in STRENGTH_VARIANTS:
            name = f"{equip_label} {label}"
            exercises.append(build_exercise(name, "strength", list(muscles), [equip]))

    for i in range(1, 51):
        exercises.append(build_exercise(
            f"Mobility Drill {i}",
            "mobility",
            ["hips" if i % 2 else "thoracic"],
            ["bodyweight"],
        ))

    for i in range(1, 31):
        exercises.append(build_exercise(
            f"Yoga Flow Sequence {i}",
            "yoga",
            ["full body"],
            ["mat"],
        ))

    return dedupe_by_name(exercises)


def main():
    root = Path(__file__).resolve().parents[1]
    out_dir = root / "DailyFitness" / "Resources" / "Exercises"
    out_dir.mkdir(parents=True, exist_ok=True)

    input_path = Path(sys.argv[1]) if len(sys.argv) > 1 else None

    if input_path and input_path.exists():
        raw = json.loads(input_path.read_text())
        exercises = []
        for item in raw:
            category = item.get("category", "strength")
            exercises.append({
                "id": item.get("id") or stable_uuid(item["name"]),
                "name": item["name"],
                "category": category,
                "primaryMuscles": item.get("primaryMuscles") or item.get("targetMuscles") or [],
                "equipment": item.get("equipment") or [],
                "imageURL": item.get("imageURL"),
                "loggingFields": item.get("loggingFields") or CATEGORY_LOGGING.get(category, "weightReps"),
            })
        exercises = dedupe_by_name(exercises)
    else:
        exercises = generate_expanded_library()

    exercises.sort(key=lambda e: e["name"].lower())
    payload = {"exercises": exercises}
    (out_dir / "exercises.json").write_text(json.dumps(payload, indent=2) + "\n")

    manifest = {
        "version": max(3, len(exercises) // 50 + 1),
        "count": len(exercises),
        "generatedAt": "2026-06-28",
    }
    (out_dir / "exercises-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote {len(exercises)} exercises to {out_dir}")


if __name__ == "__main__":
    main()
