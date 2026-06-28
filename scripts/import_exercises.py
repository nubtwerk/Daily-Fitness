#!/usr/bin/env python3
"""Merge external exercise datasets into DailyFitness seed JSON.

Usage:
  python3 scripts/import_exercises.py --source path/to/exercises.json --output DailyFitness/Resources/Exercises/exercises.json

Phase 0 ships a 10-exercise sample. Expand to 2000+ by merging ExerciseDB or similar open datasets.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Build exercises.json seed file")
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    source = json.loads(args.source.read_text())
    exercises = source.get("exercises", source)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"exercises": exercises}, indent=2))
    print(f"Wrote {len(exercises)} exercises to {args.output}")


if __name__ == "__main__":
    main()
