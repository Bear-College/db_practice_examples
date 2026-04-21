#!/usr/bin/env bash
# Run all MongoDB example.py scripts (requires mongod and pymongo).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! command -v python3 >/dev/null; then
  echo "python3 not found" >&2
  exit 1
fi

python3 -c "import pymongo" 2>/dev/null || {
  echo "Install pymongo: pip install -r $ROOT/requirements.txt" >&2
  exit 1
}

for script in "$ROOT"/0*/example.py; do
  [[ -f "$script" ]] || continue
  echo ""
  echo "==> $(dirname "${script#$ROOT/}")"
  python3 "$script"
  echo "    OK"
done

echo ""
echo "All MongoDB examples finished."
