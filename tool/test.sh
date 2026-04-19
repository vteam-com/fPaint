#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

COVERAGE_DIR="$ROOT_DIR/coverage"

echo "== fPaint test runner =="

echo "Checking Flutter installation..."
if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter is not installed or not in PATH"
  exit 1
fi

echo "Running unit tests with coverage..."
mkdir -p "$COVERAGE_DIR"
flutter test --reporter=compact --coverage

"$ROOT_DIR/tool/update_coverage_summary.sh"

echo "All tests passed."
