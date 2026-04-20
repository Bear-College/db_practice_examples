#!/usr/bin/env bash
# Wrapper — relational (MySQL) examples live under mysql/
exec "$(cd "$(dirname "$0")" && pwd)/mysql/verify_sql_examples.sh" "$@"
