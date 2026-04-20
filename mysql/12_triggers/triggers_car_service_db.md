# Triggers — `car_service_db`

Examples install **InnoDB triggers** on small lab tables **`tri_lab_account`** and **`tri_lab_audit`** inside **`car_service_db`**. They demonstrate **`BEFORE INSERT`** (validation with **`SIGNAL`**), **`AFTER INSERT`**, **`BEFORE UPDATE`**, **`AFTER UPDATE`**, and **`AFTER DELETE`**.

> **Folder name:** this module is **`12_triggers`** (triggers before functions in this repo’s numbering).

**Script:** `12_triggers/car_service_triggers_examples.sql`

```bash
gunzip -c database_mysql/car_service_db.sql.gz | mysql -u ... -p ... car_service_db
mysql -u ... -p ... car_service_db < 12_triggers/car_service_triggers_examples.sql
```

Use the **mysql** client (or compatible); **`DELIMITER`** is processed by the client when you `SOURCE` / redirect the file.

---

## Concepts

| Timing | Typical use |
|--------|-------------|
| **`BEFORE INSERT` / `UPDATE`** | Validate **`NEW.*`**, normalize values, reject with **`SIGNAL`**. |
| **`AFTER INSERT` / `UPDATE` / `DELETE`** | Write audit rows, counters (use **`NEW` / `OLD`**). |

- **`NEW`**: row being inserted or new column values on update.  
- **`OLD`**: previous row on update/delete.  
- Triggers are **not** a substitute for constraints when a simple **`CHECK`** or **`FOREIGN KEY`** suffices — use triggers for cross-row logic or logging.

---

## What the script does

1. Drops old lab objects, creates **`tri_lab_account`** (label + balance) and **`tri_lab_audit`** (event log).  
2. Creates five triggers; runs sample **`INSERT` / `UPDATE` / `DELETE`**.  
3. Selects from **`tri_lab_audit`** to show fired events.  
4. Optional commented **`INSERT`** that violates the rule (negative balance) → **`SIGNAL`**.  
5. Optional **`DROP TABLE`** at the end to remove lab objects.

To **remove triggers only** (keep tables): `DROP TRIGGER IF EXISTS tri_lab_account_bi_check;` (names must match). **`DROP TABLE tri_lab_account`** removes that table and its triggers together.
