#!/usr/bin/env python3
"""
MongoDB ODM lesson using MongoEngine.

This module demonstrates a simple object-document mapping workflow:
- connect
- define document model
- create records
- query/update/delete records

Defaults:
  MONGODB_URI=mongodb://localhost:27017
  MONGODB_DB=edu_academy_seed
"""

from __future__ import annotations

import os
from datetime import datetime

from mongoengine import DateTimeField, Document, IntField, StringField, connect


MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "edu_academy_seed")


class Product(Document):
    name = StringField(required=True, max_length=128)
    category = StringField(required=True, max_length=64)
    price = IntField(required=True, min_value=0)
    created_at = DateTimeField(default=datetime.utcnow)

    meta = {"collection": "odm_products"}


def main() -> int:
    connect(db=MONGODB_DB, host=MONGODB_URI)

    # Reset collection for repeatable output.
    Product.drop_collection()

    Product(name="iPhone 14", category="Smartphone", price=899).save()
    Product(name="MacBook Air", category="Laptop", price=1299).save()
    Product(name="Galaxy S23", category="Smartphone", price=799).save()

    all_docs = Product.objects.order_by("name")
    print(f"All products count: {all_docs.count()}")
    for doc in all_docs:
        print(f"  {doc.name} | {doc.category} | {doc.price}")

    phones = Product.objects(category="Smartphone").order_by("-price")
    print(f"\nSmartphones count: {phones.count()}")
    for doc in phones:
        print(f"  {doc.name} | {doc.price}")

    Product.objects(name="iPhone 14").update_one(set__price=849)
    iphone = Product.objects.get(name="iPhone 14")
    print(f"\nUpdated iPhone 14 price: {iphone.price}")

    Product.objects(name="Galaxy S23").delete()
    print(f"Remaining after delete: {Product.objects.count()}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
