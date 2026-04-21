#!/usr/bin/env python3
"""
Motor + Python index examples for MongoDB.

Demonstrates:
- create single / compound / unique / text / TTL / hashed indexes
- list indexes
- run simple queries that can benefit from indexes
- drop created indexes
"""

from __future__ import annotations

import asyncio
import os
from datetime import datetime, timedelta, timezone

from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import ASCENDING, DESCENDING


MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "edu_academy_seed")
COLLECTION_NAME = "odm_motor_indexes_products"


async def seed(coll) -> None:
    now = datetime.now(timezone.utc)
    await coll.delete_many({})
    await coll.insert_many(
        [
            {
                "sku": "SKU-1001",
                "name": "iPhone 14",
                "category": "Smartphone",
                "description": "Apple smartphone",
                "price": 899,
                "created_at": now,
                "expires_at": now + timedelta(days=7),
            },
            {
                "sku": "SKU-1002",
                "name": "Galaxy S23",
                "category": "Smartphone",
                "description": "Samsung flagship phone",
                "price": 799,
                "created_at": now,
                "expires_at": now + timedelta(days=7),
            },
            {
                "sku": "SKU-1003",
                "name": "MacBook Air",
                "category": "Laptop",
                "description": "Lightweight laptop",
                "price": 1299,
                "created_at": now,
                "expires_at": now + timedelta(days=7),
            },
        ]
    )


async def create_indexes(coll) -> list[str]:
    created: list[str] = []
    created.append(await coll.create_index([("category", ASCENDING)], name="ix_category_single"))
    created.append(
        await coll.create_index(
            [("category", ASCENDING), ("price", DESCENDING)],
            name="ix_category_price_compound",
        )
    )
    created.append(await coll.create_index([("sku", ASCENDING)], unique=True, name="uq_sku"))
    created.append(await coll.create_index([("description", "text")], name="ix_description_text"))
    created.append(await coll.create_index([("expires_at", ASCENDING)], expireAfterSeconds=0, name="ix_expires_at_ttl"))
    created.append(await coll.create_index([("sku", "hashed")], name="ix_sku_hashed"))
    return created


async def print_indexes(coll) -> None:
    print("\nIndexes:")
    async for idx in coll.list_indexes():
        print(f"  - {idx.get('name')}: {idx.get('key')}")


async def demo_queries(coll) -> None:
    phones = await coll.find({"category": "Smartphone"}, {"_id": 0, "name": 1, "price": 1}).to_list(length=10)
    print(f"\ncategory='Smartphone' -> {phones}")

    txt = await coll.find({"$text": {"$search": "smartphone"}}, {"_id": 0, "name": 1}).to_list(length=10)
    print(f"$text search 'smartphone' -> {txt}")


async def drop_created_indexes(coll, names: list[str]) -> None:
    for name in names:
        await coll.drop_index(name)
        print(f"Dropped index: {name}")


async def main() -> int:
    client = AsyncIOMotorClient(MONGODB_URI)
    coll = client[MONGODB_DB][COLLECTION_NAME]

    print(f"Mongo URI: {MONGODB_URI}")
    print(f"Database:  {MONGODB_DB}")
    print(f"Collection:{COLLECTION_NAME}")

    await seed(coll)
    created = await create_indexes(coll)
    await print_indexes(coll)
    await demo_queries(coll)
    await drop_created_indexes(coll, created)

    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
