#!/usr/bin/env python3
"""
FastAPI + Motor + Pydantic:
search, sorting, and pagination over MongoDB documents.

Run:
  uvicorn mongodb.10_odm.02_search_sorting_pagination.main:app --reload
"""

from __future__ import annotations

import os
from typing import Any, Dict, List, Literal

from fastapi import FastAPI, Query
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel, ConfigDict, Field


MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "edu_academy_seed")
COLLECTION_NAME = "odm_search_sort_pagination_products"

app = FastAPI(title="MongoDB ODM Search/Sorting/Pagination", version="1.0.0")
client: AsyncIOMotorClient | None = None


class ProductOut(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    id: str = Field(alias="_id")
    name: str
    category: str
    price: int
    rating: float


class ProductsPage(BaseModel):
    total: int
    page: int
    page_size: int
    sort_by: str
    sort_dir: Literal["asc", "desc"]
    q: str | None
    items: List[ProductOut]


@app.on_event("startup")
async def startup() -> None:
    global client
    client = AsyncIOMotorClient(MONGODB_URI)

    coll = client[MONGODB_DB][COLLECTION_NAME]
    count = await coll.count_documents({})
    if count > 0:
        return

    await coll.insert_many(
        [
            {"name": "iPhone 14", "category": "Smartphone", "description": "Apple smartphone", "price": 899, "rating": 4.8},
            {"name": "Galaxy S23", "category": "Smartphone", "description": "Samsung flagship phone", "price": 799, "rating": 4.7},
            {"name": "Pixel 8", "category": "Smartphone", "description": "Google Android phone", "price": 699, "rating": 4.6},
            {"name": "MacBook Air", "category": "Laptop", "description": "Apple ultrabook laptop", "price": 1299, "rating": 4.9},
            {"name": "ThinkPad X1", "category": "Laptop", "description": "Business laptop", "price": 1399, "rating": 4.8},
            {"name": "iPad Pro", "category": "Tablet", "description": "Apple tablet device", "price": 999, "rating": 4.7},
            {"name": "Kindle Paperwhite", "category": "Tablet", "description": "E-reader tablet", "price": 159, "rating": 4.5},
            {"name": "Sony WH-1000XM5", "category": "Audio", "description": "Noise canceling headphones", "price": 399, "rating": 4.8},
            {"name": "AirPods Pro", "category": "Audio", "description": "Wireless earbuds", "price": 249, "rating": 4.6},
            {"name": "Logitech MX Master 3S", "category": "Accessories", "description": "Premium wireless mouse", "price": 99, "rating": 4.9},
        ]
    )


@app.on_event("shutdown")
async def shutdown() -> None:
    if client is not None:
        client.close()


@app.get("/products", response_model=ProductsPage)
async def list_products(
    q: str | None = Query(default=None, description="Search text for name/category/description"),
    sort_by: Literal["name", "price", "rating"] = Query(default="name"),
    sort_dir: Literal["asc", "desc"] = Query(default="asc"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=5, ge=1, le=50),
) -> ProductsPage:
    assert client is not None
    coll = client[MONGODB_DB][COLLECTION_NAME]

    query: Dict[str, Any] = {}
    if q:
        query = {
            "$or": [
                {"name": {"$regex": q, "$options": "i"}},
                {"category": {"$regex": q, "$options": "i"}},
                {"description": {"$regex": q, "$options": "i"}},
            ]
        }

    sort_order = 1 if sort_dir == "asc" else -1
    skip_n = (page - 1) * page_size

    total = await coll.count_documents(query)
    cursor = coll.find(query).sort(sort_by, sort_order).skip(skip_n).limit(page_size)
    docs = await cursor.to_list(length=page_size)

    mapped: List[ProductOut] = []
    for d in docs:
        d["_id"] = str(d["_id"])
        mapped.append(ProductOut.model_validate(d))

    return ProductsPage(
        total=total,
        page=page,
        page_size=page_size,
        sort_by=sort_by,
        sort_dir=sort_dir,
        q=q,
        items=mapped,
    )
