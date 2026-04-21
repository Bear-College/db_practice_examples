#!/usr/bin/env python3
"""
Motor aggregation examples for MongoDB.

Covers operators from lesson table:
- $match
- $group
- $sum
- $avg
- $count
- $max / $min
- $sort
- $project
"""

from __future__ import annotations

import asyncio
import os
from datetime import datetime, timezone

from motor.motor_asyncio import AsyncIOMotorClient


MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "edu_academy_seed")
COLLECTION_NAME = "odm_aggregation_orders"


async def seed(coll) -> None:
    await coll.delete_many({})
    now = datetime.now(timezone.utc)
    await coll.insert_many(
        [
            {"order_id": "ORD-001", "customer": "Anna", "category": "Laptop", "amount": 1200, "quantity": 1, "created_at": now},
            {"order_id": "ORD-002", "customer": "Anna", "category": "Laptop", "amount": 900, "quantity": 1, "created_at": now},
            {"order_id": "ORD-003", "customer": "Bohdan", "category": "Smartphone", "amount": 800, "quantity": 2, "created_at": now},
            {"order_id": "ORD-004", "customer": "Chris", "category": "Smartphone", "amount": 700, "quantity": 1, "created_at": now},
            {"order_id": "ORD-005", "customer": "Daria", "category": "Tablet", "amount": 500, "quantity": 3, "created_at": now},
            {"order_id": "ORD-006", "customer": "Daria", "category": "Tablet", "amount": 450, "quantity": 1, "created_at": now},
        ]
    )


async def run_pipeline(coll, title: str, pipeline: list[dict]) -> None:
    docs = await coll.aggregate(pipeline).to_list(length=100)
    print(f"\n{title}")
    for d in docs:
        print(f"  {d}")


async def main() -> int:
    client = AsyncIOMotorClient(MONGODB_URI)
    coll = client[MONGODB_DB][COLLECTION_NAME]

    print(f"Mongo URI: {MONGODB_URI}")
    print(f"Database:  {MONGODB_DB}")
    print(f"Collection:{COLLECTION_NAME}")

    await seed(coll)

    # $match + $group + $sum + $count + $avg + $max/$min + $sort + $project
    await run_pipeline(
        coll,
        "Revenue by category ($match + $group + $sum + $count + $avg + $max/$min + $sort + $project)",
        [
            {"$match": {"amount": {"$gte": 400}}},
            {
                "$group": {
                    "_id": "$category",
                    "total_revenue": {"$sum": "$amount"},
                    "avg_revenue": {"$avg": "$amount"},
                    "orders_count": {"$count": {}},
                    "max_order": {"$max": "$amount"},
                    "min_order": {"$min": "$amount"},
                }
            },
            {"$sort": {"total_revenue": -1}},
            {
                "$project": {
                    "_id": 0,
                    "category": "$_id",
                    "total_revenue": 1,
                    "avg_revenue": 1,
                    "orders_count": 1,
                    "max_order": 1,
                    "min_order": 1,
                }
            },
        ],
    )

    await run_pipeline(
        coll,
        "Orders grouped by customer ($group + $sum(quantity) + $sort + $project)",
        [
            {
                "$group": {
                    "_id": "$customer",
                    "orders_count": {"$count": {}},
                    "total_items": {"$sum": "$quantity"},
                    "total_spent": {"$sum": "$amount"},
                }
            },
            {"$sort": {"total_spent": -1}},
            {"$project": {"_id": 0, "customer": "$_id", "orders_count": 1, "total_items": 1, "total_spent": 1}},
        ],
    )

    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
