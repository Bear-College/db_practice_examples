# ODM з MongoEngine (`10_odm`)

> Translation / Переклад: [English](../../../../04_mongodb/10_odm/odm_mongoengine.md)

Ці вправи проходять **повний CRUD-цикл** через ODM — **MongoEngine** — замість сирого PyMongo. Ви визначаєте Python-клас, що дзеркалить форму документа, зберігаєте його екземпляри, шукаєте через `Product.objects`, оновлюєте і видаляєте за предикатом. Кожна вправа — один крок циклу.

Готовий файл-компаньйон: [`10_odm/example.py`](../../../../04_mongodb/10_odm/example.py). Скрипт скидає колекцію на кожному запуску, тож захоплений вивід — детермінований.

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/10_odm/example.py
```

З'єднання за замовчуванням (можна перевизначити змінними оточення):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `odm_products`

## Підмодулі (мають окремі уроки)

- [`01_selection_operators/`](01_selection_operators/) — `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$nin`, `$and`, `$or`, `$not`, `$exists`, `$regex` через MongoEngine `Q`.
- [`02_search_sorting_pagination/`](02_search_sorting_pagination/) — Motor + FastAPI + Pydantic для пошуку, сортування та пагінації.
- [`03_indexes/`](03_indexes/) — Motor + Python для створення, перегляду та видалення індексів.
- [`04_agregation_functions/`](04_agregation_functions/) — конвеєри агрегації Motor з `$group`, `$sum`, `$avg`, `$count`, `$max`, `$min`, `$match`, `$sort`, `$project`.

---

## Модель документа

```python
from datetime import datetime
from mongoengine import DateTimeField, Document, IntField, StringField, connect

class Product(Document):
    name = StringField(required=True, max_length=128)
    category = StringField(required=True, max_length=64)
    price = IntField(required=True, min_value=0)
    created_at = DateTimeField(default=datetime.utcnow)

    meta = {"collection": "odm_products"}
```

Початковий сід (скрипт спочатку викликає `Product.drop_collection()`, щоб запустити з чистого стану):

| `name` | `category` | `price` |
|---|---|---|
| iPhone 14 | Smartphone | 899 |
| MacBook Air | Laptop | 1299 |
| Galaxy S23 | Smartphone | 799 |

---

## Шаблон вправи (повторюється в кожному розділі нижче)

| Секція | Що дає |
|---|---|
| **Контекст** | Який CRM-кейс мотивує цей крок. |
| **Чого ви навчитеся** | Метод MongoEngine і базовий драйверний виклик. |
| **Документ** | Які поля задіяні. |
| **Завдання** | Конкретна вимога. |
| **Очікуваний результат** | Реальний захоплений вивід. |
| **Підказка** | Назва методу MongoEngine. |
| **Розв'язання** | MongoEngine і `mongosh` поряд. |
| **Покрокове пояснення** | Як ODM переписує запит і де грабельки. |

---

## Вправа 1 — Визначити модель і підключитися

### Контекст

Перед будь-яким I/O застосунок повинен оголосити, що таке `Product`, і підключитися до MongoDB. Клас стає джерелом істини — кожне поле валідується і кожне збереження проходить через нього.

### Чого ви навчитеся

- Наслідуванню `Document` і оголошенню полів з обмеженнями (`required`, `max_length`, `min_value`).
- `meta = {"collection": "..."}` для фіксації імені колекції.
- `connect(db=..., host=...)` для реєстрації аліаса.

### Документ

| Поле | Тип | Обмеження |
|---|---|---|
| `name` | string | `required`, `max_length=128` |
| `category` | string | `required`, `max_length=64` |
| `price` | int | `required`, `min_value=0` |
| `created_at` | datetime | `default=datetime.utcnow` |

### Завдання

Визначити модель `Product` і підключитися до `mongodb://localhost:27017` бази `edu_academy_seed`.

### Очікуваний результат

Жодного виводу — успішне підключення мовчазне. Рядки з'являться у наступній вправі після збереження.

### Підказка

`connect(db=..., host=...)` повертається миттєво з лінивим з'єднанням; реальний TCP-хендшейк — на першому читанні/записі.

### Розв'язання

```python
import os
from datetime import datetime
from mongoengine import DateTimeField, Document, IntField, StringField, connect

MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
MONGODB_DB  = os.getenv("MONGODB_DB", "edu_academy_seed")

class Product(Document):
    name = StringField(required=True, max_length=128)
    category = StringField(required=True, max_length=64)
    price = IntField(required=True, min_value=0)
    created_at = DateTimeField(default=datetime.utcnow)

    meta = {"collection": "odm_products"}

connect(db=MONGODB_DB, host=MONGODB_URI)
```

```javascript
use("edu_academy_seed");
db.odm_products.findOne();
```

### Покрокове пояснення

1. **`StringField(required=True, max_length=128)`** валідується **на клієнті** MongoEngine *до* надсилання інсерту. Відсутнє або задовге `name` — і `.save()` падає з `ValidationError`, не доходячи до MongoDB.
2. **`IntField(min_value=0)`** так само відхиляє від'ємні ціни.
3. **`DateTimeField(default=datetime.utcnow)`** ставить поточний UTC-час при створенні документа; передавайте `default=datetime.utcnow` (без круглих дужок) — функцію, не результат її виклику.
4. **`meta = {"collection": "odm_products"}`** фіксує ім'я колекції. Без цього MongoEngine виводив би `product` з імені класу.
5. **`connect()` ідемпотентний і підтримує аліаси.** Кілька баз? Викличте двічі з `alias="other"` і вкажіть `meta = {"db_alias": "other"}`.

---

## Вправа 2 — Створити (`.save()`)

### Контекст

Бек-офісна форма додає три нові товари. Кожен екземпляр будується в Python, потім зберігається `.save()` — жодного SQL `INSERT`.

### Чого ви навчитеся

- Патерну Active Record: побудувати → `.save()` → збережено.
- Що `.save()` спочатку запускає валідатори.
- Що свіжий документ отримує згенерований `_id` після `.save()`.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| Усі | — | Призначаємо. |

### Завдання

Скинути колекцію (для детермінованості) і зберегти три товари.

### Очікуваний результат

Наступна вправа їх читатиме. Зараз `Product.objects.count()` повертає `3`.

### Підказка

`Product(name=..., category=..., price=...).save()` для кожного рядка.

### Розв'язання

```python
Product.drop_collection()

Product(name="iPhone 14",   category="Smartphone", price=899).save()
Product(name="MacBook Air", category="Laptop",    price=1299).save()
Product(name="Galaxy S23",  category="Smartphone", price=799).save()
```

```javascript
db.odm_products.deleteMany({});
db.odm_products.insertMany([
  { name: "iPhone 14",   category: "Smartphone", price: 899,  created_at: new Date() },
  { name: "MacBook Air", category: "Laptop",    price: 1299, created_at: new Date() },
  { name: "Galaxy S23",  category: "Smartphone", price: 799,  created_at: new Date() }
]);
```

### Покрокове пояснення

1. **Валідатори працюють на `.save()`**, не на `__init__`. Можна сконструювати невалідний `Product`; він «вибухне» лише на збереженні.
2. **`Product.drop_collection()`** змиває і документи, і індекси, оголошені моделлю. Чистий старт.
3. **`_id` призначається після збереження.** `p = Product(...); p.save(); print(p.id)` друкує новий `ObjectId`.
4. **Bulk-insert через `Product.objects.insert([...])`.** Швидше за три `.save()` — один round-trip.

---

## Вправа 3 — Прочитати все + сортувати (`Product.objects.order_by("name")`)

### Контекст

Сторінка «Усі товари» показує всі рядки за алфавітом.

### Чого ви навчитеся

- Ітерація по `Product.objects` повертає екземпляри моделі, а не словники.
- `order_by("field")` — зростання; `order_by("-field")` — спадання.
- `.count()` — кількість збігів.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| Усі | — | Повертаємо. |

### Завдання

Прочитати всі товари за `name` зростанням і друкувати «name | category | price».

### Очікуваний результат

```text
All products count: 3
  Galaxy S23 | Smartphone | 799
  MacBook Air | Laptop | 1299
  iPhone 14 | Smartphone | 899
```

(MongoDB сортує великі ASCII перед малими, тому `iPhone 14` після `MacBook Air`.)

### Підказка

`Product.objects.order_by("name")`.

### Розв'язання

```python
all_docs = Product.objects.order_by("name")
print(f"All products count: {all_docs.count()}")
for doc in all_docs:
    print(f"  {doc.name} | {doc.category} | {doc.price}")
```

```javascript
db.odm_products.find({}).sort({ name: 1 });
db.odm_products.countDocuments({});
```

### Покрокове пояснення

1. **`Product.objects` — лінивий QuerySet.** Жоден байт не йде в MongoDB, поки ви не почнете ітерацію, `.count()`, slice або список.
2. **`order_by("name")` повертає *новий* QuerySet** — querysets імутабельні, як у Django.
3. **Регістр.** Стандартно MongoDB сортує за байтами BSON. Для локалі — `Product.objects.order_by("name").collation({"locale": "en", "strength": 2})`.
4. **`.count()` робить окремий `countDocuments`.** Два round-trips — як в `02_search_sorting_pagination`.

---

## Вправа 4 — Фільтр (`Product.objects(category="Smartphone")`)

### Контекст

Сторінка категорії показує лише смартфони, і вітрина воліє спершу найдорожчі.

### Чого ви навчитеся

- Kwarg-фільтри (`category="Smartphone"`) — це ODM-аналог `find({"category": "Smartphone"})`.
- Зворотне сортування через префікс `-` (`order_by("-price")`).

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| `category` | string | Фільтр. |
| `price` | int | Сортування. |

### Завдання

Знайти всі товари з `category == "Smartphone"`, відсортувати за `price` спаданням.

### Очікуваний результат

```text
Smartphones count: 2
  iPhone 14 | 899
  Galaxy S23 | 799
```

### Підказка

`Product.objects(category="Smartphone").order_by("-price")`.

### Розв'язання

```python
phones = Product.objects(category="Smartphone").order_by("-price")
print(f"Smartphones count: {phones.count()}")
for doc in phones:
    print(f"  {doc.name} | {doc.price}")
```

```javascript
db.odm_products
  .find({ category: "Smartphone" })
  .sort({ price: -1 });
```

### Покрокове пояснення

1. **Кілька kwargs — це AND.** `Product.objects(category="Smartphone", price__gt=800)` потребує обох предикатів.
2. **`-price`** — це короткий запис `("price", -1)` в MongoEngine.
3. **Чейн працює добре.** `Product.objects(...).order_by(...).limit(5)` читається природно.

---

## Вправа 5 — Оновити (`.update_one(set__price=...)`)

### Контекст

Ціна `iPhone 14` падає з 899 до 849. Зміна має бути атомарною — рядок не повинен тимчасово зіпсуватися.

### Чого ви навчитеся

- `Product.objects(filter).update_one(set__field=value)` для часткових оновлень.
- Синтаксу MongoEngine `set__field` для `$set: {field: value}`.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| `price` | int | Оновлюємо. |

### Завдання

Оновити ціну `iPhone 14` до `849`, потім перечитати і перевірити.

### Очікуваний результат

```text
Updated iPhone 14 price: 849
```

### Підказка

`Product.objects(name="iPhone 14").update_one(set__price=849)`.

### Розв'язання

```python
Product.objects(name="iPhone 14").update_one(set__price=849)
iphone = Product.objects.get(name="iPhone 14")
print(f"Updated iPhone 14 price: {iphone.price}")
```

```javascript
db.odm_products.updateOne(
  { name: "iPhone 14" },
  { $set: { price: 849 } }
);
db.odm_products.findOne({ name: "iPhone 14" }, { _id: 0, price: 1 });
```

### Покрокове пояснення

1. **`set__price=849`** MongoEngine переписує в `{$set: {price: 849}}`. Подвійне підкреслення — роздільник оператора (як `__gt`, `__ne`).
2. **Інші оператори.** `inc__price=10` → `{$inc: {price: 10}}`; `push__tags="new"` → `{$push: {tags: "new"}}`; `pull__tags="old"` → `{$pull: {tags: "old"}}`.
3. **`update_one`** змінює щонайбільше один документ. `update()` (псевдонім `update_many`) — усі збіги.
4. **Валідатори запускає `.save()`, а не `update`.** Сирий `update_one(set__price=-100)` пройде, *незважаючи на* `IntField(min_value=0)` — валідатор спрацьовує лише через `.save()`. Якщо валідація важлива — `obj.price = -100; obj.save()` (і ловити `ValidationError`).
5. **`Product.objects.get()`** падає з `DoesNotExist`, якщо нічого не знайдено, і `MultipleObjectsReturned`, якщо більше одного.

---

## Вправа 6 — Видалити (`.delete()`)

### Контекст

`Galaxy S23` зняли з продажу — рядок зникає з каталога.

### Чого ви навчитеся

- `Product.objects(filter).delete()` повертає кількість видалених рядків.
- `.delete()` — деструктивний і безпідтверджувальний; для прод-коду обгортайте в транзакції.

### Документ

| Поле | Тип | Примітка |
|---|---|---|
| Усі | — | Документ видаляється. |

### Завдання

Видалити рядок `Galaxy S23` і пересвідчитись, що лишилось два товари.

### Очікуваний результат

```text
Remaining after delete: 2
```

### Підказка

`Product.objects(name="Galaxy S23").delete()` потім `Product.objects.count()`.

### Розв'язання

```python
Product.objects(name="Galaxy S23").delete()
print(f"Remaining after delete: {Product.objects.count()}")
```

```javascript
db.odm_products.deleteOne({ name: "Galaxy S23" });
db.odm_products.countDocuments({});
```

### Покрокове пояснення

1. **Порожній фільтр = «видалити все».** `Product.objects().delete()` спустошує колекцію.
2. **Патерн soft-delete.** Більшість прод-коду додає `is_deleted = BooleanField(default=False)` і фільтрує — рядок лишається в базі для аудиту.
3. **`delete()` за замовчуванням *не* запускає сигнали** — підключайте через `mongoengine.signals`. Каскадні правила краще тримати в сервісному шарі або обробнику `pre_delete`.
4. **`Product.objects.count()` повертає нову загальну кількість.** Свіжий count уникає off-by-one, якщо паралельний писач теж щось змінив.

---

## Шпаргалка

| Операція | MongoEngine | Сирий mongosh |
|---|---|---|
| Підключитись | `connect(db=..., host=...)` | `use("edu_academy_seed")` |
| Вставити одне | `Product(...).save()` | `db.coll.insertOne({...})` |
| Прочитати все | `Product.objects` | `db.coll.find({})` |
| Фільтр | `Product.objects(field=value)` | `db.coll.find({field: value})` |
| Сортування | `.order_by("name")` / `"-name"` | `.sort({name: 1})` / `{name: -1}` |
| Оновити одне | `.update_one(set__field=value)` | `db.coll.updateOne(filter, {$set: {...}})` |
| Видалити | `.delete()` | `db.coll.deleteOne(...)` |
| Підрахунок | `.count()` | `db.coll.countDocuments({...})` |
| Один (або падає) | `.objects.get(field=value)` | `db.coll.findOne({field: value})` |

## Розв'язання проблем

| Симптом | Імовірне виправлення |
|---|---|
| `ValidationError` на `.save()` | Відсутнє обов'язкове поле або порушено обмеження. `e.errors` для деталей. |
| `DoesNotExist` від `.get()` | Жоден документ не збігся. Використайте `.first()` для `None`. |
| Оновлення не запускає валідатори | За дизайном. `.save()` валідує повністю. |
| Сортування ставить малі літери в кінець | За замовчуванням — байтове BSON-сортування. Додайте `collation`. |
| `MongoEngineConnectionError: You have not defined a default connection` | Забули `connect(...)` або не той аліас. |
| Індекс не активний | `meta = {"indexes": [...]}` створює їх ліниво — викличте `Product.ensure_indexes()` під час старту. |
