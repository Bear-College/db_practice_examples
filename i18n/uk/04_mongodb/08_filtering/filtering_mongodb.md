# Фільтрація в MongoDB (`08_filtering`)

> Translation / Переклад: [English](../../../../04_mongodb/08_filtering/filtering_mongodb.md)

Ці вправи зводять усі типові техніки **фільтрації** в один робочий процес PyMongo: простий `find` / `find_one`, оператори порівняння, перевірку входження у множину, логічну композицію, доступ до вкладених полів через крапкову нотацію, фільтри масивів, регулярні вирази та перевірку наявності поля. Разом вони перекривають можливості SQL-секції `WHERE` і навіть трохи більше.

Готовий файл-компаньйон: [`08_filtering/example.py`](../../../../04_mongodb/08_filtering/example.py).

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/08_filtering/example.py
```

З'єднання за замовчуванням (можна перевизначити змінними оточення):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `filtering_people`

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що вона дає |
|---|---|
| **Контекст** | Навіщо реальному екрану цей фільтр. |
| **Чого ви навчитеся** | Який саме оператор/концепт тренує вправа. |
| **Колекція** | Лише ті поля, до яких звертаємось. |
| **Завдання** | Конкретний предикат або набір предикатів. |
| **Очікуваний результат** | Реальний вивід `python example.py`. |
| **Підказка** | Один натяк. |
| **Розв'язання** | Версії PyMongo та `mongosh` того самого запиту. |
| **Покрокове пояснення** | Що робить кожен оператор і типові помилки. |

---

## Колекція: `filtering_people`

Сід вставляє п'ять документів. Форма навмисно багата (скаляри, вкладений `profile`, масив рядків, масив піддокументів), щоб одна колекція покривала всі групи операторів:

```json
{
  "name": "Anna",
  "age": 17,
  "city": "Chicago",
  "email": "anna@gmail.com",
  "phone": "+1-202-555-0101",
  "profile": { "city": "Chicago", "experience": 1 },
  "skills":  ["Python", "JavaScript", "SQL"],
  "grades":  [{"subject": "math", "score": 95}, {"subject": "history", "score": 88}]
}
```

Зведення після пересіву:

| `name` | `age` | `city` | `email` | `phone` | `profile.experience` |
|---|---|---|---|---|---|
| Anna | 17 | Chicago | anna@gmail.com | є | 1 |
| Bohdan | 18 | New York | bohdan@outlook.com | **відсутнє** | 2 |
| Chris | 25 | Los Angeles | chris@gmail.com | є | 4 |
| Daria | 30 | Kyiv | daria@yahoo.com | є | 7 |
| Emma | 45 | New York | emma@gmail.com | є | 15 |

Допоміжна функція зі скрипта:

```python
def run_query(coll, title, query):
    docs = list(coll.find(query, {"_id": 0, "name": 1}).sort("name", 1))
    names = [d.get("name") for d in docs]
    print(f"{title}\n  query={query}\n  count={len(docs)}\n  names={names}\n")
```

---

## Вправа 1 — `find()` (вибрати все) + проєкція

### Контекст

Адмін-UI показує бічну панель з **іменами** усіх людей. Гнати по мережі повний документ — марно: екрану потрібне лише `name`.

### Чого ви навчитеся

- `find({})` для сканування колекції.
- Проєкції `{ "_id": 0, "name": 1 }` для обрізання трафіку.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `name` | string | Єдине повертане поле. |

### Завдання

Повернути всі документи, проєктувати лише `name`, прибрати `_id`, відсортувати за алфавітом.

### Очікуваний результат

```text
find() all documents
  count=5
  names=[Anna, Bohdan, Chris, Daria, Emma]
```

### Підказка

Порожній фільтр `{}` відповідає всьому. Другий аргумент `find()` — проєкція.

### Розв'язання

```python
docs = list(coll.find({}, {"_id": 0, "name": 1}).sort("name", 1))
for d in docs:
    print(d)
```

```javascript
db.filtering_people.find({}, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Покрокове пояснення

1. **`find({})` повертає курсор**, а не список. Ітерація вичерпує його; обгорнути `list(...)`, щоб матеріалізувати.
2. **`_id` повертається за замовчуванням.** Прибирається лише через `{"_id": 0}`.
3. **Включення / виключення не можна змішувати**, крім `_id`. `{"name": 1, "email": 0}` — помилка; `{"_id": 0, "name": 1}` — канонічна форма.

---

## Вправа 2 — `find_one()` (один документ)

### Контекст

Сторінка профілю показує повний запис одного користувача — клік по «Anna» має повернути саме її документ.

### Чого ви навчитеся

- `find_one()` для «потрібен один рядок».
- Різниці між `find_one`, що повертає `None`, і `find`, що повертає порожній курсор.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| Усі | — | Документ цілком. |

### Завдання

Знайти користувача з `name = "Anna"` і повернути весь документ (без `_id`).

### Очікуваний результат

```text
find_one() by name=Anna
  doc={'name': 'Anna', 'age': 17, 'city': 'Chicago', 'email': 'anna@gmail.com', 'phone': '+1-202-555-0101', 'profile': {'city': 'Chicago', 'experience': 1}, 'skills': ['Python', 'JavaScript', 'SQL'], 'grades': [{'subject': 'math', 'score': 95}, {'subject': 'history', 'score': 88}]}
```

### Підказка

`coll.find_one(filter, projection)` повертає `dict` або `None`.

### Розв'язання

```python
one = coll.find_one({"name": "Anna"}, {"_id": 0})
print(one)
```

```javascript
db.filtering_people.findOne({ name: "Anna" }, { _id: 0 });
```

### Покрокове пояснення

1. **`find_one` повертає перший збіг.** Якщо їх кілька, решту тихо пропускає — комбінуйте з унікальним полем або сортуванням, щоб «перший» був детермінованим.
2. **`None` означає «нічого не знайдено».** Завжди перевіряйте перед `one["age"]`, інакше `TypeError: 'NoneType' object is not subscriptable`.
3. **Правила проєкції такі ж, як у `find`.** `{"_id": 0}` прибирає ObjectId.

---

## Вправа 3 — Оператори порівняння (`$gt`, `$lte`)

### Контекст

Два аналітичні фільтри: (а) «користувачі старші за 25»; (б) «користувачі 30 років і молодші» для звіту за віковими групами.

### Чого ви навчитеся

- П'яти базових операторів порівняння: `$eq`, `$ne`, `$gt`, `$gte`, `$lt`, `$lte`.
- Що порівняння з `null` має особливі правила (див. Вправу 9).

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `age` | int | Числовий стовпець для порівняння. |

### Завдання

1. Імена тих, у кого `age > 25`.
2. Імена тих, у кого `age <= 30`.

### Очікуваний результат

```text
Comparison: age > 25
  query={'age': {'$gt': 25}}
  count=2
  names=[Daria, Emma]

Comparison: age <= 30
  query={'age': {'$lte': 30}}
  count=4
  names=[Anna, Bohdan, Chris, Daria]
```

### Підказка

`{ field: { $gt: value } }`. Замість `$gt` — `$gte`, `$lt`, `$lte`, `$ne`, `$eq`.

### Розв'язання

```python
older = list(coll.find({"age": {"$gt": 25}}, {"_id": 0, "name": 1}).sort("name", 1))
under = list(coll.find({"age": {"$lte": 30}}, {"_id": 0, "name": 1}).sort("name", 1))
print("older:", [d["name"] for d in older])
print("under:", [d["name"] for d in under])
```

```javascript
db.filtering_people.find({ age: { $gt: 25 } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ age: { $lte: 30 } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Покрокове пояснення

1. **`$gt` — строго більше.** Якщо межа має включатись — `$gte`.
2. **Порівняння враховує тип.** `{age: {$gt: "10"}}` *не* спрацює на числове `age: 17` — MongoDB порівнює в межах одного BSON-типу.
3. **`{age: 17}` — короткий запис `{age: {$eq: 17}}`.** Форми еквівалентні.

---

## Вправа 4 — `$in` / `$nin` (входження у множину)

### Контекст

На дашборді є тумблер «офіси США»: показувати лише людей з Нью-Йорка або Лос-Анджелеса, або інвертувати — виключити їх.

### Чого ви навчитеся

- `$in` для «значення серед …».
- `$nin` для «значення не серед …».
- Що `$nin` також збігається з документами, де поле *відсутнє*.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `city` | string | Категоріальний стовпець. |

### Завдання

1. `$in`: міста у `["New York", "Los Angeles"]`.
2. `$nin`: міста НЕ у `["New York", "Los Angeles"]`.

### Очікуваний результат

```text
$in: city in [New York, Los Angeles]
  query={'city': {'$in': ['New York', 'Los Angeles']}}
  count=3
  names=[Bohdan, Chris, Emma]

$nin: city not in [New York, Los Angeles]
  query={'city': {'$nin': ['New York', 'Los Angeles']}}
  count=2
  names=[Anna, Daria]
```

### Підказка

`{ city: { $in: [...] } }`. Зворотне — `$nin`.

### Розв'язання

```python
in_us  = list(coll.find({"city": {"$in":  ["New York", "Los Angeles"]}}, {"_id": 0, "name": 1}).sort("name", 1))
out_us = list(coll.find({"city": {"$nin": ["New York", "Los Angeles"]}}, {"_id": 0, "name": 1}).sort("name", 1))
print("inside :", [d["name"] for d in in_us])
print("outside:", [d["name"] for d in out_us])
```

```javascript
db.filtering_people.find({ city: { $in:  ["New York", "Los Angeles"] } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ city: { $nin: ["New York", "Los Angeles"] } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Покрокове пояснення

1. **`$in` — читабельна форма ланцюга `$or`.** `{city: {$in: ["A", "B"]}}` ≡ `{$or: [{city: "A"}, {city: "B"}]}`.
2. **`$nin` приймає й документи без поля.** Якщо `city` відсутній — значення «не в списку», бо значення *немає*. Поєднуйте з `$exists: true`, якщо поле має бути.
3. **`$in` працює і з масивами.** `{skills: {$in: ["Python", "Go"]}}` шукає документи, чий `skills` містить *одне з* значень — не обидва.

---

## Вправа 5 — Логічні оператори (`$and`, `$or`, `$not`)

### Контекст

Три композиційні фільтри з аудиторських звітів:

- (а) Повнолітні в Нью-Йорку (`age >= 18 AND city = "New York"`).
- (б) Краєві віки (`age < 18 OR age > 40`).
- (в) Неповнолітні (`NOT (age >= 18)`) — переписане через `$not` навмисно.

### Чого ви навчитеся

- Явному `$and` (і коли він обов'язковий).
- `$or` для диз'юнкції.
- `$not` як заперечення виразу в межах поля.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `age` | int | В усіх трьох запитах. |
| `city` | string | В (а). |

### Завдання

Написати три запити:

1. `$and`: `age >= 18` AND `city = "New York"`.
2. `$or`: `age < 18` OR `age > 40`.
3. `$not`: `age` НЕ `>= 18`.

### Очікуваний результат

```text
$and: age >= 18 AND city=New York
  query={'$and': [{'age': {'$gte': 18}}, {'city': 'New York'}]}
  count=2
  names=[Bohdan, Emma]

$or: age < 18 OR age > 40
  query={'$or': [{'age': {'$lt': 18}}, {'age': {'$gt': 40}}]}
  count=2
  names=[Anna, Emma]

$not: age NOT >= 18
  query={'age': {'$not': {'$gte': 18}}}
  count=1
  names=[Anna]
```

### Підказка

- Неявний `$and`: `{age: {$gte: 18}, city: "New York"}` — зазвичай достатньо.
- Явний `$and`: потрібен, коли на **одне й те саме поле** накладаються дві різні умови (наприклад, `{$and: [{age: {$gte: 18}}, {age: {$lt: 65}}]}`).
- `$not` обгортає **вираз-оператор**, а не значення.

### Розв'язання

```python
adults_ny = list(coll.find(
    {"$and": [{"age": {"$gte": 18}}, {"city": "New York"}]},
    {"_id": 0, "name": 1},
).sort("name", 1))

extremes = list(coll.find(
    {"$or": [{"age": {"$lt": 18}}, {"age": {"$gt": 40}}]},
    {"_id": 0, "name": 1},
).sort("name", 1))

minors = list(coll.find(
    {"age": {"$not": {"$gte": 18}}},
    {"_id": 0, "name": 1},
).sort("name", 1))

for label, rows in (("adults_ny", adults_ny), ("extremes", extremes), ("minors", minors)):
    print(label, [d["name"] for d in rows])
```

```javascript
db.filtering_people.find(
  { $and: [ { age: { $gte: 18 } }, { city: "New York" } ] },
  { _id: 0, name: 1 }
).sort({ name: 1 });

db.filtering_people.find(
  { $or: [ { age: { $lt: 18 } }, { age: { $gt: 40 } } ] },
  { _id: 0, name: 1 }
).sort({ name: 1 });

db.filtering_people.find(
  { age: { $not: { $gte: 18 } } },
  { _id: 0, name: 1 }
).sort({ name: 1 });
```

### Покрокове пояснення

1. **Неявний `$and` між полями.** Кілька ключів верхнього рівня в запиті об'єднуються логічним І. `$and` потрібен лише для І за **одним і тим самим** полем.
2. **`$or` коротко замикається на кожному документі.** MongoDB зупиняється на першій гілці, що збіглася — порядок гілок впливає на швидкість.
3. **`$not` vs. `$ne`.** `$ne` — заперечення рівності в межах поля (`age $ne 17`). `$not` — заперечення *виразу* (`age $not $gte 18`). Беріть `$not`, коли праворуч стоїть оператор.
4. **Існує і `$nor`.** «Жоден з …» — корисний, але рідко; `$and` із `$not`-ами зрозуміліший.

---

## Вправа 6 — Вкладені документи (крапкова нотація)

### Контекст

Піддокумент `profile` дублює кілька денормалізованих показників. Два звіти його використовують: хто живе в Нью-Йорку (за `profile.city`), і хто є «senior» з 10+ роками досвіду.

### Чого ви навчитеся

- Як звертатись до вкладених полів через крапкову нотацію (`profile.city`).
- Що крапкова нотація однаково працює і для масивів піддокументів (з пасткою з `06_array_operators`).

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `profile.city` | string | Вкладена категорія. |
| `profile.experience` | int | Вкладене число. |

### Завдання

1. `profile.city = "New York"`.
2. `profile.experience >= 10`.

### Очікуваний результат

```text
Nested: profile.city = New York
  query={'profile.city': 'New York'}
  count=2
  names=[Bohdan, Emma]

Nested: profile.experience >= 10
  query={'profile.experience': {'$gte': 10}}
  count=1
  names=[Emma]
```

### Підказка

Беріть шлях у лапки: `"profile.city"` — Python не дозволяє крапку в ключі-літералі без лапок.

### Розв'язання

```python
ny  = list(coll.find({"profile.city": "New York"},        {"_id": 0, "name": 1}).sort("name", 1))
sen = list(coll.find({"profile.experience": {"$gte": 10}}, {"_id": 0, "name": 1}).sort("name", 1))
print("NY  :", [d["name"] for d in ny])
print("Sen :", [d["name"] for d in sen])
```

```javascript
db.filtering_people.find({ "profile.city": "New York" },          { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ "profile.experience": { $gte: 10 } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Покрокове пояснення

1. **Беріть крапковий ключ у лапки.** Python: `{"profile.city": ...}`; JS: `{ "profile.city": ... }`. Без лапок — або помилка парсера, або поле `city` біля неіснуючого батька.
2. **Автоматичних індексів на вкладених полях нема.** Якщо навантаження велике — створюйте `{"profile.city": 1}` явно.
3. **Для масиву піддокументів** `grades.score` спрацює, якщо **будь-який** елемент має такий `score` — див. Вправу 7 у `06_array_operators` для форми `$elemMatch`, що прив'язує дві умови до одного елемента.

---

## Вправа 7 — Фільтри масивів (`$all`, `$size`, `$elemMatch`)

### Контекст

Ті ж самі три оператори запиту масивів з `06_array_operators`, застосовані до багатшого документа `filtering_people`. Вони показують, що оператори масивів комбінуються з рештою DSL так само, як і скалярні.

### Чого ви навчитеся

- Як перевикористовувати `$all`, `$size`, `$elemMatch` всередині змішаного запиту.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `skills` | масив рядків | Цілі `$all` і `$size`. |
| `grades` | масив піддокументів | Ціль `$elemMatch`. |

### Завдання

1. `$all`: `skills` містить і `Python`, і `JavaScript`.
2. `$size`: довжина `skills` дорівнює 3.
3. `$elemMatch`: хоч одна оцінка з `score > 90`.

### Очікуваний результат

```text
Array $all: skills has Python + JavaScript
  query={'skills': {'$all': ['Python', 'JavaScript']}}
  count=2
  names=[Anna, Daria]

Array $size: skills length = 3
  query={'skills': {'$size': 3}}
  count=3
  names=[Anna, Chris, Emma]

Array $elemMatch: grades.score > 90
  query={'grades': {'$elemMatch': {'score': {'$gt': 90}}}}
  count=4
  names=[Anna, Bohdan, Daria, Emma]
```

### Підказка

Див. окремий урок `06_array_operators`. Синтаксис ідентичний.

### Розв'язання

```python
run_query(coll, "$all",       {"skills": {"$all": ["Python", "JavaScript"]}})
run_query(coll, "$size",      {"skills": {"$size": 3}})
run_query(coll, "$elemMatch", {"grades": {"$elemMatch": {"score": {"$gt": 90}}}})
```

```javascript
db.filtering_people.find({ skills: { $all: ["Python", "JavaScript"] } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ skills: { $size: 3 } },                       { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ grades: { $elemMatch: { score: { $gt: 90 } } } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Покрокове пояснення

1. **Той самий оператор працює для масиву будь-якого типу елементів.** `$all` над рядками, цілими, піддокументами.
2. **`$size` приймає лише цілий літерал.** Жодних діапазонів — обхід через `$expr` див. в `06_array_operators`.
3. **`$elemMatch` — єдиний спосіб** прив'язати *дві* умови до *одного й того ж* елемента масиву піддокументів. Крапкова форма `grades.score > 90` збігається з **будь-яким** елементом.

---

## Вправа 8 — Регулярний вираз (`$regex`)

### Контекст

Команда маркетингу хоче розіслати кампанію тільки тим, хто на Gmail. Адреса закінчується на `@gmail.com`.

### Чого ви навчитеся

- `$regex` для пошуку за підрядком/шаблоном.
- Регістронечутливому пошуку через `$options: "i"`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `email` | string | Шукаємо за патерном. |

### Завдання

Імена користувачів, чий `email` закінчується на `@gmail.com`.

### Очікуваний результат

```text
Regex: email ends with @gmail.com
  query={'email': {'$regex': '@gmail.com$'}}
  count=3
  names=[Anna, Chris, Emma]
```

### Підказка

Закріпіть шаблон `$` — «кінець рядка». `^` — «початок».

### Розв'язання

```python
gmail = list(coll.find({"email": {"$regex": "@gmail.com$"}}, {"_id": 0, "name": 1}).sort("name", 1))
print([d["name"] for d in gmail])
```

```javascript
db.filtering_people.find({ email: { $regex: "@gmail.com$" } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ email: /@gmail\.com$/ }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Покрокове пояснення

1. **`$regex` приймає PCRE-подібний рядок** (без обгорткових `/.../`). `^` — на початок, `$` — на кінець.
2. **`.` — це wildcard, а не літеральна крапка.** `@gmail.com$` тут спрацює, бо літеральна `.` стоїть між `gmail` і `com` і реальний збіг дає лише `gmail.com` — але педантично треба `@gmail\.com$`.
3. **Регістронечутливий пошук.** `{$regex: "@GMAIL", $options: "i"}` або JS-літерал `/.../i` у mongosh.
4. **Використання індексу.** Якщо шаблон закріплений на початку (`^anna`), може використовувати індекс. Шаблон у середині або з кінцем (`gmail.com$`) — повне сканування. Для 5 документів — нічого, для мільйонів — біль.

---

## Вправа 9 — `$exists` (поле є / відсутнє)

### Контекст

Звіт «очищення контактів» потребує двох зрізів: клієнти, у яких **є телефон** (можемо надіслати SMS), і ті, у кого `phone` **відсутній** (треба надіслати email з проханням заповнити).

### Чого ви навчитеся

- `$exists: true` проти `$exists: false`.
- Різниці між *поле відсутнє* та *поле зі значенням `null`*.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `phone` | string \| відсутнє | У Bohdan поля `phone` нема взагалі. |

### Завдання

1. `$exists: true` — користувачі, у яких є поле `phone`.
2. `$exists: false` — користувачі без `phone`.

### Очікуваний результат

```text
$exists: has phone field
  query={'phone': {'$exists': True}}
  count=4
  names=[Anna, Chris, Daria, Emma]

$exists: phone field is missing
  query={'phone': {'$exists': False}}
  count=1
  names=[Bohdan]
```

### Підказка

`{ phone: { $exists: true } }` — це булеве, не рядок.

### Розв'язання

```python
have   = list(coll.find({"phone": {"$exists": True}},  {"_id": 0, "name": 1}).sort("name", 1))
missing = list(coll.find({"phone": {"$exists": False}}, {"_id": 0, "name": 1}).sort("name", 1))
print("have   :", [d["name"] for d in have])
print("missing:", [d["name"] for d in missing])
```

```javascript
db.filtering_people.find({ phone: { $exists: true  } }, { _id: 0, name: 1 }).sort({ name: 1 });
db.filtering_people.find({ phone: { $exists: false } }, { _id: 0, name: 1 }).sort({ name: 1 });
```

### Покрокове пояснення

1. **`$exists` перевіряє лише наявність, не значення.** Документ з `phone: null` усе одно збігається з `$exists: true`.
2. **Щоб відфільтрувати «значення є і не null»**, комбінуйте: `{phone: {$exists: true, $ne: None}}`.
3. **`$exists` — найближче в MongoDB до SQL `IS NULL`.** У SQL «нема значення» — одне; у MongoDB — два (*поле відсутнє* і *явний `null`*). Точно знайте, який варіант вам потрібен.
4. **Індекси.** `$exists: true` може використати наявний індекс. `$exists: false` зазвичай ні — потрібен sparse-індекс.

---

## Шпаргалка

| Мета | Оператор | Приклад |
|---|---|---|
| Вибрати все | `find({})` | `coll.find({})` |
| Один рядок | `find_one({...})` | `coll.find_one({"name": "Anna"})` |
| Точне порівняння | `$gt`, `$gte`, `$lt`, `$lte`, `$ne` | `{age: {$gt: 25}}` |
| Множина | `$in`, `$nin` | `{city: {$in: ["NY", "LA"]}}` |
| І/АБО/НЕ | `$and`, `$or`, `$not` | `{$or: [{age: {$lt: 18}}, {age: {$gt: 40}}]}` |
| Вкладене поле | крапкова нотація | `{"profile.city": "Kyiv"}` |
| Масив (цілий) | `$all`, `$size`, `$elemMatch` | (див. Вправу 7) |
| Шаблон | `$regex` | `{email: {$regex: "@gmail.com$"}}` |
| Поле є | `$exists` | `{phone: {$exists: true}}` |

## Розв'язання проблем

| Симптом | Імовірне виправлення |
|---|---|
| `$and` з тим самим полем повертає не те | Ви написали `{age: A, age: B}` — другий ключ переписав перший. Обгорніть у `$and`. |
| `$nin` повертає документи без поля | Очікувано — `$nin` приймає відсутні поля. Додайте `$exists: true`. |
| Регулярка повільна | Закріпіть `^`, щоб задіяти індекс, або зберігайте нормалізоване поле у нижньому регістрі. |
| Порівняння рядка повертає нуль | Несумісність типів — `{age: {$gt: "10"}}` не зіставиться з числовими `age`. |
| Крапкова нотація збігається через елементи | Вживайте `$elemMatch`, щоб закріпити умови на одному елементі масиву. |
