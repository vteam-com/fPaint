#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COVERAGE_DIR="$ROOT_DIR/coverage"
COVERAGE_LCOV_FILE="$COVERAGE_DIR/lcov.info"
COVERAGE_UNIT_FILE="$COVERAGE_DIR/lcov_units.info"
COVERAGE_SUMMARY_FILE="$COVERAGE_DIR/cc.txt"

echo "== fPaint test runner =="

echo "Checking Flutter installation..."
if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter is not installed or not in PATH"
  exit 1
fi

echo "Running unit tests with coverage..."
mkdir -p "$COVERAGE_DIR"
flutter test --reporter=compact --coverage

if [[ -f "$COVERAGE_LCOV_FILE" ]]; then
  cp "$COVERAGE_LCOV_FILE" "$COVERAGE_UNIT_FILE"

  if command -v lcov >/dev/null 2>&1; then
    lcov --summary "$COVERAGE_LCOV_FILE" 2>&1 | grep -v "^Reading tracefile" | tee "$COVERAGE_SUMMARY_FILE"
    echo ""
    echo "Coverage summary written to: $COVERAGE_SUMMARY_FILE"
  fi
fi

echo "All tests passed."
