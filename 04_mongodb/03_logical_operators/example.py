#!/usr/bin/env python3
"""
MongoDB logical operators lesson (PyMongo).

Operators covered:
- $and
- $or
- $not

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
COLLECTION_NAME = "logical_operators_people"


def pretty(docs: List[Dict[str, Any]]) -> str:
    if not docs:
        return "[]"
    rows = []
    for d in docs:
        rows.append(f"{d.get('name')} (age={d.get('age')}, city={d.get('city')})")
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
            {"name": "Anna", "age": 17, "city": "Chicago"},
            {"name": "Bohdan", "age": 18, "city": "New York"},
            {"name": "Chris", "age": 25, "city": "Los Angeles"},
            {"name": "Daria", "age": 30, "city": "Kyiv"},
            {"name": "Emma", "age": 45, "city": "New York"},
            {"name": "Farid", "age": 60, "city": "Berlin"},
            {"name": "Hanna", "age": 61, "city": "Warsaw"},
        ]
    )

    # From the image table:
    # { "$and": [ { "age": { "$gte": 18 } }, { "city": "New York" } ] }
    run_query(
        coll,
        "$and (logical AND)",
        {"$and": [{"age": {"$gte": 18}}, {"city": "New York"}]},
    )

    # { "$or": [ { "age": { "$lt": 18 } }, { "age": { "$gt": 60 } } ] }
    run_query(
        coll,
        "$or (logical OR)",
        {"$or": [{"age": {"$lt": 18}}, {"age": {"$gt": 60}}]},
    )

    # { "age": { "$not": { "$gte": 18 } } }
    run_query(
        coll,
        "$not (logical NOT)",
        {"age": {"$not": {"$gte": 18}}},
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
