#!/usr/bin/env python3
"""
MongoDB pagination and sorting lesson (PyMongo).

Topics covered:
- sorting with sort(...)
- pagination with skip(...) + limit(...)

Defaults:
  MONGODB_URI=mongodb://localhost:27017
  MONGODB_DB=edu_academy_seed
"""

from __future__ import annotations

import os
from typing import Any, Dict, List

from pymongo import ASCENDING, DESCENDING, MongoClient


MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "edu_academy_seed")
COLLECTION_NAME = "pagination_sorting_products"


def print_rows(title: str, docs: List[Dict[str, Any]]) -> None:
    print(f"\n{title}")
    if not docs:
        print("  (no documents)")
        return
    for d in docs:
        print(
            "  "
            + f"name={d.get('name')}, category={d.get('category')}, "
            + f"price={d.get('price')}, rating={d.get('rating')}"
        )


def fetch_page(coll, *, page: int, per_page: int, sort_spec: List[tuple[str, int]]) -> List[Dict[str, Any]]:
    if page < 1:
        raise ValueError("page must be >= 1")
    skip_n = (page - 1) * per_page
    return list(
        coll.find({}, {"_id": 0})
        .sort(sort_spec)
        .skip(skip_n)
        .limit(per_page)
    )


def main() -> int:
    client = MongoClient(MONGODB_URI)
    db = client[MONGODB_DB]
    coll = db[COLLECTION_NAME]

    print(f"Mongo URI: {MONGODB_URI}")
    print(f"Database:  {MONGODB_DB}")
    print(f"Collection:{COLLECTION_NAME}")

    # Reset lesson collection so output is deterministic.
    coll.delete_many({})
    coll.insert_many(
        [
            {"name": "iPhone 14", "category": "Smartphone", "price": 899, "rating": 4.8},
            {"name": "Galaxy S23", "category": "Smartphone", "price": 799, "rating": 4.7},
            {"name": "Pixel 8", "category": "Smartphone", "price": 699, "rating": 4.6},
            {"name": "MacBook Air", "category": "Laptop", "price": 1299, "rating": 4.9},
            {"name": "ThinkPad X1", "category": "Laptop", "price": 1399, "rating": 4.8},
            {"name": "iPad Pro", "category": "Tablet", "price": 999, "rating": 4.7},
            {"name": "Kindle Paperwhite", "category": "Tablet", "price": 159, "rating": 4.5},
            {"name": "Sony WH-1000XM5", "category": "Audio", "price": 399, "rating": 4.8},
            {"name": "AirPods Pro", "category": "Audio", "price": 249, "rating": 4.6},
            {"name": "Logitech MX Master 3S", "category": "Accessories", "price": 99, "rating": 4.9},
        ]
    )

    # Sorting examples.
    by_price_asc = list(coll.find({}, {"_id": 0}).sort([("price", ASCENDING)]))
    print_rows("Sorted by price ASC", by_price_asc)

    by_rating_desc_then_price_asc = list(
        coll.find({}, {"_id": 0}).sort([("rating", DESCENDING), ("price", ASCENDING)])
    )
    print_rows("Sorted by rating DESC, then price ASC", by_rating_desc_then_price_asc)

    # Pagination examples over a deterministic sort key.
    page_size = 3
    page_1 = fetch_page(coll, page=1, per_page=page_size, sort_spec=[("name", ASCENDING)])
    page_2 = fetch_page(coll, page=2, per_page=page_size, sort_spec=[("name", ASCENDING)])
    page_3 = fetch_page(coll, page=3, per_page=page_size, sort_spec=[("name", ASCENDING)])

    print_rows(f"Page 1 (size={page_size}, sort=name ASC)", page_1)
    print_rows(f"Page 2 (size={page_size}, sort=name ASC)", page_2)
    print_rows(f"Page 3 (size={page_size}, sort=name ASC)", page_3)

    total = coll.count_documents({})
    print(f"\nTotal documents: {total}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
