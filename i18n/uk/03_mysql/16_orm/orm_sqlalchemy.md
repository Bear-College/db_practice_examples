# ORM SQLAlchemy — приклади на Python (`03_mysql/16_orm`)

> Translation / Переклад: [English](../../../../03_mysql/16_orm/orm_sqlalchemy.md)

Самодостатні демо для типових тем реляційних БД та ORM. У кожному підкаталозі є `example.py`, який можна запустити після встановлення залежностей.

**Теми (з програми курсу):** типи даних, ключі, типи зв'язків, нормалізація проти денормалізації, CRUD, JOIN-и, агрегати / `GROUP BY` / `HAVING`, міграції (Alembic).

## Налаштування

З каталогу `03_mysql/16_orm/` (або з кореня репо через `cd 03_mysql/16_orm`):

```bash
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Запустити будь-який приклад:

```bash
python 01_data_types/example.py
```

За замовчуванням приклади використовують **SQLite** (файли `*.db` поруч зі скриптом або `:memory:`), тож більше нічого не потрібно.

## Підкаталоги

| Каталог | Тема |
|---------|------|
| [`01_data_types`](01_data_types/) | Типи стовпців / Python (`Integer`, `String`, `DateTime`, `JSON`, `Enum`, …) |
| [`02_keys`](02_keys/) | Первинний ключ, унікальний, складений первинний ключ, зовнішні ключі |
| [`03_relationships`](03_relationships/) | one-to-many, many-to-one, many-to-many, one-to-one |
| [`04_normalization`](04_normalization/) | Нормалізована проти денормалізованої структури (ілюстрація) |
| [`05_crud`](05_crud/) | Створення, читання, оновлення, видалення через `Session` |
| [`06_joins`](06_joins/) | `join` / `outerjoin` у запитах Core та ORM |
| [`07_aggregates_having`](07_aggregates_having/) | `func`, `GROUP BY`, `HAVING` |
| [`08_migrations`](08_migrations/) | Ревізія Alembic + `upgrade` / `downgrade` |

Для **міграцій** запустіть `python example.py` усередині `08_migrations/` (використовує `upgrade` / `downgrade` Alembic).
