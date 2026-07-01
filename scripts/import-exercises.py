#!/usr/bin/env python3
"""Authoritative DailyFitness exercise-library build pipeline.

Produces Resources/Exercises/exercises.json (+ exercises-manifest.json) from three
sources, merged and de-duplicated by name (earlier sources win, so real imagery is
preferred):

  1. free-exercise-db  (scripts/data/free-exercise-db.json) — ~873 public-domain
     records (Unlicense) with real hosted illustration imagery. Covers strength,
     flexibility (stretching) and cardio.
  2. curated_exercises  (scripts/data/curated_exercises.json) — hand-curated yoga,
     mobility and flexibility movements the open dataset lacks. Optional.
  3. combinatorial expansion — a deterministic generator of realistic strength
     variants (movement x equipment x angle/grip/stance) so the library reaches the
     >=2,000-exercise target with sensible metadata.

Every emitted record carries a NON-NULL imageURL: a real CDN url for dataset
records, or a `placeholder:<category>` sentinel that the app renders as a
category illustration (see ExerciseImageView.swift).

All ids are stable uuid5(name) so regenerating never duplicates existing seeds.
The canonical muscle/equipment taxonomy below is mirrored in
DailyFitness/Domain/Models/Taxonomy.swift — keep the two in sync.

Usage:
    python3 scripts/import-exercises.py            # rebuild from bundled sources
    python3 scripts/import-exercises.py --stats    # rebuild and print a breakdown
"""

from __future__ import annotations

import argparse
import json
import uuid
from collections import Counter
from pathlib import Path

# --------------------------------------------------------------------------- #
# Canonical taxonomy  (mirror of Taxonomy.swift)
# --------------------------------------------------------------------------- #

# token -> display name
MUSCLES = {
    "chest": "Chest", "back": "Back", "lats": "Lats", "traps": "Traps",
    "lower_back": "Lower Back", "shoulders": "Shoulders", "biceps": "Biceps",
    "triceps": "Triceps", "forearms": "Forearms", "neck": "Neck", "core": "Core",
    "obliques": "Obliques", "glutes": "Glutes", "quads": "Quads",
    "hamstrings": "Hamstrings", "calves": "Calves", "adductors": "Adductors",
    "abductors": "Abductors", "hip_flexors": "Hip Flexors", "hips": "Hips",
    "spine": "Spine", "thoracic": "Thoracic", "ankles": "Ankles",
    "wrists": "Wrists", "full_body": "Full Body",
}

EQUIPMENT = {
    "barbell": "Barbell", "dumbbell": "Dumbbell", "kettlebell": "Kettlebell",
    "cable": "Cable", "machine": "Machine", "smith_machine": "Smith Machine",
    "bodyweight": "Bodyweight", "bands": "Bands", "ez_bar": "EZ Bar",
    "exercise_ball": "Exercise Ball", "medicine_ball": "Medicine Ball",
    "foam_roller": "Foam Roller", "pull_up_bar": "Pull-Up Bar", "bench": "Bench",
    "rack": "Rack", "mat": "Mat", "box": "Box", "trx": "TRX", "block": "Block",
    "strap": "Strap", "wall": "Wall", "chair": "Chair", "plate": "Plate",
    "other": "Other",
}

CATEGORIES = ["strength", "mobility", "flexibility", "yoga", "cardio"]

CATEGORY_LOGGING = {
    "strength": "weightReps",
    "mobility": "duration",
    "flexibility": "hold",
    "yoga": "duration",
    "cardio": "duration",
}

IMG_BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

# free-exercise-db vocab -> canonical
FEDB_CATEGORY = {
    "strength": "strength", "powerlifting": "strength", "strongman": "strength",
    "olympic weightlifting": "strength", "plyometrics": "strength",
    "cardio": "cardio", "stretching": "flexibility",
}
FEDB_MUSCLE = {
    "abdominals": "core", "abductors": "abductors", "adductors": "adductors",
    "biceps": "biceps", "calves": "calves", "chest": "chest",
    "forearms": "forearms", "glutes": "glutes", "hamstrings": "hamstrings",
    "lats": "lats", "lower back": "lower_back", "middle back": "back",
    "neck": "neck", "quadriceps": "quads", "shoulders": "shoulders",
    "traps": "traps", "triceps": "triceps",
}
FEDB_EQUIPMENT = {
    "body only": "bodyweight", "barbell": "barbell", "dumbbell": "dumbbell",
    "cable": "cable", "machine": "machine", "kettlebells": "kettlebell",
    "bands": "bands", "e-z curl bar": "ez_bar", "exercise ball": "exercise_ball",
    "medicine ball": "medicine_ball", "foam roll": "foam_roller", "other": "other",
}

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "scripts" / "data"
OUT_DIR = ROOT / "DailyFitness" / "Resources" / "Exercises"
NAMESPACE = uuid.NAMESPACE_DNS


def stable_uuid(name: str) -> str:
    return str(uuid.uuid5(NAMESPACE, f"dailyfitness.exercise.{name.strip().lower()}"))


def make(name, category, muscles, equipment, image_url):
    muscles = [m for m in dict.fromkeys(muscles) if m in MUSCLES]
    equipment = [e for e in dict.fromkeys(equipment) if e in EQUIPMENT] or ["other"]
    return {
        "id": stable_uuid(name),
        "name": name.strip(),
        "category": category,
        "primaryMuscles": muscles,
        "equipment": equipment,
        "imageURL": image_url,
        "loggingFields": CATEGORY_LOGGING[category],
    }


# --------------------------------------------------------------------------- #
# Source 1: free-exercise-db snapshot
# --------------------------------------------------------------------------- #

def load_free_exercise_db():
    path = DATA / "free-exercise-db.json"
    if not path.exists():
        return []
    raw = json.loads(path.read_text())
    out = []
    for item in raw:
        name = (item.get("name") or "").strip()
        if not name:
            continue
        category = FEDB_CATEGORY.get(item.get("category", "strength"), "strength")
        muscles = [FEDB_MUSCLE[m] for m in item.get("primaryMuscles", []) if m in FEDB_MUSCLE]
        if not muscles:
            muscles = [FEDB_MUSCLE[m] for m in item.get("secondaryMuscles", []) if m in FEDB_MUSCLE]
        equip = FEDB_EQUIPMENT.get(item.get("equipment"), "other")
        images = item.get("images") or []
        image_url = (IMG_BASE + images[0]) if images else f"placeholder:{category}"
        out.append(make(name, category, muscles or ["full_body"], [equip], image_url))
    return out


# --------------------------------------------------------------------------- #
# Source 2: curated yoga / mobility / flexibility
# --------------------------------------------------------------------------- #

def load_curated():
    path = DATA / "curated_exercises.json"
    if not path.exists():
        return []
    raw = json.loads(path.read_text())
    records = raw.get("records", raw) if isinstance(raw, dict) else raw
    out = []
    for item in records:
        name = (item.get("name") or "").strip()
        category = item.get("category", "yoga")
        if not name or category not in CATEGORIES:
            continue
        muscles = [m for m in item.get("primaryMuscles", []) if m in MUSCLES] or ["full_body"]
        equip = [e for e in item.get("equipment", []) if e in EQUIPMENT] or ["bodyweight"]
        out.append(make(name, category, muscles, equip, f"placeholder:{category}"))
    return out


# --------------------------------------------------------------------------- #
# Source 3: deterministic combinatorial strength expansion
# --------------------------------------------------------------------------- #
# Each template: base movement, muscles, allowed equipment, and angle/grip/stance
# modifiers that genuinely apply. The generator emits "{modifier} {equip} {base}"
# (omitting equip when `show_equip` is False) for realistic, distinct names.

E = {  # equipment -> label used in names
    "barbell": "Barbell", "dumbbell": "Dumbbell", "kettlebell": "Kettlebell",
    "cable": "Cable", "machine": "Machine", "smith_machine": "Smith Machine",
    "bodyweight": "", "bands": "Band", "ez_bar": "EZ-Bar", "trx": "TRX",
    "pull_up_bar": "", "plate": "Plate",
}

# (base, muscles, equipments, modifiers, show_equip)
TEMPLATES = [
    ("Bench Press", ["chest", "triceps", "shoulders"],
     ["barbell", "dumbbell", "smith_machine", "machine"],
     ["", "Flat", "Incline", "Decline", "Close-Grip", "Wide-Grip", "Paused"], True),
    ("Chest Fly", ["chest"],
     ["dumbbell", "cable", "machine"],
     ["", "Flat", "Incline", "Decline", "Low-to-High", "High-to-Low"], True),
    ("Chest Press", ["chest", "triceps"],
     ["machine", "cable"],
     ["", "Seated", "Incline", "Decline"], True),
    ("Push-Up", ["chest", "triceps", "core"],
     ["bodyweight", "trx"],
     ["", "Wide", "Close-Grip", "Decline", "Incline", "Archer", "Diamond"], False),
    ("Overhead Press", ["shoulders", "triceps"],
     ["barbell", "dumbbell", "smith_machine", "machine", "kettlebell"],
     ["", "Seated", "Standing", "Push"], True),
    ("Arnold Press", ["shoulders", "triceps"], ["dumbbell"], ["", "Seated", "Standing"], True),
    ("Lateral Raise", ["shoulders"],
     ["dumbbell", "cable", "machine", "bands"],
     ["", "Seated", "Standing", "Single-Arm", "Leaning"], True),
    ("Front Raise", ["shoulders"],
     ["dumbbell", "cable", "barbell", "plate"],
     ["", "Seated", "Standing", "Single-Arm"], True),
    ("Rear Delt Fly", ["shoulders", "traps"],
     ["dumbbell", "cable", "machine"],
     ["", "Bent-Over", "Seated", "Incline"], True),
    ("Upright Row", ["shoulders", "traps"],
     ["barbell", "dumbbell", "cable", "smith_machine"],
     ["", "Wide-Grip", "Close-Grip"], True),
    ("Shrug", ["traps"],
     ["barbell", "dumbbell", "cable", "smith_machine", "machine"],
     ["", "Behind-the-Back", "Single-Arm"], True),
    ("Face Pull", ["shoulders", "traps", "back"], ["cable", "bands"],
     ["", "Seated", "Half-Kneeling"], True),
    ("Bent-Over Row", ["back", "lats", "biceps"],
     ["barbell", "dumbbell", "smith_machine"],
     ["", "Underhand", "Pendlay"], True),
    ("Row", ["back", "lats", "biceps"],
     ["cable", "machine", "dumbbell"],
     ["Seated", "Single-Arm", "Chest-Supported", "Wide-Grip", "Close-Grip"], True),
    ("Lat Pulldown", ["lats", "back", "biceps"],
     ["cable", "machine"],
     ["", "Wide-Grip", "Close-Grip", "Reverse-Grip", "Neutral-Grip", "Single-Arm"], False),
    ("Pull-Up", ["lats", "back", "biceps"], ["pull_up_bar"],
     ["", "Wide-Grip", "Close-Grip", "Neutral-Grip", "Weighted", "Commando"], False),
    ("Chin-Up", ["lats", "back", "biceps"], ["pull_up_bar"], ["", "Weighted", "Close-Grip"], False),
    ("Pullover", ["lats", "chest"], ["dumbbell", "cable", "barbell"], ["", "Flat", "Incline"], True),
    ("Back Squat", ["quads", "glutes"], ["barbell", "smith_machine"], ["", "Paused", "Box", "High-Bar", "Low-Bar"], True),
    ("Front Squat", ["quads", "glutes"], ["barbell", "smith_machine", "kettlebell"], ["", "Paused"], True),
    ("Goblet Squat", ["quads", "glutes"], ["dumbbell", "kettlebell"], ["", "Paused", "Tempo"], True),
    ("Split Squat", ["quads", "glutes"], ["bodyweight", "dumbbell", "barbell", "kettlebell", "smith_machine"], ["Bulgarian", "Rear-Foot-Elevated", ""], True),
    ("Hack Squat", ["quads", "glutes"], ["machine"], ["", "Reverse"], True),
    ("Leg Press", ["quads", "glutes"], ["machine"], ["", "Wide-Stance", "Narrow-Stance", "Single-Leg", "High-Foot"], False),
    ("Leg Extension", ["quads"], ["machine"], ["", "Single-Leg", "Seated"], False),
    ("Lunge", ["quads", "glutes"], ["bodyweight", "dumbbell", "barbell", "kettlebell"], ["Walking", "Reverse", "Forward", "Lateral", "Curtsy"], True),
    ("Step-Up", ["quads", "glutes"], ["bodyweight", "dumbbell", "barbell"], ["", "Lateral", "Crossover"], True),
    ("Deadlift", ["hamstrings", "glutes", "lower_back"], ["barbell", "dumbbell"], ["", "Conventional", "Sumo", "Deficit", "Snatch-Grip"], True),
    ("Romanian Deadlift", ["hamstrings", "glutes"], ["barbell", "dumbbell", "kettlebell", "smith_machine"], ["", "Single-Leg", "Paused"], True),
    ("Stiff-Leg Deadlift", ["hamstrings", "glutes"], ["barbell", "dumbbell"], [""], True),
    ("Good Morning", ["hamstrings", "lower_back", "glutes"], ["barbell", "bands"], ["", "Seated"], True),
    ("Leg Curl", ["hamstrings"], ["machine"], ["Lying", "Seated", "Single-Leg", "Standing"], True),
    ("Hip Thrust", ["glutes", "hamstrings"], ["barbell", "dumbbell", "machine", "bands"], ["", "Single-Leg", "B-Stance"], True),
    ("Glute Bridge", ["glutes", "hamstrings"], ["bodyweight", "barbell", "dumbbell", "bands"], ["", "Single-Leg", "Frog"], True),
    ("Calf Raise", ["calves"], ["machine", "dumbbell", "barbell", "smith_machine", "bodyweight"], ["Standing", "Seated", "Single-Leg", "Donkey"], True),
    ("Bicep Curl", ["biceps", "forearms"], ["dumbbell", "barbell", "cable", "ez_bar", "machine", "kettlebell"], ["", "Standing", "Seated", "Incline", "Preacher", "Spider", "Concentration"], True),
    ("Hammer Curl", ["biceps", "forearms"], ["dumbbell", "cable"], ["", "Standing", "Seated", "Cross-Body"], True),
    ("Reverse Curl", ["forearms", "biceps"], ["barbell", "dumbbell", "ez_bar", "cable"], [""], True),
    ("Wrist Curl", ["forearms"], ["dumbbell", "barbell", "cable"], ["", "Reverse", "Seated"], True),
    ("Triceps Extension", ["triceps"], ["dumbbell", "cable", "ez_bar", "barbell", "machine"], ["Overhead", "Lying", "Single-Arm", "Seated"], True),
    ("Triceps Pushdown", ["triceps"], ["cable"], ["", "Rope", "V-Bar", "Straight-Bar", "Reverse-Grip", "Single-Arm"], False),
    ("Triceps Kickback", ["triceps"], ["dumbbell", "cable"], ["", "Single-Arm"], True),
    ("Skullcrusher", ["triceps"], ["ez_bar", "barbell", "dumbbell"], ["", "Incline", "Decline"], True),
    ("Crunch", ["core"], ["bodyweight", "cable", "machine"], ["", "Weighted", "Reverse", "Bicycle"], True),
    ("Sit-Up", ["core"], ["bodyweight", "weighted"], ["", "Decline", "Weighted"], False),
    ("Leg Raise", ["core", "hip_flexors"], ["bodyweight", "pull_up_bar"], ["Lying", "Hanging", "Captains-Chair"], False),
    ("Plank", ["core"], ["bodyweight"], ["", "Side", "Weighted", "Long-Lever"], False),
    ("Russian Twist", ["obliques", "core"], ["bodyweight", "medicine_ball", "plate"], ["", "Weighted"], True),
    ("Cable Crunch", ["core"], ["cable"], ["", "Kneeling", "Standing"], False),
    ("Wood Chop", ["obliques", "core"], ["cable", "medicine_ball"], ["High-to-Low", "Low-to-High", "Horizontal"], True),
    ("Pallof Press", ["core", "obliques"], ["cable", "bands"], ["", "Half-Kneeling", "Standing"], True),
    ("Side Bend", ["obliques"], ["dumbbell", "cable"], ["", "Standing", "Seated"], True),
    ("Hanging Knee Raise", ["core", "hip_flexors"], ["pull_up_bar"], ["", "Twisting"], False),
    ("Ab Wheel Rollout", ["core"], ["other"], ["", "Kneeling", "Standing"], False),
    # Posterior chain / lower-body accessories
    ("Hip Abduction", ["abductors", "glutes"], ["machine", "cable", "bands"], ["Seated", "Standing"], True),
    ("Hip Adduction", ["adductors"], ["machine", "cable", "bands"], ["Seated", "Standing"], True),
    ("Glute Kickback", ["glutes", "hamstrings"], ["cable", "machine", "bands", "bodyweight"], ["", "Single-Leg"], True),
    ("Back Extension", ["lower_back", "glutes", "hamstrings"], ["bodyweight", "machine"], ["", "Weighted"], True),
    ("Reverse Hyperextension", ["glutes", "lower_back", "hamstrings"], ["machine", "bodyweight"], [""], True),
    ("Nordic Curl", ["hamstrings"], ["bodyweight"], ["", "Assisted"], False),
    ("Sissy Squat", ["quads"], ["bodyweight", "machine"], [""], False),
    ("Pistol Squat", ["quads", "glutes"], ["bodyweight"], ["", "Assisted"], False),
    ("Wall Sit", ["quads"], ["bodyweight"], [""], False),
    ("Cossack Squat", ["adductors", "quads", "glutes"], ["bodyweight", "dumbbell", "kettlebell"], [""], True),
    ("Sumo Squat", ["adductors", "glutes", "quads"], ["dumbbell", "kettlebell", "barbell"], [""], True),
    ("Pec Deck", ["chest"], ["machine"], [""], False),
    ("Dip", ["chest", "triceps"], ["bodyweight", "machine"], ["", "Weighted", "Chest", "Triceps"], False),
    # Rows / pulls
    ("Inverted Row", ["back", "lats", "biceps"], ["bodyweight", "trx", "smith_machine"], ["", "Wide-Grip", "Underhand"], False),
    ("T-Bar Row", ["back", "lats", "biceps"], ["barbell", "machine"], ["", "Chest-Supported"], True),
    ("Meadows Row", ["back", "lats"], ["barbell"], [""], True),
    ("Seal Row", ["back", "lats"], ["barbell", "dumbbell"], [""], True),
    ("Rack Pull", ["back", "glutes", "traps"], ["barbell"], ["", "Below-Knee", "Above-Knee"], True),
    ("Straight-Arm Pulldown", ["lats"], ["cable"], ["", "Single-Arm"], False),
    # Olympic / power
    ("Power Clean", ["full_body", "traps", "quads"], ["barbell", "dumbbell", "kettlebell"], ["", "Hang"], True),
    ("Power Snatch", ["full_body", "traps", "shoulders"], ["barbell", "dumbbell", "kettlebell"], ["", "Hang"], True),
    ("Clean and Press", ["full_body", "shoulders"], ["barbell", "dumbbell", "kettlebell"], [""], True),
    ("Push Press", ["shoulders", "triceps", "quads"], ["barbell", "dumbbell", "kettlebell"], ["", "Seated"], True),
    ("Thruster", ["quads", "shoulders", "glutes"], ["barbell", "dumbbell", "kettlebell"], [""], True),
    ("Kettlebell Swing", ["glutes", "hamstrings", "core"], ["kettlebell", "dumbbell"], ["", "Single-Arm", "American"], False),
    ("Turkish Get-Up", ["full_body", "core", "shoulders"], ["kettlebell", "dumbbell"], [""], True),
    ("Farmer's Carry", ["forearms", "traps", "core"], ["dumbbell", "kettlebell"], ["", "Single-Arm"], True),
    ("Suitcase Carry", ["obliques", "forearms", "core"], ["dumbbell", "kettlebell"], [""], True),
    ("Overhead Carry", ["shoulders", "core", "traps"], ["dumbbell", "kettlebell"], ["", "Single-Arm"], True),
    # Landmine
    ("Landmine Press", ["shoulders", "chest", "triceps"], ["barbell"], ["", "Single-Arm", "Half-Kneeling"], True),
    ("Landmine Row", ["back", "lats"], ["barbell"], ["", "Single-Arm"], True),
    ("Landmine Squat", ["quads", "glutes"], ["barbell"], [""], True),
    ("Landmine Rotation", ["obliques", "core", "shoulders"], ["barbell"], [""], True),
    # Press / chest variants
    ("Floor Press", ["chest", "triceps"], ["barbell", "dumbbell"], ["", "Close-Grip"], True),
    ("Pin Press", ["chest", "triceps", "shoulders"], ["barbell"], [""], True),
    ("Cable Crossover", ["chest"], ["cable"], ["High", "Low", "Mid"], False),
    ("Svend Press", ["chest"], ["plate"], [""], True),
    ("Z Press", ["shoulders", "triceps", "core"], ["barbell", "dumbbell", "kettlebell"], [""], True),
    ("Bradford Press", ["shoulders"], ["barbell"], [""], True),
    ("Cuban Press", ["shoulders", "traps"], ["dumbbell", "barbell"], [""], True),
    # Curl / arm variants
    ("Drag Curl", ["biceps"], ["barbell", "dumbbell"], [""], True),
    ("Zottman Curl", ["biceps", "forearms"], ["dumbbell"], [""], True),
    ("Cable Pull-Through", ["glutes", "hamstrings"], ["cable", "bands"], [""], False),
    ("Kroc Row", ["back", "lats", "forearms"], ["dumbbell"], [""], True),
    ("Renegade Row", ["back", "core", "lats"], ["dumbbell", "kettlebell"], [""], True),
    # Squat / deadlift variants
    ("Zercher Squat", ["quads", "glutes", "core"], ["barbell"], [""], True),
    ("Trap Bar Deadlift", ["quads", "glutes", "traps"], ["barbell"], ["", "High-Handle", "Low-Handle"], True),
    ("Jefferson Curl", ["hamstrings", "lower_back", "spine"], ["dumbbell", "barbell"], [""], True),
    ("Reverse Nordic", ["quads"], ["bodyweight"], [""], False),
    ("Spanish Squat", ["quads"], ["bands"], [""], True),
    ("Calf Press", ["calves"], ["machine"], ["", "Single-Leg"], True),
    # Calisthenic holds / core
    ("Copenhagen Plank", ["adductors", "core"], ["bodyweight"], [""], False),
    ("Hollow Body Hold", ["core"], ["bodyweight"], [""], False),
    ("Dead Hang", ["forearms", "lats"], ["pull_up_bar"], [""], False),
    ("L-Sit", ["core", "hip_flexors", "triceps"], ["bodyweight"], [""], False),
    ("Frog Pump", ["glutes"], ["bodyweight", "bands"], [""], False),
]

PLYO = [
    ("Box Jump", ["quads", "glutes", "calves"]),
    ("Broad Jump", ["quads", "glutes", "hamstrings"]),
    ("Jump Squat", ["quads", "glutes"]),
    ("Burpee", ["full_body"]),
    ("Mountain Climber", ["core", "hip_flexors"]),
    ("Tuck Jump", ["quads", "calves"]),
    ("Skater Jump", ["glutes", "quads"]),
    ("Depth Jump", ["quads", "glutes", "calves"]),
    ("Clap Push-Up", ["chest", "triceps"]),
    ("Medicine Ball Slam", ["core", "shoulders", "back"]),
]

CARDIO = [
    ("Treadmill Run", ["quads", "hamstrings", "calves"], ["machine"]),
    ("Treadmill Incline Walk", ["glutes", "calves", "hamstrings"], ["machine"]),
    ("Outdoor Run", ["quads", "hamstrings", "calves"], ["bodyweight"]),
    ("Sprint Intervals", ["quads", "hamstrings", "glutes"], ["bodyweight"]),
    ("Rowing Machine", ["back", "lats", "quads"], ["machine"]),
    ("Assault Bike", ["quads", "shoulders"], ["machine"]),
    ("Stationary Bike", ["quads", "calves"], ["machine"]),
    ("Spin Bike", ["quads", "glutes"], ["machine"]),
    ("Elliptical", ["quads", "glutes"], ["machine"]),
    ("Stair Climber", ["glutes", "quads", "calves"], ["machine"]),
    ("Jump Rope", ["calves", "shoulders"], ["other"]),
    ("Battle Ropes", ["shoulders", "core", "forearms"], ["other"]),
    ("Ski Erg", ["lats", "core", "triceps"], ["machine"]),
    ("Swimming", ["full_body"], ["other"]),
    ("Incline Walk", ["glutes", "calves"], ["bodyweight"]),
]


def expand_name(modifier, equip_label, base, show_equip):
    parts = []
    if modifier:
        parts.append(modifier)
    if show_equip and equip_label:
        parts.append(equip_label)
    parts.append(base)
    return " ".join(parts)


def generate_combinatorial():
    out = []
    seen = set()

    def add(name, category, muscles, equip):
        key = name.lower()
        if key in seen:
            return
        seen.add(key)
        out.append(make(name, category, muscles, equip, f"placeholder:{category}"))

    for base, muscles, equips, mods, show_equip in TEMPLATES:
        for equip in equips:
            equip_canon = equip if equip in EQUIPMENT else "other"
            label = E.get(equip, EQUIPMENT.get(equip, "").split()[0] if equip in EQUIPMENT else "")
            for mod in mods:
                name = expand_name(mod, label, base, show_equip)
                add(name, "strength", muscles, [equip_canon])

    for base, muscles in PLYO:
        add(base, "strength", muscles, ["bodyweight"])

    for name, muscles, equip in CARDIO:
        add(name, "cardio", muscles, equip)

    return out


# --------------------------------------------------------------------------- #
# Merge + emit
# --------------------------------------------------------------------------- #

def build():
    fedb = load_free_exercise_db()
    curated = load_curated()
    combo = generate_combinatorial()

    merged = []
    seen = set()
    for source in (fedb, curated, combo):  # earlier wins -> real imagery preferred
        for ex in source:
            key = ex["name"].strip().lower()
            if key in seen:
                continue
            seen.add(key)
            merged.append(ex)

    merged.sort(key=lambda e: e["name"].lower())
    return merged, len(fedb), len(curated), len(combo)


def main():
    parser = argparse.ArgumentParser(description="Build the DailyFitness exercise library")
    parser.add_argument("--stats", action="store_true", help="print a category/source breakdown")
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    exercises, n_fedb, n_cur, n_combo = build()

    # Integrity guards.
    assert all(e["imageURL"] for e in exercises), "imageURL must never be null"
    ids = [e["id"] for e in exercises]
    assert len(ids) == len(set(ids)), "duplicate ids detected"

    payload = {"exercises": exercises}
    (OUT_DIR / "exercises.json").write_text(json.dumps(payload, indent=2) + "\n")

    version = max(4, len(exercises) // 100)
    manifest = {"version": version, "count": len(exercises), "generatedAt": "2026-06-29"}
    (OUT_DIR / "exercises-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    # Reference dump of the canonical taxonomy (for Taxonomy.swift parity checks).
    (DATA / "taxonomy.json").write_text(json.dumps({
        "muscles": MUSCLES, "equipment": EQUIPMENT, "categories": CATEGORIES,
        "categoryLogging": CATEGORY_LOGGING,
    }, indent=2) + "\n")

    print(f"Wrote {len(exercises)} exercises (manifest version {version}) to {OUT_DIR}")
    if args.stats:
        by_cat = Counter(e["category"] for e in exercises)
        real_img = sum(1 for e in exercises if e["imageURL"].startswith("http"))
        print(f"  sources: free-exercise-db={n_fedb}  curated={n_cur}  combinatorial={n_combo}")
        print(f"  by category: {dict(by_cat)}")
        print(f"  real imagery: {real_img}  placeholder imagery: {len(exercises) - real_img}")
        muscles_used = Counter(m for e in exercises for m in e["primaryMuscles"])
        print(f"  distinct muscles used: {len(muscles_used)} / {len(MUSCLES)}")


if __name__ == "__main__":
    main()
