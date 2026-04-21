#!/usr/bin/env python3
"""
MongoDB string operators lesson (PyMongo).

Operators covered:
- $regex
- $text

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
COLLECTION_NAME = "string_operators_people"


def pretty(docs: List[Dict[str, Any]]) -> str:
    if not docs:
        return "[]"
    rows = []
    for d in docs:
        rows.append(f"{d.get('name')} <{d.get('email')}>")
    return "[" + ", ".join(rows) + "]"


def run_query(coll, label: str, query: Dict[str, Any], *, projection: Dict[str, Any] | None = None) -> None:
    docs = list(coll.find(query, projection or {"_id": 0}).sort("name", 1))
    print(f"{label}\n  query={query}\n  count={len(docs)}\n  docs={pretty(docs)}\n")


def main() -> int:
    client = MongoClient(MONGODB_URI)
    db = client[MONGODB_DB]
    coll = db[COLLECTION_NAME]

    print(f"Mongo URI: {MONGODB_URI}")
    print(f"Database:  {MONGODB_DB}")
    print(f"Collection:{COLLECTION_NAME}\n")

    # Reset lesson collection for deterministic output.
    coll.drop()
    coll = db[COLLECTION_NAME]

    coll.insert_many(
        [
            {"name": "Anna", "email": "anna@gmail.com", "bio": "Frontend developer and UI engineer"},
            {"name": "Bohdan", "email": "bohdan@outlook.com", "bio": "Backend developer working with Python"},
            {"name": "Chris", "email": "chris@gmail.com", "bio": "Data analyst and SQL specialist"},
            {"name": "Daria", "email": "daria@yahoo.com", "bio": "Mobile engineer and mentor"},
        ]
    )

    # Required for $text queries.
    coll.create_index([("bio", "text")], name="ix_bio_text")

    # From image: { "email": { "$regex": "@gmail.com$" } }
    run_query(
        coll,
        "$regex (similar to SQL LIKE)",
        {"email": {"$regex": "@gmail.com$"}},
    )

    # From image: { "$text": { "$search": "developer" } }
    run_query(
        coll,
        "$text (full-text search)",
        {"$text": {"$search": "developer"}},
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
