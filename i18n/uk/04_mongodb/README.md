# Покажчик уроків MongoDB (`04_mongodb/`)

> Translation / Переклад: [English](../../../04_mongodb/README.md)

Цей каталог містить уроки PyMongo до локального MongoDB. Кожен пронумерований урок, що має `example.py`, також включає підкаталог **`csharp/`** з тими самими вправами на офіційному **MongoDB .NET Driver** (SDK-стиль: `Program.cs` плюс невеликий `.csproj`).

## Посилання на модулі

| Каталог | Тема | Урок `.md` |
|---|---|---|
| [`01_crud/`](01_crud/) | CRUD-операції | [`crud_mongodb.md`](01_crud/crud_mongodb.md) |
| [`02_selection_queries/`](02_selection_queries/) | Фільтри порівняння та багатозначні | [`selection_queries_mongodb.md`](02_selection_queries/selection_queries_mongodb.md) |
| [`03_logical_operators/`](03_logical_operators/) | `$and`, `$or`, `$not` | [`logical_operators_mongodb.md`](03_logical_operators/logical_operators_mongodb.md) |
| [`04_string_operators/`](04_string_operators/) | `$regex`, `$text` | [`string_operators_mongodb.md`](04_string_operators/string_operators_mongodb.md) |
| [`05_check_operators/`](05_check_operators/) | `$exists`, `$type` | [`check_operators_mongodb.md`](05_check_operators/check_operators_mongodb.md) |
| [`06_array_operators/`](06_array_operators/) | `$all`, `$size`, `$elemMatch` | [`array_operators_mongodb.md`](06_array_operators/array_operators_mongodb.md) |
| [`07_pagination_sorting/`](07_pagination_sorting/) | `sort`, `skip`, `limit` | [`pagination_sorting_mongodb.md`](07_pagination_sorting/pagination_sorting_mongodb.md) |
| [`08_filtering/`](08_filtering/) | Комбіновані шаблони фільтрації | [`filtering_mongodb.md`](08_filtering/filtering_mongodb.md) |
| [`09_indexes/`](09_indexes/) | Одинарні/складені/унікальні/текстові/TTL/хешовані індекси | [`indexes_mongodb.md`](09_indexes/indexes_mongodb.md) |
| [`10_odm/`](10_odm/) | Основи ODM з MongoEngine | [`odm_mongoengine.md`](10_odm/odm_mongoengine.md) |

## Корисні файли

- [`mongodb_topics.md`](mongodb_topics.md) — огляд тем та налаштування
- [`verify_mongodb_examples.sh`](verify_mongodb_examples.sh) — запустити всі скрипти уроків
- [`requirements.txt`](requirements.txt) — залежності Python

### C# (.NET 8 + MongoDB.Driver)

З каталогу уроку:

```bash
cd 01_crud/csharp
dotnet run
```

Ті самі змінні середовища, що й для Python: **`MONGODB_URI`**, **`MONGODB_DB`** (база даних за замовчуванням — `edu_academy_seed`). Опційно для уроку про індекси: **`MONGO_RUN_DROP_INDEXES=1`** — виконати блок видалення індексів; **`MONGO_RUN_CREATE_INDEXES=0`** — пропустити створення індексів.
