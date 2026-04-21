#!/usr/bin/env python3
"""
MongoDB check operators lesson (PyMongo).

Operators covered:
- $exists
- $type

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
COLLECTION_NAME = "check_operators_people"


def pretty(docs: List[Dict[str, Any]]) -> str:
    if not docs:
        return "[]"
    rows = []
    for d in docs:
        rows.append(
            f"{d.get('name')} (age={d.get('age')}, phone={d.get('phone', 'N/A')},"
            + f" age_type={type(d.get('age')).__name__})"
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
            {"name": "Anna", "age": 17, "phone": "+1-202-555-0101"},
            {"name": "Bohdan", "age": 18},
            {"name": "Chris", "age": 25, "phone": "+1-202-555-0102"},
            {"name": "Daria", "age": 30.5, "phone": "+380-44-555-0103"},
            {"name": "Emma", "age": "45", "phone": "+1-202-555-0104"},
        ]
    )

    # From image: { "phone": { "$exists": true } }
    run_query(
        coll,
        "$exists (field exists)",
        {"phone": {"$exists": True}},
    )

    # From image: { "age": { "$type": "int" } }
    run_query(
        coll,
        "$type (field type is int)",
        {"age": {"$type": "int"}},
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
