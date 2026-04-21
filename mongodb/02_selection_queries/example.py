#!/usr/bin/env python3
"""
MongoDB selection query operators lesson (PyMongo).

Operators covered:
- $eq
- $ne
- $gt
- $lt
- $gte
- $lte
- $in
- $nin

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
COLLECTION_NAME = "selection_queries_people"


def pretty(docs: List[Dict[str, Any]]) -> str:
    if not docs:
        return "[]"
    rows = []
    for d in docs:
        profile = d.get("profile", {})
        rows.append(
            f"{d.get('name')} (age={d.get('age')}, city={d.get('city')}, "
            + f"profile.city={profile.get('city')}, profile.experience={profile.get('experience')})"
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
                "age": 17,
                "city": "Chicago",
                "profile": {"city": "Chicago", "experience": 1, "role": "intern"},
            },
            {
                "name": "Bohdan",
                "age": 18,
                "city": "New York",
                "profile": {"city": "New York", "experience": 2, "role": "junior"},
            },
            {
                "name": "Chris",
                "age": 25,
                "city": "Los Angeles",
                "profile": {"city": "Los Angeles", "experience": 4, "role": "developer"},
            },
            {
                "name": "Daria",
                "age": 30,
                "city": "Kyiv",
                "profile": {"city": "Kyiv", "experience": 7, "role": "lead"},
            },
            {
                "name": "Emma",
                "age": 45,
                "city": "New York",
                "profile": {"city": "New York", "experience": 15, "role": "architect"},
            },
            {
                "name": "Farid",
                "age": 60,
                "city": "Berlin",
                "profile": {"city": "Berlin", "experience": 20, "role": "principal"},
            },
            {
                "name": "Hanna",
                "age": 61,
                "city": "Warsaw",
                "profile": {"city": "Warsaw", "experience": 21, "role": "advisor"},
            },
        ]
    )

    run_query(coll, "$eq  (equals)", {"age": {"$eq": 25}})
    run_query(coll, "$ne  (not equals)", {"age": {"$ne": 25}})
    run_query(coll, "$gt  (greater than)", {"age": {"$gt": 25}})
    run_query(coll, "$lt  (less than)", {"age": {"$lt": 30}})
    run_query(coll, "$gte (greater or equals)", {"age": {"$gte": 18}})
    run_query(coll, "$lte (less or equals)", {"age": {"$lte": 60}})
    run_query(coll, "$in  (in list)", {"city": {"$in": ["New York", "Los Angeles"]}})
    run_query(coll, "$nin (not in list)", {"city": {"$nin": ["New York", "Los Angeles"]}})
    run_query(coll, "Nested $eq on profile.city", {"profile.city": {"$eq": "New York"}})
    run_query(coll, "Nested $gte on profile.experience", {"profile.experience": {"$gte": 10}})
    run_query(
        coll,
        "Nested $in on profile.role",
        {"profile.role": {"$in": ["developer", "architect"]}},
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
