# SQLAlchemy ORM — Python examples (`03_mysql/16_orm`)

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/16_orm/orm_sqlalchemy.md)

These exercises walk through **SQLAlchemy 2.0 ORM** in Python — declarative models, sessions, CRUD, relationships, joins, aggregates, and Alembic migrations. Each subfolder ships with a self-contained `example.py` that creates a fresh **SQLite** database next to the script (no MySQL server required for these specific exercises), so you can run any example with a single command.

**Themes (from the course outline):** data types, keys, relationship types, normalization vs denormalization, CRUD, JOINs, aggregates / `GROUP BY` / `HAVING`, migrations (Alembic).

## Setup

From `03_mysql/16_orm/` (or repo root with `cd 03_mysql/16_orm`):

```bash
python -m venv .venv
source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Run any example:

```bash
python 01_data_types/example.py
```

Each script drops and recreates its tables on every run, so you can re-execute as often as you like.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | Why the example exists (1-2 sentences). |
| **What you'll learn** | ORM constructs trained in this exact exercise. |
| **Tables in play** | Only the columns the example actually touches. |
| **Task** | Concrete requirements (models, session calls, query). |
| **Expected result** | Real stdout from a live `python example.py` run. |
| **Hint** | A single nudge toward the right SQLAlchemy API. |
| **Solution** | Working Python you can paste into `example.py`. |
| **Step-by-step explanation** | How each ORM line maps to SQL and the typical mistakes. |

---

## Map: SQLAlchemy 2.0 ideas

| Theme | API surface |
|--------|-------------|
| **Declarative model** | `class Base(DeclarativeBase): pass`, then `class Thing(Base): __tablename__ = "things"`. |
| **Typed columns** | `Mapped[int] = mapped_column(Integer, primary_key=True)`. |
| **Constraints** | `UniqueConstraint`, `PrimaryKeyConstraint`, `ForeignKey(...)`. |
| **Relationships** | `relationship(back_populates="…", cascade="…", uselist=False, secondary=…)`. |
| **Session** | `with Session(engine) as session: session.add(...); session.commit()`. |
| **Queries** | `select(Model).where(...).order_by(...)`, `session.scalars(...)`, `session.execute(...).all()`. |
| **Aggregates** | `func.count`, `func.sum`, `func.avg` + `.group_by(...).having(...)`. |
| **Joins** | `.join(...)`, `.outerjoin(...)`, `joinedload(rel)` for eager-loading. |
| **Migrations** | Alembic `revision`, `upgrade`, `downgrade` (`command.upgrade(cfg, "head")`). |

---

## Schema touchpoints

Each subfolder defines its **own** tables (so the lessons are independent). For example, `05_crud` creates a single `items` table; `06_joins` creates `departments` + `employees`; and so on. The mapping is laid out per exercise.

---

## Exercise 1 — Typed columns (`01_data_types`)

### Context

The first thing every ORM project needs is a way to declare typed columns. SQLAlchemy 2.0 uses **`Mapped[…]` annotations + `mapped_column(...)`** so the Python type and the SQL type stay in sync — and so type checkers can catch mismatches before you hit the database.

### What you'll learn

- Declaring a model with `DeclarativeBase` and `__tablename__`.
- Mapping common Python types: `int`, `str`, `Decimal`, `float`, `bool`, `datetime`, `dict`, `bytes`, `Enum`.
- How `Numeric(10, 2)`, `String(32)`, `BigInteger`, `Boolean`, `JSON`, `LargeBinary`, `Enum` translate to a DDL fragment.
- Using `default=…` for "filled by Python" defaults and inserting/refreshing through `Session`.

### Tables in play

| Table | Columns |
|---|---|
| `products` | `id`, `sku`, `name`, `price`, `weight_kg`, `units_in_stock`, `is_active`, `created_at`, `release_date`, `attrs`, `photo`, `status` |

### Task

1. Define `class Product(Base)` mapped to `products`.
2. Cover the type matrix: `Integer` PK + autoincrement, `String(32)` unique, `Text`, `Numeric(10, 2)` for money, `Float` nullable, `BigInteger`, `Boolean`, `DateTime` with `default=datetime.utcnow`, `Date` nullable, `JSON` nullable, `LargeBinary` nullable, `Enum(OrderStatus)`.
3. Drop and recreate the schema, insert one row with `Session.add(...) → commit()`, then `session.refresh(p)` and print the row.
4. Print the SQLite DDL fragment via `CreateTable(Product.__table__).compile(dialect=engine.dialect)`.

### Expected result (real output of `python 01_data_types/example.py`)

```text
Inserted: 1 OIL-1L 24.99 {'viscosity': '5W-30', 'brand': 'Demo'} OrderStatus.new

SQLite DDL fragment:

CREATE TABLE products (
	id INTEGER NOT NULL, 
	sku VARCHAR(32) NOT NULL, 
	name TEXT NOT NULL, 
	price NUMERIC(10, 2) NOT NULL, 
	weight_kg FLOAT, 
	units_in_stock BIGINT NOT NULL, 
	is_active BOOLEAN NOT NULL, 
	created_at DATETIME NOT NULL, 
	release_date DATE, 
	attrs JSON, 
	photo BLOB, 
	status VARCHAR(4) NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (sku)
)
```

### Hint

Use `Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)`. For money always use `Numeric(10, 2)` with `Decimal`, never `Float`.

### Solution

```python
import enum
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    JSON, BigInteger, Boolean, Date, DateTime, Enum, Float,
    Integer, LargeBinary, Numeric, String, Text, create_engine,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session


class Base(DeclarativeBase):
    pass


class OrderStatus(str, enum.Enum):
    new = "new"
    paid = "paid"


class Product(Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    sku: Mapped[str] = mapped_column(String(32), unique=True)
    name: Mapped[str] = mapped_column(Text)
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    weight_kg: Mapped[float | None] = mapped_column(Float, nullable=True)
    units_in_stock: Mapped[int] = mapped_column(BigInteger, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    release_date: Mapped[datetime | None] = mapped_column(Date, nullable=True)
    attrs: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    photo: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    status: Mapped[OrderStatus] = mapped_column(Enum(OrderStatus), default=OrderStatus.new)


engine = create_engine("sqlite:///01_data_types_lab.db", echo=False)
Base.metadata.drop_all(engine)
Base.metadata.create_all(engine)

with Session(engine) as session:
    p = Product(
        sku="OIL-1L",
        name="Engine oil 1L",
        price=Decimal("24.99"),
        weight_kg=0.95,
        attrs={"viscosity": "5W-30", "brand": "Demo"},
    )
    session.add(p)
    session.commit()
    session.refresh(p)
    print("Inserted:", p.id, p.sku, p.price, p.attrs, p.status)
```

### Step-by-step explanation

1. **`DeclarativeBase`** is the SQLAlchemy 2.0 base class for all models. Each `Base` subclass becomes a row class **and** a table mapping at the same time.
2. **`Mapped[T]` annotations** carry the Python-side type. Mypy/Pyright use them to catch field misuse; SQLAlchemy uses them to pick a SQL type when one isn't given to `mapped_column`.
3. **Type pairings** matter: `Numeric(10, 2)` for money (binary-exact, total 10 digits, 2 fractional) — never `Float`, which loses cents. `BigInteger` for inventory counts that can blow past `int32`.
4. **`default=…`** is evaluated **in Python** at flush time (so `default=datetime.utcnow` produces wall-clock time on the client). Use `server_default=…` if you want the database to assign the value.
5. **`Session.add(p)`** stages the row; **`commit()`** flushes the SQL `INSERT` and commits the transaction. **`session.refresh(p)`** re-`SELECT`s the row to populate server-generated columns (`id`, `created_at`).
6. **DDL inspection**: `CreateTable(Product.__table__).compile(...)` renders the `CREATE TABLE` for the engine's dialect — handy for proving to yourself that your annotations produced the SQL you expected.

---

## Exercise 2 — Keys: primary, unique, composite, foreign (`02_keys`)

### Context

Real schemas need more than a single integer PK. You typically also have a **natural unique** (an email or SKU that should be one-per-row at the database level), occasionally a **composite primary key** (junction tables), and **foreign keys** with cascade rules so deletes don't orphan child rows.

### What you'll learn

- Surrogate PK + natural `UniqueConstraint`.
- **Composite primary key** via `PrimaryKeyConstraint("user_id", "team_id")`.
- **Foreign keys** with `ondelete="CASCADE"`.
- Pairing `relationship(...)` on both sides with `back_populates="…"`.

### Tables in play

| Table | Columns |
|---|---|
| `users` | `id` (PK), `email` (unique), `name` |
| `posts` | `id` (PK), `user_id` (FK → users.id, cascade), `title` |
| `memberships` | `user_id` + `team_id` (composite PK; user_id is FK → users.id) |

### Task

1. Define `User` with `id` PK and a `UniqueConstraint("email")`.
2. Define `Post` with a `ForeignKey("users.id", ondelete="CASCADE")` and a `relationship(back_populates="posts")`.
3. Define `Membership` with `PrimaryKeyConstraint("user_id", "team_id")` and `ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE")`.
4. Attach the reverse relationship on `User` (`User.posts = relationship(..., back_populates="author", cascade="all, delete-orphan")`).
5. Insert one user, two posts, one membership; in a second session, fetch the user by email and print `posts: len(u.posts)`.

### Expected result (real output of `python 02_keys/example.py`)

```text
User: 1 ada@example.com posts: 2
```

### Hint

Use `session.flush()` after inserting the user but before the children — this populates `u.id` so you can hand it to `Post(user_id=u.id, …)` in the same session.

### Solution

```python
from sqlalchemy import (
    ForeignKey, ForeignKeyConstraint, PrimaryKeyConstraint,
    String, UniqueConstraint, create_engine, select,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    __table_args__ = (UniqueConstraint("email", name="uq_users_email"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(120))
    name: Mapped[str] = mapped_column(String(80))


class Membership(Base):
    __tablename__ = "memberships"
    __table_args__ = (
        PrimaryKeyConstraint("user_id", "team_id", name="pk_memberships"),
        ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
    )
    user_id: Mapped[int] = mapped_column()
    team_id: Mapped[int] = mapped_column()
    role: Mapped[str] = mapped_column(String(40), default="member")


class Post(Base):
    __tablename__ = "posts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    title: Mapped[str] = mapped_column(String(200))
    author: Mapped[User] = relationship(back_populates="posts")


User.posts = relationship("Post", back_populates="author",
                          cascade="all, delete-orphan")
```

### Step-by-step explanation

1. **`UniqueConstraint("email", name="uq_users_email")`** lives in `__table_args__` (a tuple). Giving the constraint an explicit `name=` lets you target it by name in Alembic migrations.
2. **Composite PK via `PrimaryKeyConstraint("user_id", "team_id")`** — this is the canonical pattern for **junction tables** that also carry metadata (`role` here). Each column alone is **not** unique; the **pair** is.
3. **`ForeignKey(..., ondelete="CASCADE")`** is a database-side rule: when the parent row is deleted, the engine deletes the child. Note: cascade only fires when the engine enforces it (PRAGMA in SQLite, default in MySQL/InnoDB with `FOREIGN_KEY_CHECKS=ON`).
4. **`relationship(back_populates="…")`** on both sides means assigning `post.author = user` automatically appears in `user.posts`. **`cascade="all, delete-orphan"`** on the parent makes `session.delete(user)` also delete its posts at the ORM level (independent of the DB-side `ondelete`).
5. **`session.flush()`** sends pending SQL to the DB **without committing** — it forces `users.id` to be populated so subsequent child inserts can reference it.

---

## Exercise 3 — Relationship cardinalities (`03_relationships`)

### Context

Almost every schema mixes three relationship kinds: **one-to-many** (author → books), **many-to-many** (students ↔ courses through a junction table), and **one-to-one** (user ↔ profile). SQLAlchemy expresses all three with a single `relationship(...)` call — only the flags change.

### What you'll learn

- One-to-many / many-to-one with `back_populates` on both sides.
- Many-to-many with a `secondary=Table(...)` association table.
- One-to-one by adding `uselist=False` on the parent side + `unique=True` on the FK.
- `cascade="all, delete-orphan"` to propagate deletes.

### Tables in play

| Table | Columns |
|---|---|
| `authors` | `id`, `name` |
| `books` | `id`, `title`, `author_id` → authors.id |
| `students` | `id`, `name` |
| `courses` | `id`, `code` |
| `student_course` | `student_id`, `course_id` (composite PK; FKs to both sides) |
| `users` | `id`, `login` (unique) |
| `profiles` | `id`, `user_id` (unique → users.id), `bio` |

### Task

1. Define `Author` and `Book` for **one-to-many**, with `Author.books` and `Book.author` linked via `back_populates`. Cascade `delete-orphan` so removing an `Author` also removes their `Book` children.
2. Define `Student`, `Course`, and a junction `Table("student_course", …, primary_key=True, primary_key=True)`. Use `relationship(secondary=student_course, back_populates="…")` on both ORM sides.
3. Define `User` and `Profile` as **one-to-one** by setting `uselist=False` on `User.profile` and `unique=True` on `Profile.user_id`.
4. In `main()`: create one `Author` with two books (via `a.books.extend([...])`), one `Student` with two courses, one `User` with one `Profile`. Commit. In a fresh session, fetch each and print the names.

### Expected result (real output of `python 03_relationships/example.py`)

```text
Author → books: Le Guin ['The Left Hand of Darkness', 'The Dispossessed']
Student ↔ courses: Sam ['DB-101', 'PY-202']
User 1–1 profile: neo The One
```

### Hint

For many-to-many, the association `Table` lives in `Base.metadata` (not as a `Mapped` class). Use plain `Column(ForeignKey(...), primary_key=True)` for both columns.

### Solution

```python
from typing import List
from sqlalchemy import Column, ForeignKey, String, Table, create_engine, select
from sqlalchemy.orm import (
    DeclarativeBase, Mapped, mapped_column, relationship, Session,
)


class Base(DeclarativeBase):
    pass


student_course = Table(
    "student_course", Base.metadata,
    Column("student_id", ForeignKey("students.id", ondelete="CASCADE"), primary_key=True),
    Column("course_id",  ForeignKey("courses.id",  ondelete="CASCADE"), primary_key=True),
)


class Student(Base):
    __tablename__ = "students"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(80))
    courses: Mapped[List["Course"]] = relationship(
        secondary=student_course, back_populates="students")


class Course(Base):
    __tablename__ = "courses"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(20))
    students: Mapped[List[Student]] = relationship(
        secondary=student_course, back_populates="courses")


class Author(Base):
    __tablename__ = "authors"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(80))
    books: Mapped[List["Book"]] = relationship(
        back_populates="author", cascade="all, delete-orphan")


class Book(Base):
    __tablename__ = "books"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(200))
    author_id: Mapped[int] = mapped_column(ForeignKey("authors.id"))
    author: Mapped[Author] = relationship(back_populates="books")


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    login: Mapped[str] = mapped_column(String(40), unique=True)
    profile: Mapped["Profile | None"] = relationship(
        back_populates="user", uselist=False, cascade="all, delete-orphan")


class Profile(Base):
    __tablename__ = "profiles"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True)
    bio: Mapped[str] = mapped_column(String(500))
    user: Mapped[User] = relationship(back_populates="profile")
```

### Step-by-step explanation

1. **One-to-many** is asymmetric: the **child** holds the FK (`Book.author_id`), the **parent** holds the collection (`Author.books`). `back_populates="…"` keeps them in sync in memory.
2. **`cascade="all, delete-orphan"`** at the parent means "if a `Book` is unhooked from its `Author`, delete the `Book`". Without `delete-orphan`, an unhooked book would survive as orphan in the table.
3. **Many-to-many** uses a plain `Table` (not a `Mapped` class) named in `secondary=`. Both ends say `secondary=student_course`. The composite primary key on the junction table prevents duplicate enrolments at the DB level.
4. **One-to-one** is two tricks combined: `uselist=False` on the parent's `relationship` (so SQLAlchemy returns a scalar, not a list), plus `unique=True` on the child's FK column (so the database enforces at-most-one child).
5. **Reading back**: `a.books` and `s.courses` are accessed as plain Python lists; SQLAlchemy issues the lazy `SELECT` on first access (one extra round-trip per attribute — switch to `joinedload` to fold into one query).

---

## Exercise 4 — Normalization vs denormalization (`04_normalization`)

### Context

Newcomers often "duplicate" data into wide tables ("just put customer_name on every order line") because it feels easier. The lab shows the trade-off side-by-side: a **3NF** layout (`customers`, `orders`, `order_lines`) versus a **denormalized** flat table that repeats customer columns on every row — and the update anomalies that come with it.

### What you'll learn

- Splitting data across three normalized tables related by FKs.
- Building the same lab as one wide table for comparison.
- Why **two separate `DeclarativeBase` subclasses** keep the two schemas independent.

### Tables in play

| Table | Columns |
|---|---|
| `norm_customers` | `id`, `name`, `phone` |
| `norm_orders` | `id`, `customer_id` → norm_customers.id, `ref` |
| `norm_order_lines` | `id`, `order_id` → norm_orders.id, `sku`, `qty`, `unit_price` |
| `denorm_order_lines_flat` | `id`, `order_ref`, `customer_name`, `customer_phone`, `sku`, `qty`, `notes` |

### Task

1. Define `NormBase(DeclarativeBase)` with three models: `Customer`, `NormOrder`, `NormOrderLine` (FK chain).
2. Define a **separate** `DenormBase(DeclarativeBase)` with one model `OrderLineFlat` that repeats `customer_name`, `customer_phone` on every row.
3. Create both metadatas, insert one normalized order with one line, one denormalized flat line.
4. Print the table names from each metadata.

### Expected result (real output of `python 04_normalization/example.py`)

```text
Normalized tables: ['norm_customers', 'norm_orders', 'norm_order_lines']
Denormalized flat: ['denorm_order_lines_flat']
```

### Hint

Two declarative bases share the same engine but have separate `metadata` registries — call `.metadata.create_all(engine)` on each.

### Solution

```python
from decimal import Decimal
from sqlalchemy import ForeignKey, Numeric, String, Text, create_engine
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session


class NormBase(DeclarativeBase):
    pass


class Customer(NormBase):
    __tablename__ = "norm_customers"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(40))
    orders: Mapped[list["NormOrder"]] = relationship(back_populates="customer")


class NormOrder(NormBase):
    __tablename__ = "norm_orders"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("norm_customers.id"))
    ref: Mapped[str] = mapped_column(String(40))
    customer: Mapped[Customer] = relationship(back_populates="orders")
    lines: Mapped[list["NormOrderLine"]] = relationship(
        back_populates="order", cascade="all, delete-orphan")


class NormOrderLine(NormBase):
    __tablename__ = "norm_order_lines"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("norm_orders.id"))
    sku: Mapped[str] = mapped_column(String(40))
    qty: Mapped[int] = mapped_column()
    unit_price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    order: Mapped[NormOrder] = relationship(back_populates="lines")


class DenormBase(DeclarativeBase):
    pass


class OrderLineFlat(DenormBase):
    __tablename__ = "denorm_order_lines_flat"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    order_ref: Mapped[str] = mapped_column(String(40))
    customer_name: Mapped[str] = mapped_column(String(120))
    customer_phone: Mapped[str] = mapped_column(String(40))
    sku: Mapped[str] = mapped_column(String(40))
    qty: Mapped[int] = mapped_column()
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
```

### Step-by-step explanation

1. **3NF (third normal form)** in plain English: every non-key column depends on the whole key, and only on the key. In `norm_order_lines` the price/qty depend on the line; the customer's name doesn't, so it lives in `norm_customers`.
2. **Denormalized layout** repeats `customer_name` and `customer_phone` on every line. It's faster to read with no joins, but **update anomalies** appear: changing a customer's phone now means `UPDATE` across many rows; if one of them is missed, the data is inconsistent.
3. **Two declarative bases** keep the schemas independent. They share the same engine, but `NormBase.metadata.create_all(engine)` and `DenormBase.metadata.create_all(engine)` are called separately — handy when you really do want two unrelated mini-schemas in the same lab DB.
4. **Cascade on `lines`** mirrors business reality: deleting an order should delete its lines, never the other way around.
5. **When to denormalize?** Pre-aggregated reports, read-heavy caches, time-series snapshots. The rule of thumb: **normalize for writes, denormalize for reads** — and document the denormalization with a comment that says where the source of truth lives.

---

## Exercise 5 — CRUD with `Session` (`05_crud`)

### Context

Every ORM project boils down to four verbs: **Create**, **Read**, **Update**, **Delete**. SQLAlchemy 2.0 uses a `Session` as a unit-of-work: you stage changes via Python attribute access, then `commit()` flushes them all together.

### What you'll learn

- `session.add(model)` and `session.add_all([...])` for **Create**.
- `session.scalars(select(Model).where(...))` for **Read** (single + multiple rows).
- Mutating an attached instance for **Update** (no SQL by hand).
- `session.delete(row)` then `commit()` for **Delete**.
- The `with Session(engine) as session:` context manager and why it auto-rolls-back on exception.

### Tables in play

| Table | Columns |
|---|---|
| `items` | `id` PK, `name`, `qty` |

### Task

1. Define a single-table model `Item(id, name, qty)`.
2. **Create**: add two items `("Bolt M8", 100)` and `("Washer", 250)`.
3. **Read**: load the "Bolt M8" row with `session.scalars(select(Item).where(Item.name == "Bolt M8")).one()` and the full ordered list.
4. **Update**: fetch `Item` with `id = 1`, subtract `3` from `qty`, commit. Re-read with `session.get(Item, 1)`.
5. **Delete**: fetch `Item` with `id = 2`, call `session.delete(row)`, commit. Re-read the survivors.

### Expected result (real output of `python 05_crud/example.py`)

```text
READ one / all: 1 ['Bolt M8', 'Washer']
After UPDATE: 97
After DELETE: [(1, 'Bolt M8')]
```

### Hint

Use a fresh `with Session(engine) as session:` block for each step. Inside the same block, set `row.qty -= 3` and let SQLAlchemy emit the `UPDATE` on `commit()`.

### Solution

```python
from sqlalchemy import String, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session


class Base(DeclarativeBase):
    pass


class Item(Base):
    __tablename__ = "items"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100))
    qty: Mapped[int] = mapped_column(default=0)


engine = create_engine("sqlite:///05_crud_lab.db", echo=False)
Base.metadata.drop_all(engine)
Base.metadata.create_all(engine)

with Session(engine) as session:
    session.add_all([Item(name="Bolt M8", qty=100), Item(name="Washer", qty=250)])
    session.commit()

with Session(engine) as session:
    one = session.scalars(select(Item).where(Item.name == "Bolt M8")).one()
    all_rows = session.scalars(select(Item).order_by(Item.id)).all()
    print("READ one / all:", one.id, [r.name for r in all_rows])

with Session(engine) as session:
    row = session.scalars(select(Item).where(Item.id == 1)).one()
    row.qty -= 3
    session.commit()

with Session(engine) as session:
    print("After UPDATE:", session.get(Item, 1).qty)

with Session(engine) as session:
    row = session.scalars(select(Item).where(Item.id == 2)).one()
    session.delete(row)
    session.commit()

with Session(engine) as session:
    remaining = session.scalars(select(Item)).all()
    print("After DELETE:", [(r.id, r.name) for r in remaining])
```

### Step-by-step explanation

1. **`with Session(engine) as session:`** opens a unit-of-work. On normal exit it commits *if anything was committed*; on exception it rolls back. That's why every step in the lab uses its own block.
2. **Create**: `session.add(item)` stages an `INSERT`. `session.add_all([...])` is the bulk-friendly variant. The SQL is sent at `flush()` (which `commit()` triggers).
3. **Read**: `select(Item).where(...)` builds a 2.0-style statement. `session.scalars(...)` unwraps single-column rows; `.one()` requires exactly one row (else `MultipleResultsFound`/`NoResultFound`); `.all()` returns the list.
4. **Update**: there is **no `update()` method on the row.** You assign Python attributes (`row.qty -= 3`); SQLAlchemy compares them to the original values and emits the right `UPDATE` on commit.
5. **Delete**: `session.delete(row)` marks the row for deletion; `commit()` issues the `DELETE`. If the row had FK-linked children, cascade rules decide what happens to them.
6. **`session.get(Item, 1)`** is the fast path for "fetch by PK": it checks the session's identity map first and avoids a query when possible.

---

## Exercise 6 — JOINs in Core/ORM (`06_joins`)

### Context

Reports almost always join: "employees with department name" needs `INNER JOIN departments`, while "employees and their department, even if unassigned" needs `LEFT OUTER JOIN`. SQLAlchemy lets you build both with `.join(...)` and `.outerjoin(...)`, and lets you avoid the N+1 problem with **eager loading** via `joinedload`.

### What you'll learn

- Explicit `INNER JOIN` via `select(...).join(Table, on_clause)`.
- `LEFT OUTER JOIN` via `.outerjoin(...)` (right-side columns become `None`).
- Eager loading a relationship with `joinedload(rel)` — one SQL query, no N+1.

### Tables in play

| Table | Columns |
|---|---|
| `departments` | `id`, `name` |
| `employees` | `id`, `name`, `dept_id` → departments.id (nullable) |

### Task

1. Define `Department` and `Employee` with a nullable FK from `Employee.dept_id` to `Department.id`.
2. Seed one `Department` "Service" with two employees (`Ann`, `Bob`) and one floating employee (`Temp`, `dept=None`).
3. Build three queries and print their results:
   - `INNER JOIN`: `select(Employee.name, Department.name).join(Department, Employee.dept_id == Department.id)` (drops `Temp`).
   - `LEFT OUTER JOIN`: same statement but with `.outerjoin(...)` (keeps `Temp`, department is `None`).
   - **Eager load**: `select(Employee).options(joinedload(Employee.dept))` and read `e.dept.name` per row.

### Expected result (real output of `python 06_joins/example.py`)

```text
INNER JOIN: [('Ann', 'Service'), ('Bob', 'Service')]
LEFT OUTER JOIN: [('Ann', 'Service'), ('Bob', 'Service'), ('Temp', None)]
joinedload: [('Ann', 'Service'), ('Bob', 'Service'), ('Temp', None)]
```

### Hint

`.outerjoin` is "LEFT OUTER JOIN" by default in SQLAlchemy. `joinedload(rel)` emits one SQL query with a `LEFT OUTER JOIN` and **populates the relationship eagerly** instead of lazy-loading per-instance.

### Solution

```python
from sqlalchemy import ForeignKey, String, create_engine, select
from sqlalchemy.orm import (
    DeclarativeBase, Mapped, mapped_column, relationship,
    Session, joinedload,
)


class Base(DeclarativeBase):
    pass


class Department(Base):
    __tablename__ = "departments"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(80))
    employees: Mapped[list["Employee"]] = relationship(back_populates="dept")


class Employee(Base):
    __tablename__ = "employees"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(80))
    dept_id: Mapped[int | None] = mapped_column(
        ForeignKey("departments.id"), nullable=True)
    dept: Mapped[Department | None] = relationship(back_populates="employees")


with Session(engine) as session:
    stmt = (
        select(Employee.name, Department.name)
        .join(Department, Employee.dept_id == Department.id)
        .order_by(Employee.name)
    )
    print("INNER JOIN:", session.execute(stmt).all())

    stmt_left = (
        select(Employee.name, Department.name)
        .outerjoin(Department, Employee.dept_id == Department.id)
        .order_by(Employee.name)
    )
    print("LEFT OUTER JOIN:", session.execute(stmt_left).all())

with Session(engine) as session:
    emps = (
        session.scalars(select(Employee).options(joinedload(Employee.dept)))
        .unique().all()
    )
    print("joinedload:", [(e.name, e.dept.name if e.dept else None) for e in emps])
```

### Step-by-step explanation

1. **`.join(Right, on_clause)`** emits `INNER JOIN`. Any row in `employees` without a matching department is silently dropped — that's why `Temp` disappears.
2. **`.outerjoin(Right, on_clause)`** emits `LEFT OUTER JOIN`. The right-side columns become `None` for unmatched rows, so `Temp` survives with `department = None`.
3. **`select(Employee.name, Department.name)`** returns **tuples** — `session.execute(stmt).all()` yields a list of `Row` objects you can unpack. Use `session.scalars(...)` only when you `select(SingleModelOrColumn)`.
4. **`joinedload(Employee.dept)`** is the eager-loading option: SQLAlchemy turns `SELECT … FROM employees` into `SELECT … FROM employees LEFT OUTER JOIN departments ON …` and stamps each `Employee.dept` immediately — no N+1.
5. **`.unique()`** before `.all()` is required with `joinedload` on collections (and recommended on scalars) because the joined SQL can return duplicate parent rows; `unique()` de-dupes by primary key on the ORM side.

---

## Exercise 7 — Aggregates, `GROUP BY`, `HAVING` (`07_aggregates_having`)

### Context

A product manager wants "average price per category, but only categories with at least one product, ordered alphabetically" — plus a one-shot grand total. This is **`func.count` + `func.avg` + `group_by` + `having`** on the ORM side, exactly matching the SQL clauses.

### What you'll learn

- Building aggregate expressions with the **`func`** namespace.
- Labelling them with `.label("…")` so they have stable column names.
- `.group_by(...)` and `.having(...)` on a `select(...)` statement.
- One-shot scalar aggregates via `session.scalar(select(func.sum(...)))`.

### Tables in play

| Table | Columns |
|---|---|
| `parts` | `id`, `category`, `sku`, `price` |

### Task

1. Define `Part(id, category, sku, price)` with `price` as `Numeric(10, 2)`.
2. Seed three rows: `("filters", "F-1", 12.00)`, `("filters", "F-2", 15.00)`, `("brakes", "B-1", 40.00)`.
3. Build a `select` returning `category`, `func.count(Part.id) AS n`, `func.avg(Part.price) AS avg_price`, grouped by `category`, with `HAVING count >= 1`, ordered by `category`.
4. Print the result rows. Then `session.scalar(select(func.sum(Part.price)))` to print the grand total.

### Expected result (real output of `python 07_aggregates_having/example.py`)

```text
GROUP BY + HAVING: [('brakes', 1, 40.0), ('filters', 2, 13.5)]
SUM(all prices): 67.00
```

### Hint

`select(Part.category, func.count(Part.id).label("n"), func.avg(Part.price).label("avg_price")).group_by(Part.category).having(func.count(Part.id) >= 1)`.

### Solution

```python
from decimal import Decimal
from sqlalchemy import Numeric, String, create_engine, func, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session


class Base(DeclarativeBase):
    pass


class Part(Base):
    __tablename__ = "parts"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    category: Mapped[str] = mapped_column(String(40))
    sku: Mapped[str] = mapped_column(String(40))
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))


with Session(engine) as session:
    stmt = (
        select(
            Part.category,
            func.count(Part.id).label("n"),
            func.avg(Part.price).label("avg_price"),
        )
        .group_by(Part.category)
        .having(func.count(Part.id) >= 1)
        .order_by(Part.category)
    )
    print("GROUP BY + HAVING:", session.execute(stmt).all())

    total = session.scalar(select(func.sum(Part.price)))
    print("SUM(all prices):", total)
```

### Step-by-step explanation

1. **`func.<name>(args)`** is SQLAlchemy's lazy proxy for SQL functions: `func.count(Part.id)` becomes `COUNT(parts.id)`, `func.avg(Part.price)` becomes `AVG(parts.price)`. The names are passed through verbatim to the SQL dialect — `func.lower("X")` works the same way.
2. **`.label("avg_price")`** assigns an alias to the column so callers can reference it by name. Without a label the resulting column comes out with a backend-specific generated name (`avg_1`, etc.).
3. **`.group_by(Part.category)`** maps directly to SQL `GROUP BY parts.category`. Every non-aggregated column in `select(...)` must appear in `group_by` (this is the SQL standard, and MySQL with `ONLY_FULL_GROUP_BY` enforces it).
4. **`.having(...)`** filters **groups**, not rows. It can mention aggregates (`func.count(Part.id) >= 1`), unlike `.where(...)`, which can't.
5. **`session.scalar(...)`** returns the first column of the first row (or `None`). Perfect for one-shot aggregates like a grand total.
6. **Why the avg shows `13.5` (float) for filters?** SQLite returns `AVG()` as a float by default. On MySQL/PostgreSQL with `Numeric`, you'd typically get a `Decimal('13.50')`. Cast explicitly with `func.cast(... , Numeric(10, 2))` if you need stability across backends.

---

## Exercise 8 — Migrations with Alembic (`08_migrations`)

### Context

Schemas evolve: new columns, renamed tables, added indexes. Hand-editing the production DB is a recipe for drift. **Alembic** is the migration tool that ships with SQLAlchemy: each schema change becomes a **revision script** with `upgrade()` and `downgrade()` functions, versioned in git, applied in order.

### What you'll learn

- The minimal Alembic layout: `alembic.ini`, `alembic/env.py`, `alembic/versions/*.py`, plus a `models.py` registered as `target_metadata`.
- A revision's `upgrade()` (apply the change) and `downgrade()` (revert it).
- Driving the migration from Python via `alembic.command.upgrade(cfg, "head")` and `command.downgrade(cfg, "base")`.

### Tables in play

| Table | Columns |
|---|---|
| `users` | `id` PK, `email` (unique) |
| `alembic_version` | Single-column bookkeeping table that records the current revision. |

### Task

1. Write `models.py` with a single `User` model (id, email unique).
2. Write a revision `001_create_users_table.py` whose `upgrade()` calls `op.create_table(...)` for `users` and whose `downgrade()` calls `op.drop_table("users")`.
3. Write `example.py` that:
   - Deletes any existing SQLite file from a previous run.
   - Calls `command.upgrade(cfg, "head")` and prints the resulting table list (must include `users` and `alembic_version`).
   - Inserts one user via `Session`, prints its id.
   - Calls `command.downgrade(cfg, "base")` and prints the resulting table list (no `users`).

### Expected result (real output of `python 08_migrations/example.py`)

```text
INFO  [alembic.runtime.migration] Context impl SQLiteImpl.
INFO  [alembic.runtime.migration] Will assume non-transactional DDL.
INFO  [alembic.runtime.migration] Running upgrade  -> 001, create users table
INFO  [alembic.runtime.migration] Context impl SQLiteImpl.
INFO  [alembic.runtime.migration] Will assume non-transactional DDL.
INFO  [alembic.runtime.migration] Running downgrade 001 -> , create users table
==> alembic upgrade head
Tables after upgrade: ['alembic_version', 'users']
Seeded user id: 1
==> alembic downgrade base
Tables after downgrade: ['alembic_version']
```

### Hint

Inside `alembic/env.py` import `from models import Base` and set `target_metadata = Base.metadata` so Alembic's autogenerate (if you use it later) knows your models.

### Solution

```python
from pathlib import Path
import os

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, select
from sqlalchemy.orm import Session

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
    with Session(engine) as session:
        session.add(User(email="migrations@example.com"))
        session.commit()
        row = session.scalars(
            select(User).where(User.email == "migrations@example.com")
        ).first()
        print("Seeded user id:", row.id if row else None)

    print("==> alembic downgrade base")
    command.downgrade(cfg, "base")
    print("Tables after downgrade:", inspect(engine).get_table_names())
```

And the revision script (`alembic/versions/001_create_users_table.py`):

```python
import sqlalchemy as sa
from alembic import op

revision = "001"
down_revision = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("email", sa.String(length=120), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
    )


def downgrade() -> None:
    op.drop_table("users")
```

### Step-by-step explanation

1. **`Config("alembic.ini")`** loads the standard Alembic config file. The `sqlalchemy.url` setting there points at the database; `script_location` points at the `alembic/` folder.
2. **`command.upgrade(cfg, "head")`** applies every revision from the current state up to the latest. `"head"` is the symbolic name for "most recent"; `"base"` is "no revisions applied".
3. **Revision metadata** (`revision = "001"`, `down_revision = None`) chains revisions into a directed graph. Alembic stores the current revision in the `alembic_version` table — that's the second table you see after upgrade.
4. **`op.create_table(...)`** and **`op.drop_table(...)`** are dialect-agnostic helpers from `alembic.op`. Always write a **reversible** `downgrade()` — even if it's just `op.drop_table` — so rolling back a bad release is trivial.
5. **`inspect(engine).get_table_names()`** is a dialect-agnostic way to list the tables — useful in tests to assert that a migration ran successfully.
6. **Order of operations** in production: never edit a previous revision; always create a new one. Never run `downgrade` against prod unless you have a tested backup — `downgrade` operations that drop columns are destructive.

---

## Troubleshooting: my ORM example won't run

| Symptom | Likely fix |
|---|---|
| `ModuleNotFoundError: No module named 'sqlalchemy'` | Activate the virtualenv: `source .venv/bin/activate`. |
| `sqlite3.OperationalError: no such table` | The script didn't run `Base.metadata.create_all(engine)` before the first `INSERT`. |
| `MultipleResultsFound` / `NoResultFound` | `.one()` expects exactly one row; use `.first()` (returns `None`) or `.all()`. |
| `DetachedInstanceError` reading `obj.relation` | The `Session` closed before the lazy load. Re-fetch inside a new `with Session(engine) as session:` block, or use `joinedload`. |
| `IntegrityError: UNIQUE constraint failed` | Re-running without `drop_all`. Either drop before create, or use a fresh SQLite file. |
| N+1 SELECTs in logs (with `echo=True`) | Add `.options(joinedload(Model.rel))` or `.options(selectinload(Model.rel))`. |
| Alembic `Target database is not up to date` | Run `alembic upgrade head` before generating a new autogenerate revision. |

If you want to run **all** examples at once: `for d in 0[1-8]_*; do (cd "$d" && python example.py); done`.
