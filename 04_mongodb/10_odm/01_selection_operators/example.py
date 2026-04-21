#!/usr/bin/env python3
"""
MongoEngine ODM: selection operators.

Covers operators from the lesson table:
$eq, $ne, $gt, $gte, $lt, $lte, $in, $nin, $and, $or, $not, $exists, $regex
"""

from __future__ import annotations

import os

from mongoengine import BooleanField, Document, IntField, StringField, connect
from mongoengine.queryset.visitor import Q


MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB = os.getenv("MONGODB_DB", "edu_academy_seed")


class Person(Document):
    name = StringField(required=True, max_length=128)
    age = IntField(required=True, min_value=0)
    status = StringField(required=True, max_length=32)
    active = BooleanField(required=True, default=True)
    email = StringField(required=False, max_length=256)

    meta = {"collection": "odm_selection_operators_people"}


def print_result(label: str, qs) -> None:
    names = [d.name for d in qs.order_by("name")]
    print(f"{label}: count={len(names)} -> {names}")


def main() -> int:
    connect(db=MONGODB_DB, host=MONGODB_URI)

    Person.drop_collection()
    Person.objects.insert(
        [
            Person(name="Vlad", age=25, status="active", active=True, email="vlad@gmail.com"),
            Person(name="Anna", age=30, status="pending", active=True),
            Person(name="Bohdan", age=17, status="deleted", active=False, email="bohdan@example.com"),
            Person(name="Chris", age=19, status="active", active=True, email="chris@gmail.com"),
            Person(name="Daria", age=65, status="pending", active=False),
        ]
    )

    print_result("$eq   age=25", Person.objects(age=25))
    print_result("$ne   age!=30", Person.objects(age__ne=30))
    print_result("$gt   age>18", Person.objects(age__gt=18))
    print_result("$gte  age>=18", Person.objects(age__gte=18))
    print_result("$lt   age<65", Person.objects(age__lt=65))
    print_result("$lte  age<=65", Person.objects(age__lte=65))
    print_result("$in   status in [active,pending]", Person.objects(status__in=["active", "pending"]))
    print_result("$nin  status not in [deleted]", Person.objects(status__nin=["deleted"]))

    print_result(
        "$and  age>18 AND active=True",
        Person.objects(Q(age__gt=18) & Q(active=True)),
    )
    print_result(
        "$or   age<18 OR active=False",
        Person.objects(Q(age__lt=18) | Q(active=False)),
    )
    print_result(
        "$not  NOT(age<18)",
        Person.objects(~Q(age__lt=18)),
    )

    print_result("$exists email exists", Person.objects(email__exists=True))
    print_result("$regex name starts with Vlad", Person.objects(name__regex=r"^Vlad"))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
