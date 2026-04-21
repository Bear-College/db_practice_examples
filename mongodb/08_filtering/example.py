#!/usr/bin/env python3
"""
MongoDB filtering lesson (PyMongo).

Covers:
- find() and find_one()
- comparison operators
- $in / $nin
- $and / $or / $not
- nested document search (dot notation)
- array filters ($all, $size, $elemMatch)
- regex ($regex)
- NULL-style filtering ($exists)

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
COLLECTION_NAME = "filtering_people"


def short_docs(docs: List[Dict[str, Any]]) -> str:
    if not docs:
        return "[]"
    return "[" + ", ".join(d.get("name", "?") for d in docs) + "]"


def run_query(coll, title: str, query: Dict[str, Any]) -> None:
    docs = list(coll.find(query, {"_id": 0, "name": 1}).sort("name", 1))
    print(f"{title}\n  query={query}\n  count={len(docs)}\n  names={short_docs(docs)}\n")


def main() -> int:
    client = MongoClient(MONGODB_URI)
    db = client[MONGODB_DB]
    coll = db[COLLECTION_NAME]

    print(f"Mongo URI: {MONGODB_URI}")
    print(f"Database:  {MONGODB_DB}")
    print(f"Collection:{COLLECTION_NAME}\n")

    # Reset lesson data.
    coll.delete_many({})
    coll.insert_many(
        [
            {
                "name": "Anna",
                "age": 17,
                "city": "Chicago",
                "email": "anna@gmail.com",
                "phone": "+1-202-555-0101",
                "profile": {"city": "Chicago", "experience": 1},
                "skills": ["Python", "JavaScript", "SQL"],
                "grades": [{"subject": "math", "score": 95}, {"subject": "history", "score": 88}],
            },
            {
                "name": "Bohdan",
                "age": 18,
                "city": "New York",
                "email": "bohdan@outlook.com",
                "profile": {"city": "New York", "experience": 2},
                "skills": ["Python", "Go"],
                "grades": [{"subject": "math", "score": 89}, {"subject": "physics", "score": 91}],
            },
            {
                "name": "Chris",
                "age": 25,
                "city": "Los Angeles",
                "email": "chris@gmail.com",
                "phone": "+1-202-555-0102",
                "profile": {"city": "Los Angeles", "experience": 4},
                "skills": ["JavaScript", "TypeScript", "Node.js"],
                "grades": [{"subject": "math", "score": 78}, {"subject": "biology", "score": 84}],
            },
            {
                "name": "Daria",
                "age": 30,
                "city": "Kyiv",
                "email": "daria@yahoo.com",
                "phone": "+380-44-555-0103",
                "profile": {"city": "Kyiv", "experience": 7},
                "skills": ["Python", "JavaScript"],
                "grades": [{"subject": "math", "score": 92}, {"subject": "chemistry", "score": 94}],
            },
            {
                "name": "Emma",
                "age": 45,
                "city": "New York",
                "email": "emma@gmail.com",
                "phone": "+1-202-555-0104",
                "profile": {"city": "New York", "experience": 15},
                "skills": ["Python", "Architecture", "Leadership"],
                "grades": [{"subject": "math", "score": 90}, {"subject": "management", "score": 99}],
            },
        ]
    )

    # 1) find(): select all
    all_docs = list(coll.find({}, {"_id": 0, "name": 1}).sort("name", 1))
    print(f"find() all documents\n  count={len(all_docs)}\n  names={short_docs(all_docs)}\n")

    # 2) find_one(): single document
    one = coll.find_one({"name": "Anna"}, {"_id": 0})
    print(f"find_one() by name=Anna\n  doc={one}\n")

    # 3) Comparison operators
    run_query(coll, "Comparison: age > 25", {"age": {"$gt": 25}})
    run_query(coll, "Comparison: age <= 30", {"age": {"$lte": 30}})

    # 4) Multi-value filters
    run_query(coll, "$in: city in [New York, Los Angeles]", {"city": {"$in": ["New York", "Los Angeles"]}})
    run_query(coll, "$nin: city not in [New York, Los Angeles]", {"city": {"$nin": ["New York", "Los Angeles"]}})

    # 5) Logical operators
    run_query(coll, "$and: age >= 18 AND city=New York", {"$and": [{"age": {"$gte": 18}}, {"city": "New York"}]})
    run_query(coll, "$or: age < 18 OR age > 40", {"$or": [{"age": {"$lt": 18}}, {"age": {"$gt": 40}}]})
    run_query(coll, "$not: age NOT >= 18", {"age": {"$not": {"$gte": 18}}})

    # 6) Nested documents (dot notation)
    run_query(coll, "Nested: profile.city = New York", {"profile.city": "New York"})
    run_query(coll, "Nested: profile.experience >= 10", {"profile.experience": {"$gte": 10}})

    # 7) Array filtering
    run_query(coll, "Array $all: skills has Python + JavaScript", {"skills": {"$all": ["Python", "JavaScript"]}})
    run_query(coll, "Array $size: skills length = 3", {"skills": {"$size": 3}})
    run_query(coll, "Array $elemMatch: grades.score > 90", {"grades": {"$elemMatch": {"score": {"$gt": 90}}}})

    # 8) String regex
    run_query(coll, "Regex: email ends with @gmail.com", {"email": {"$regex": "@gmail.com$"}})

    # 9) NULL-style / field-exists filtering
    run_query(coll, "$exists: has phone field", {"phone": {"$exists": True}})
    run_query(coll, "$exists: phone field is missing", {"phone": {"$exists": False}})

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
