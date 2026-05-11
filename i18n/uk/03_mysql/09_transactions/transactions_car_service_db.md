# Транзакції — `car_service_db`

> Translation / Переклад: [English](../../../../03_mysql/09_transactions/transactions_car_service_db.md)

Приклади використовують невелику лабораторну таблицю **`tx_lab`** всередині **`car_service_db`** (з **`01_database_mysql/car_service_db.sql.gz`**). Скрипт створює таблицю, виконує **`START TRANSACTION`** / **`COMMIT`** / **`ROLLBACK`** / **`SAVEPOINT`**, потім за потреби видаляє її.

**Скрипти**

- `09_transactions/car_service_transactions_examples.sql` — begin / commit / rollback / savepoints
- `09_transactions/car_service_isolation_levels_examples.sql` — `READ UNCOMMITTED`, `READ COMMITTED`, `REPEATABLE READ`, `SERIALIZABLE`; Частина A — одна сесія, Частина B — рецепт у двох терміналах для ефектів конкуренції

```bash
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 09_transactions/car_service_transactions_examples.sql
mysql -u ... -p ... car_service_db < 09_transactions/car_service_isolation_levels_examples.sql
```

**Запускайте весь файл в одній клієнтській сесії** (напр., `mysql < file` або вставляйте в одну вкладку). Якщо кожна інструкція виконується в окремому з'єднанні — транзакції не поводитимуться як показано.

---

## Поняття

| Фраза | Значення |
|-------|----------|
| **`START TRANSACTION`** / **`BEGIN`** | Розпочати явну транзакцію (InnoDB). |
| **`COMMIT`** | Зробити всі зміни поточної транзакції **постійними**. |
| **`ROLLBACK`** | **Відкинути** всі зміни з моменту `START TRANSACTION` (або останнього `COMMIT`). |
| **`SAVEPOINT name`** | Позначити точку всередині транзакції. |
| **`ROLLBACK TO SAVEPOINT name`** | Скасувати роботу **після** цієї точки; раніша робота транзакції лишається. |
| **`RELEASE SAVEPOINT name`** | Видалити точку збереження (опціонально). |
| **Autocommit** | Коли `@@autocommit = 1` (за замовчуванням), кожна інструкція — своя мінітранзакція, якщо ви не відкрили явної. |
| **Рівень ізоляції** | Як видимі змін інших сесій (у процесі або зафіксовані) цій транзакції (`SET SESSION TRANSACTION ISOLATION LEVEL …` перед `START TRANSACTION`). За замовчуванням в InnoDB — **`REPEATABLE READ`**. |

**«Додати» транзакцію:** обгорнути DML у **`START TRANSACTION`** … **`COMMIT`** або **`ROLLBACK`**.

**«Прибрати» / завершити транзакцію:** **`COMMIT`** (зберегти зміни) або **`ROLLBACK`** (відкинути). Після цього ви повертаєтесь до звичайного autocommit, доки не виконаєте новий **`START TRANSACTION`**.

---

## Вправи (блоки у `.sql`-файлі)

1. Створити **`tx_lab`** і засіяти два «майстерні» з балансами.
2. Показати **`@@autocommit`**.
3. **Rollback** — переказати кошти, потім **`ROLLBACK`**; баланси повертаються до початкових.
4. **Commit** — знову переказати, потім **`COMMIT`**; баланси залишаються оновленими.
5. **Savepoint** — часткове скасування через **`ROLLBACK TO SAVEPOINT`**, потім **`COMMIT`**.
6. Опціонально **`SET autocommit = 0`** … **`COMMIT`** … **`SET autocommit = 1`** (закоментовано; обережно у спільних сесіях).
7. Рівні ізоляції — виконайте **`car_service_isolation_levels_examples.sql`**; для частини B використайте два термінали.

---

## Прибирання

Розкоментуйте **`DROP TABLE tx_lab;`** в кінці скрипта, якщо хочете видалити лабораторну таблицю.
