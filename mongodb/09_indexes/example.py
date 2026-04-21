#!/usr/bin/env python3
"""
MongoDB indexes lesson (PyMongo).

Index types covered:
- single field
- compound
- unique
- text
- TTL
- hashed

Database default: edu_academy_seed
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Tuple

from pymongo import ASCENDING, DESCENDING, MongoClient
from pymongo.errors import OperationFailure


MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "edu_academy_seed")
COLLECTION_NAME = "indexes_people"

# You can control index operations here.
RUN_CREATE_INDEXES = True
RUN_DROP_INDEXES = False

# Add/remove index names in these sets/lists to control behavior.
INDEXES_TO_CREATE = {
    "ix_city_single",
    "ix_city_age_compound",
    "uq_email_unique",
    "ix_bio_text",
    "ix_expires_at_ttl",
    "ix_user_id_hashed",
}
INDEXES_TO_DROP = [
    # Example:
    # "ix_city_single",
]


def seed_data(coll) -> None:
    now = datetime.now(timezone.utc)
    coll.delete_many({})
    coll.insert_many(
        [
            {
                "user_id": "u1001",
                "name": "Anna",
                "email": "anna@example.com",
                "city": "New York",
                "age": 22,
                "bio": "Python developer and backend engineer",
                "expires_at": now + timedelta(days=5),
            },
            {
                "user_id": "u1002",
                "name": "Bohdan",
                "email": "bohdan@example.com",
                "city": "Chicago",
                "age": 28,
                "bio": "JavaScript developer and frontend specialist",
                "expires_at": now + timedelta(days=3),
            },
            {
                "user_id": "u1003",
                "name": "Chris",
                "email": "chris@example.com",
                "city": "New York",
                "age": 35,
                "bio": "Data engineer and SQL expert",
                "expires_at": now + timedelta(days=10),
            },
            {
                "user_id": "u1004",
                "name": "Daria",
                "email": "daria@example.com",
                "city": "Kyiv",
                "age": 30,
                "bio": "Engineering manager and mentor",
                # Expired document for TTL demo (removal is async in MongoDB).
                "expires_at": now - timedelta(days=1),
            },
        ]
    )


def desired_indexes() -> List[Dict[str, Any]]:
    return [
        {
            "name": "ix_city_single",
            "keys": [("city", ASCENDING)],
            "kwargs": {},
            "desc": "Single field index on city",
        },
        {
            "name": "ix_city_age_compound",
            "keys": [("city", ASCENDING), ("age", DESCENDING)],
            "kwargs": {},
            "desc": "Compound index on city + age",
        },
        {
            "name": "uq_email_unique",
            "keys": [("email", ASCENDING)],
            "kwargs": {"unique": True},
            "desc": "Unique index on email",
        },
        {
            "name": "ix_bio_text",
            "keys": [("bio", "text")],
            "kwargs": {},
            "desc": "Text index on bio",
        },
        {
            "name": "ix_expires_at_ttl",
            "keys": [("expires_at", ASCENDING)],
            "kwargs": {"expireAfterSeconds": 0},
            "desc": "TTL index on expires_at",
        },
        {
            "name": "ix_user_id_hashed",
            "keys": [("user_id", "hashed")],
            "kwargs": {},
            "desc": "Hashed index on user_id",
        },
    ]


def print_indexes(coll) -> None:
    print(f"\nIndexes in {coll.name}:")
    for idx in coll.list_indexes():
        name = idx.get("name")
        keys = idx.get("key")
        extras = {k: v for k, v in idx.items() if k not in {"v", "key", "ns", "name"}}
        print(f"  - {name}: keys={list(keys.items()) if keys else keys}, options={extras}")


def create_indexes(coll) -> None:
    for spec in desired_indexes():
        if spec["name"] not in INDEXES_TO_CREATE:
            continue
        created_name = coll.create_index(spec["keys"], name=spec["name"], **spec["kwargs"])
        print(f"Created index: {created_name} ({spec['desc']})")


def drop_indexes(coll) -> None:
    for index_name in INDEXES_TO_DROP:
        try:
            coll.drop_index(index_name)
            print(f"Dropped index: {index_name}")
        except OperationFailure as e:
            print(f"Could not drop index '{index_name}': {e}")


def demo_queries(coll) -> None:
    print("\nDemo queries using indexes:")
    city_docs = list(coll.find({"city": "New York"}, {"_id": 0, "name": 1, "city": 1}).sort("name", 1))
    print(f"  city='New York' -> {city_docs}")

    text_docs = list(coll.find({"$text": {"$search": "developer"}}, {"_id": 0, "name": 1, "bio": 1}))
    print(f"  $text search 'developer' -> {text_docs}")


def main() -> int:
    client = MongoClient(MONGODB_URI)
    db = client[MONGODB_DB]
    coll = db[COLLECTION_NAME]

    print(f"Mongo URI: {MONGODB_URI}")
    print(f"Database:  {MONGODB_DB}")
    print(f"Collection:{COLLECTION_NAME}")

    seed_data(coll)
    print_indexes(coll)

    if RUN_CREATE_INDEXES:
        print("\nCreating indexes...")
        create_indexes(coll)
        print_indexes(coll)

    if RUN_DROP_INDEXES:
        print("\nDropping configured indexes...")
        drop_indexes(coll)
        print_indexes(coll)

    demo_queries(coll)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
