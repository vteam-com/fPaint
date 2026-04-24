#!/bin/sh

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_FAILURE_EXIT_CODE="1"
FCHECK_VERSION="1.2.0"
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

# fcheck --fix can touch dependency declarations; refresh package resolution
# before formatter/analyzer reads analysis_options includes.
echo --- Pub Get post-fcheck
flutter pub get > /dev/null || { echo "Pub get failed"; exit 1; }

echo --- Format sources
dart format lib test tool
dart fix --apply

if [ "$fcheck_exit_code" -ne 0 ]; then
	exit "$CHECK_FAILURE_EXIT_CODE"
fi

echo --- Analyze
flutter analyze lib test --no-pub | sed 's/^/    /'

echo --- Test
test_output="$(flutter test --reporter=compact --coverage --no-pub 2>&1)" || {
	echo "$test_output"
	exit "$CHECK_FAILURE_EXIT_CODE"
}

echo --- Coverage Summary
"$ROOT_DIR/tool/update_coverage_summary.sh" || exit "$CHECK_FAILURE_EXIT_CODE"
