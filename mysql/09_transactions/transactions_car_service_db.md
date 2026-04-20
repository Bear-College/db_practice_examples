# Transactions — `car_service_db`

Examples use a small lab table **`tx_lab`** inside **`car_service_db`** (loaded from **`database_mysql/car_service_db.sql.gz`**). The script creates the table, runs **`START TRANSACTION`** / **`COMMIT`** / **`ROLLBACK`** / **`SAVEPOINT`**, then optionally drops the table.

**Scripts**

- `09_transactions/car_service_transactions_examples.sql` — begin / commit / rollback / savepoints  
- `09_transactions/car_service_isolation_levels_examples.sql` — `READ UNCOMMITTED`, `READ COMMITTED`, `REPEATABLE READ`, `SERIALIZABLE`; Part A runs in one session, Part B is a two-terminal recipe for concurrency effects  

```bash
gunzip -c database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 09_transactions/car_service_transactions_examples.sql
mysql -u ... -p ... car_service_db < 09_transactions/car_service_isolation_levels_examples.sql
```

**Run the whole file in one client session** (e.g. `mysql < file` or paste in one tab). If each statement runs in a separate connection, transactions will not behave as shown.

---

## Concepts

| Phrase | Meaning |
|--------|---------|
| **`START TRANSACTION`** / **`BEGIN`** | Start an explicit transaction (InnoDB). |
| **`COMMIT`** | Make all changes in the current transaction **permanent**. |
| **`ROLLBACK`** | **Discard** all changes since `START TRANSACTION` (or since last `COMMIT`). |
| **`SAVEPOINT name`** | Mark a point inside the transaction. |
| **`ROLLBACK TO SAVEPOINT name`** | Undo work **after** that savepoint; earlier work in the transaction stays. |
| **`RELEASE SAVEPOINT name`** | Remove a savepoint (optional). |
| **Autocommit** | When `@@autocommit = 1` (default), each statement is its own mini-transaction unless you opened an explicit one. |
| **Isolation level** | How visible other sessions’ in-flight or committed changes are to this transaction (`SET SESSION TRANSACTION ISOLATION LEVEL …` before `START TRANSACTION`). InnoDB default is **`REPEATABLE READ`**. |

**“Adding” a transaction:** wrap DML in **`START TRANSACTION`** … **`COMMIT`** or **`ROLLBACK`**.

**“Removing” / ending a transaction:** **`COMMIT`** (keep changes) or **`ROLLBACK`** (discard). After that, you are back to normal autocommit behavior until the next **`START TRANSACTION`**.

---

## Exercises (blocks in the `.sql` file)

1. Create **`tx_lab`** and seed two “workshop” balances.  
2. Show **`@@autocommit`**.  
3. **Rollback** — transfer money, then **`ROLLBACK`**; balances return to seed values.  
4. **Commit** — transfer again, then **`COMMIT`**; balances stay updated.  
5. **Savepoint** — partial undo with **`ROLLBACK TO SAVEPOINT`**, then **`COMMIT`**.  
6. Optional **`SET autocommit = 0`** … **`COMMIT`** … **`SET autocommit = 1`** (commented; be careful in shared sessions).  
7. Isolation levels — run **`car_service_isolation_levels_examples.sql`**; use two terminals for Part B.

---

## Cleanup

Uncomment **`DROP TABLE tx_lab;`** at the end of the script if you want the lab table removed.
