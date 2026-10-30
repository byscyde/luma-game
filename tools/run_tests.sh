#!/usr/bin/env bash
# Imports the project (refreshes the class cache + translations), then runs the
# headless test suite and the level validator. Exit code is non-zero on any failure.
#   GODOT=/path/to/godot tools/run_tests.sh [--filter=substr]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build/reports
# Two passes: the first import can parse autoload scripts before assets exist.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --import > build/reports/import.log 2>&1
if grep -E "SCRIPT ERROR|Parse Error" build/reports/import.log; then
  echo "import reported script errors"; exit 1
fi
"$GODOT" --headless --path . res://tests/run_tests.tscn -- --save-path=user://test_save.json --junit=res://build/reports/junit.xml "$@" | tee build/reports/tests.log
"$GODOT" --headless --path . --script res://tools/validate_levels.gd | tee build/reports/levels.log
