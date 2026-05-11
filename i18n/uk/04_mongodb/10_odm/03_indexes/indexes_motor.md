# Індекси з Motor (`10_odm/03_indexes`)

> Translation / Переклад: [English](../../../../../04_mongodb/10_odm/03_indexes/indexes_motor.md)

Ці вправи дублюють `09_indexes`, але з **асинхронним** Python-драйвером **Motor**. Ті ж шість типів індексів (single, compound, unique, text, TTL, hashed), та сама схема перевірки через `explain` — змінюється лише обгортка з `async def`.

Готовий файл-компаньйон: [`10_odm/03_indexes/main.py`](../../../../../04_mongodb/10_odm/03_indexes/main.py). Скрипт засіває три товари, створює всі шість індексів, виводить їх, виконує два демо-запити і знову їх видаляє, щоб наступний запуск починався з нуля.

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/03_indexes/main.py
```

З'єднання за замовчуванням (можна перевизначити змінними оточення):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `odm_motor_indexes_products`

---

## Колекція: `odm_motor_indexes_products`

Сід вставляє три товари (`SKU-1001`, `SKU-1002`, `SKU-1003`) з полями, що відповідають кожному індексу:

```json
{
  "sku": "SKU-1001",
  "name": "iPhone 14",
  "category": "Smartphone",
  "description": "Apple smartphone",
  "price": 899,
  "created_at": ISODate("..."),
  "expires_at": ISODate("...")
}
```

| `sku` | `name` | `category` | `price` | `description` |
|---|---|---|---|---|
| SKU-1001 | iPhone 14 | Smartphone | 899 | "Apple smartphone" |
| SKU-1002 | Galaxy S23 | Smartphone | 799 | "Samsung flagship phone" |
| SKU-1003 | MacBook Air | Laptop | 1299 | "Lightweight laptop" |

Після `create_indexes` `list_indexes` показує:

```text
Indexes:
  - _id_: SON([('_id', 1)])
  - ix_category_single: SON([('category', 1)])
  - ix_category_price_compound: SON([('category', 1), ('price', -1)])
  - uq_sku: SON([('sku', 1)])
  - ix_description_text: SON([('_fts', 'text'), ('_ftsx', 1)])
  - ix_expires_at_ttl: SON([('expires_at', 1)])
  - ix_sku_hashed: SON([('sku', 'hashed')])
```

Два демо-запити повертають:

```text
category='Smartphone' -> [{'name': 'iPhone 14', 'price': 899}, {'name': 'Galaxy S23', 'price': 799}]
$text search 'smartphone' -> [{'name': 'iPhone 14'}]
```

---

## Шаблон вправи (повторюється в кожному розділі нижче)

| Секція | Що дає |
|---|---|
| **Контекст** | Яке навантаження мотивує цей індекс. |
| **Чого ви навчитеся** | Який async-виклик і які kwargs. |
| **Колекція** | Які поля беруть участь. |
| **Завдання** | Конкретний `create_index`. |
| **Очікуваний результат** | Реальний JSON `list_indexes()` / `explain()`. |
| **Підказка** | Сигнатура функції Motor. |
| **Розв'язання** | Motor (Python) і `mongosh` поряд. |
| **Покрокове пояснення** | Особливості async і типові помилки. |

---

## Вправа 1 — Індекс по одному полю (`ix_category_single`)

### Контекст

Каталог фільтрує за `category` при кожному завантаженні сторінки. Без індексу — повне сканування; з індексом — пошук за ключем.

### Чого ви навчитеся

- `await coll.create_index([...])` — сигнатура Motor така ж, як у PyMongo.
- Як читати стадію `IXSCAN` в async explain.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `category` | string | Ключ фільтра. |

### Завдання

Створити індекс по `category` (зростання) з ім'ям `ix_category_single` і пересвідчитись, що `find({"category": "Smartphone"})` його використовує.

### Очікуваний результат

```text
- ix_category_single: SON([('category', 1)])

category='Smartphone' -> [{'name': 'iPhone 14', 'price': 899}, {'name': 'Galaxy S23', 'price': 799}]
```

Реальний `explain` (захоплений на цих даних) показав `IXSCAN` з `keysExamined == 2` і `nReturned == 2` — підручниковий індексований доступ:

```text
"stage": "IXSCAN",
"indexName": "ix_category_price_compound",   // див. Вправу 2: чому саме він
"isMultiKey": false,
"direction": "forward",
"indexBounds": { "category": ["[\"Smartphone\", \"Smartphone\"]"], "price": ["[MaxKey, MinKey]"] },
"keysExamined": 2,
"seeks": 1,
"dupsTested": 0,
"dupsDropped": 0
```

(Планувальник обрав складений індекс з Вправи 2, бо обидва мають спільний префікс `category` — див. пояснення нижче.)

### Підказка

`await coll.create_index([("category", ASCENDING)], name="ix_category_single")`.

### Розв'язання

```python
from pymongo import ASCENDING
await coll.create_index([("category", ASCENDING)], name="ix_category_single")
```

```javascript
use("edu_academy_seed");
db.odm_motor_indexes_products.createIndex({ category: 1 }, { name: "ix_category_single" });
db.odm_motor_indexes_products.find({ category: "Smartphone" }).explain("executionStats");
```

### Покрокове пояснення

1. **`create_index` — awaitable.** Без `await` повертається `Future`, індекс не створюється, а наступний рядок працює на застарілому стані.
2. **Ідемпотентно.** Повторний виклик зі специфікацією без змін — no-op.
3. **Планувальник може обрати інший індекс.** Маючи і `ix_category_single`, і складений `ix_category_price_compound`, MongoDB може віддати перевагу складеному — обидва обслуговують рівність по `category`, але складений також задовольняє можливе сортування за `price`.
4. **Один індекс ≠ один запит.** Індекс по одному полю обслуговує будь-який запит, що використовує це поле як провідний рівнісно-діапазонний предикат.

---

## Вправа 2 — Складений індекс (`ix_category_price_compound`)

### Контекст

Віджет «товари в цій категорії, спочатку найдорожчі». Складений `(category ASC, price DESC)` дозволяє MongoDB повернути дані вже відсортованими.

### Чого ви навчитеся

- Порядок полів у складеному індексі визначає, які запити він обслуговує.
- Чому в explain межі для невикористаного хвостового поля виглядають як `[MaxKey, MinKey]`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `category` | string | Перший ключ. |
| `price` | int | Другий ключ, спадання. |

### Завдання

Створити `ix_category_price_compound` і пересвідчитись, що `find({"category": "Smartphone"})` його використовує (так і є — `category` є префіксом).

### Очікуваний результат

```text
- ix_category_price_compound: SON([('category', 1), ('price', -1)])
```

Реальний `explain('executionStats')`:

```text
"stage": "IXSCAN",
"indexName": "ix_category_price_compound",
"isMultiKey": false,
"direction": "forward",
"indexBounds": {
  "category": ["[\"Smartphone\", \"Smartphone\"]"],
  "price":    ["[MaxKey, MinKey]"]
},
"keysExamined": 2,
"seeks": 1
```

`price: [MaxKey, MinKey]` означає «увесь діапазон» — запит не обмежив `price`, але індекс усе одно скан-проходить обидва ключі для кожного збігу `category`.

### Підказка

`await coll.create_index([("category", ASCENDING), ("price", DESCENDING)], name="ix_category_price_compound")`.

### Розв'язання

```python
from pymongo import ASCENDING, DESCENDING
await coll.create_index(
    [("category", ASCENDING), ("price", DESCENDING)],
    name="ix_category_price_compound",
)
```

```javascript
db.odm_motor_indexes_products.createIndex(
  { category: 1, price: -1 },
  { name: "ix_category_price_compound" }
);
```

### Покрокове пояснення

1. **`(category, price)` обслуговує запити по `category` сам** (правило префікса), отже одиничний `ix_category_single` технічно надлишковий, якщо ви завжди матимете і складений; тримайте його лише, якщо є запити з сортуванням саме по `category`, де напрямок складеного `price: -1` буде заважати.
2. **ESR (Equality, Sort, Range).** Тут `category` — рівність, `price` — сортування. Поставити `price` першим — і фільтр по `category` сповільниться.
3. **`isMultiKey: false`** підтверджує, що жодне з полів не є масивом.

---

## Вправа 3 — Унікальний індекс (`uq_sku`)

### Контекст

`sku` друкується на штрих-коді — має бути глобально унікальним. Унікальний індекс не пропустить дублікат.

### Чого ви навчитеся

- Опції `unique=True`.
- `DuplicateKeyError` при конфліктній вставці.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `sku` | string | Має бути унікальним. |

### Завдання

Створити `uq_sku` на `sku` з `unique=True`. Переконатись, що дублікат відхиляється.

### Очікуваний результат

```text
- uq_sku: SON([('sku', 1)])
```

Спроба вставити другий `SKU-1001` дає:

```text
pymongo.errors.DuplicateKeyError: E11000 duplicate key error collection:
edu_academy_seed.odm_motor_indexes_products index: uq_sku dup key: { sku: "SKU-1001" }
```

### Підказка

`await coll.create_index([("sku", ASCENDING)], unique=True, name="uq_sku")`.

### Розв'язання

```python
from pymongo.errors import DuplicateKeyError

await coll.create_index([("sku", ASCENDING)], unique=True, name="uq_sku")

try:
    await coll.insert_one({"sku": "SKU-1001", "name": "Duplicate"})
except DuplicateKeyError as e:
    print("rejected:", e.details.get("errmsg"))
```

```javascript
db.odm_motor_indexes_products.createIndex(
  { sku: 1 },
  { unique: true, name: "uq_sku" }
);
```

### Покрокове пояснення

1. **Обробка помилок у async ідентична синхронній** — `try / except` навколо `await`.
2. **Існуючі дублікати ламають створення.** `createIndex` падає з `E11000`, якщо в колекції вже є конфліктні `sku`.
3. **Unique vs hashed.** Хешований індекс (Вправа 6) на тому ж полі не може бути unique — тому в цьому уроці є *обидва*: `uq_sku` для обмеження, `ix_sku_hashed` для гіпотетичного шардингу.

---

## Вправа 4 — Текстовий індекс (`ix_description_text`)

### Контекст

Пошук по `description` у каталозі. Текстовий індекс перетворює "smartphone" / "phone" / "headphones" на токенізований пошук.

### Чого ви навчитеся

- Асинхронному створенню текстового індексу (`("description", "text")`).
- Тому самому запиту `$text` / `$search`, що в уроці `09_indexes`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `description` | string | Токенізуємо. |

### Завдання

Створити `ix_description_text`, потім шукати `"smartphone"`.

### Очікуваний результат

```text
- ix_description_text: SON([('_fts', 'text'), ('_ftsx', 1)])

$text search 'smartphone' -> [{'name': 'iPhone 14'}]
```

Лише `iPhone 14` має літерал `smartphone` у описі — у Galaxy S23 опис "Samsung flagship phone".

### Підказка

`await coll.create_index([("description", "text")], name="ix_description_text")`.

### Розв'язання

```python
await coll.create_index([("description", "text")], name="ix_description_text")

cursor = coll.find(
    {"$text": {"$search": "smartphone"}},
    {"_id": 0, "name": 1},
)
docs = await cursor.to_list(length=10)
```

```javascript
db.odm_motor_indexes_products.createIndex({ description: "text" }, { name: "ix_description_text" });
db.odm_motor_indexes_products.find({ $text: { $search: "smartphone" } }, { _id: 0, name: 1 });
```

### Покрокове пояснення

1. **Один текстовий індекс на колекцію** — але може охоплювати кілька рядкових полів з вагами.
2. **Стоп-слова та стеммінг** залежать від мови (`default_language: "english"`). `"phones"` і `"phone"` обидва збігаються.
3. **Запит через `$text`, а не `description: "smartphone"`** — рівність — це точний рядковий збіг.

---

## Вправа 5 — TTL-індекс (`ix_expires_at_ttl`)

### Контекст

Кешовані рядки з порівнянням цін мітять полем `expires_at`; коли термін мине — рядок має зникнути автоматично.

### Чого ви навчитеся

- Опції `expireAfterSeconds=0`.
- Тому, що TTL-видалення йде ~раз на хвилину.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `expires_at` | дата | Справжня BSON-`Date`. |

### Завдання

Створити `ix_expires_at_ttl` з `expireAfterSeconds=0`.

### Очікуваний результат

```text
- ix_expires_at_ttl: SON([('expires_at', 1)])
```

Якби `expires_at` у сіді був у минулому, відповідний рядок зник би протягом ~60 секунд.

### Підказка

`await coll.create_index([("expires_at", ASCENDING)], expireAfterSeconds=0, name="ix_expires_at_ttl")`.

### Розв'язання

```python
await coll.create_index(
    [("expires_at", ASCENDING)],
    expireAfterSeconds=0,
    name="ix_expires_at_ttl",
)
```

```javascript
db.odm_motor_indexes_products.createIndex(
  { expires_at: 1 },
  { expireAfterSeconds: 0, name: "ix_expires_at_ttl" }
);
```

### Покрокове пояснення

1. **Поле — `datetime`** в Python (BSON `Date` по дроту). Рядок не запустить TTL.
2. **`expireAfterSeconds` додається до дати.** `0` означає «протермінувати, щойно дата минула»; `3600` дав би годинну відстрочку.
3. **TTL-монітор працює ~раз на хвилину.** Тож протермінований запис може жити до ~60 с.
4. **`expireAfterSeconds` живе на індексі, не документі.** Одне правило TTL на індекс/колекцію — кілька TTL потребують кількох колекцій або partial-фільтрів.

---

## Вправа 6 — Хешований індекс (`ix_sku_hashed`)

### Контекст

Якби ця колекція шардилась між багатьма вузлами, хешування `sku` тримало б вставки рівномірно розподіленими, навіть якщо значення йдуть монотонно (`SKU-1001`, `SKU-1002`, …).

### Чого ви навчитеся

- Формі `[("sku", "hashed")]`.
- Чому на тому самому полі можна мати і unique, і hashed індекси.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `sku` | string | Хешуємо для розподілу. |

### Завдання

Створити `ix_sku_hashed`.

### Очікуваний результат

```text
- ix_sku_hashed: SON([('sku', 'hashed')])
```

### Підказка

`await coll.create_index([("sku", "hashed")], name="ix_sku_hashed")`.

### Розв'язання

```python
await coll.create_index([("sku", "hashed")], name="ix_sku_hashed")
```

```javascript
db.odm_motor_indexes_products.createIndex({ sku: "hashed" }, { name: "ix_sku_hashed" });
```

### Покрокове пояснення

1. **Хешований — лише рівність.** `find({sku: "SKU-1001"})` користує індекс; `find({sku: {$gt: "SKU-1001"}})` — ні.
2. **Два індекси на одному полі — це нормально.** `uq_sku` (B-tree, unique) і `ix_sku_hashed` (hashed) співіснують — кожен обслуговує свою форму запиту.
3. **Корисний переважно для шардингу.** На моноінстансі хешований індекс нічого додаткового не дає поверх unique B-tree.

---

## Вправа 7 — Перелік і видалення індексів

### Контекст

Після експерименту скрипт прибирає створені індекси, щоб наступний запуск починався з чистого стану — як тестова фікстура.

### Чого ви навчитеся

- Асинхронному патерну для `list_indexes()` (`async for idx in coll.list_indexes()`).
- Списку імен, який повертає `create_index`, — його можна повторно використати для видалення.

### Колекція

| Усі | — | — |
|---|---|---|

### Завдання

1. Вивести кожен індекс.
2. Видалити лише ті, що створив скрипт (не `_id_`).

### Очікуваний результат

```text
Indexes:
  - _id_: SON([('_id', 1)])
  - ix_category_single: SON([('category', 1)])
  - ix_category_price_compound: SON([('category', 1), ('price', -1)])
  - uq_sku: SON([('sku', 1)])
  - ix_description_text: SON([('_fts', 'text'), ('_ftsx', 1)])
  - ix_expires_at_ttl: SON([('expires_at', 1)])
  - ix_sku_hashed: SON([('sku', 'hashed')])

Dropped index: ix_category_single
Dropped index: ix_category_price_compound
Dropped index: uq_sku
Dropped index: ix_description_text
Dropped index: ix_expires_at_ttl
Dropped index: ix_sku_hashed
```

### Підказка

Ітеруйте `async for idx in coll.list_indexes(): ...`; збирайте імена, що повернув `create_index`, для пізнішого `await coll.drop_index(name)`.

### Розв'язання

```python
async def print_indexes(coll):
    print("Indexes:")
    async for idx in coll.list_indexes():
        print(f"  - {idx.get('name')}: {idx.get('key')}")

async def drop_created_indexes(coll, names):
    for name in names:
        await coll.drop_index(name)
        print(f"Dropped index: {name}")
```

```javascript
db.odm_motor_indexes_products.getIndexes().forEach(i => printjson(i));
db.odm_motor_indexes_products.dropIndex("ix_category_single");
db.odm_motor_indexes_products.dropIndexes(); // обережно — видалить УСЕ окрім _id_
```

### Покрокове пояснення

1. **`list_indexes()` повертає async-курсор.** Не робіть `await` напряму — ітеруйте `async for`.
2. **`_id_` неможливо видалити.** `dropIndexes()` його пропускає; `drop_index("_id_")` падає.
3. **Видалення неіснуючого індексу** падає з `OperationFailure`. Якщо не хочете, щоб це зривало очищення, обгортайте `try / except`.

---

## Шпаргалка

| Мета | Специфікація | Опції |
|---|---|---|
| Одне поле | `[("category", 1)]` | — |
| Складений | `[("category", 1), ("price", -1)]` | — |
| Унікальний | `[("sku", 1)]` | `unique=True` |
| Текстовий | `[("description", "text")]` | — |
| TTL | `[("expires_at", 1)]` | `expireAfterSeconds=0` |
| Хешований | `[("sku", "hashed")]` | — |

## Розв'язання проблем

| Симптом | Імовірне виправлення |
|---|---|
| `RuntimeWarning: coroutine '...' was never awaited` | Викликали `coll.create_index(...)` без `await`. Індекс не створено. |
| `IndexOptionsConflict` | Однакове ім'я, різна специфікація. Видаліть і створіть заново. |
| `DuplicateKeyError` під час `createIndex` | Уже існують дублікати. Спершу приберіть. |
| Текстовий пошук нічого не повертає | Стоп-слова, стеми, мова. Перевірте посаджений текст. |
| TTL-рядок не зникає | Поле має бути BSON `Date`; монітор працює ~раз на хвилину. |
| Запит усе одно `COLLSCAN` | Запустіть `db.command("explain", ...)` — побачите чому: не той тип, не той напрямок, тощо. |
