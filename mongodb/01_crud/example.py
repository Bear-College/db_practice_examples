#!/usr/bin/env python3
"""
MongoDB CRUD lesson (PyMongo).

Operations mirror the study table:
- insert_one
- insert_many
- update_one
- update_many
- delete_one
- delete_many (filtered)
- delete_many({}) for collection cleanup
- drop() for collection removal

This script targets the MongoDB practice database restored/seeded from `database_mongo/`.
Set env if needed:
  MONGODB_URI (default: mongodb://localhost:27017)
  MONGODB_DB  (default: edu_academy_seed)
"""

from __future__ import annotations

import os
from typing import Any, Dict, List

from pymongo import MongoClient


MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "edu_academy_seed")
COLLECTION_NAME = "products"


def print_docs(title: str, docs: List[Dict[str, Any]]) -> None:
    print(f"\n{title}")
    if not docs:
        print("  (no documents)")
        return
    for doc in docs:
        print(
            "  "
            + f"name={doc.get('name')}, "
            + f"category={doc.get('category')}, "
            + f"price={doc.get('price')}"
        )


def main() -> int:
    client = MongoClient(MONGODB_URI)
    db = client[MONGODB_DB]
    products = db[COLLECTION_NAME]

    print(f"Mongo URI: {MONGODB_URI}")
    print(f"Database:  {MONGODB_DB}")
    print(f"Collection:{COLLECTION_NAME}")

    # Start from a clean state for a repeatable lesson run.
    products.delete_many({})

    # 1) Add one record: insert_one({...})
    products.insert_one({"name": "iPhone 14", "category": "Phone", "price": 999})

    # 2) Add multiple records: insert_many([{...}, {...}])
    products.insert_many(
        [
            {"name": "Galaxy S23", "category": "Phone", "price": 899},
            {"name": "MacBook Air", "category": "Laptop", "price": 1299},
            {"name": "Pixel 8", "category": "Phone", "price": 799},
        ]
    )
    print_docs("After INSERT operations:", list(products.find({}, {"_id": 0})))

    # 3) Update one record: update_one({"name": "iPhone 14"}, {"$set": {"price": 899}})
    one_result = products.update_one({"name": "iPhone 14"}, {"$set": {"price": 899}})
    print(f"\nupdate_one matched={one_result.matched_count}, modified={one_result.modified_count}")

    # 4) Update all matching records:
    #    update_many({"category": "Phone"}, {"$set": {"category": "Smartphone"}})
    many_result = products.update_many(
        {"category": "Phone"},
        {"$set": {"category": "Smartphone"}},
    )
    print(f"update_many matched={many_result.matched_count}, modified={many_result.modified_count}")
    print_docs("After UPDATE operations:", list(products.find({}, {"_id": 0})))

    # 5) Delete one record: delete_one({"name": "iPhone 14"})
    del_one = products.delete_one({"name": "iPhone 14"})
    print(f"\ndelete_one deleted={del_one.deleted_count}")

    # 6) Delete all matching records:
    #    delete_many({"category": "Smartphone"})
    del_many_filtered = products.delete_many({"category": "Smartphone"})
    print(f"delete_many(category=Smartphone) deleted={del_many_filtered.deleted_count}")
    print_docs("After DELETE (filtered) operations:", list(products.find({}, {"_id": 0})))

    # 7) Clear collection: delete_many({})
    cleared = products.delete_many({})
    print(f"\ndelete_many({{}}) deleted={cleared.deleted_count}")
    print(f"Remaining docs in collection: {products.count_documents({})}")

    # 8) Drop collection: drop()
    products.drop()
    print(f"Collection exists after drop: {COLLECTION_NAME in db.list_collection_names()}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
