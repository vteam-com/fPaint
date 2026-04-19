#!/bin/sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COVERAGE_DIR="$ROOT_DIR/coverage"
COVERAGE_LCOV_FILE="$COVERAGE_DIR/lcov.info"
COVERAGE_SUMMARY_FILE="$COVERAGE_DIR/cc.txt"

if [ ! -f "$COVERAGE_LCOV_FILE" ]; then
	echo "Coverage file not found: $COVERAGE_LCOV_FILE"
	exit 1
fi

if [ ! -s "$COVERAGE_LCOV_FILE" ]; then
	echo "Coverage file is empty: $COVERAGE_LCOV_FILE"
	exit 1
fi

if ! grep -q "^LF:" "$COVERAGE_LCOV_FILE"; then
	echo "Coverage file does not contain line totals: $COVERAGE_LCOV_FILE"
	exit 1
fi

COVERAGE_PERCENTAGE="$(awk -F: '
	/^LF:/ { line_found += $2; next }
	/^LH:/ { line_hit += $2; next }
	END {
		if (line_found <= 0) {
			exit 1
		}
		printf "%.1f%%", (line_hit / line_found) * 100
	}
' "$COVERAGE_LCOV_FILE")" || {
	echo "Coverage file does not contain valid line totals: $COVERAGE_LCOV_FILE"
	exit 1
}

printf '%s\n' "$COVERAGE_PERCENTAGE" | tee "$COVERAGE_SUMMARY_FILE"