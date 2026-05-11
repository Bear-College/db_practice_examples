# Transactions — `car_service_db`

> Translation / Переклад: [Українська](../../i18n/uk/03_mysql/09_transactions/transactions_car_service_db.md)

These exercises walk through **explicit transactions** (`START TRANSACTION` / `COMMIT` / `ROLLBACK` / `SAVEPOINT`) and the four **isolation levels** InnoDB supports. They use a small lab table **`tx_lab`** (two "workshop bank accounts" you can move money between) and **`iso_lab`** (parts stock) inside **`car_service_db`** (loaded from **`01_database_mysql/car_service_db.sql.gz`**).

Runnable companion scripts:

- [`09_transactions/car_service_transactions_examples.sql`](car_service_transactions_examples.sql) — begin / commit / rollback / savepoints
- [`09_transactions/car_service_isolation_levels_examples.sql`](car_service_isolation_levels_examples.sql) — `READ UNCOMMITTED` / `READ COMMITTED` / `REPEATABLE READ` / `SERIALIZABLE`. Part A runs in one session; Part B is a two-terminal recipe.

```bash
mysql -u root -e "CREATE DATABASE IF NOT EXISTS car_service_db;"
gunzip -c 01_database_mysql/car_service_db.sql.gz | mysql -u root car_service_db
mysql -u root car_service_db < 03_mysql/09_transactions/car_service_transactions_examples.sql
mysql -u root car_service_db < 03_mysql/09_transactions/car_service_isolation_levels_examples.sql
```

**Important:** run **the whole file in one client session** (e.g. `mysql < file` or paste in one tab). Transactions don't span connections — if each statement is in a separate connection, the demos will not work.

---

## Exercise template (used in every section below)

| Section | What it gives you |
|---|---|
| **Context** | A small workshop scenario (money transfer, stock decrement). |
| **What you'll learn** | The specific transaction primitive trained in this exercise. |
| **Tables in play** | The lab table involved (`tx_lab` or `iso_lab`). |
| **Task** | The numbered statements to run. |
| **Expected result** | Real "before / inside / after" output from a live `mysql` run. |
| **Hint** | Which command opens, commits, or undoes the transaction. |
| **Solution** | The full SQL block. |
| **Step-by-step explanation** | What each command does and the typical gotchas. |

---

## Concepts cheat sheet

| Phrase | Meaning |
|--------|---------|
| **`START TRANSACTION`** / **`BEGIN`** | Open an explicit transaction (InnoDB). |
| **`COMMIT`** | Make all changes since `START TRANSACTION` **permanent**. |
| **`ROLLBACK`** | **Discard** all changes since `START TRANSACTION` (or the last `COMMIT`). |
| **`SAVEPOINT name`** | Mark a point inside the transaction you can roll back to. |
| **`ROLLBACK TO SAVEPOINT name`** | Undo only the work **after** that savepoint; earlier changes survive. |
| **`RELEASE SAVEPOINT name`** | Remove a savepoint (optional). |
| **Autocommit** | When `@@autocommit = 1` (default), each single statement is its own mini-transaction unless you opened an explicit one with `START TRANSACTION`. |
| **Isolation level** | How visible other sessions' in-flight or committed changes are to this transaction (`SET SESSION TRANSACTION ISOLATION LEVEL …` before `START TRANSACTION`). InnoDB default is **`REPEATABLE READ`**. |

**"Adding" a transaction:** wrap DML in `START TRANSACTION` … `COMMIT` (keep) or `ROLLBACK` (discard).
**"Ending" a transaction:** `COMMIT` or `ROLLBACK`. After that you're back to normal autocommit behaviour until the next `START TRANSACTION`.

---

## Lab schema reset (run once per session)

```sql
DROP TABLE IF EXISTS tx_lab;

CREATE TABLE tx_lab (
  id      INT NOT NULL AUTO_INCREMENT,
  name    VARCHAR(80) NOT NULL,
  balance DECIMAL(12,2) NOT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO tx_lab (name, balance) VALUES
  ('North Bay Workshop', 1000.00),
  ('South Bay Workshop',  500.00);
```

Two "workshop bank accounts" with starting balances 1000.00 and 500.00. Every exercise below assumes this seed.

---

## Exercise 1 — Inspect autocommit and the seed

### Context

Before touching transactions, confirm two things: that autocommit is **on** (the default), and that `tx_lab` has the two seed rows. This is the baseline you'll roll back to.

### What you'll learn

- How to read `@@session.autocommit`.
- That a transaction is implicit per statement when autocommit is 1.

### Tables in play

| Table | Columns |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Task

Run a single `SELECT` that returns both `@@session.autocommit` and `COUNT(*)` of `tx_lab`, using `UNION ALL`.

### Expected result (real rows from a live run)

```text
+-------------+-------+
| metric      | value |
+-------------+-------+
| autocommit  |     1 |
| tx_lab_rows |     2 |
+-------------+-------+
```

### Hint

`SELECT "autocommit", @@session.autocommit UNION ALL SELECT "tx_lab_rows", COUNT(*) FROM tx_lab;`.

### Solution

```sql
SELECT "autocommit" AS metric, @@session.autocommit AS value
UNION ALL
SELECT "tx_lab_rows"        AS metric, COUNT(*)            AS value FROM tx_lab;
```

### Step-by-step explanation

1. **`@@session.autocommit`** is the session-level value. `@@global.autocommit` is the server default.
2. **`UNION ALL`** keeps both metric rows. `UNION` (without `ALL`) would deduplicate — fine here, but `UNION ALL` is slightly cheaper.
3. **Why care about autocommit?** With autocommit on, **every statement is its own transaction** — `UPDATE … WHERE id = 1` is already committed by the time you read the next prompt. The exercises below open explicit transactions to override that.

---

## Exercise 2 — `START TRANSACTION` + `ROLLBACK` (discard the changes)

### Context

You start a money transfer between two workshops — 200 from North to South — then realise you used the wrong amount. `ROLLBACK` undoes everything since `START TRANSACTION` as if it never happened.

### What you'll learn

- The simplest "open transaction, mutate, undo" cycle.
- That `ROLLBACK` is **non-destructive** to data that was there before the transaction.

### Tables in play

| Table | Columns |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Task

1. `START TRANSACTION`.
2. Subtract 200 from id 1, add 200 to id 2.
3. `SELECT` to see in-flight state.
4. `ROLLBACK`.
5. `SELECT` again — balances are back to seed.

### Expected result (real "inside vs after" output)

Inside the transaction (before rollback):

```text
+------------------------------------+----+--------------------+---------+
| phase                              | id | name               | balance |
+------------------------------------+----+--------------------+---------+
| inside transaction before rollback |  1 | North Bay Workshop |  800.00 |
| inside transaction before rollback |  2 | South Bay Workshop |  700.00 |
+------------------------------------+----+--------------------+---------+
```

After `ROLLBACK`:

```text
+----------------------------------------+----+--------------------+---------+
| phase                                  | id | name               | balance |
+----------------------------------------+----+--------------------+---------+
| after ROLLBACK (back to seed balances) |  1 | North Bay Workshop | 1000.00 |
| after ROLLBACK (back to seed balances) |  2 | South Bay Workshop |  500.00 |
+----------------------------------------+----+--------------------+---------+
```

### Hint

`START TRANSACTION;` … `UPDATE …;` … `ROLLBACK;`.

### Solution

```sql
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 200.00 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 200.00 WHERE id = 2;

SELECT 'inside transaction before rollback' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;

ROLLBACK;

SELECT 'after ROLLBACK (back to seed balances)' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;
```

### Step-by-step explanation

1. **`START TRANSACTION`** opens an explicit transaction. From now on every DML is buffered in the engine's undo logs.
2. **Both `UPDATE`s** run inside the same transaction. Inside the session you can see the new balances (`800` and `700`) — but no other session can.
3. **`ROLLBACK`** discards the buffered changes. The database is back to the seed values, and any locks taken are released.
4. **No data was harmed.** This is the safety net SQL gives you for multi-step mutations.
5. **Common bug:** running the `UPDATE` in autocommit mode by accident (no `START TRANSACTION`). The change is committed immediately; `ROLLBACK` does nothing.

---

## Exercise 3 — `START TRANSACTION` + `COMMIT` (persist the changes)

### Context

This time the transfer is correct (150 from North to South). `COMMIT` makes the change durable; once it returns, the new balances survive a server restart.

### What you'll learn

- Closing a transaction with `COMMIT`.
- That the in-flight read of an uncommitted row sees the new value **only inside this session**.

### Tables in play

| Table | Columns |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Task

1. `START TRANSACTION`.
2. Subtract 150 from id 1, add 150 to id 2.
3. `COMMIT`.
4. `SELECT` — both rows reflect the transfer.

### Expected result (real rows from a live run)

```text
+-----------------------------------+----+--------------------+---------+
| phase                             | id | name               | balance |
+-----------------------------------+----+--------------------+---------+
| after COMMIT (transfer persisted) |  1 | North Bay Workshop |  850.00 |
| after COMMIT (transfer persisted) |  2 | South Bay Workshop |  650.00 |
+-----------------------------------+----+--------------------+---------+
```

### Hint

The mirror of Exercise 2 — `ROLLBACK` becomes `COMMIT`.

### Solution

```sql
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 150.00 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 150.00 WHERE id = 2;

COMMIT;

SELECT 'after COMMIT (transfer persisted)' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;
```

### Step-by-step explanation

1. **`COMMIT`** flushes the undo and redo logs and releases locks; the row is now visible to everyone.
2. **Atomicity:** both `UPDATE`s land together. If the server crashed between them, on restart InnoDB rolls back the partial transaction — you cannot land "money debited but not credited".
3. **Durability:** after `COMMIT` returns, the change is on disk. Even a power loss won't lose it.
4. **Notice the running totals:** Exercise 2 reset to seed (`1000`/`500`), then this transfer subtracted 150 / added 150, ending at `850` / `650`. Each exercise is cumulative.

---

## Exercise 4 — `SAVEPOINT` and `ROLLBACK TO SAVEPOINT` (partial undo)

### Context

A more delicate workflow: debit one account, mark a checkpoint, credit the other, then change your mind and undo **only the credit** — keeping the debit. Useful when an upstream step is verified but a downstream step needs to be re-tried with different parameters.

### What you'll learn

- `SAVEPOINT name` marks a "you can come back here" line.
- `ROLLBACK TO SAVEPOINT name` undoes only work **after** that point.
- `RELEASE SAVEPOINT name` removes the marker (optional).
- The final `COMMIT` persists the surviving work.

### Tables in play

| Table | Columns |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Task

1. `START TRANSACTION`.
2. Subtract 50 from id 1.
3. `SAVEPOINT after_debit`.
4. Add 50 to id 2.
5. `ROLLBACK TO SAVEPOINT after_debit` — credit is undone, debit stays.
6. `SELECT` — intermediate state.
7. Re-apply the credit, `RELEASE SAVEPOINT after_debit`, `COMMIT`.
8. `SELECT` — final state.

### Expected result (real rows from a live run)

Right after `ROLLBACK TO SAVEPOINT` (debit stayed, credit gone):

```text
+-------------------------------------------------------+----+--------------------+---------+
| phase                                                 | id | name               | balance |
+-------------------------------------------------------+----+--------------------+---------+
| after ROLLBACK TO SAVEPOINT (workshop2 credit undone) |  1 | North Bay Workshop |  800.00 |
| after ROLLBACK TO SAVEPOINT (workshop2 credit undone) |  2 | South Bay Workshop |  650.00 |
+-------------------------------------------------------+----+--------------------+---------+
```

After `COMMIT` (credit re-applied):

```text
+---------------------------------------+----+--------------------+---------+
| phase                                 | id | name               | balance |
+---------------------------------------+----+--------------------+---------+
| after COMMIT following savepoint demo |  1 | North Bay Workshop |  800.00 |
| after COMMIT following savepoint demo |  2 | South Bay Workshop |  700.00 |
+---------------------------------------+----+--------------------+---------+
```

### Hint

`SAVEPOINT name` → `… do work …` → `ROLLBACK TO SAVEPOINT name` → `… redo or skip …` → `COMMIT`.

### Solution

```sql
START TRANSACTION;

UPDATE tx_lab SET balance = balance - 50.00 WHERE id = 1;

SAVEPOINT after_debit;

UPDATE tx_lab SET balance = balance + 50.00 WHERE id = 2;

ROLLBACK TO SAVEPOINT after_debit;

SELECT 'after ROLLBACK TO SAVEPOINT (workshop2 credit undone)' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;

UPDATE tx_lab SET balance = balance + 50.00 WHERE id = 2;

RELEASE SAVEPOINT after_debit;

COMMIT;

SELECT 'after COMMIT following savepoint demo' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;
```

### Step-by-step explanation

1. **The debit happens first** and is "behind" the savepoint. After `ROLLBACK TO SAVEPOINT after_debit`, the debit is **still there**; only work that came **after** the savepoint is gone.
2. **`SAVEPOINT` is local to the current transaction.** A `ROLLBACK` (without `TO SAVEPOINT`) discards the entire transaction along with all its savepoints.
3. **`RELEASE SAVEPOINT`** removes the marker. After release, you can't roll back to it any more, but the work that occurred since then is unaffected.
4. **Tracking running balance:** before this exercise: `850` / `650`. Debit −50 ⇒ `800` / `650`. Final credit +50 ⇒ `800` / `700`.
5. **Real use case:** application-level retries. The outer transaction wraps a multi-step business action; each retryable step is bracketed by a savepoint so a single failure doesn't undo everything.

---

## Exercise 5 — `SET autocommit = 0` (multi-statement implicit transactions)

### Context

Some clients (notably the `mysql` CLI in script mode) like to "turn off autocommit" so a sequence of statements becomes one big transaction. Useful for bulk loaders. Be careful: forgetting the final `COMMIT` leaves your session holding locks.

### What you'll learn

- `SET SESSION autocommit = 0` makes every subsequent statement implicitly part of a transaction.
- You still need `COMMIT` to persist; otherwise the work vanishes on disconnect.
- `SET SESSION autocommit = 1` returns to the default.

### Tables in play

| Table | Columns |
|---|---|
| `tx_lab` | `id`, `name`, `balance` |

### Task

1. `SET SESSION autocommit = 0`.
2. Two `UPDATE`s (10 from North to South).
3. `COMMIT`.
4. `SET SESSION autocommit = 1`.

(In the companion script this block is commented out by default — uncomment to run it.)

### Expected result

After the block: balances move by 10 (e.g. `790.00` / `710.00` if you continue from Exercise 4). Tail the table to confirm.

### Hint

Two `UPDATE` statements between `SET autocommit = 0` and `COMMIT` form a single transaction.

### Solution

```sql
SET SESSION autocommit = 0;

UPDATE tx_lab SET balance = balance - 10 WHERE id = 1;
UPDATE tx_lab SET balance = balance + 10 WHERE id = 2;

COMMIT;

SET SESSION autocommit = 1;

SELECT 'after autocommit=0 demo' AS phase,
       id, name, balance
FROM tx_lab
ORDER BY id;
```

### Step-by-step explanation

1. **`autocommit = 0`** makes the engine treat `tx_lab` writes as part of an open transaction — no explicit `START TRANSACTION` needed.
2. **Without the final `COMMIT`**, disconnecting (or running `SET autocommit = 1`) rolls back uncommitted work in many client modes.
3. **Why not always use this?** It surprises co-workers. The explicit `START TRANSACTION; … COMMIT;` block is much more obvious to readers and code reviewers.
4. **Safety:** in shared sessions (replication runners, schema migration tools), changing `autocommit` mid-script can interact with other tools' assumptions. Set it back to 1 before you finish.

---

## Exercise 6 — `REPEATABLE READ` (InnoDB default)

### Context

You're running the daily inventory report. While you're reading, another technician decrements a different SKU. Your report must show **a consistent snapshot** of the stock as it was at the start of your transaction.

### What you'll learn

- InnoDB's default isolation level: `REPEATABLE READ`.
- A plain `SELECT` inside a transaction reads a **snapshot** established on the **first** read.
- Other sessions' commits don't change rows you've already "seen".

### Tables in play

| Table | Columns |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Task

1. `SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ`.
2. `START TRANSACTION`.
3. Read `id = 1`.
4. `UPDATE` a different row (`id = 2`).
5. Read `id = 1` again — same value as step 3.
6. `COMMIT`. Re-read — everyone sees the new committed state.

### Expected result (real rows from a live run)

First read inside transaction:

```text
+---------------------+----+------------+-----------+
| phase               | id | part_code  | stock_qty |
+---------------------+----+------------+-----------+
| RR: first read id=1 |  1 | BRK-PAD-01 |        40 |
+---------------------+----+------------+-----------+
```

Second read of the same row in the same transaction (snapshot — identical):

```text
+----------------------------------------------------------------+----+------------+-----------+
| phase                                                          | id | part_code  | stock_qty |
+----------------------------------------------------------------+----+------------+-----------+
| RR: second read id=1 (same snapshot as first read in this txn) |  1 | BRK-PAD-01 |        40 |
+----------------------------------------------------------------+----+------------+-----------+
```

After `COMMIT` (all rows, including the in-txn `UPDATE` to id 2):

```text
+-------------------------------------------------+----+-------------+-----------+
| phase                                           | id | part_code   | stock_qty |
+-------------------------------------------------+----+-------------+-----------+
| RR: after COMMIT — everyone sees committed data |  1 | BRK-PAD-01  |        40 |
| RR: after COMMIT — everyone sees committed data |  2 | OIL-5W30-4L |        22 |
| RR: after COMMIT — everyone sees committed data |  3 | FLT-AIR-88  |        12 |
+-------------------------------------------------+----+-------------+-----------+
```

### Hint

`SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ` **before** `START TRANSACTION`.

### Solution

```sql
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

START TRANSACTION;

SELECT 'RR: first read id=1' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

UPDATE iso_lab SET stock_qty = stock_qty - 3 WHERE id = 2;

SELECT 'RR: second read id=1 (same snapshot as first read in this txn)' AS phase,
       id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;

SELECT 'RR: after COMMIT — everyone sees committed data' AS phase,
       id, part_code, stock_qty FROM iso_lab ORDER BY id;
```

### Step-by-step explanation

1. **Snapshot semantics:** at the first read in the transaction, InnoDB creates a "read view". All subsequent plain `SELECT`s see the data as of that snapshot, regardless of other sessions' commits.
2. **Writes use the latest committed data**, not the snapshot — that's why your own `UPDATE` to id 2 changed `stock_qty` from 25 to 22 (you must check the row "freshly" before mutating).
3. **`UPDATE`s in your txn are visible to your subsequent reads** in the same transaction.
4. **Phantom row protection:** RR plus InnoDB's gap locks usually prevents phantoms for range scans within the same transaction. Lower levels (RC, RU) do not.

---

## Exercise 7 — `READ COMMITTED`

### Context

Real-time dashboards prefer `READ COMMITTED` (RC): every statement sees the freshest committed data. If another session commits between your two `SELECT`s, the second one reflects the change.

### What you'll learn

- `READ COMMITTED` re-reads on every statement.
- Trade-off: you can get **non-repeatable reads** (same `SELECT` twice, different result).
- Concurrency benefit: fewer gap locks than RR.

### Tables in play

| Table | Columns |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Task

1. `SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED`.
2. `START TRANSACTION`.
3. Read `id = 1`.
4. `COMMIT`.

(For the real demonstration of non-repeatable reads, you need two terminals — see "Part B" further down.)

### Expected result (real rows from a live run)

```text
+-----------------+----+------------+-----------+
| phase           | id | part_code  | stock_qty |
+-----------------+----+------------+-----------+
| RC: read in txn |  1 | BRK-PAD-01 |        40 |
+-----------------+----+------------+-----------+
```

### Hint

`SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED` before `START TRANSACTION`.

### Solution

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

START TRANSACTION;

SELECT 'RC: read in txn' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;
```

### Step-by-step explanation

1. **`READ COMMITTED`** re-reads the latest committed snapshot for every statement. There is no transaction-wide snapshot.
2. **Non-repeatable read** is the price: if another session commits between your `SELECT`s, you'll see two different values.
3. **Why pick RC?** Higher concurrency on writes — no gap locks on plain `SELECT`. Useful for read-heavy dashboards.
4. **PostgreSQL parallel:** RC is Postgres's default. MySQL defaults to RR which is stricter.

---

## Exercise 8 — `READ UNCOMMITTED`

### Context

The textbook "dirty read" isolation level. In MySQL/InnoDB, you usually still get a consistent read even at this level for plain `SELECT` — but the level changes lock behaviour for locking reads (`SELECT … FOR UPDATE`). Prefer RC and above in practice.

### What you'll learn

- The level is allowed, but InnoDB still hides most "uncommitted" data from plain `SELECT`.
- For the textbook dirty-read demo you need two sessions — Part B below.

### Tables in play

| Table | Columns |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Task

1. `SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED`.
2. `START TRANSACTION`.
3. Read all rows.
4. `COMMIT`.

### Expected result (real rows from a live run)

```text
+------------------------------------------------------------+----+-------------+-----------+
| phase                                                      | id | part_code   | stock_qty |
+------------------------------------------------------------+----+-------------+-----------+
| RU: read (level set; use Part B for dirty-read experiment) |  1 | BRK-PAD-01  |        40 |
| RU: read (level set; use Part B for dirty-read experiment) |  2 | OIL-5W30-4L |        22 |
| RU: read (level set; use Part B for dirty-read experiment) |  3 | FLT-AIR-88  |        12 |
+------------------------------------------------------------+----+-------------+-----------+
```

### Hint

The output looks identical to the committed state in one session — the difference shows up with concurrent uncommitted writes.

### Solution

```sql
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

START TRANSACTION;

SELECT 'RU: read (level set; use Part B for dirty-read experiment)' AS phase,
       id, part_code, stock_qty FROM iso_lab ORDER BY id;

COMMIT;
```

### Step-by-step explanation

1. **InnoDB caveat:** plain `SELECT` under `READ UNCOMMITTED` often **still** returns the latest committed row, not the in-flight one. The "dirty read" textbook story is a SQL-92 ideal that InnoDB only partly exposes.
2. **Where the level actually matters:** locking reads (`SELECT … FOR UPDATE`, `SELECT … LOCK IN SHARE MODE`) and InnoDB-internal undo-log decisions.
3. **In practice:** avoid `READ UNCOMMITTED` in app code. Pick RC or RR.

---

## Exercise 9 — `SERIALIZABLE`

### Context

The strictest level: every `SELECT` behaves like `SELECT … LOCK IN SHARE MODE` and InnoDB adds gap locks to forbid phantoms. Use when you absolutely need linearisable semantics (financial ledgers, inventory under high contention).

### What you'll learn

- `SERIALIZABLE` implicitly upgrades plain `SELECT` to shared-lock reads.
- The trade-off: drastically higher lock contention.

### Tables in play

| Table | Columns |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Task

1. `SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE`.
2. `START TRANSACTION`.
3. Read `id = 1` (this places a shared lock).
4. `COMMIT`.
5. **Restore the default level** for subsequent work: `SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ`.

### Expected result (real rows from a live run)

```text
+-----------------------------+----+------------+-----------+
| phase                       | id | part_code  | stock_qty |
+-----------------------------+----+------------+-----------+
| SER: locked consistent read |  1 | BRK-PAD-01 |        40 |
+-----------------------------+----+------------+-----------+
```

### Hint

The result looks the same as at any other level — the difference is **what other sessions can do** while your transaction is open (they'll block trying to write the same range).

### Solution

```sql
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

START TRANSACTION;

SELECT 'SER: locked consistent read' AS phase, id, part_code, stock_qty
FROM iso_lab WHERE id = 1;

COMMIT;

SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
```

### Step-by-step explanation

1. **Plain `SELECT` ≡ `SELECT … LOCK IN SHARE MODE`** under SERIALIZABLE. Concurrent writers block until your transaction ends.
2. **Gap locks** prevent another session from inserting a row into the range you just scanned — that's phantom protection.
3. **Cost:** throughput drops, deadlocks become more frequent. Use sparingly.
4. **Always reset** at the end (`SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ`) so the rest of your session doesn't run at SERIALIZABLE by accident.

---

## Exercise 10 — Part B: two-terminal concurrency recipe

### Context

To **see** the textbook anomalies (non-repeatable reads, phantoms, dirty reads), you need two `mysql` sessions running side by side. The companion script ships a guided two-terminal recipe — copy the lines into each terminal in the order indicated.

### What you'll learn

- How to demonstrate **non-repeatable read** in `READ COMMITTED` (B2).
- How to demonstrate **repeatable read** in `REPEATABLE READ` (B3).
- How `REPEATABLE READ` blocks phantom inserts vs `READ COMMITTED` (B4).

### Tables in play

| Table | Columns |
|---|---|
| `iso_lab` | `id`, `part_code`, `stock_qty` |

### Task

Open two `mysql` clients (Terminal 1, Terminal 2). Follow the recipe in `09_transactions/car_service_isolation_levels_examples.sql`, Part B.

### Expected result

Each scenario gives you an "anomaly" or "no anomaly" outcome. Example for B2 (non-repeatable read under `READ COMMITTED`):

- Terminal 1, first `SELECT`: stock_qty = 40
- Terminal 2 commits `stock_qty - 1`
- Terminal 1, second `SELECT`: stock_qty = 39 ← changed inside the same transaction

### Hint

`SET SESSION TRANSACTION ISOLATION LEVEL …` before `START TRANSACTION` in each terminal. Run statements **in order** between the two terminals as written.

### Solution

See [`09_transactions/car_service_isolation_levels_examples.sql`](car_service_isolation_levels_examples.sql), Part B (commented). The four scenarios:

- **B1 — `READ UNCOMMITTED`:** classic "dirty read" attempt; InnoDB often still hides the uncommitted row.
- **B2 — `READ COMMITTED`:** non-repeatable read confirmed.
- **B3 — `REPEATABLE READ`:** snapshot is repeatable; you don't see the other terminal's commit until you finish.
- **B4 — Phantom range:** `RC` shows the new row count, `RR` keeps the original count.

### Step-by-step explanation

1. **One transaction per terminal.** A second `mysql -u root car_service_db` gives you an independent session.
2. **Order matters.** Step the statements alternately. If you run all of Terminal 2 first, the experiment collapses.
3. **Cleanup between scenarios.** Each `START TRANSACTION` should be paired with a `COMMIT` or `ROLLBACK`; otherwise the next scenario inherits leftover locks.
4. **Why use scripts not autocommit?** Because we need explicit transaction control to observe these anomalies. Autocommit hides them.

---

## Cleanup

Both scripts end with optional `DROP TABLE` for the lab tables. Uncomment them if you want a clean slate; otherwise the data persists for further experiments.

---

## Troubleshooting

| Symptom | Likely fix |
|---|---|
| `ROLLBACK` doesn't seem to undo anything | The session is in autocommit mode. Open a transaction first: `START TRANSACTION;`. |
| `SAVEPOINT` errors with `unknown savepoint` | The savepoint was released, or `COMMIT` / `ROLLBACK` cleared it. Savepoints are only valid inside the same transaction. |
| Two terminals don't see each other's changes | Each connection has its own snapshot, especially under RR. `COMMIT` first. |
| Lock wait timeout exceeded | Another session is holding a row lock. `SHOW ENGINE INNODB STATUS;` shows who. |
| Deadlock at SERIALIZABLE | Inevitable under high contention; retry the transaction in the app. |
| Isolation level didn't change | Set it **before** `START TRANSACTION`, in the same session. |
