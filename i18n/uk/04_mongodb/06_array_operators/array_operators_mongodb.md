# Оператори масивів у MongoDB (`06_array_operators`)

> Translation / Переклад: [English](../../../../04_mongodb/06_array_operators/array_operators_mongodb.md)

Ці вправи проходять **базові оператори масивів** у MongoDB: три **операторів запиту**, що фільтрують документи за вмістом масиву (`$all`, `$size`, `$elemMatch`), та три **операторів оновлення**, що змінюють масив на місці (`$push`, `$addToSet`, `$pull`).

Готовий файл-компаньйон: [`06_array_operators/example.py`](../../../../04_mongodb/06_array_operators/example.py). Скрипт переcіює колекцію `array_operators_people`, тож результати детерміновані. Вправи з `$push` / `$addToSet` / `$pull` нижче показують, що буде під час запуску в `mongosh` поверх тих самих даних — у `example.py` їх немає, бо скрипт навмисно лише читає.

```bash
pip install -r 04_mongodb/requirements.txt
python 04_mongodb/06_array_operators/example.py
```

Параметри з'єднання за замовчуванням (можна перевизначити змінними оточення):

- `MONGODB_URI=mongodb://localhost:27017`
- `MONGODB_DB=edu_academy_seed`
- Колекція: `array_operators_people`

---

## Шаблон вправи (повторюється у кожному розділі нижче)

| Секція | Що вона дає |
|---|---|
| **Контекст** | Навіщо реальній команді цей запит (1-2 речення). |
| **Чого ви навчитеся** | Який саме оператор тренує ця вправа. |
| **Колекція** | Лише потрібні поля. |
| **Завдання** | Чіткі вимоги (фільтр, проєкція, сортування). |
| **Очікуваний результат** | Реальний вивід `python example.py` або `mongosh`. |
| **Підказка** | Один натяк на потрібний оператор. |
| **Розв'язання** | Версії на PyMongo і `mongosh` поряд. |
| **Покрокове пояснення** | Що робить кожна частина і типові пастки. |

---

## Колекція: `array_operators_people`

Кожен документ має `name`, масив рядків `skills` та масив вкладених документів `grades`:

```json
{
  "name": "Anna",
  "skills": ["Python", "JavaScript", "SQL"],
  "grades": [
    { "subject": "math",    "score": 95 },
    { "subject": "history", "score": 88 }
  ]
}
```

Сід вставляє чотирьох студентів:

| `name` | `skills` | `grades` |
|---|---|---|
| Anna | `[Python, JavaScript, SQL]` | math 95, history 88 |
| Bohdan | `[Python, Go]` | math 89, physics 91 |
| Chris | `[JavaScript, TypeScript, Node.js]` | math 78, biology 84 |
| Daria | `[Python, JavaScript]` | math 92, chemistry 94 |

---

## Вправа 1 — `$all` (масив містить усі перелічені значення)

### Контекст

HR-портал шукає кандидатів, у яких у списку навичок **одночасно є** Python **і** JavaScript — порядок значень у масиві не важливий, додаткові навички дозволені.

### Чого ви навчитеся

- Оператора запиту `$all` для масивів.
- Чому `$all` не дорівнює рівності масиву (`skills: [...]`).
- Читати результат як «включення множини», а не «точний збіг».

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `name` | string | За ним сортуємо вихід. |
| `skills` | масив рядків | Масив, який фільтруємо. |

### Завдання

Повернути всіх, чий масив `skills` містить **і** `"Python"`, **і** `"JavaScript"`. Сортувати за `name` за зростанням, проєктувати лише потрібні поля.

### Очікуваний результат

```text
$all (array contains all values)
  query={'skills': {'$all': ['Python', 'JavaScript']}}
  count=2
  docs=[Anna (skills=['Python', 'JavaScript', 'SQL'], grades=[{'subject': 'math', 'score': 95}, {'subject': 'history', 'score': 88}]), Daria (skills=['Python', 'JavaScript'], grades=[{'subject': 'math', 'score': 92}, {'subject': 'chemistry', 'score': 94}])]
```

Підходять **Anna** і **Daria** — Bohdan пропадає (немає JavaScript), Chris пропадає (немає Python).

### Підказка

Використовуйте `{ skills: { $all: [...] } }`. Значення всередині — це невпорядкована множина обов'язкових елементів.

### Розв'язання

```python
from pymongo import MongoClient

coll = MongoClient("mongodb://localhost:27017")["edu_academy_seed"]["array_operators_people"]

cursor = coll.find(
    {"skills": {"$all": ["Python", "JavaScript"]}},
    {"_id": 0},
).sort("name", 1)
for doc in cursor:
    print(doc)
```

```javascript
use("edu_academy_seed");
db.array_operators_people
  .find(
    { skills: { $all: ["Python", "JavaScript"] } },
    { _id: 0 }
  )
  .sort({ name: 1 });
```

### Покрокове пояснення

1. **`$all` шукає підмножини.** Усі перелічені значення мають бути в масиві; додаткові — дозволено. Anna з `["Python", "JavaScript", "SQL"]` підходить, бо перші два присутні.
2. **Порядок неважливий.** `$all: ["Python", "JavaScript"]` і `$all: ["JavaScript", "Python"]` — однакові.
3. **`$all` проти рівності.** `{skills: ["Python", "JavaScript"]}` вимагає *точно* такий масив — тієї ж довжини і в тому ж порядку. Це б відкинуло Anna (у неї 3 навички). `$all` — це «містить усі».
4. **Проєкція `{"_id": 0}`** прибирає галасливий `ObjectId`. Передавайте її другим позиційним аргументом до `find()`.

---

## Вправа 2 — `$size` (довжина масиву дорівнює N)

### Контекст

Команда навчання хоче помітити «різнобічних» студентів — з **рівно трьома** навичками. Усі з більшою чи меншою кількістю не цікавлять.

### Чого ви навчитеся

- Оператора `$size` для *точної* довжини масиву.
- Чому `$size` **не** підтримує діапазонних порівнянь.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `skills` | масив рядків | Тут перевіряємо довжину. |

### Завдання

Повернути тих, у кого масив `skills` має **рівно три** елементи.

### Очікуваний результат

```text
$size (array length equals 3)
  query={'skills': {'$size': 3}}
  count=2
  docs=[Anna (skills=['Python', 'JavaScript', 'SQL'], grades=[...]), Chris (skills=['JavaScript', 'TypeScript', 'Node.js'], grades=[...])]
```

Два збіги: **Anna** (`Python, JavaScript, SQL`) і **Chris** (`JavaScript, TypeScript, Node.js`). У Daria — 2, у Bohdan — 2, обидва відкинуто.

### Підказка

`{ field: { $size: <int> } }`. Значення праворуч **обов'язково** має бути цілим літералом.

### Розв'язання

```python
docs = list(
    coll.find({"skills": {"$size": 3}}, {"_id": 0}).sort("name", 1)
)
for d in docs:
    print(d["name"], "->", d["skills"])
```

```javascript
db.array_operators_people
  .find({ skills: { $size: 3 } }, { _id: 0, name: 1, skills: 1 })
  .sort({ name: 1 });
```

### Покрокове пояснення

1. **`$size` перевіряє лише довжину.** Це одне ціле число; не можна писати `$size: { $gt: 2 }`.
2. **Без діапазонних запитів.** Якщо потрібно «понад N елементів», переходьте на агрегації з `$expr` та виразом `$size`, наприклад `{$expr: {$gt: [{$size: "$skills"}, 2]}}`.
3. **Індекси не допомагають.** Простий `$size` не використовує звичайний індекс. Для великих колекцій тримайте окреме поле `skills_count` і індексуйте його.

---

## Вправа 3 — `$elemMatch` (відповідає один із вкладених документів)

### Контекст

Екзаменаційна комісія шукає кожного студента, у кого є **хоча б один** предмет із оцінкою понад 90 — але збіг має бути в **одному й тому самому** вкладеному документі (тобто `subject="math"` і `score>90` мають бути з одного `grades[i]`, а не з двох різних).

### Чого ви навчитеся

- `$elemMatch` для масивів вкладених документів.
- Чим відрізняється `$elemMatch` від звичайного `grades.score: {$gt: 90}`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `grades` | масив піддокументів | Кожен має `subject` і `score`. |

### Завдання

Повернути всіх, у кого є **хоча б один** запис у `grades` із `score` строго більшим за 90.

### Очікуваний результат

```text
$elemMatch (array has element matching condition)
  query={'grades': {'$elemMatch': {'score': {'$gt': 90}}}}
  count=3
  docs=[Anna (...grades=[{'subject': 'math', 'score': 95}, ...]), Bohdan (...grades=[..., {'subject': 'physics', 'score': 91}]), Daria (...grades=[{'subject': 'math', 'score': 92}, {'subject': 'chemistry', 'score': 94}])]
```

Три збіги: **Anna** (math 95), **Bohdan** (physics 91), **Daria** (math 92 / chemistry 94). Chris (максимум 84) відкинуто.

### Підказка

Використовуйте `$elemMatch` щоразу, коли треба **кілька умов на тому самому елементі** масиву піддокументів.

### Розв'язання

```python
docs = list(
    coll.find(
        {"grades": {"$elemMatch": {"score": {"$gt": 90}}}},
        {"_id": 0, "name": 1, "grades": 1},
    ).sort("name", 1)
)
for d in docs:
    print(d)
```

```javascript
db.array_operators_people
  .find(
    { grades: { $elemMatch: { score: { $gt: 90 } } } },
    { _id: 0, name: 1, grades: 1 }
  )
  .sort({ name: 1 });
```

### Покрокове пояснення

1. **`$elemMatch` прив'язує умови до одного елемента.** З однією умовою (як тут) це еквівалентно крапковій нотації `grades.score: {$gt: 90}`. Різниця проявляється з **двома** умовами: `{grades: {$elemMatch: {subject: "math", score: {$gt: 90}}}}` вимагає *єдиний* запис, який **одночасно** і математика, і >90.
2. **Пастка крапкової нотації.** `{ "grades.subject": "math", "grades.score": {$gt: 90} }` спрацює, якщо **будь-яка** оцінка з математики **і** **будь-яка** оцінка більша за 90 — це можуть бути різні елементи. Перемикайтесь на `$elemMatch`, коли це принципово.
3. **Без `_id` у вкладених документах.** Елементи масиву піддокументів не отримують автоматичного `_id`. Якщо потрібно адресувати конкретний елемент пізніше (наприклад, для `$pull`), додайте стабільне власне поле.

---

## Вправа 4 — `$push` (додати до масиву в кінець)

### Контекст

Студент щойно завершив курс Rust. CRM додає `"Rust"` до наявного списку навичок Anna без перезапису всього масиву.

### Чого ви навчитеся

- `$push` як канонічний оператор «додати одне значення».
- Як `updateOne` повідомляє про `matchedCount` і `modifiedCount`.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `skills` | масив рядків | Сюди додаємо. |

### Завдання

Знайти Anna і додати `"Rust"` до її `skills`. Вивести оновлений документ.

### Очікуваний результат (захоплено наживо у `mongosh`)

```text
BEFORE:
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL' ] }

--- $push: add Rust to Anna.skills ---
{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1, "upsertedCount": 0 }
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL', 'Rust' ] }
```

### Підказка

`{ $push: { <масивне_поле>: <значення> } }`. Значення **завжди додається**, навіть якщо вже є в масиві.

### Розв'язання

```python
result = coll.update_one(
    {"name": "Anna"},
    {"$push": {"skills": "Rust"}},
)
print("matched =", result.matched_count, "modified =", result.modified_count)
print(coll.find_one({"name": "Anna"}, {"_id": 0, "name": 1, "skills": 1}))
```

```javascript
db.array_operators_people.updateOne(
  { name: "Anna" },
  { $push: { skills: "Rust" } }
);
db.array_operators_people.findOne(
  { name: "Anna" },
  { _id: 0, name: 1, skills: 1 }
);
```

### Покрокове пояснення

1. **`$push` завжди дописує.** Подвійний запуск з тим самим значенням створить дублікат (`["Python", "Rust", "Rust"]`). Для «вставити, якщо немає» використовуйте `$addToSet` (Вправа 5).
2. **Багато значень одразу через `$each`.** `{$push: {skills: {$each: ["Rust", "Elixir"]}}}` додає обидва в одному виклику.
3. **`matched_count` проти `modified_count`.** `matched_count == 1` означає, що фільтр знайшов Anna. `modified_count == 1` підтверджує, що масив змінився. Якщо значення вже було (наприклад, no-op для `$addToSet`), `modified_count` може бути `0`.
4. **Атомарність.** Заміна всього масиву виконується атомарно на рівні документа — інший писач не вклинеться між читанням і записом.

---

## Вправа 5 — `$addToSet` (додати лише за відсутності)

### Контекст

На тому самому екрані CRM є кнопка «позначити тегом». Її подвійне натискання тим самим тегом **не повинно** створити дублікат.

### Чого ви навчитеся

- `$addToSet` як «об'єднання множин» замість `$push`.
- Як MongoDB звітує про no-op оновлення (`modifiedCount: 0`).

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `skills` | масив рядків | Трактуємо як множину. |

### Завдання

1. Спробувати додати `"Python"` до `skills` Anna. Він уже там — переконатись, що дубліката немає.
2. Потім додати `"Elixir"`, якого **нема**. Переконатись, що значення з'явилось.

### Очікуваний результат (захоплено наживо у `mongosh`)

```text
--- $addToSet: try to add Python (duplicate) to Anna.skills ---
{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 0, "upsertedCount": 0 }
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL', 'Rust' ] }

--- $addToSet: add Elixir (new) to Anna.skills ---
{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1, "upsertedCount": 0 }
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL', 'Rust', 'Elixir' ] }
```

(Масив Anna містить `Rust`, бо до цього виконалась Вправа 4.)

### Підказка

`{ $addToSet: { <масивне_поле>: <значення> } }` — як `$push`, але no-op, якщо значення вже є.

### Розв'язання

```python
r1 = coll.update_one({"name": "Anna"}, {"$addToSet": {"skills": "Python"}})
print("Python  -> matched =", r1.matched_count, "modified =", r1.modified_count)

r2 = coll.update_one({"name": "Anna"}, {"$addToSet": {"skills": "Elixir"}})
print("Elixir  -> matched =", r2.matched_count, "modified =", r2.modified_count)
```

```javascript
db.array_operators_people.updateOne(
  { name: "Anna" },
  { $addToSet: { skills: "Python" } }
);
db.array_operators_people.updateOne(
  { name: "Anna" },
  { $addToSet: { skills: "Elixir" } }
);
```

### Покрокове пояснення

1. **Семантика множини, не списку.** `$addToSet` пропускає запис, якщо значення вже є. `matched_count` лишається `1` (Anna знайдена), але `modified_count` стає `0`.
2. **Порівняння — структурне.** Для примітивів (рядки, числа) MongoDB порівнює за значенням. Для вкладених документів усі поля та їх порядок мають збігатися точно. `{a:1,b:2}` і `{b:2,a:1}` для `$addToSet` — **різні**.
3. **Пакетний доступ через `$each`.** `{$addToSet: {skills: {$each: ["A", "B"]}}}` додасть обидва, яких бракує — без `$each` в масив потрапить один елемент `["A", "B"]`.

---

## Вправа 6 — `$pull` (видалити всі збіги)

### Контекст

Зі списку навичок зник один напрям. Усі, хто ще тримає `"Rust"` у `skills`, мають його втратити.

### Чого ви навчитеся

- `$pull` для видалення значень із масиву.
- Видалення за значенням vs. за предикатом.

### Колекція

| Поле | Тип | Примітка |
|---|---|---|
| `skills` | масив рядків | Звідси видаляємо. |

### Завдання

Видалити `"Rust"` з `skills` Anna. Переконатись, що масив скоротився на один елемент.

### Очікуваний результат (захоплено наживо у `mongosh`)

```text
--- $pull: remove Rust from Anna.skills ---
{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1, "upsertedCount": 0 }
{ name: 'Anna', skills: [ 'Python', 'JavaScript', 'SQL', 'Elixir' ] }
```

### Підказка

`{ $pull: { <масивне_поле>: <значення-або-умова> } }`. Скаляр праворуч — видалення за рівністю; об'єкт — видалення за предикатом.

### Розв'язання

```python
result = coll.update_one(
    {"name": "Anna"},
    {"$pull": {"skills": "Rust"}},
)
print("matched =", result.matched_count, "modified =", result.modified_count)
print(coll.find_one({"name": "Anna"}, {"_id": 0, "name": 1, "skills": 1}))
```

```javascript
db.array_operators_people.updateOne(
  { name: "Anna" },
  { $pull: { skills: "Rust" } }
);
db.array_operators_people.findOne(
  { name: "Anna" },
  { _id: 0, name: 1, skills: 1 }
);
```

### Покрокове пояснення

1. **`$pull` видаляє всі збіги за один прохід.** Якби у Anna було `["Rust", "Rust"]`, обидва зникли б за один запит.
2. **Форма-предикат для масиву об'єктів.** Видалити лише оцінку з математики: `{$pull: {grades: {subject: "math"}}}`. Внутрішній об'єкт зіставляється з кожним елементом через неявний `$and`.
3. **Скидайте з кінців через `$pop`.** `$pop` (`1` — останній, `-1` — перший) корисний, коли треба просто обрізати кінчик масиву, не знаючи значення.
4. **Конкурентність.** `$pull` виконується під блокуванням на рівні документа — безпечно з кількох клієнтів.

---

## Шпаргалка

| Мета | Оператор | Приклад |
|---|---|---|
| Масив містить усі перелічені значення | `$all` | `{skills: {$all: ["Python", "JavaScript"]}}` |
| Довжина масиву дорівнює N | `$size` | `{skills: {$size: 3}}` |
| Хоча б один піддокумент відповідає | `$elemMatch` | `{grades: {$elemMatch: {score: {$gt: 90}}}}` |
| Додати (дозволяє дублікати) | `$push` | `{$push: {skills: "Rust"}}` |
| Додати лише за відсутності | `$addToSet` | `{$addToSet: {skills: "Elixir"}}` |
| Видалити всі збіги | `$pull` | `{$pull: {skills: "Rust"}}` |

## Розв'язання проблем

| Симптом | Імовірне виправлення |
|---|---|
| `$size: { $gt: 2 }` повертає помилку | `$size` приймає лише ціле. Використайте `{$expr: {$gt: [{$size: "$skills"}, 2]}}`. |
| `$all` нічого не повертає | Переконайтесь, що типи значень збігаються з вмістом масиву (`"1"` ≠ `1`). |
| `$elemMatch` і крапкова нотація дають різні кількості | Ви написали дві умови на двох елементах. Перейдіть на `$elemMatch`, щоб закріпити їх за одним елементом. |
| `$addToSet` додає дублікати об'єктів | Порядок полів у вкладеному документі відрізняється — нормалізуйте форму перед порівнянням. |
| `$pull` видалив усе | Предикат збігся з більшою кількістю елементів — звужуйте умову. |
