# SQLAlchemy ORM — Python examples (`mysql/16_orm`)

Self-contained demos for common relational/ORM topics. Each subfolder has an `example.py` you can run after installing dependencies.

**Themes (from course outline):** data types, keys, relationship types, normalization vs denormalization, CRUD, JOINs, aggregates / `GROUP BY` / `HAVING`, migrations (Alembic).

## Setup

From `mysql/16_orm/` (or repo root with `cd mysql/16_orm`):

```bash
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Run any example:

```bash
python 01_data_types/example.py
```

Examples use **SQLite** by default (`*.db` files next to the script or `:memory:`) so nothing else is required.

## Subfolders

| Folder | Theme |
|--------|--------|
| [`01_data_types`](01_data_types/) | Column / Python types (`Integer`, `String`, `DateTime`, `JSON`, `Enum`, …) |
| [`02_keys`](02_keys/) | Primary key, unique, composite primary key, foreign keys |
| [`03_relationships`](03_relationships/) | one-to-many, many-to-one, many-to-many, one-to-one |
| [`04_normalization`](04_normalization/) | Normalized vs denormalized layout (illustration) |
| [`05_crud`](05_crud/) | Create, read, update, delete with `Session` |
| [`06_joins`](06_joins/) | `join` / `outerjoin` in Core and ORM queries |
| [`07_aggregates_having`](07_aggregates_having/) | `func`, `GROUP BY`, `HAVING` |
| [`08_migrations`](08_migrations/) | Alembic revision + `upgrade` / `downgrade` |

For **migrations**, run `python example.py` inside `08_migrations/` (uses Alembic `upgrade` / `downgrade`).
