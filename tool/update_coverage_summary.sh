#!/bin/sh

set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COVERAGE_DIR="$ROOT_DIR/coverage"
COVERAGE_LCOV_FILE="$COVERAGE_DIR/lcov.info"
COVERAGE_UNIT_FILE="$COVERAGE_DIR/lcov_units.info"
COVERAGE_SUMMARY_FILE="$COVERAGE_DIR/cc.txt"

if [ ! -f "$COVERAGE_LCOV_FILE" ]; then
	echo "Coverage file not found: $COVERAGE_LCOV_FILE"
	exit 0
fi

cp "$COVERAGE_LCOV_FILE" "$COVERAGE_UNIT_FILE"

if command -v lcov >/dev/null 2>&1; then
	lcov --summary "$COVERAGE_LCOV_FILE" 2>&1 | grep -v "^Reading tracefile" | tee "$COVERAGE_SUMMARY_FILE"
	echo ""
	echo "Coverage summary written to: $COVERAGE_SUMMARY_FILE"
	if [ ! -f "$COVERAGE_SUMMARY_FILE" ]; then
		echo "Coverage summary file was not created: $COVERAGE_SUMMARY_FILE"
		exit 1
	fi
	if [ ! -s "$COVERAGE_SUMMARY_FILE" ]; then
		echo "Coverage summary file is empty: $COVERAGE_SUMMARY_FILE"
		exit 1
	fi
	if ! grep -q "lines" "$COVERAGE_SUMMARY_FILE"; then
		echo "Coverage summary output did not contain line coverage details: $COVERAGE_SUMMARY_FILE"
		exit 1
	fi
	if ! grep -q "functions" "$COVERAGE_SUMMARY_FILE"; then
		echo "Coverage summary output did not contain function coverage details: $COVERAGE_SUMMARY_FILE"
		exit 1
	fi
	if ! grep -q "branches" "$COVERAGE_SUMMARY_FILE"; then
		echo "Coverage summary output did not contain branch coverage details: $COVERAGE_SUMMARY_FILE"
		exit 1
	fi
	if [ ! -f "$COVERAGE_UNIT_FILE" ]; then
		echo "Coverage unit file was not created: $COVERAGE_UNIT_FILE"
		exit 1
	fi
	if [ ! -s "$COVERAGE_UNIT_FILE" ]; then
		echo "Coverage unit file is empty: $COVERAGE_UNIT_FILE"
		exit 1
	fi
	if ! grep -q "^SF:" "$COVERAGE_UNIT_FILE"; then
		echo "Coverage unit file does not contain LCOV records: $COVERAGE_UNIT_FILE"
		exit 1
	fi
	if ! grep -q "^SF:" "$COVERAGE_LCOV_FILE"; then
		echo "Coverage file does not contain LCOV records: $COVERAGE_LCOV_FILE"
		exit 1
	fi
	if ! cmp -s "$COVERAGE_LCOV_FILE" "$COVERAGE_UNIT_FILE"; then
		echo "Coverage unit file does not match LCOV source: $COVERAGE_UNIT_FILE"
		exit 1
	fi
fi