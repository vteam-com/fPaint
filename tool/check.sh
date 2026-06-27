#!/bin/sh

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_FAILURE_EXIT_CODE="1"
FCHECK_VERSION="1.4.1"
TEST_OUTPUT_DIR="$ROOT_DIR/test/output"
COVERAGE_LCOV_FILE="$ROOT_DIR/coverage/lcov.info"
COVERAGE_SUMMARY_FILE="$TEST_OUTPUT_DIR/cc.txt"
ANSI_RED="$(printf '\033[31m')"
ANSI_BOLD="$(printf '\033[1m')"
ANSI_BLINK="$(printf '\033[5m')"
ANSI_RESET="$(printf '\033[0m')"

cd "$ROOT_DIR"

show_fcheck_score_error() {
	printf '\n%s%s%s' "$ANSI_RED" "$ANSI_BOLD" "$ANSI_BLINK"
	cat <<'EOF'
################################################################
############### Expected fCheck SCORE of 100%   ################
############### Fix the remaining fCheck issues ################
################################################################
EOF
	printf '%s\n\n' "$ANSI_RESET"
}

echo --- Pub Get
flutter pub get > /dev/null || { echo "Pub get failed"; exit 1; }
echo --- Pub Outdated
flutter pub outdated

echo --- fCheck
# Install the pinned version into the isolated cache, then run it.
# Note: `dart pub cache exec` doesn't exist on all Dart SDK versions; `pub global run` does.
dart pub global activate fcheck "$FCHECK_VERSION" > /dev/null
dart pub global run fcheck --strict --svg --fix --list full
fcheck_exit_code="$?"

case "$fcheck_exit_code" in
	0)
		;;
	[1-9]|[1-9][0-9])
		show_fcheck_score_error
		;;
	*)
		echo "fCheck failed"
		exit "$CHECK_FAILURE_EXIT_CODE"
		;;
esac

echo --- Format sources
dart format lib test tool
dart fix --apply

if [ "$fcheck_exit_code" -ne 0 ]; then
	exit "$CHECK_FAILURE_EXIT_CODE"
fi

echo --- Analyze
flutter analyze lib test --no-pub

echo --- Test
test_started_at="$(date +%s)"
test_output="$(flutter test --reporter=compact --coverage --no-pub 2>&1)"
test_exit_code="$?"
test_finished_at="$(date +%s)"
test_elapsed_seconds="$((test_finished_at - test_started_at))"
test_elapsed_minutes="$((test_elapsed_seconds / 60))"
test_elapsed_remaining_seconds="$((test_elapsed_seconds % 60))"
printf '%s %sm %ss\n' '--- Test Duration:' "$test_elapsed_minutes" "$test_elapsed_remaining_seconds"

if [ "$test_exit_code" -ne 0 ]; then
	echo "$test_output"
	exit "$CHECK_FAILURE_EXIT_CODE"
fi

echo --- Coverage Summary
if [ ! -f "$COVERAGE_LCOV_FILE" ]; then
	echo "Coverage file not found: $COVERAGE_LCOV_FILE"
	exit "$CHECK_FAILURE_EXIT_CODE"
fi

if [ ! -s "$COVERAGE_LCOV_FILE" ]; then
	echo "Coverage file is empty: $COVERAGE_LCOV_FILE"
	exit "$CHECK_FAILURE_EXIT_CODE"
fi

if ! grep -q "^LF:" "$COVERAGE_LCOV_FILE"; then
	echo "Coverage file does not contain line totals: $COVERAGE_LCOV_FILE"
	exit "$CHECK_FAILURE_EXIT_CODE"
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
	exit "$CHECK_FAILURE_EXIT_CODE"
}

mkdir -p "$TEST_OUTPUT_DIR"
printf '%s\n' "$COVERAGE_PERCENTAGE" | tee "$COVERAGE_SUMMARY_FILE"
