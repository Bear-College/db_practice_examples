# Індекси в MongoDB (`09_indexes`)

> Translation / Переклад: [English](../../../../04_mongodb/09_indexes/indexes_mongodb.md)

Ці вправи проходять **шість основних типів індексів** MongoDB — індекс по одному полю, складений, унікальний, текстовий, TTL і хешований — через PyMongo. У кожному розділі є виклик `create_index`, метадані з `db.collection.getIndexes()` і (де це важливо) план `explain('executionStats')`, який доводить, що новий індекс справді використовується.

Готовий файл-компаньйон: [`09_indexes/example.py`](../../../../04_mongodb/09_indexes/example.py). Скрипт засіває чотирьох людей, гарантує існування перелічених індексів, друкує їх і виконує два демо-запити (`city`-фільтр і `$text`-пошук). Створенням керують дві змінні нагорі скрипта:

```python
RUN_CREATE_INDEXES = True        # увімкнути створення
RUN_DROP_INDEXES   = False       # увімкнути видалення
INDEXES_TO_CREATE  = {"ix_city_single", "ix_city_age_compound", ...}
INDEXES_TO_DROP    = []
```

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/09_indexes/example.py
```

З'єднання за замовчуванням (можна перевизначити змінними оточення):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `indexes_people`

---

## Шаблон вправи (повторюється в кожному розділі нижче)

| Секція | Що дає |
|---|---|
| **Контекст** | Яке навантаження мотивує саме цей індекс. |
| **Чого ви навчитеся** | Конкретний тип індексу. |
| **Колекція** | Поля, що беруть участь в індексі. |
| **Завдання** | Точна команда `create_index`. |
| **Очікуваний результат** | Реальний JSON `getIndexes()` / `explain()`. |
| **Підказка** | Потрібна функція PyMongo і правильні `kwargs`. |
| **Розв'язання** | PyMongo і `mongosh` поряд. |
| **Покрокове пояснення** | Що дає індекс і де грабельки. |

---

## Колекція: `indexes_people`

Сід вставляє 4 користувачів з полями, на які ціляться індекси:

```json
{
  "user_id": "u1001",
  "name": "Anna",
  "email": "anna@example.com",
  "city": "New York",
  "age": 22,
  "bio": "Python developer and backend engineer",
  "expires_at": ISODate("...")
}
```

| `name` | `city` | `age` | `email` | `bio` | `expires_at` |
|---|---|---|---|---|---|
| Anna | New York | 22 | anna@example.com | "Python developer and backend engineer" | +5 днів |
| Bohdan | Chicago | 28 | bohdan@example.com | "JavaScript developer and frontend specialist" | +3 дні |
| Chris | New York | 35 | chris@example.com | "Data engineer and SQL expert" | +10 днів |
| Daria | Kyiv | 30 | daria@example.com | "Engineering manager and mentor" | **-1 день** (вже минув) |

`expires_at` у Daria — в минулому. TTL-монітор приберe її протягом ~60 секунд, коли TTL-індекс активний.

Після першого запуску скрипта `getIndexes()` повертає:

```text
Indexes in indexes_people:
  - _id_: keys=[('_id', 1)], options={}
  - ix_city_single: keys=[('city', 1)], options={}
  - ix_city_age_compound: keys=[('city', 1), ('age', -1)], options={}
  - uq_email_unique: keys=[('email', 1)], options={'unique': True}
  - ix_bio_text: keys=[('_fts', 'text'), ('_ftsx', 1)], options={'weights': SON([('bio', 1)]), 'default_language': 'english', 'language_override': 'language', 'textIndexVersion': 3}
  - ix_expires_at_ttl: keys=[('expires_at', 1)], options={'expireAfterSeconds': 0}
  - ix_user_id_hashed: keys=[('user_id', 'hashed')], options={}
```

---

## Вправа 1 — Індекс по одному полю

### Контекст

Звіт «клієнти за містом» тисячі разів на день виконує `find({city: "..."})`. Без індексу — повне сканування колекції; з індексом — пошук за ключем.

### Чого ви навчитеся

- Найпростіший виклик `create_index`: одне поле, зростання.
- Як читати стадію `IXSCAN` у плані `explain`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `city` | string | Предикат запиту. |

### Завдання

Створити індекс по `city` (за зростанням), назвати `ix_city_single`, потім запустити `find({"city": "New York"})` і пересвідчитись, що планувальник використовує його.

### Очікуваний результат

```text
Created index: ix_city_single (Single field index on city)
```

`explain('executionStats')` для `find({"city": "New York"})` звітує `IXSCAN` по `ix_city_single`:

```text
--- Winning plan (find city=New York) ---
{
  "stage": "FETCH",
  "inputStage": {
    "stage": "IXSCAN",
    "keyPattern": { "city": 1 },
    "indexName": "ix_city_single",
    "isMultiKey": false,
    "direction": "forward",
    "indexBounds": { "city": ["[\"New York\", \"New York\"]"] }
  }
}

--- executionStats (find city=New York) ---
{
  "executionSuccess": true,
  "nReturned": 2,
  "executionTimeMillis": 1,
  "totalKeysExamined": 2,
  "totalDocsExamined": 2
}
```

`totalKeysExamined == nReturned == 2` — підручниковий «ідеальний» індексований доступ: один ключ на один повернутий документ.

### Підказка

`coll.create_index([("city", ASCENDING)], name="ix_city_single")`.

### Розв'язання

```python
from pymongo import ASCENDING, MongoClient

coll = MongoClient("mongodb://localhost:27017")["edu_academy_seed"]["indexes_people"]
coll.create_index([("city", ASCENDING)], name="ix_city_single")

plan = coll.database.command(
    "explain",
    {"find": coll.name, "filter": {"city": "New York"}},
    verbosity="executionStats",
)
print(plan["queryPlanner"]["winningPlan"])
```

```javascript
use("edu_academy_seed");
db.indexes_people.createIndex({ city: 1 }, { name: "ix_city_single" });
db.indexes_people.find({ city: "New York" }).explain("executionStats");
```

### Покрокове пояснення

1. **`createIndex` — ідемпотентний.** Повторний виклик з тією ж специфікацією — no-op. Зі *змінами* і тим самим іменем — помилка.
2. **Напрямок (`1` / `-1`) має значення для складеного індексу**, не для одиничного. Запит з `sort({city: -1})` все одно використає індекс за зростанням — MongoDB просто пройде його назад.
3. **Витрати на розмір.** Кожен лист B-дерева містить ключ + `_id` документа. Закладайте 5-15% від розміру колекції на кожен індекс.
4. **`IXSCAN` → `FETCH`.** Спочатку індекс повертає `_id` збігів; потім окрема стадія підтягує повні документи. З *покриваючою* проєкцією (тільки індексовані поля) `FETCH` зникає.

---

## Вправа 2 — Складений індекс

### Контекст

Той самий дашборд хоче ще й «клієнти в цьому місті, найстарші зверху». Один індекс, який знає і `city`, і `age`, перетворює фільтр + сортування на один індексований прохід.

### Чого ви навчитеся

- Порядок полів у складеному індексі важливий.
- Змішані напрямки `asc` / `desc`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `city` | string | Перший ключ. |
| `age` | int | Другий ключ, за спаданням. |

### Завдання

Створити складений індекс `(city ASC, age DESC)` з ім'ям `ix_city_age_compound`. Переконатись, що він з'явився в метаданих.

### Очікуваний результат

```text
Created index: ix_city_age_compound (Compound index on city + age)

Indexes in indexes_people:
  ...
  - ix_city_age_compound: keys=[('city', 1), ('age', -1)], options={}
  ...
```

### Підказка

`create_index([("city", ASCENDING), ("age", DESCENDING)], name="ix_city_age_compound")`.

### Розв'язання

```python
from pymongo import ASCENDING, DESCENDING
coll.create_index(
    [("city", ASCENDING), ("age", DESCENDING)],
    name="ix_city_age_compound",
)
```

```javascript
db.indexes_people.createIndex(
  { city: 1, age: -1 },
  { name: "ix_city_age_compound" }
);
```

### Покрокове пояснення

1. **Equality, Sort, Range.** Оптимальний порядок полів — **ESR**: спочатку рівність, потім поле сортування, потім діапазон. `city` (рівність) перед `age` (sort/range) — саме той випадок.
2. **Префікси індексу.** `(city, age)` обслуговує запити по `city` сам, **але не** по `age` сам. Якщо потрібно і те, і те, створюйте два індекси.
3. **Змішані напрямки.** `(city ASC, age DESC)` і `(city DESC, age ASC)` — еквівалентні: MongoDB може йти обома напрямками. Але `(city ASC, age DESC)` і `(city ASC, age ASC)` — **різні**: для сортування `{city: 1, age: -1}` без сортування в пам'яті придатний лише перший.
4. **Селективність.** Якщо є вибір, ставте селективніше поле першим; для навантаження «city → age» `city` справді кращий вибір.

---

## Вправа 3 — Унікальний індекс

### Контекст

`email` має бути унікальним для кожного користувача — застосунок зараз покладається на базу для відхилення дублікатів під час вставки.

### Чого ви навчитеся

- Опції індексу `unique=True`.
- Помилки `DuplicateKey`, що захищає цілісність.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `email` | string | Має бути унікальним. |

### Завдання

Створити унікальний індекс `uq_email_unique` на `email`. Продемонструвати, що повторна вставка з тим самим email відхиляється.

### Очікуваний результат

```text
Created index: uq_email_unique (Unique index on email)
```

Метадані показують `'unique': True`:

```text
- uq_email_unique: keys=[('email', 1)], options={'unique': True}
```

Спроба `coll.insert_one({"email": "anna@example.com", ...})` спричиняє `pymongo.errors.DuplicateKeyError: E11000 duplicate key error collection: edu_academy_seed.indexes_people index: uq_email_unique dup key: { email: "anna@example.com" }`.

### Підказка

`coll.create_index([("email", ASCENDING)], unique=True, name="uq_email_unique")`.

### Розв'язання

```python
from pymongo.errors import DuplicateKeyError

coll.create_index([("email", ASCENDING)], unique=True, name="uq_email_unique")

try:
    coll.insert_one({
        "user_id": "u9999",
        "name": "Anna 2",
        "email": "anna@example.com",
    })
except DuplicateKeyError as e:
    print("rejected:", e.details.get("errmsg"))
```

```javascript
db.indexes_people.createIndex(
  { email: 1 },
  { unique: true, name: "uq_email_unique" }
);
try {
  db.indexes_people.insertOne({ email: "anna@example.com" });
} catch (e) {
  print("rejected:", e.errmsg);
}
```

### Покрокове пояснення

1. **Унікальність — за індексованим значенням.** Два документи можуть мати `email == null` лише якщо `email` справді `null` (а не відсутній); для дозволу багатьох відсутніх — *sparse*-індекс.
2. **Існуючі дублікати ламають створення.** Якщо колекція вже містить два документи з однаковим email, `createIndex` падає з `duplicate key`. Спершу прибирайте.
3. **Кластерне забезпечення.** У шардованому кластері унікальний ключ має містити шард-ключ — інакше MongoDB не зможе гарантувати унікальність між шардами.
4. **Компроміс читання/запису.** Унікальний індекс читається з тією ж швидкістю, що й звичайний, але кожна вставка платить невеликий штраф за перевірку.

---

## Вправа 4 — Текстовий індекс

### Контекст

Внутрішня пошукова сторінка «hire-search» виконує запити по `bio` на кшталт «Python developer». Текстовий індекс перетворює це на токенізований повнотекстовий пошук, який *значно* дешевший за regex-сканування.

### Чого ви навчитеся

- Тип текстового індексу.
- Оператора запиту `$text` / `$search`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `bio` | string | Текстово індексований стовпець. |

### Завдання

Створити текстовий індекс `ix_bio_text` на `bio`, потім зробити запит за словом `"developer"`.

### Очікуваний результат

```text
Created index: ix_bio_text (Text index on bio)
```

Метадані показують внутрішні ключі `_fts` / `_ftsx`:

```text
- ix_bio_text: keys=[('_fts', 'text'), ('_ftsx', 1)],
  options={'weights': SON([('bio', 1)]), 'default_language': 'english',
           'language_override': 'language', 'textIndexVersion': 3}
```

Запуск пошуку:

```text
$text search 'developer' -> [
  {'name': 'Bohdan', 'bio': 'JavaScript developer and frontend specialist'},
  {'name': 'Anna',   'bio': 'Python developer and backend engineer'}
]
```

Chris пропадає (у нього в bio "Data engineer", а не "developer").

### Підказка

Перший аргумент `create_index` — `[("bio", "text")]`. Зверніть увагу: рядок `"text"`, а не `1`/`-1`.

### Розв'язання

```python
coll.create_index([("bio", "text")], name="ix_bio_text")

hits = list(
    coll.find(
        {"$text": {"$search": "developer"}},
        {"_id": 0, "name": 1, "bio": 1},
    )
)
for d in hits:
    print(d)
```

```javascript
db.indexes_people.createIndex({ bio: "text" }, { name: "ix_bio_text" });
db.indexes_people.find(
  { $text: { $search: "developer" } },
  { _id: 0, name: 1, bio: 1 }
);
```

### Покрокове пояснення

1. **У колекції може бути не більше одного текстового індексу** — але він може охоплювати кілька рядкових полів: `[("title", "text"), ("body", "text")]`.
2. **Лише `$text` ним користується.** Запит `{bio: "developer"}` — це точна рівність рядків, а не токенізований пошук.
3. **Стеммінг та стоп-слова.** `default_language: "english"` вмикає Porter-стеммінг і вилучення англійських стоп-слів. `{$text: {$search: "develop"}}` теж знайде "developer".
4. **Оцінка через `$meta`.** Додайте `{score: {$meta: "textScore"}}` у проєкцію і сортування, щоб ранжувати результати.

---

## Вправа 5 — TTL (time-to-live) індекс

### Контекст

У Daria `expires_at` встановлено на вчора. Аутентифікаційна система зберігає session-подібні записи, які **повинні** автоматично «протухати», — TTL-індекс прибирає їх на стороні сервера, без cron-задач.

### Чого ви навчитеся

- Тип TTL-індексу.
- Опції `expireAfterSeconds`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `expires_at` | дата | Має бути справжнім `Date` (BSON), не рядком. |

### Завдання

Створити TTL-індекс `ix_expires_at_ttl` на `expires_at` з `expireAfterSeconds=0`. Через ~60 секунд протермінований документ Daria зникне.

### Очікуваний результат

```text
Created index: ix_expires_at_ttl (TTL index on expires_at)
```

Метадані:

```text
- ix_expires_at_ttl: keys=[('expires_at', 1)], options={'expireAfterSeconds': 0}
```

Після запуску TTL-монітора (за замовчуванням раз на хвилину) Daria зникне:

```python
coll.count_documents({"name": "Daria"})  # з часом стане 0
```

### Підказка

`create_index([("expires_at", ASCENDING)], expireAfterSeconds=0, name="ix_expires_at_ttl")`.

### Розв'язання

```python
coll.create_index(
    [("expires_at", ASCENDING)],
    expireAfterSeconds=0,
    name="ix_expires_at_ttl",
)
```

```javascript
db.indexes_people.createIndex(
  { expires_at: 1 },
  { expireAfterSeconds: 0, name: "ix_expires_at_ttl" }
);
```

### Покрокове пояснення

1. **Поле має бути BSON-датою.** Рядкові дати не зчитуються.
2. **`expireAfterSeconds`** — це **термін очікування** після індексованої дати. `0` означає «видаляти, щойно дата мине».
3. **TTL-монітор запускається ~раз на хвилину.** Тож запис може ще жити ~60 секунд після фактичного протермінування.
4. **Не для кешування.** TTL видаляє *весь* документ. Для часткового протермінування використовуйте `$set` + перевірку дати.

---

## Вправа 6 — Хешований індекс

### Контекст

Поле `user_id` — рядок з високою кардинальністю, на якому шардиться продакшн-кластер. Хешований індекс рівномірно розкидає дані між шардами, навіть коли значення `user_id` ідуть лексикографічно (`u1001`, `u1002`, …).

### Чого ви навчитеся

- Тип хешованого індексу.
- Чому це канонічний вибір для шард-ключа на монотонно зростаючих значеннях.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `user_id` | string | Хешуємо для шардингу. |

### Завдання

Створити хешований індекс `ix_user_id_hashed` на `user_id`.

### Очікуваний результат

```text
Created index: ix_user_id_hashed (Hashed index on user_id)
```

Метадані:

```text
- ix_user_id_hashed: keys=[('user_id', 'hashed')], options={}
```

### Підказка

Специфікація індексу — `[("user_id", "hashed")]` (як і з `"text"`).

### Розв'язання

```python
coll.create_index([("user_id", "hashed")], name="ix_user_id_hashed")
```

```javascript
db.indexes_people.createIndex({ user_id: "hashed" }, { name: "ix_user_id_hashed" });
```

### Покрокове пояснення

1. **Хешовані індекси — лише рівність.** `{user_id: "u1003"}` швидко; `{user_id: {$gt: "u1003"}}` — ні (функція хешу нищить порядок).
2. **Як шард-ключ.** Рівномірний розподіл вставок між шардами — головна причина обрати хешований індекс замість звичайного.
3. **Без обмеження унікальності.** Хешований індекс не може бути unique. Якщо потрібні обидва, створюйте *два* індекси: один хешований (для шардингу) і один звичайний `unique` (для обмеження).
4. **Витрати на зберігання.** Хеші — 64-бітні цілі, зазвичай менші за вихідні рядки.

---

## Вправа 7 — Перевірка через `explain('executionStats')`

### Контекст

Індекси марні, якщо планувальник їх ігнорує. Щоразу після додавання/зміни індексу доведіть реальним `explain`-запуском, що він використовується.

### Чого ви навчитеся

- Двох варіантів `explain`, які використовуються в 99% випадків: `queryPlanner` і `executionStats`.
- Як читати `nReturned`, `totalKeysExamined`, `totalDocsExamined`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `city` | string | Фільтр для перевірки `ix_city_single`. |

### Завдання

Запустити `find({"city": "New York"}).explain("executionStats")` і перевірити три речі: (а) переможна стадія — `IXSCAN`, (б) правильний `indexName`, (в) `totalKeysExamined == nReturned` (без зайвої роботи).

### Очікуваний результат

```text
--- Winning plan (find city=New York) ---
{
  "stage": "FETCH",
  "inputStage": {
    "stage": "IXSCAN",
    "keyPattern": { "city": 1 },
    "indexName": "ix_city_single",
    "isMultiKey": false,
    "direction": "forward",
    "indexBounds": { "city": ["[\"New York\", \"New York\"]"] }
  }
}

--- executionStats ---
{
  "executionSuccess": true,
  "nReturned": 2,
  "executionTimeMillis": 1,
  "totalKeysExamined": 2,
  "totalDocsExamined": 2
}
```

### Підказка

У PyMongo використовуйте `db.command("explain", {...}, verbosity="executionStats")` — портабельніше, ніж `cursor.explain()`, який поводиться по-різному між версіями.

### Розв'язання

```python
plan = coll.database.command(
    "explain",
    {"find": coll.name, "filter": {"city": "New York"}},
    verbosity="executionStats",
)
print(plan["queryPlanner"]["winningPlan"])
stats = plan["executionStats"]
print("nReturned         =", stats["nReturned"])
print("totalKeysExamined =", stats["totalKeysExamined"])
print("totalDocsExamined =", stats["totalDocsExamined"])
```

```javascript
db.indexes_people
  .find({ city: "New York" })
  .explain("executionStats");
```

### Покрокове пояснення

1. **`COLLSCAN` — червоний прапорець.** Це означає, що MongoDB прочитала кожен документ. Або планувальник не знайшов придатного індексу, або предикат недостатньо селективний.
2. **`totalDocsExamined ≫ nReturned`?** Індекс не покриває предикат. Додайте відсутню колонку до індексу.
3. **`totalKeysExamined ≫ nReturned`?** Індекс використовується частково, але межі діапазону широкі. Як правило, винен неправильний порядок у складеному індексі.
4. **`isCached: true`.** Планувальник повторно використав кешований план. Плани кешуються за формою запиту — однакова форма, різні параметри → один план.

---

## Шпаргалка

| Мета | Специфікація | Опції |
|---|---|---|
| Одне поле | `[("city", 1)]` | — |
| Складений | `[("city", 1), ("age", -1)]` | — |
| Унікальний | `[("email", 1)]` | `unique=True` |
| Текстовий | `[("bio", "text")]` | — |
| TTL | `[("expires_at", 1)]` | `expireAfterSeconds=0` |
| Хешований | `[("user_id", "hashed")]` | — |

## Розв'язання проблем

| Симптом | Імовірне виправлення |
|---|---|
| `IndexOptionsConflict` | Індекс з таким іменем уже існує, але з *іншою* специфікацією. Видаліть, перестворіть. |
| `DuplicateKeyError` під час `createIndex` (unique) | Уже є дублікати. Спершу приберіть їх (наприклад, `aggregate` для пошуку груп). |
| Запит усе одно `COLLSCAN` | Тип предиката не збігається з типом поля, або напрямок сортування заважає індексу. `explain()` підкаже. |
| Текстовий пошук нічого не повертає | Слова можуть токенізуватись інакше (стеми, стоп-слова). Спробуйте корінь або змініть мову. |
| TTL-рядок не зникає | Поле не BSON-дата, або монітор ще не запустився (зачекайте ~60 с). |
| Хешований індекс пригальмовує діапазонний запит | Очікувано — він лише для рівності. Додайте звичайний індекс для діапазонів. |
