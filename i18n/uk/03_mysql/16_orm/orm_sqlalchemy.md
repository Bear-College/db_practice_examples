# ORM SQLAlchemy — приклади на Python (`03_mysql/16_orm`)

> Translation / Переклад: [English](../../../../03_mysql/16_orm/orm_sqlalchemy.md)

Ці вправи проходять **SQLAlchemy 2.0 ORM** у Python — декларативні моделі, сесії, CRUD, зв'язки, join-и, агрегати та міграції Alembic. У кожному підкаталозі є самодостатній `example.py`, що створює свіжу базу **SQLite** поруч зі скриптом (для цих вправ MySQL-сервер не потрібен), тож кожен приклад запускається однією командою.

**Теми (з програми курсу):** типи даних, ключі, типи зв'язків, нормалізація проти денормалізації, CRUD, JOIN-и, агрегати / `GROUP BY` / `HAVING`, міграції (Alembic).

## Налаштування

З каталогу `03_mysql/16_orm/` (або з кореня репо через `cd 03_mysql/16_orm`):

```bash
python -m venv .venv
source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Запустити будь-який приклад:

```bash
python 01_data_types/example.py
```

Кожен скрипт скидає й пересоздає свої таблиці при кожному запуску, тож виконувати його можна скільки завгодно разів.

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що вона дає |
|---|---|
| **Контекст** | Навіщо існує приклад (1-2 речення). |
| **Чого ви навчитеся** | Які конструкції ORM тренує саме ця вправа. |
| **Задіяні таблиці** | Лише ті колонки, які насправді використовуються. |
| **Завдання** | Чіткі вимоги (моделі, виклики сесії, запит). |
| **Очікуваний результат** | Справжній stdout з живого `python example.py`. |
| **Підказка** | Один натяк на потрібний SQLAlchemy API. |
| **Розв'язання** | Робочий Python, який можна вставити в `example.py`. |
| **Покрокове пояснення** | Як кожен ORM-рядок мапиться в SQL і які типові помилки. |

---

## Карта ідей SQLAlchemy 2.0

| Тема | API |
|--------|-------------|
| **Декларативна модель** | `class Base(DeclarativeBase): pass`, далі `class Thing(Base): __tablename__ = "things"`. |
| **Типізовані колонки** | `Mapped[int] = mapped_column(Integer, primary_key=True)`. |
| **Обмеження** | `UniqueConstraint`, `PrimaryKeyConstraint`, `ForeignKey(...)`. |
| **Зв'язки** | `relationship(back_populates="…", cascade="…", uselist=False, secondary=…)`. |
| **Сесія** | `with Session(engine) as session: session.add(...); session.commit()`. |
| **Запити** | `select(Model).where(...).order_by(...)`, `session.scalars(...)`, `session.execute(...).all()`. |
| **Агрегати** | `func.count`, `func.sum`, `func.avg` + `.group_by(...).having(...)`. |
| **JOIN-и** | `.join(...)`, `.outerjoin(...)`, `joinedload(rel)` для eager-loading. |
| **Міграції** | Alembic `revision`, `upgrade`, `downgrade` (`command.upgrade(cfg, "head")`). |

---

## Точки дотику зі схемою

Кожен підкаталог визначає **власні** таблиці (тому уроки незалежні). Наприклад, `05_crud` створює одну таблицю `items`; `06_joins` — `departments` + `employees`; і так далі. Мапінг описано в кожній вправі.

---

## Вправа 1 — Типізовані колонки (`01_data_types`)

### Контекст

Перше, що потрібно будь-якому ORM-проєкту — спосіб оголошувати типізовані колонки. SQLAlchemy 2.0 використовує **анотації `Mapped[…]` + `mapped_column(...)`**, щоб Python-тип і SQL-тип лишалися синхронними — і щоб тайп-чекери могли ловити невідповідності до того, як ви вдарите по базі.

### Чого ви навчитеся

- Оголошувати модель з `DeclarativeBase` і `__tablename__`.
- Мапити поширені Python-типи: `int`, `str`, `Decimal`, `float`, `bool`, `datetime`, `dict`, `bytes`, `Enum`.
- Як `Numeric(10, 2)`, `String(32)`, `BigInteger`, `Boolean`, `JSON`, `LargeBinary`, `Enum` перетворюються на фрагмент DDL.
- Використовувати `default=…` для значень, заповнених Python, і вставляти/оновлювати через `Session`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `products` | `id`, `sku`, `name`, `price`, `weight_kg`, `units_in_stock`, `is_active`, `created_at`, `release_date`, `attrs`, `photo`, `status` |

### Завдання

1. Визначити `class Product(Base)`, замапити на `products`.
2. Покрити матрицю типів: `Integer` PK + autoincrement, `String(32)` unique, `Text`, `Numeric(10, 2)` для грошей, `Float` nullable, `BigInteger`, `Boolean`, `DateTime` з `default=datetime.utcnow`, `Date` nullable, `JSON` nullable, `LargeBinary` nullable, `Enum(OrderStatus)`.
3. Скинути й створити схему, вставити один рядок через `Session.add(...) → commit()`, далі `session.refresh(p)` і вивести рядок.
4. Вивести DDL-фрагмент SQLite через `CreateTable(Product.__table__).compile(dialect=engine.dialect)`.

### Очікуваний результат (реальний вивід `python 01_data_types/example.py`)

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

### Підказка

Використовуйте `Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)`. Для грошей завжди `Numeric(10, 2)` з `Decimal`, ніколи `Float`.

### Розв'язання

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

### Покрокове пояснення

1. **`DeclarativeBase`** — це базовий клас SQLAlchemy 2.0 для всіх моделей. Кожен підклас `Base` одночасно стає і класом рядка, і мапінгом таблиці.
2. **Анотації `Mapped[T]`** несуть Python-тип. Mypy/Pyright ловлять помилки з полями; SQLAlchemy використовує їх, щоб обрати SQL-тип, коли його не дано в `mapped_column`.
3. **Парування типів** має значення: `Numeric(10, 2)` для грошей (binary-exact, всього 10 цифр, 2 знаки після коми) — ніколи `Float`, який втрачає копійки. `BigInteger` для лічильників запасів, що можуть вийти за `int32`.
4. **`default=…`** обчислюється **у Python** під час flush (тож `default=datetime.utcnow` дає wall-clock час клієнта). Використовуйте `server_default=…`, якщо хочете, щоб значення обчислювала база.
5. **`Session.add(p)`** стейджить рядок; **`commit()`** виштовхує SQL `INSERT` і коммітить транзакцію. **`session.refresh(p)`** робить re-`SELECT`, щоб заповнити серверно-згенеровані колонки (`id`, `created_at`).
6. **Інспекція DDL**: `CreateTable(Product.__table__).compile(...)` рендерить `CREATE TABLE` під діалект двигуна — зручно довести собі, що ваші анотації дали той SQL, який ви очікували.

---

## Вправа 2 — Ключі: primary, unique, composite, foreign (`02_keys`)

### Контекст

Реальні схеми потребують більше ніж один цілочисельний PK. Зазвичай ще є **природний унікальний** (email чи SKU, який має бути один-на-рядок на рівні бази), іноді **складений первинний ключ** (junction-таблиці), і **зовнішні ключі** з правилами каскаду, щоб видалення не лишали сирітські дочірні рядки.

### Чого ви навчитеся

- Сурогатний PK + природний `UniqueConstraint`.
- **Складений первинний ключ** через `PrimaryKeyConstraint("user_id", "team_id")`.
- **Зовнішні ключі** з `ondelete="CASCADE"`.
- Парний `relationship(...)` з обох боків з `back_populates="…"`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `users` | `id` (PK), `email` (unique), `name` |
| `posts` | `id` (PK), `user_id` (FK → users.id, cascade), `title` |
| `memberships` | `user_id` + `team_id` (composite PK; user_id — FK → users.id) |

### Завдання

1. Визначити `User` з PK `id` і `UniqueConstraint("email")`.
2. Визначити `Post` з `ForeignKey("users.id", ondelete="CASCADE")` і `relationship(back_populates="posts")`.
3. Визначити `Membership` з `PrimaryKeyConstraint("user_id", "team_id")` і `ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE")`.
4. Додати зворотний `relationship` на `User` (`User.posts = relationship(..., back_populates="author", cascade="all, delete-orphan")`).
5. Вставити одного користувача, два пости, одну membership; у другій сесії знайти користувача за email і вивести `posts: len(u.posts)`.

### Очікуваний результат (реальний вивід `python 02_keys/example.py`)

```text
User: 1 ada@example.com posts: 2
```

### Підказка

Використовуйте `session.flush()` після вставки користувача, але до дочірніх — це заповнить `u.id`, щоб передати його в `Post(user_id=u.id, …)` у тій самій сесії.

### Розв'язання

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

### Покрокове пояснення

1. **`UniqueConstraint("email", name="uq_users_email")`** живе в `__table_args__` (кортеж). Явне `name=` для констрейнту дає змогу адресувати його за іменем у міграціях Alembic.
2. **Складений PK через `PrimaryKeyConstraint("user_id", "team_id")`** — канонічний патерн для **junction-таблиць**, що ще й несуть метадані (`role` тут). Кожен стовпець окремо **не** унікальний; унікальна **пара**.
3. **`ForeignKey(..., ondelete="CASCADE")`** — це правило на стороні бази: коли видаляється батьківський рядок, двигун видаляє дочірній. Працює лише, коли двигун це enforce-ить (PRAGMA в SQLite, за замовчуванням у MySQL/InnoDB з `FOREIGN_KEY_CHECKS=ON`).
4. **`relationship(back_populates="…")`** з обох боків означає, що `post.author = user` автоматично з'явиться в `user.posts`. **`cascade="all, delete-orphan"`** на батьку робить так, що `session.delete(user)` ще й видалить його пости на рівні ORM (незалежно від `ondelete` бази).
5. **`session.flush()`** відправляє pending SQL у БД **без коміту** — це примушує `users.id` заповнитися, щоб подальші вставки дочірніх рядків могли його посилатися.

---

## Вправа 3 — Кардинальності зв'язків (`03_relationships`)

### Контекст

Майже кожна схема змішує три типи зв'язків: **one-to-many** (автор → книги), **many-to-many** (студенти ↔ курси через junction-таблицю), і **one-to-one** (користувач ↔ профіль). SQLAlchemy виражає всі три одним викликом `relationship(...)` — змінюються лише прапорці.

### Чого ви навчитеся

- One-to-many / many-to-one з `back_populates` обом сторонам.
- Many-to-many з асоціативною таблицею `secondary=Table(...)`.
- One-to-one через `uselist=False` на батьку + `unique=True` на FK.
- `cascade="all, delete-orphan"`, щоб поширити видалення.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `authors` | `id`, `name` |
| `books` | `id`, `title`, `author_id` → authors.id |
| `students` | `id`, `name` |
| `courses` | `id`, `code` |
| `student_course` | `student_id`, `course_id` (composite PK; FKs до обох сторін) |
| `users` | `id`, `login` (unique) |
| `profiles` | `id`, `user_id` (unique → users.id), `bio` |

### Завдання

1. Визначити `Author` і `Book` як **one-to-many**: `Author.books` і `Book.author`, поєднані `back_populates`. Каскад `delete-orphan`, щоб видалення `Author` видаляло й дочірні `Book`.
2. Визначити `Student`, `Course` і junction `Table("student_course", …, primary_key=True, primary_key=True)`. Використати `relationship(secondary=student_course, back_populates="…")` з обох ORM-сторін.
3. Визначити `User` і `Profile` як **one-to-one**: `uselist=False` на `User.profile` і `unique=True` на `Profile.user_id`.
4. У `main()`: створити одного `Author` з двома книгами (через `a.books.extend([...])`), одного `Student` з двома курсами, одного `User` з одним `Profile`. Закомітити. У свіжій сесії дістати кожного й вивести імена.

### Очікуваний результат (реальний вивід `python 03_relationships/example.py`)

```text
Author → books: Le Guin ['The Left Hand of Darkness', 'The Dispossessed']
Student ↔ courses: Sam ['DB-101', 'PY-202']
User 1–1 profile: neo The One
```

### Підказка

Для many-to-many асоціативна `Table` живе в `Base.metadata` (не як `Mapped`-клас). Використовуйте звичайні `Column(ForeignKey(...), primary_key=True)` для обох стовпців.

### Розв'язання

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

### Покрокове пояснення

1. **One-to-many** асиметричний: **дочірній** тримає FK (`Book.author_id`), **батько** тримає колекцію (`Author.books`). `back_populates="…"` тримає їх синхронними в пам'яті.
2. **`cascade="all, delete-orphan"`** на батьку означає «якщо `Book` відчеплено від свого `Author`, видалити `Book`». Без `delete-orphan` відчеплена книга жила б у таблиці як сирота.
3. **Many-to-many** використовує звичайну `Table` (не `Mapped`-клас), вказану в `secondary=`. Обидва кінці кажуть `secondary=student_course`. Складений PK на junction-таблиці запобігає дублюванню записів на рівні БД.
4. **One-to-one** — це дві хитрості разом: `uselist=False` на `relationship` батька (щоб SQLAlchemy повертала скаляр, а не список) плюс `unique=True` на FK-колонці дочірнього (щоб БД enforce-ила «не більше одного дочірнього»).
5. **Зчитування**: `a.books` і `s.courses` доступаються як звичайні Python-списки; SQLAlchemy видає ліниві `SELECT` при першому доступі (один round-trip на атрибут — переключитесь на `joinedload`, щоб згорнути в один запит).

---

## Вправа 4 — Нормалізація проти денормалізації (`04_normalization`)

### Контекст

Новачки часто «дублюють» дані у широкі таблиці («просто поклади customer_name в кожен order line»), бо так здається простіше. Лаб показує компроміс пліч-о-пліч: розкладка в **3NF** (`customers`, `orders`, `order_lines`) проти **денормалізованої** плоскої таблиці, що повторює стовпці клієнта в кожному рядку — і аномалії оновлення, які з цим приходять.

### Чого ви навчитеся

- Розкласти дані по трьох нормалізованих таблицях, зв'язаних FK.
- Побудувати ту саму лабу як одну широку таблицю для порівняння.
- Чому **два окремих підкласи `DeclarativeBase`** тримають схеми незалежними.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `norm_customers` | `id`, `name`, `phone` |
| `norm_orders` | `id`, `customer_id` → norm_customers.id, `ref` |
| `norm_order_lines` | `id`, `order_id` → norm_orders.id, `sku`, `qty`, `unit_price` |
| `denorm_order_lines_flat` | `id`, `order_ref`, `customer_name`, `customer_phone`, `sku`, `qty`, `notes` |

### Завдання

1. Визначити `NormBase(DeclarativeBase)` з трьома моделями: `Customer`, `NormOrder`, `NormOrderLine` (ланцюжок FK).
2. Визначити **окремий** `DenormBase(DeclarativeBase)` з однією моделлю `OrderLineFlat`, що повторює `customer_name`, `customer_phone` у кожному рядку.
3. Створити обидві метадати, вставити одне нормалізоване замовлення з однією строкою, одну денормалізовану плоску строку.
4. Вивести імена таблиць з кожної метадати.

### Очікуваний результат (реальний вивід `python 04_normalization/example.py`)

```text
Normalized tables: ['norm_customers', 'norm_orders', 'norm_order_lines']
Denormalized flat: ['denorm_order_lines_flat']
```

### Підказка

Дві декларативні бази користуються одним двигуном, але мають окремі реєстри `metadata` — викликайте `.metadata.create_all(engine)` на кожній.

### Розв'язання

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

### Покрокове пояснення

1. **3NF (третя нормальна форма)** простою мовою: кожен неключовий стовпець залежить від усього ключа і тільки від ключа. У `norm_order_lines` ціна/кількість залежать від рядка; ім'я клієнта — ні, тож воно живе в `norm_customers`.
2. **Денормалізована розкладка** повторює `customer_name` і `customer_phone` у кожному рядку. Читати швидше — без join-ів, але з'являються **аномалії оновлення**: змінити телефон клієнта тепер означає `UPDATE` по багатьох рядках; якщо хоч один пропущено — дані неконсистентні.
3. **Дві декларативні бази** тримають схеми незалежними. Вони ділять один двигун, але `NormBase.metadata.create_all(engine)` і `DenormBase.metadata.create_all(engine)` викликаються окремо — зручно, коли ви справді хочете дві непов'язані міні-схеми в одній лаб-БД.
4. **Каскад на `lines`** відображає бізнес-реальність: видалення замовлення має видалити його рядки, а не навпаки.
5. **Коли денормалізувати?** Пред-агреговані звіти, read-heavy кеші, time-series снімки. Правило: **нормалізувати для запису, денормалізувати для читання** — і документувати денормалізацію коментарем, де живе джерело істини.

---

## Вправа 5 — CRUD з `Session` (`05_crud`)

### Контекст

Кожен ORM-проєкт зводиться до чотирьох дієслів: **Create**, **Read**, **Update**, **Delete**. SQLAlchemy 2.0 використовує `Session` як unit-of-work: ви стейджите зміни через атрибути Python, потім `commit()` виштовхує їх разом.

### Чого ви навчитеся

- `session.add(model)` і `session.add_all([...])` для **Create**.
- `session.scalars(select(Model).where(...))` для **Read** (один + багато рядків).
- Мутацію приєднаного інстансу для **Update** (без ручного SQL).
- `session.delete(row)` потім `commit()` для **Delete**.
- Контекстний менеджер `with Session(engine) as session:` і чому він автоматично rollback-ить при виключенні.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `items` | `id` PK, `name`, `qty` |

### Завдання

1. Визначити модель з однією таблицею `Item(id, name, qty)`.
2. **Create**: додати два items `("Bolt M8", 100)` і `("Washer", 250)`.
3. **Read**: завантажити рядок "Bolt M8" через `session.scalars(select(Item).where(Item.name == "Bolt M8")).one()` і повний відсортований список.
4. **Update**: дістати `Item` з `id = 1`, відняти `3` від `qty`, закомітити. Прочитати знову через `session.get(Item, 1)`.
5. **Delete**: дістати `Item` з `id = 2`, викликати `session.delete(row)`, закомітити. Прочитати тих, хто вижив.

### Очікуваний результат (реальний вивід `python 05_crud/example.py`)

```text
READ one / all: 1 ['Bolt M8', 'Washer']
After UPDATE: 97
After DELETE: [(1, 'Bolt M8')]
```

### Підказка

Використовуйте свіжий блок `with Session(engine) as session:` для кожного кроку. У тому ж блоці пишіть `row.qty -= 3` і дайте SQLAlchemy відіслати `UPDATE` на `commit()`.

### Розв'язання

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

### Покрокове пояснення

1. **`with Session(engine) as session:`** відкриває unit-of-work. На нормальному виході він коммітить *якщо щось було закомічено*; на виключенні — робить rollback. Тому кожен крок лаби використовує власний блок.
2. **Create**: `session.add(item)` стейджить `INSERT`. `session.add_all([...])` — масовий варіант. SQL відсилається на `flush()` (який тригерить `commit()`).
3. **Read**: `select(Item).where(...)` будує 2.0-style інструкцію. `session.scalars(...)` розпаковує рядки з однією колонкою; `.one()` вимагає рівно один рядок (інакше `MultipleResultsFound`/`NoResultFound`); `.all()` повертає список.
4. **Update**: на рядку **немає методу `update()`.** Ви присвоюєте Python-атрибути (`row.qty -= 3`); SQLAlchemy порівнює їх з оригіналом і видає правильний `UPDATE` на commit.
5. **Delete**: `session.delete(row)` помічає рядок до видалення; `commit()` видає `DELETE`. Якщо в рядка були FK-зв'язані діти, правила каскаду вирішують, що з ними станеться.
6. **`session.get(Item, 1)`** — швидкий шлях для «дістати за PK»: він спершу перевіряє identity map сесії і уникає запиту, коли можна.

---

## Вправа 6 — JOIN-и в Core/ORM (`06_joins`)

### Контекст

Звіти майже завжди джойнять: «співробітники з ім'ям відділу» потребує `INNER JOIN departments`, а «співробітники і їхній відділ, навіть якщо без відділу» — `LEFT OUTER JOIN`. SQLAlchemy дозволяє побудувати обидва через `.join(...)` і `.outerjoin(...)`, а проблему N+1 уникати **eager loading** через `joinedload`.

### Чого ви навчитеся

- Явний `INNER JOIN` через `select(...).join(Table, on_clause)`.
- `LEFT OUTER JOIN` через `.outerjoin(...)` (праві колонки стають `None`).
- Eager-loading зв'язку через `joinedload(rel)` — один SQL-запит, без N+1.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `departments` | `id`, `name` |
| `employees` | `id`, `name`, `dept_id` → departments.id (nullable) |

### Завдання

1. Визначити `Department` і `Employee` з nullable FK від `Employee.dept_id` до `Department.id`.
2. Сід: один `Department` "Service" з двома працівниками (`Ann`, `Bob`) і один без відділу (`Temp`, `dept=None`).
3. Побудувати три запити і вивести результати:
   - `INNER JOIN`: `select(Employee.name, Department.name).join(Department, Employee.dept_id == Department.id)` (відкине `Temp`).
   - `LEFT OUTER JOIN`: та сама інструкція, але `.outerjoin(...)` (тримає `Temp`, відділ — `None`).
   - **Eager load**: `select(Employee).options(joinedload(Employee.dept))` і читати `e.dept.name` по кожному рядку.

### Очікуваний результат (реальний вивід `python 06_joins/example.py`)

```text
INNER JOIN: [('Ann', 'Service'), ('Bob', 'Service')]
LEFT OUTER JOIN: [('Ann', 'Service'), ('Bob', 'Service'), ('Temp', None)]
joinedload: [('Ann', 'Service'), ('Bob', 'Service'), ('Temp', None)]
```

### Підказка

`.outerjoin` за замовчуванням — це "LEFT OUTER JOIN" у SQLAlchemy. `joinedload(rel)` видає один SQL-запит з `LEFT OUTER JOIN` і **заповнює зв'язок одразу** замість ліниво-завантаженого по інстансу.

### Розв'язання

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

### Покрокове пояснення

1. **`.join(Right, on_clause)`** видає `INNER JOIN`. Будь-який рядок у `employees` без відповідного відділу мовчки відкидається — тому `Temp` зникає.
2. **`.outerjoin(Right, on_clause)`** видає `LEFT OUTER JOIN`. Праві колонки стають `None` для рядків без пари, тож `Temp` лишається з `department = None`.
3. **`select(Employee.name, Department.name)`** повертає **кортежі** — `session.execute(stmt).all()` дає список об'єктів `Row`, які можна розпаковувати. `session.scalars(...)` використовуйте лише коли `select(OneModelOrColumn)`.
4. **`joinedload(Employee.dept)`** — опція eager-loading: SQLAlchemy перетворює `SELECT … FROM employees` на `SELECT … FROM employees LEFT OUTER JOIN departments ON …` і заповнює `Employee.dept` одразу — без N+1.
5. **`.unique()`** перед `.all()` потрібен з `joinedload` на колекціях (і рекомендований на скалярах), бо джойнений SQL може повернути дублі батьківських рядків; `unique()` дедуплікує по PK на стороні ORM.

---

## Вправа 7 — Агрегати, `GROUP BY`, `HAVING` (`07_aggregates_having`)

### Контекст

Продакт-менеджер хоче «середню ціну на категорію, але лише категорії, де принаймні один товар, відсортовані за алфавітом» — плюс одноразовий загальний підсумок. Це **`func.count` + `func.avg` + `group_by` + `having`** на стороні ORM, що точно відповідає SQL-секціям.

### Чого ви навчитеся

- Будувати агрегатні вирази через namespace **`func`**.
- Підписувати їх через `.label("…")` для стабільних імен колонок.
- `.group_by(...)` і `.having(...)` на інструкції `select(...)`.
- Одноразові скалярні агрегати через `session.scalar(select(func.sum(...)))`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `parts` | `id`, `category`, `sku`, `price` |

### Завдання

1. Визначити `Part(id, category, sku, price)` з `price` як `Numeric(10, 2)`.
2. Сід: три рядки: `("filters", "F-1", 12.00)`, `("filters", "F-2", 15.00)`, `("brakes", "B-1", 40.00)`.
3. Побудувати `select`, що повертає `category`, `func.count(Part.id) AS n`, `func.avg(Part.price) AS avg_price`, з групуванням за `category`, `HAVING count >= 1`, відсортовано за `category`.
4. Вивести рядки. Далі `session.scalar(select(func.sum(Part.price)))`, щоб вивести загальний підсумок.

### Очікуваний результат (реальний вивід `python 07_aggregates_having/example.py`)

```text
GROUP BY + HAVING: [('brakes', 1, 40.0), ('filters', 2, 13.5)]
SUM(all prices): 67.00
```

### Підказка

`select(Part.category, func.count(Part.id).label("n"), func.avg(Part.price).label("avg_price")).group_by(Part.category).having(func.count(Part.id) >= 1)`.

### Розв'язання

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

### Покрокове пояснення

1. **`func.<name>(args)`** — ледачий проксі SQLAlchemy для SQL-функцій: `func.count(Part.id)` стає `COUNT(parts.id)`, `func.avg(Part.price)` — `AVG(parts.price)`. Імена передаються в SQL-діалект як є — `func.lower("X")` працює так само.
2. **`.label("avg_price")`** дає псевдонім колонці, щоб викликачі могли звертатися за іменем. Без міток колонка має згенероване ім'я бекенду (`avg_1` тощо).
3. **`.group_by(Part.category)`** мапиться напряму на SQL `GROUP BY parts.category`. Кожен неагрегований стовпець у `select(...)` має з'явитися в `group_by` (це SQL-стандарт; MySQL з `ONLY_FULL_GROUP_BY` це enforce-ить).
4. **`.having(...)`** фільтрує **групи**, а не рядки. Він може згадувати агрегати (`func.count(Part.id) >= 1`), на відміну від `.where(...)`, який не може.
5. **`session.scalar(...)`** повертає першу колонку першого рядка (або `None`). Ідеально для одноразових агрегатів типу загального підсумку.
6. **Чому avg показує `13.5` (float) для filters?** SQLite за замовчуванням повертає `AVG()` як float. На MySQL/PostgreSQL з `Numeric` зазвичай отримаєте `Decimal('13.50')`. Кастуйте явно через `func.cast(... , Numeric(10, 2))`, якщо потрібна стабільність між бекендами.

---

## Вправа 8 — Міграції з Alembic (`08_migrations`)

### Контекст

Схеми еволюціонують: нові колонки, перейменовані таблиці, додані індекси. Ручне редагування продакшн-БД — рецепт дрейфу. **Alembic** — інструмент міграцій, що йде з SQLAlchemy: кожна зміна схеми стає **revision-скриптом** з функціями `upgrade()` і `downgrade()`, версіонується в git, застосовується по порядку.

### Чого ви навчитеся

- Мінімальна розкладка Alembic: `alembic.ini`, `alembic/env.py`, `alembic/versions/*.py`, плюс `models.py`, зареєстрований як `target_metadata`.
- `upgrade()` ревізії (застосувати зміну) і `downgrade()` (відкатити).
- Запуск міграції з Python через `alembic.command.upgrade(cfg, "head")` і `command.downgrade(cfg, "base")`.

### Задіяні таблиці

| Таблиця | Колонки |
|---|---|
| `users` | `id` PK, `email` (unique) |
| `alembic_version` | Однострічкова службова таблиця, що зберігає поточну ревізію. |

### Завдання

1. Написати `models.py` з однією моделлю `User` (id, email unique).
2. Написати ревізію `001_create_users_table.py`, де `upgrade()` викликає `op.create_table(...)` для `users`, а `downgrade()` — `op.drop_table("users")`.
3. Написати `example.py`, який:
   - Видаляє наявний SQLite-файл попереднього запуску.
   - Викликає `command.upgrade(cfg, "head")` і виводить список таблиць (має бути `users` і `alembic_version`).
   - Вставляє одного користувача через `Session`, виводить його id.
   - Викликає `command.downgrade(cfg, "base")` і виводить список таблиць (без `users`).

### Очікуваний результат (реальний вивід `python 08_migrations/example.py`)

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

### Підказка

Усередині `alembic/env.py` імпортуйте `from models import Base` і встановіть `target_metadata = Base.metadata`, щоб autogenerate (якщо використовуватимете) знав ваші моделі.

### Розв'язання

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

І revision-скрипт (`alembic/versions/001_create_users_table.py`):

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

### Покрокове пояснення

1. **`Config("alembic.ini")`** завантажує стандартний конфіг Alembic. Налаштування `sqlalchemy.url` там вказує на БД; `script_location` — на папку `alembic/`.
2. **`command.upgrade(cfg, "head")`** застосовує всі ревізії з поточного стану до найновішої. `"head"` — символічне ім'я «найновіша»; `"base"` — «жодної застосованої».
3. **Метадані ревізії** (`revision = "001"`, `down_revision = None`) формують орієнтований граф. Alembic зберігає поточну ревізію в таблиці `alembic_version` — це й та друга таблиця після upgrade.
4. **`op.create_table(...)`** і **`op.drop_table(...)`** — діалект-агностичні хелпери з `alembic.op`. Завжди пишіть **зворотний** `downgrade()` — навіть якщо це лише `op.drop_table` — щоб відкат поганого релізу був тривіальним.
5. **`inspect(engine).get_table_names()`** — діалект-агностичний спосіб перелічити таблиці — корисно в тестах для перевірки успішного запуску міграції.
6. **Порядок дій у продакшені**: ніколи не редагуйте попередню ревізію; завжди створюйте нову. Ніколи не запускайте `downgrade` на проді без тестованої копії — операції downgrade, що дропають колонки, деструктивні.

---

## Усунення проблем: мій ORM-приклад не запускається

| Симптом | Імовірне виправлення |
|---|---|
| `ModuleNotFoundError: No module named 'sqlalchemy'` | Активуйте virtualenv: `source .venv/bin/activate`. |
| `sqlite3.OperationalError: no such table` | Скрипт не викликав `Base.metadata.create_all(engine)` до першого `INSERT`. |
| `MultipleResultsFound` / `NoResultFound` | `.one()` чекає рівно один рядок; використайте `.first()` (повертає `None`) або `.all()`. |
| `DetachedInstanceError` при читанні `obj.relation` | `Session` закрилась до lazy-load. Перечитайте у новому блоці `with Session(engine) as session:` або використайте `joinedload`. |
| `IntegrityError: UNIQUE constraint failed` | Перезапуск без `drop_all`. Або дропайте перед створенням, або використайте свіжий SQLite-файл. |
| N+1 SELECT-ів у логах (з `echo=True`) | Додайте `.options(joinedload(Model.rel))` або `.options(selectinload(Model.rel))`. |
| Alembic `Target database is not up to date` | Перед генерацією нової autogenerate-ревізії запустіть `alembic upgrade head`. |

Щоб запустити **всі** приклади одразу: `for d in 0[1-8]_*; do (cd "$d" && python example.py); done`.
