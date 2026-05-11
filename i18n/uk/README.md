<!-- @format -->

# Українські переклади / Ukrainian translations

Цей каталог `i18n/uk/` є **дзеркалом** структури репозиторію з україномовними версіями файлів `.md` та `.sql`. Англомовні файли залишаються в оригінальних розташуваннях і є **джерелом істини** (source of truth).

> Translation root index. The English source of truth lives in the repository root and the six top-level folders (`01_database_mysql/` … `06_mongo_terraform/`); this folder mirrors that tree with Ukrainian-language `.md` and `.sql` files.

---

## Як це працює / How it works

- Шлях файлу в перекладі **точно дзеркалить** англомовний:
  - EN: `03_mysql/13_functions/functions_car_service_db.md`
  - UK: `i18n/uk/03_mysql/13_functions/functions_car_service_db.md`
- У файлах `.sql` SQL-код **ідентичний** англомовному (ті самі імена таблиць, колонок, ключових слів). Перекладаються лише `-- коментарі` та заголовки секцій.
- У файлах `.md` повністю перекладається текст. Технічні ідентифікатори (імена таблиць, функцій, SQL-ключові слова, команди CLI) залишаються англійською.
- На початку кожного англомовного `.md` (під заголовком H1) додано банер із посиланням на українську версію:
  - `> Переклад / Translation: [Українська](шлях/до/i18n/uk/.../файл.md)`

---

## Карта перекладів / Translation map

| Розділ EN | Опис | Розділ UK |
|-----------|------|-----------|
| [`README.md`](../../README.md) | Огляд репозиторію | [`i18n/uk/README_root.md`](README_root.md) |
| [`01_database_mysql/`](../../01_database_mysql/) | Схема `car_service_db` | [`i18n/uk/01_database_mysql/`](01_database_mysql/) |
| `02_database_mongo/` | Дамп `edu_academy_seed` (немає `.md`/`.sql`) | — (без перекладу) |
| [`03_mysql/`](../../03_mysql/) | MySQL-уроки на `car_service_db` | [`i18n/uk/03_mysql/`](03_mysql/) |
| [`04_mongodb/`](../../04_mongodb/) | MongoDB-уроки на `edu_academy_seed` | [`i18n/uk/04_mongodb/`](04_mongodb/) |
| [`05_aws_terraform/`](../../05_aws_terraform/) | Terraform: AWS RDS MySQL | [`i18n/uk/05_aws_terraform/`](05_aws_terraform/) |
| [`06_mongo_terraform/`](../../06_mongo_terraform/) | Terraform: MongoDB Atlas | [`i18n/uk/06_mongo_terraform/`](06_mongo_terraform/) |

---

## Глосарій (EN → UK) / Glossary

### Основні поняття баз даних

| Англійською | Українською | Примітки |
|-------------|-------------|----------|
| database | база даних | абревіатура — БД |
| schema | схема | |
| table | таблиця | |
| row, record | рядок, запис | у SQL-контексті — «рядок таблиці» |
| column | стовпець (рідше — колонка) | |
| field | поле | в SQL = стовпець; у MongoDB = поле документа |
| value | значення | |
| data type | тип даних | |
| NULL | NULL (порожнє значення) | англомовне слово зберігаємо |
| constraint | обмеження | |
| primary key (PK) | первинний ключ | |
| foreign key (FK) | зовнішній ключ | |
| unique key | унікальний ключ | |
| index | індекс | |
| composite index | складений (композитний) індекс | |
| view | подання (представлення) | |
| sequence / auto increment | автоінкремент, послідовність | |
| collation | сортувальна послідовність (collation) | |
| character set | набір символів | |

### Запити та оператори SQL

| Англійською | Українською | Примітки |
|-------------|-------------|----------|
| query | запит | |
| statement | інструкція (оператор) | `SELECT` — це SQL-інструкція |
| expression | вираз | |
| clause | секція (клаузу́ла) | напр., секція `WHERE` |
| keyword | ключове слово | |
| function (built-in) | вбудована функція | |
| stored function | збережена функція | |
| stored procedure | збережена процедура | |
| trigger | тригер | |
| event | подія | |
| cursor | курсор | |
| variable | змінна | |
| parameter | параметр | |
| join | з'єднання (join) | у тексті часто залишаємо `JOIN` |
| inner join | внутрішнє з'єднання | |
| left/right outer join | ліве/праве зовнішнє з'єднання | |
| cross join | декартів добуток (`CROSS JOIN`) | |
| subquery | підзапит | |
| correlated subquery | корельований підзапит | |
| CTE (common table expression) | СТЕ, узагальнений табличний вираз | |
| aggregate function | агрегатна функція | |
| window function | віконна функція | |
| `GROUP BY` | групування | |
| `ORDER BY` | сортування | |
| `HAVING` | умова після групування (`HAVING`) | |
| pattern matching | пошук за шаблоном | `LIKE`, `REGEXP` |
| pagination | пагінація (посторінкове виведення) | |
| sorting | сортування | |

### Транзакції та паралелізм

| Англійською | Українською | Примітки |
|-------------|-------------|----------|
| transaction | транзакція | |
| commit | підтвердження транзакції (`COMMIT`) | |
| rollback | відкат транзакції (`ROLLBACK`) | |
| savepoint | точка збереження (`SAVEPOINT`) | |
| isolation level | рівень ізоляції | |
| read uncommitted | читання незафіксованих | |
| read committed | читання зафіксованих | |
| repeatable read | повторне читання | |
| serializable | серіалізовність | |
| deadlock | взаємне блокування (deadlock) | |
| lock | блокування | |
| dirty read | «брудне» читання | |
| phantom read | фантомне читання | |
| non-repeatable read | неповторне читання | |

### Мови SQL / Categories

| Англійською | Українською | Що це |
|-------------|-------------|-------|
| DDL — Data Definition Language | мова визначення даних | `CREATE`, `ALTER`, `DROP` |
| DML — Data Manipulation Language | мова маніпулювання даними | `INSERT`, `UPDATE`, `DELETE` |
| DQL — Data Query Language | мова запитів | `SELECT` |
| DCL — Data Control Language | мова керування доступом | `GRANT`, `REVOKE` |
| TCL — Transaction Control Language | мова керування транзакціями | `COMMIT`, `ROLLBACK`, `SAVEPOINT` |

### Типи даних (вибірково)

| Англійською | Українською |
|-------------|-------------|
| integer | ціле число |
| decimal / numeric | десяткове / з фіксованою комою |
| float, double | з плаваючою комою |
| boolean | булевий (логічний) |
| string, text | текст, рядок символів |
| char / varchar | символьний / змінної довжини |
| date | дата |
| time | час |
| datetime, timestamp | дата-час, мітка часу |
| JSON | JSON (зберігаємо як є) |
| BLOB | BLOB (двійкові дані) |

### MongoDB / NoSQL

| Англійською | Українською | Примітки |
|-------------|-------------|----------|
| document | документ | |
| collection | колекція | |
| field | поле | |
| nested / embedded document | вкладений документ | |
| array | масив | |
| operator | оператор | напр., `$gt`, `$in` |
| projection | проєкція | |
| aggregation pipeline | конвеєр агрегації | |
| stage | стадія (етап) | |
| index | індекс | |
| compound index | складений індекс | |
| ODM (Object-Document Mapper) | об'єктно-документне відображення | |
| ObjectId | ObjectId (зберігаємо як є) | |

### ORM / Terraform / інфраструктура

| Англійською | Українською |
|-------------|-------------|
| ORM (Object-Relational Mapping) | об'єктно-реляційне відображення |
| model | модель |
| migration | міграція |
| session | сесія |
| connection pool | пул з'єднань |
| Terraform | Terraform (зберігаємо як є) |
| provider | провайдер |
| resource | ресурс |
| state | стан (state-файл) |
| backend | бекенд (зберігання state) |
| module | модуль |
| variable / output | змінна / вихідне значення |

---

## Зауваження щодо термінології / Terminology notes

- **«Рядок»** — багатозначне слово. У контексті SQL-таблиці означає **row**; у контексті типів даних означає **string**. Контекст зазвичай однозначно його розкриває; за потреби уточнюємо: «рядок таблиці» / «текстовий рядок».
- Назви SQL-команд, ключових слів, функцій, таблиць і колонок **не транслітеруються** і пишуться як в англійському оригіналі (`SELECT`, `INNER JOIN`, `customers.first_name`).
- Команди shell / CLI у блоках коду **не перекладаються**.
- Числа й технічні мітки (наприклад, `MySQL 8.0`, `BSON`) зберігаються в оригінальному вигляді.

---

## Структура каталогу `i18n/uk/`

```
i18n/uk/
├── README.md                 # цей файл (огляд + глосарій)
├── README_root.md            # переклад кореневого README.md
├── 01_database_mysql/
│   └── car_service_schema.sql
├── 03_mysql/
│   ├── README.md
│   ├── 00_dataset_bootstrap/README.md
│   ├── 00_debugging_basics/README.md
│   ├── 00_environment_setup/README.md
│   ├── 00_git_workflow_for_sql/README.md
│   ├── 00_sql_style_guide/README.md
│   ├── 01_relational_algebra_Koda/
│   │   ├── algebra_Koda_car_service_db.md
│   │   └── car_service_algebra_examples.sql
│   ├── 02_ddl/ … 15_cycles/   # md + sql у кожному уроці
│   └── 16_orm/orm_sqlalchemy.md
├── 04_mongodb/
│   ├── README.md
│   ├── mongodb_topics.md
│   ├── 01_crud/ … 09_indexes/
│   └── 10_odm/                # odm_mongoengine.md + 4 підурока
├── 05_aws_terraform/README.md
└── 06_mongo_terraform/README.md
```

---

## Повний покажчик перекладів / Full translation index

### Корінь репозиторію

| Англійською | Українською |
|-------------|-------------|
| [`README.md`](../../README.md) | [`README_root.md`](README_root.md) |

### `01_database_mysql/`

| Англійською | Українською |
|-------------|-------------|
| [`car_service_schema.sql`](../../01_database_mysql/car_service_schema.sql) | [`01_database_mysql/car_service_schema.sql`](01_database_mysql/car_service_schema.sql) |

### `03_mysql/`

| Англійською | Українською |
|-------------|-------------|
| [`README.md`](../../03_mysql/README.md) | [`03_mysql/README.md`](03_mysql/README.md) |
| [`00_dataset_bootstrap/README.md`](../../03_mysql/00_dataset_bootstrap/README.md) | [`03_mysql/00_dataset_bootstrap/README.md`](03_mysql/00_dataset_bootstrap/README.md) |
| [`00_debugging_basics/README.md`](../../03_mysql/00_debugging_basics/README.md) | [`03_mysql/00_debugging_basics/README.md`](03_mysql/00_debugging_basics/README.md) |
| [`00_environment_setup/README.md`](../../03_mysql/00_environment_setup/README.md) | [`03_mysql/00_environment_setup/README.md`](03_mysql/00_environment_setup/README.md) |
| [`00_git_workflow_for_sql/README.md`](../../03_mysql/00_git_workflow_for_sql/README.md) | [`03_mysql/00_git_workflow_for_sql/README.md`](03_mysql/00_git_workflow_for_sql/README.md) |
| [`00_sql_style_guide/README.md`](../../03_mysql/00_sql_style_guide/README.md) | [`03_mysql/00_sql_style_guide/README.md`](03_mysql/00_sql_style_guide/README.md) |
| [`01_relational_algebra_Koda/algebra_Koda_car_service_db.md`](../../03_mysql/01_relational_algebra_Koda/algebra_Koda_car_service_db.md) + [`car_service_algebra_examples.sql`](../../03_mysql/01_relational_algebra_Koda/car_service_algebra_examples.sql) | [`03_mysql/01_relational_algebra_Koda/algebra_Koda_car_service_db.md`](03_mysql/01_relational_algebra_Koda/algebra_Koda_car_service_db.md) + [`car_service_algebra_examples.sql`](03_mysql/01_relational_algebra_Koda/car_service_algebra_examples.sql) |
| [`02_ddl/ddl_car_service_db.md`](../../03_mysql/02_ddl/ddl_car_service_db.md) + [`car_service_ddl_examples.sql`](../../03_mysql/02_ddl/car_service_ddl_examples.sql) + [`car_service_relationships_examples.sql`](../../03_mysql/02_ddl/car_service_relationships_examples.sql) | [`03_mysql/02_ddl/ddl_car_service_db.md`](03_mysql/02_ddl/ddl_car_service_db.md) + [`car_service_ddl_examples.sql`](03_mysql/02_ddl/car_service_ddl_examples.sql) + [`car_service_relationships_examples.sql`](03_mysql/02_ddl/car_service_relationships_examples.sql) |
| [`03_dml/dml_car_service_db.md`](../../03_mysql/03_dml/dml_car_service_db.md) + [`car_service_dml_examples.sql`](../../03_mysql/03_dml/car_service_dml_examples.sql) | [`03_mysql/03_dml/dml_car_service_db.md`](03_mysql/03_dml/dml_car_service_db.md) + [`car_service_dml_examples.sql`](03_mysql/03_dml/car_service_dml_examples.sql) |
| [`04_dql/dql_car_service_db.md`](../../03_mysql/04_dql/dql_car_service_db.md) + [`car_service_dql_examples.sql`](../../03_mysql/04_dql/car_service_dql_examples.sql) | [`03_mysql/04_dql/dql_car_service_db.md`](03_mysql/04_dql/dql_car_service_db.md) + [`car_service_dql_examples.sql`](03_mysql/04_dql/car_service_dql_examples.sql) |
| [`05_order_commands/order_commands_car_service_db.md`](../../03_mysql/05_order_commands/order_commands_car_service_db.md) + [`car_service_order_examples.sql`](../../03_mysql/05_order_commands/car_service_order_examples.sql) | [`03_mysql/05_order_commands/order_commands_car_service_db.md`](03_mysql/05_order_commands/order_commands_car_service_db.md) + [`car_service_order_examples.sql`](03_mysql/05_order_commands/car_service_order_examples.sql) |
| [`06_subqueries/subqueries_car_service_db.md`](../../03_mysql/06_subqueries/subqueries_car_service_db.md) + [`car_service_subqueries_examples.sql`](../../03_mysql/06_subqueries/car_service_subqueries_examples.sql) | [`03_mysql/06_subqueries/subqueries_car_service_db.md`](03_mysql/06_subqueries/subqueries_car_service_db.md) + [`car_service_subqueries_examples.sql`](03_mysql/06_subqueries/car_service_subqueries_examples.sql) |
| [`07_join/joins_car_service_db.md`](../../03_mysql/07_join/joins_car_service_db.md) + [`car_service_join_examples.sql`](../../03_mysql/07_join/car_service_join_examples.sql) | [`03_mysql/07_join/joins_car_service_db.md`](03_mysql/07_join/joins_car_service_db.md) + [`car_service_join_examples.sql`](03_mysql/07_join/car_service_join_examples.sql) |
| [`08_indexes/indexes_car_service_db.md`](../../03_mysql/08_indexes/indexes_car_service_db.md) + [`car_service_indexes_examples.sql`](../../03_mysql/08_indexes/car_service_indexes_examples.sql) | [`03_mysql/08_indexes/indexes_car_service_db.md`](03_mysql/08_indexes/indexes_car_service_db.md) + [`car_service_indexes_examples.sql`](03_mysql/08_indexes/car_service_indexes_examples.sql) |
| [`09_transactions/transactions_car_service_db.md`](../../03_mysql/09_transactions/transactions_car_service_db.md) + [`car_service_transactions_examples.sql`](../../03_mysql/09_transactions/car_service_transactions_examples.sql) + [`car_service_isolation_levels_examples.sql`](../../03_mysql/09_transactions/car_service_isolation_levels_examples.sql) | [`03_mysql/09_transactions/transactions_car_service_db.md`](03_mysql/09_transactions/transactions_car_service_db.md) + [`car_service_transactions_examples.sql`](03_mysql/09_transactions/car_service_transactions_examples.sql) + [`car_service_isolation_levels_examples.sql`](03_mysql/09_transactions/car_service_isolation_levels_examples.sql) |
| [`10_windows_functions/windows_functions_car_service_db.md`](../../03_mysql/10_windows_functions/windows_functions_car_service_db.md) + [`car_service_windows_functions_examples.sql`](../../03_mysql/10_windows_functions/car_service_windows_functions_examples.sql) | [`03_mysql/10_windows_functions/windows_functions_car_service_db.md`](03_mysql/10_windows_functions/windows_functions_car_service_db.md) + [`car_service_windows_functions_examples.sql`](03_mysql/10_windows_functions/car_service_windows_functions_examples.sql) |
| [`11_variables/variables_car_service_db.md`](../../03_mysql/11_variables/variables_car_service_db.md) + [`car_service_variables_examples.sql`](../../03_mysql/11_variables/car_service_variables_examples.sql) | [`03_mysql/11_variables/variables_car_service_db.md`](03_mysql/11_variables/variables_car_service_db.md) + [`car_service_variables_examples.sql`](03_mysql/11_variables/car_service_variables_examples.sql) |
| [`12_triggers/triggers_car_service_db.md`](../../03_mysql/12_triggers/triggers_car_service_db.md) + [`car_service_triggers_examples.sql`](../../03_mysql/12_triggers/car_service_triggers_examples.sql) | [`03_mysql/12_triggers/triggers_car_service_db.md`](03_mysql/12_triggers/triggers_car_service_db.md) + [`car_service_triggers_examples.sql`](03_mysql/12_triggers/car_service_triggers_examples.sql) |
| [`13_functions/functions_car_service_db.md`](../../03_mysql/13_functions/functions_car_service_db.md) + [`car_service_functions_examples.sql`](../../03_mysql/13_functions/car_service_functions_examples.sql) | [`03_mysql/13_functions/functions_car_service_db.md`](03_mysql/13_functions/functions_car_service_db.md) + [`car_service_functions_examples.sql`](03_mysql/13_functions/car_service_functions_examples.sql) |
| [`14_procedures/procedures_car_service_db.md`](../../03_mysql/14_procedures/procedures_car_service_db.md) + [`car_service_procedures_examples.sql`](../../03_mysql/14_procedures/car_service_procedures_examples.sql) | [`03_mysql/14_procedures/procedures_car_service_db.md`](03_mysql/14_procedures/procedures_car_service_db.md) + [`car_service_procedures_examples.sql`](03_mysql/14_procedures/car_service_procedures_examples.sql) |
| [`15_cycles/cycles_car_service_db.md`](../../03_mysql/15_cycles/cycles_car_service_db.md) + [`car_service_cycles_examples.sql`](../../03_mysql/15_cycles/car_service_cycles_examples.sql) | [`03_mysql/15_cycles/cycles_car_service_db.md`](03_mysql/15_cycles/cycles_car_service_db.md) + [`car_service_cycles_examples.sql`](03_mysql/15_cycles/car_service_cycles_examples.sql) |
| [`16_orm/orm_sqlalchemy.md`](../../03_mysql/16_orm/orm_sqlalchemy.md) | [`03_mysql/16_orm/orm_sqlalchemy.md`](03_mysql/16_orm/orm_sqlalchemy.md) |
| `17_query_performance_explain/` (порожньо) | — |
| `18_advanced_indexing/` (порожньо) | — |

### `04_mongodb/`

| Англійською | Українською |
|-------------|-------------|
| [`README.md`](../../04_mongodb/README.md) | [`04_mongodb/README.md`](04_mongodb/README.md) |
| [`mongodb_topics.md`](../../04_mongodb/mongodb_topics.md) | [`04_mongodb/mongodb_topics.md`](04_mongodb/mongodb_topics.md) |
| [`01_crud/crud_mongodb.md`](../../04_mongodb/01_crud/crud_mongodb.md) | [`04_mongodb/01_crud/crud_mongodb.md`](04_mongodb/01_crud/crud_mongodb.md) |
| [`02_selection_queries/selection_queries_mongodb.md`](../../04_mongodb/02_selection_queries/selection_queries_mongodb.md) | [`04_mongodb/02_selection_queries/selection_queries_mongodb.md`](04_mongodb/02_selection_queries/selection_queries_mongodb.md) |
| [`03_logical_operators/logical_operators_mongodb.md`](../../04_mongodb/03_logical_operators/logical_operators_mongodb.md) | [`04_mongodb/03_logical_operators/logical_operators_mongodb.md`](04_mongodb/03_logical_operators/logical_operators_mongodb.md) |
| [`04_string_operators/string_operators_mongodb.md`](../../04_mongodb/04_string_operators/string_operators_mongodb.md) | [`04_mongodb/04_string_operators/string_operators_mongodb.md`](04_mongodb/04_string_operators/string_operators_mongodb.md) |
| [`05_check_operators/check_operators_mongodb.md`](../../04_mongodb/05_check_operators/check_operators_mongodb.md) | [`04_mongodb/05_check_operators/check_operators_mongodb.md`](04_mongodb/05_check_operators/check_operators_mongodb.md) |
| [`06_array_operators/array_operators_mongodb.md`](../../04_mongodb/06_array_operators/array_operators_mongodb.md) | [`04_mongodb/06_array_operators/array_operators_mongodb.md`](04_mongodb/06_array_operators/array_operators_mongodb.md) |
| [`07_pagination_sorting/pagination_sorting_mongodb.md`](../../04_mongodb/07_pagination_sorting/pagination_sorting_mongodb.md) | [`04_mongodb/07_pagination_sorting/pagination_sorting_mongodb.md`](04_mongodb/07_pagination_sorting/pagination_sorting_mongodb.md) |
| [`08_filtering/filtering_mongodb.md`](../../04_mongodb/08_filtering/filtering_mongodb.md) | [`04_mongodb/08_filtering/filtering_mongodb.md`](04_mongodb/08_filtering/filtering_mongodb.md) |
| [`09_indexes/indexes_mongodb.md`](../../04_mongodb/09_indexes/indexes_mongodb.md) | [`04_mongodb/09_indexes/indexes_mongodb.md`](04_mongodb/09_indexes/indexes_mongodb.md) |
| [`10_odm/odm_mongoengine.md`](../../04_mongodb/10_odm/odm_mongoengine.md) | [`04_mongodb/10_odm/odm_mongoengine.md`](04_mongodb/10_odm/odm_mongoengine.md) |
| [`10_odm/01_selection_operators/selection_operators_odm.md`](../../04_mongodb/10_odm/01_selection_operators/selection_operators_odm.md) | [`04_mongodb/10_odm/01_selection_operators/selection_operators_odm.md`](04_mongodb/10_odm/01_selection_operators/selection_operators_odm.md) |
| [`10_odm/02_search_sorting_pagination/search_sorting_pagination_motor_fastapi.md`](../../04_mongodb/10_odm/02_search_sorting_pagination/search_sorting_pagination_motor_fastapi.md) | [`04_mongodb/10_odm/02_search_sorting_pagination/search_sorting_pagination_motor_fastapi.md`](04_mongodb/10_odm/02_search_sorting_pagination/search_sorting_pagination_motor_fastapi.md) |
| [`10_odm/03_indexes/indexes_motor.md`](../../04_mongodb/10_odm/03_indexes/indexes_motor.md) | [`04_mongodb/10_odm/03_indexes/indexes_motor.md`](04_mongodb/10_odm/03_indexes/indexes_motor.md) |
| [`10_odm/04_agregation_functions/agregation_functions_motor.md`](../../04_mongodb/10_odm/04_agregation_functions/agregation_functions_motor.md) | [`04_mongodb/10_odm/04_agregation_functions/agregation_functions_motor.md`](04_mongodb/10_odm/04_agregation_functions/agregation_functions_motor.md) |

### `05_aws_terraform/` та `06_mongo_terraform/`

| Англійською | Українською |
|-------------|-------------|
| [`05_aws_terraform/README.md`](../../05_aws_terraform/README.md) | [`05_aws_terraform/README.md`](05_aws_terraform/README.md) |
| [`06_mongo_terraform/README.md`](../../06_mongo_terraform/README.md) | [`06_mongo_terraform/README.md`](06_mongo_terraform/README.md) |

---

## Внесок у переклад / Contributing

- Тримайте структуру каталогу `i18n/uk/` **точно дзеркальною** до англомовної.
- Не змінюйте SQL-код у `.sql` — лише `-- коментарі`.
- Використовуйте терміни з глосарію вище для узгодженості.
- При додаванні нового англомовного уроку — створіть відповідний український файл у дзеркалі.
