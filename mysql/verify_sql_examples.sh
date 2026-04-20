#!/usr/bin/env bash
# Run all practice .sql files against local MySQL and fail on first error.
# Prerequisites:
#   - mysql client on PATH
#   - Server running (socket or TCP per your ~/.my.cnf)
#   - For algebra + DQL: load database_mysql/car_service_db.sql.gz into `car_service_db` first, e.g.:
#       gunzip -c database_mysql/car_service_db.sql.gz | mysql -u... -p... car_service_db
#
# Usage (from repo root):
#   chmod +x verify_sql_examples.sh
#   ./verify_sql_examples.sh
# Optional env:
#   MYSQL_USER=root MYSQL_ARGS='-psecret' ./verify_sql_examples.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
MYSQL_USER="${MYSQL_USER:-root}"
# shellcheck disable=SC2206
MYSQL=( mysql -u "$MYSQL_USER" ${MYSQL_ARGS:-} )

echo "==> mysql client"
command -v mysql >/dev/null

echo "==> server ping"
"${MYSQL[@]}" -e "SELECT VERSION() AS mysql_version\\G"

run_file() {
  local label="$1"
  local path="$2"
  echo ""
  echo "==> $label"
  echo "    $path"
  "${MYSQL[@]}" < "$path"
  echo "    OK"
}

run_file "DDL (ddl_practice)" "$ROOT/02_ddl/car_service_ddl_examples.sql"
run_file "DML (dml_practice)" "$ROOT/03_dml/car_service_dml_examples.sql"

if ! "${MYSQL[@]}" -Nse "SHOW DATABASES LIKE 'car_service_db'" | grep -q .; then
  echo ""
  echo "SKIP: database \`car_service_db\` not found."
  echo "Load: gunzip -c database_mysql/car_service_db.sql.gz | mysql -u $MYSQL_USER ... car_service_db"
  echo "Then re-run this script for algebra + DQL checks."
  exit 0
fi

run_file "Relational algebra (car_service_db)" "$ROOT/01_relational_algebra_Koda/car_service_algebra_examples.sql"
run_file "DQL (car_service_db)" "$ROOT/04_dql/car_service_dql_examples.sql"
run_file "SQL clause order (car_service_db)" "$ROOT/05_order_commands/car_service_order_examples.sql"
run_file "Subqueries (car_service_db)" "$ROOT/06_subqueries/car_service_subqueries_examples.sql"
run_file "JOINs (car_service_db)" "$ROOT/07_join/car_service_join_examples.sql"
run_file "Indexes lab (car_service_db)" "$ROOT/08_indexes/car_service_indexes_examples.sql"
run_file "Transactions (car_service_db)" "$ROOT/09_transactions/car_service_transactions_examples.sql"
run_file "Window functions (car_service_db)" "$ROOT/10_windows_functions/car_service_windows_functions_examples.sql"
run_file "Variables (car_service_db)" "$ROOT/11_variables/car_service_variables_examples.sql"
run_file "Built-in functions (car_service_db)" "$ROOT/13_functions/car_service_functions_examples.sql"
run_file "Triggers (car_service_db)" "$ROOT/12_triggers/car_service_triggers_examples.sql"
run_file "Stored procedures (car_service_db)" "$ROOT/14_procedures/car_service_procedures_examples.sql"
run_file "Cycles / loops (car_service_db)" "$ROOT/15_cycles/car_service_cycles_examples.sql"

echo ""
echo "All SQL files executed successfully."
