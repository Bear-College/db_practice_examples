#!/usr/bin/env python3
"""
MongoDB array operators lesson (PyMongo).

Operators covered:
- $all
- $size
- $elemMatch

Defaults:
  MONGODB_URI=mongodb://localhost:27017
  MONGODB_DB=edu_academy_seed
"""

from __future__ import annotations

import os
from typing import Any, Dict, List

from pymongo import MongoClient


MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "edu_academy_seed")
COLLECTION_NAME = "array_operators_people"


def pretty(docs: List[Dict[str, Any]]) -> str:
    if not docs:
        return "[]"
    rows = []
    for d in docs:
        rows.append(
            f"{d.get('name')} (skills={d.get('skills')}, grades={d.get('grades')})"
        )
    return "[" + ", ".join(rows) + "]"


def run_query(coll, label: str, query: Dict[str, Any]) -> None:
    docs = list(coll.find(query, {"_id": 0}).sort("name", 1))
    print(f"{label}\n  query={query}\n  count={len(docs)}\n  docs={pretty(docs)}\n")


def main() -> int:
    client = MongoClient(MONGODB_URI)
    db = client[MONGODB_DB]
    coll = db[COLLECTION_NAME]

    print(f"Mongo URI: {MONGODB_URI}")
    print(f"Database:  {MONGODB_DB}")
    print(f"Collection:{COLLECTION_NAME}\n")

    # Reset lesson collection to keep output deterministic.
    coll.delete_many({})
    coll.insert_many(
        [
            {
                "name": "Anna",
                "skills": ["Python", "JavaScript", "SQL"],
                "grades": [{"subject": "math", "score": 95}, {"subject": "history", "score": 88}],
            },
            {
                "name": "Bohdan",
                "skills": ["Python", "Go"],
                "grades": [{"subject": "math", "score": 89}, {"subject": "physics", "score": 91}],
            },
            {
                "name": "Chris",
                "skills": ["JavaScript", "TypeScript", "Node.js"],
                "grades": [{"subject": "math", "score": 78}, {"subject": "biology", "score": 84}],
            },
            {
                "name": "Daria",
                "skills": ["Python", "JavaScript"],
                "grades": [{"subject": "math", "score": 92}, {"subject": "chemistry", "score": 94}],
            },
        ]
    )

    # From image: { "skills": { "$all": ["Python", "JavaScript"] } }
    run_query(
        coll,
        "$all (array contains all values)",
        {"skills": {"$all": ["Python", "JavaScript"]}},
    )

    # From image: { "skills": { "$size": 3 } }
    run_query(
        coll,
        "$size (array length equals 3)",
        {"skills": {"$size": 3}},
    )

    # From image: { "grades": { "$elemMatch": { "score": { "$gt": 90 } } } }
    run_query(
        coll,
        "$elemMatch (array has element matching condition)",
        {"grades": {"$elemMatch": {"score": {"$gt": 90}}}},
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
