# CRUD у MongoDB (`01_crud`)

> Translation / Переклад: [English](../../../../04_mongodb/01_crud/crud_mongodb.md)

Ці вправи проходять **вісім основних CRUD-операцій** MongoDB через **PyMongo** (Python) і еквівалентний **mongosh** (JavaScript). Усі приклади виконуються на практичній базі `edu_academy_seed` та колекції **`products`**.

Готовий приклад: [`01_crud/example.py`](../../../../04_mongodb/01_crud/example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/01_crud/example.py
```

Налаштування з'єднання за замовчуванням (можна перевизначити через змінні середовища):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`

На початку запуску скрипт скидає колекцію через `delete_many({})`, тож вивід кожної вправи нижче — детермінований і повторюваний.

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що вона дає |
|---|---|
| **Контекст** | Навіщо реальному каталогу/адмінці ця операція. |
| **Чого ви навчитеся** | Конструкції PyMongo/mongosh, що тренує саме ця вправа. |
| **Колекція** | Документи та поля, з якими ми працюємо. |
| **Завдання** | Чітка вимога (точний фільтр/оновлення/видалення). |
| **Очікуваний результат** | Реальний вивід, знятий з живого `python example.py`. |
| **Підказка** | Один натяк на потрібний метод. |
| **Розв'язання** | Робочий Python (PyMongo) **та** еквівалентний JS для mongosh. |
| **Покрокове пояснення** | Що робить кожен фрагмент і пастки BSON / `$set` / `_id`. |

---

## Карта: SQL ↔ CRUD у MongoDB

| Операція | Стиль SQL | MongoDB / PyMongo |
|---|---|---|
| Додати один запис | `INSERT INTO products VALUES (...);` | `insert_one({...})` |
| Додати багато записів | `INSERT INTO products VALUES (...), (...);` | `insert_many([{...}, {...}])` |
| Оновити один запис | `UPDATE products SET ... WHERE ... LIMIT 1;` | `update_one({...}, {"$set": {...}})` |
| Оновити всі відповідні | `UPDATE products SET ... WHERE ...;` | `update_many({...}, {"$set": {...}})` |
| Видалити один запис | `DELETE FROM products WHERE ... LIMIT 1;` | `delete_one({...})` |
| Видалити всі відповідні | `DELETE FROM products WHERE ...;` | `delete_many({...})` |
| Очистити колекцію | `DELETE FROM products;` | `delete_many({})` |
| Видалити колекцію | `DROP TABLE products;` | `drop()` |

## Схема колекції

Колекція `products` навмисно мала і пласка:

```json
{ "_id": ObjectId("..."), "name": "iPhone 14", "category": "Phone", "price": 999 }
```

| Поле | Тип BSON | Примітки |
|---|---|---|
| `_id` | `ObjectId` | Генерується сервером, якщо явно не передати. |
| `name` | `string` | Природний ключ у фільтрах update/delete нижче. |
| `category` | `string` | Приклади значень: `Phone`, `Laptop`, `Smartphone`. |
| `price` | `int` | Зберігається як 32-бітний BSON-цілий (Python `int`). |

---

## Вправа 1 — `insert_one` (додати один запис)

### Контекст

Контент-менеджер публікує новий SKU — лише один документ, і ми хочемо отримати згенерований `_id`, щоб адмінка показала посилання-підтвердження.

### Чого ви навчитеся

- Викликати `insert_one` з одним документом.
- Що MongoDB сам генерує `ObjectId` у поле `_id`, якщо ви його не вказали.
- Об'єкту-результату `InsertOneResult` у PyMongo (`.inserted_id`).

### Колекція

| Колекція | Поля, що пишемо |
|---|---|
| `products` | `name`, `category`, `price` |

### Завдання

Вставити один продукт `{ "name": "iPhone 14", "category": "Phone", "price": 999 }` у порожню колекцію `products`.

### Очікуваний результат

```text
After INSERT operations:
  name=iPhone 14, category=Phone, price=999
  ...
```

(реальний вивід `python 04_mongodb/01_crud/example.py`, знятий після кроку 2 — скрипт спершу додає один документ, потім ще три у Вправі 2, після чого друкує всі чотири).

### Підказка

`insert_one({...})` приймає **документ** напряму (не список).

### Розв'язання

```python
from pymongo import MongoClient

client = MongoClient("mongodb://localhost:27017")
products = client["edu_academy_seed"]["products"]

result = products.insert_one(
    {"name": "iPhone 14", "category": "Phone", "price": 999}
)
print(result.inserted_id)
```

```javascript
use edu_academy_seed
db.products.insertOne({ name: "iPhone 14", category: "Phone", price: 999 })
```

### Покрокове пояснення

1. **`insert_one`** приймає один dict — якщо передати список, отримаєте `TypeError`. Для списків — `insert_many`.
2. **Поле `_id` генерується автоматично** на боці сервера як `ObjectId` (12-байтове BSON-значення). Перевірити можна через `result.inserted_id` у PyMongo або по `_id` у відповіді mongosh.
3. **Порядок полів** зберігається у BSON, але ніколи не покладайтеся на нього в запитах — Mongo адресує поля за іменем.
4. **Числа**: `999` у Python летить як 32-бітний `Int32`. Python `float` (наприклад, `999.0`) приземлиться як `Double`, що змінить поведінку `$type` (див. урок `05_check_operators`).

---

## Вправа 2 — `insert_many` (масова вставка)

### Контекст

Імпортували три SKU з CSV постачальника. Один мережевий round-trip із пакетом значно дешевший, ніж три окремі `insert_one`.

### Чого ви навчитеся

- Надсилати список документів одним викликом.
- Користуватися `InsertManyResult.inserted_ids` (список у порядку вставки).
- Чому пакетні записи у рази швидші, ніж Python-цикл.

### Колекція

| Колекція | Поля, що пишемо |
|---|---|
| `products` | `name`, `category`, `price` |

### Завдання

Після одиничної вставки додати ще три документи одним викликом: `Galaxy S23` ($899, Phone), `MacBook Air` ($1299, Laptop), `Pixel 8` ($799, Phone).

### Очікуваний результат

```text
After INSERT operations:
  name=iPhone 14, category=Phone, price=999
  name=Galaxy S23, category=Phone, price=899
  name=MacBook Air, category=Laptop, price=1299
  name=Pixel 8, category=Phone, price=799
```

### Підказка

`insert_many([...])` приймає **список** документів. Повертає по одному `_id` на документ.

### Розв'язання

```python
products.insert_many([
    {"name": "Galaxy S23", "category": "Phone", "price": 899},
    {"name": "MacBook Air", "category": "Laptop", "price": 1299},
    {"name": "Pixel 8", "category": "Phone", "price": 799},
])
```

```javascript
db.products.insertMany([
  { name: "Galaxy S23", category: "Phone", price: 899 },
  { name: "MacBook Air", category: "Laptop", price: 1299 },
  { name: "Pixel 8", category: "Phone", price: 799 }
])
```

### Покрокове пояснення

1. **Один мережевий round-trip** надсилає весь пакет. Для тисяч документів `insert_many` випереджає цикл `insert_one` у 10-100 разів.
2. **`ordered=True` за замовчуванням.** Якщо документ №2 впав (дублікат `_id`, валідатор схеми тощо), документи №3+ будуть пропущені. Передайте `ordered=False`, щоб продовжити при помилках і зібрати їх у кінці.
3. **Порожній список** кидає `InvalidOperation`. Перед викликом перевіряйте `len(docs) > 0`.
4. **`inserted_ids`** позиційно вирівняний з вхідним списком — індекс `i` відповідає `docs[i]`.

---

## Вправа 3 — `update_one` (змінити один документ)

### Контекст

Маркетинг затвердив зниження ціни лише для iPhone 14. Потрібно змінити рівно один документ — решта каталогу має лишитися недоторканою.

### Чого ви навчитеся

- Використовувати `update_one` з фільтром і update-оператором.
- Обов'язковому `$set` для часткового оновлення.
- Полям `UpdateResult`: `matched_count` проти `modified_count`.

### Колекція

| Колекція | Поле фільтру | Поле, що змінюємо |
|---|---|---|
| `products` | `name` | `price` |

### Завдання

Встановити `price = 899` у документі, де `name == "iPhone 14"`.

### Очікуваний результат

```text
update_one matched=1, modified=1
```

### Підказка

Зміну **обов'язково** загорнути у `{"$set": {...}}`. Якщо передати «голий» `{"price": 899}`, виклик впаде (а у старих драйверах — замінить документ цілком).

### Розв'язання

```python
result = products.update_one(
    {"name": "iPhone 14"},
    {"$set": {"price": 899}},
)
print(f"matched={result.matched_count}, modified={result.modified_count}")
```

```javascript
db.products.updateOne(
  { name: "iPhone 14" },
  { $set: { price: 899 } }
)
```

### Покрокове пояснення

1. **Перший аргумент — фільтр** з такою ж формою, як у `find()`. Якщо збігається кілька документів, оновиться **лише перший зустрінутий** (порядок storage, нестабільний).
2. **Другий аргумент — специфікація оновлення**, яка має починатися з оператора (`$set`, `$inc`, `$unset`, …). Без оператора PyMongo 4+ кидає `WriteError`.
3. **`matched_count`** — скільки документів пройшли фільтр; **`modified_count`** — скільки реально змінилися. Якщо нове значення дорівнює старому, побачите `matched=1, modified=0` — корисно для виявлення no-op оновлень.
4. Щоб **вставити, якщо не знайдено**, додайте `upsert=True`; результат тоді матиме `.upserted_id`.

---

## Вправа 4 — `update_many` (змінити всі збіги)

### Контекст

Перейменування таксономії: компанія ребрендує всі «Phone» на «Smartphone» у каталозі. Один запит, кожен відповідний документ.

### Чого ви навчитеся

- Різниці між `update_one` і `update_many` (єдиній різниці між ними).
- Перевіряти, скільки документів зачепив фільтр.

### Колекція

| Колекція | Поле фільтру | Поле, що змінюємо |
|---|---|---|
| `products` | `category` | `category` |

### Завдання

Змінити `category` з `"Phone"` на `"Smartphone"` для **кожного** відповідного документа.

### Очікуваний результат

```text
update_many matched=3, modified=3

After UPDATE operations:
  name=iPhone 14, category=Smartphone, price=899
  name=Galaxy S23, category=Smartphone, price=899
  name=MacBook Air, category=Laptop, price=1299
  name=Pixel 8, category=Smartphone, price=799
```

### Підказка

Форма така ж, як в `update_one`, лише назва методу інша.

### Розв'язання

```python
result = products.update_many(
    {"category": "Phone"},
    {"$set": {"category": "Smartphone"}},
)
print(f"matched={result.matched_count}, modified={result.modified_count}")
```

```javascript
db.products.updateMany(
  { category: "Phone" },
  { $set: { category: "Smartphone" } }
)
```

### Покрокове пояснення

1. **`update_many` чіпає всі збіги.** Це найчастіша «бойова» пастка — забути, що `update_one` зупиняється на першому збігу і тихо лишає старі дані.
2. **MacBook Air не зачеплено**, бо його `category == "Laptop"` не задовольняє фільтр — наочний доказ того, що масштаб визначає фільтр, а не цикл.
3. **Оператори атомарні на рівні документа.** Поки запис ітерує, інші пишучі процеси можуть вклинюватися між документами (MongoDB гарантує атомарність лише на документ, а не транзакцію над усіма збігами — для цього потрібна session/transaction).

---

## Вправа 5 — `delete_one` (видалити один документ)

### Контекст

Клієнт повідомив, що зарезервоване оголошення про iPhone 14 треба прибрати з публічного каталогу (юридична вимога). Видаляємо рівно один документ за іменем.

### Чого ви навчитеся

- Видаляти один документ.
- `DeleteResult.deleted_count` (0 або 1).
- Чому `delete_one` безпечніший за `delete_many` для адмін-дій нашвидкуруч.

### Колекція

| Колекція | Поле фільтру |
|---|---|
| `products` | `name` |

### Завдання

Видалити документ, де `name == "iPhone 14"`.

### Очікуваний результат

```text
delete_one deleted=1
```

### Підказка

`delete_one(filter)` — без другого аргументу, без `$set`.

### Розв'язання

```python
result = products.delete_one({"name": "iPhone 14"})
print(f"deleted={result.deleted_count}")
```

```javascript
db.products.deleteOne({ name: "iPhone 14" })
```

### Покрокове пояснення

1. **`delete_one` зупиняється на першому збігу** у storage-порядку. З дублікатами імен немає гарантії, *який саме* документ зникне.
2. **`deleted_count`** — `0` або `1`. Якщо треба семантично підтвердити видалення (наприклад, для аудиту), використовуйте `find_one_and_delete` — він повертає видалений документ.
3. **Порожній фільтр `{}` видалить *випадковий* документ.** Та сама пастка, що й `DELETE` без `WHERE` — ніколи не запускайте без фільтра у продакшені.

---

## Вправа 6 — `delete_many` (з фільтром)

### Контекст

У регіоні припиняють продаж «Smartphone». Видаляємо всі продукти з цією категорією.

### Чого ви навчитеся

- Видаляти всі документи, що відповідають фільтру, одним викликом.
- Перевіряти масштаб через `deleted_count`.

### Колекція

| Колекція | Поле фільтру |
|---|---|
| `products` | `category` |

### Завдання

Видалити кожен документ, де `category == "Smartphone"`.

### Очікуваний результат

```text
delete_many(category=Smartphone) deleted=2

After DELETE (filtered) operations:
  name=MacBook Air, category=Laptop, price=1299
```

### Підказка

`delete_many({"category": "Smartphone"})`.

### Розв'язання

```python
result = products.delete_many({"category": "Smartphone"})
print(f"deleted={result.deleted_count}")
```

```javascript
db.products.deleteMany({ category: "Smartphone" })
```

### Покрокове пояснення

1. **Чому 2, а не 3?** Тому що Вправа 5 уже видалила iPhone 14 (який у Вправі 4 був перекатегоризований у `Smartphone`). Залишилися лише Galaxy S23 і Pixel 8 у цій категорії.
2. **`delete_many` атомарний на документ**, а не як транзакція. Якщо сервер впаде посеред ітерації, ви побачите часткове видалення — для all-or-nothing потрібні sessions.
3. **Завжди перевіряйте фільтр через `find()`** у продакшені. Скасування нема.

---

## Вправа 7 — `delete_many({})` (очистити колекцію)

### Контекст

Прибирання після заняття: спорожнити практичну колекцію, не видаляючи її саму (щоб вижили індекси).

### Чого ви навчитеся

- Порожній фільтр `{}` збігається з будь-яким документом.
- Різниці між «спорожнити колекцію» та «видалити колекцію» (наступна вправа).

### Колекція

| Колекція | Фільтр |
|---|---|
| `products` | `{}` (усе) |

### Завдання

Видалити всі документи, що лишилися, потім перевірити, що кількість дорівнює `0`.

### Очікуваний результат

```text
delete_many({}) deleted=1
Remaining docs in collection: 0
```

### Підказка

`delete_many({})` плюс `count_documents({})` для перевірки.

### Розв'язання

```python
cleared = products.delete_many({})
print(f"deleted={cleared.deleted_count}")
print(f"remaining={products.count_documents({})}")
```

```javascript
db.products.deleteMany({})
db.products.countDocuments({})
```

### Покрокове пояснення

1. **`{}` — це «завжди істинний» фільтр** (аналог `WHERE 1=1` у SQL). Це *єдиний* спосіб попросити `delete_many` змести все.
2. **`count_documents({})`** виконує агрегацію з точним підрахунком. `estimated_document_count()` швидший, але користується кешованими метаданими — це нормально для дашбордів, але не для асертів у тестах.
3. **Колекція лишається** після цього, просто порожня. Усі індекси, валідатори, налаштування зберігаються.

---

## Вправа 8 — `drop` (видалити колекцію цілком)

### Контекст

Після воркшопу зачищаємо все — і дані, **і** метадані колекції (індекси, опції). Наступний запуск починається з повністю чистого аркушу.

### Чого ви навчитеся

- `drop()` видаляє саму колекцію, а не лише її документи.
- Перевіряти, що колекція зникла, через список колекцій.

### Колекція

| Колекція | Що відбувається |
|---|---|
| `products` | Повністю видаляється |

### Завдання

Видалити колекцію `products` і впевнитися, що її більше нема у базі.

### Очікуваний результат

```text
Collection exists after drop: False
```

### Підказка

`drop()` — без параметрів. Перевірити через `db.list_collection_names()`.

### Розв'язання

```python
products.drop()
print(COLLECTION_NAME in client["edu_academy_seed"].list_collection_names())
```

```javascript
db.products.drop()
db.getCollectionNames().includes("products")
```

### Покрокове пояснення

1. **`drop` видаляє**: документи, запис колекції у `system.namespaces`, кожен вторинний індекс і всі per-collection опції (validator, ttl, capped). **Назад без бекапу не повернеш.**
2. **`delete_many({})` vs `drop()`**: перше лишає колекцію готовою до нових вставок (дешево, індекси на місці); друге — еквівалент `DROP TABLE`. Для рутинних ресетів у тестах краще `delete_many({})`.
3. **Авто-відтворення:** запис у видалену колекцію автоматично створить її при наступному insert, але **без старих індексів**. Якщо ви покладалися на unique-індекс, створіть його явно ще раз.

---

## Розв'язання типових проблем

| Симптом | Імовірне рішення |
|---|---|
| `WriteError: Modifiers may not be applied to _id` | Ви намагалися змінити `_id`. Не можна — `_id` незмінний. Видаліть і вставте заново. |
| `update_one` повертає `matched=0` | Фільтр нічого не знаходить. Перевірте через `find_one(filter)`, що саме він збігає. |
| `update_one` повертає `matched=1, modified=0` | Нове значення дорівнює старому — Mongo пропускає запис. Це не помилка. |
| `BulkWriteError` на `insert_many` | Дубль `_id` або валідація. Передайте `ordered=False`, щоб вставити решту, і дивіться `.details`. |
| `pymongo.errors.OperationFailure: not authorized` | Підключайтеся під користувачем з `readWrite` на цю базу. |

Запустити весь урок наскрізь: `python 04_mongodb/01_crud/example.py`.
