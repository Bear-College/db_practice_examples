"""
Міграції / Migrations — Alembic upgrade and downgrade.

Run from this directory:
    python example.py

Requires: pip install -r ../requirements.txt
"""
from __future__ import annotations

import os
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, select

os.chdir(Path(__file__).resolve().parent)


def main() -> None:
    cfg = Config("alembic.ini")
    db_path = Path("08_migrations_lab.db")
    if db_path.exists():
        db_path.unlink()

    print("==> alembic upgrade head")
    command.upgrade(cfg, "head")

    engine = create_engine("sqlite:///08_migrations_lab.db")
    print("Tables after upgrade:", inspect(engine).get_table_names())

    from models import User
    from sqlalchemy.orm import Session

    with Session(engine) as session:
        session.add(User(email="migrations@example.com"))
        session.commit()
        row = session.scalars(select(User).where(User.email == "migrations@example.com")).first()
        print("Seeded user id:", row.id if row else None)

    print("==> alembic downgrade base")
    command.downgrade(cfg, "base")
    print("Tables after downgrade:", inspect(engine).get_table_names())


if __name__ == "__main__":
    main()
