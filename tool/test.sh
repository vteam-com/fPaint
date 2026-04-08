#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "== fPaint test runner =="

echo "Checking Flutter installation..."
if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter is not installed or not in PATH"
  exit 1
fi

echo "Checking macOS device availability..."
if ! devices_output="$(flutter devices 2>&1)"; then
  echo "Error: unable to list Flutter devices"
  echo "$devices_output"
  exit 1
fi

if [[ "$devices_output" != *"• macos"* ]]; then
  echo "Error: macOS device is not available"
  echo "Available devices:"
  echo "$devices_output"
  exit 1
fi

echo "Running unit tests..."
flutter test --reporter=compact

echo "Running integration tests on macOS..."
integration_files=()
while IFS= read -r f; do
  integration_files+=("$f")
done < <(find integration_test -maxdepth 1 -type f -name "*_test.dart" | sort)

if [[ ${#integration_files[@]} -eq 0 ]]; then
  echo "No integration test files found under integration_test/"
  exit 1
fi

cleanup_desktop_test_processes() {
  # Desktop integration runs can leave stale processes that block the next debug attach.
  pkill -x fPaint >/dev/null 2>&1 || true
  pkill -f "build/macos/Build/Products/.*/fPaint\.app" >/dev/null 2>&1 || true
  pkill -f "flutter_tester.*fpaint" >/dev/null 2>&1 || true
}

run_integration_file_once() {
  local test_file="$1"
  local log_file="$2"

  flutter test "$test_file" --reporter=compact -d macos 2>&1 | tee "$log_file"
}

is_transient_launch_failure() {
  local log_file="$1"

  grep -E -q \
    "Error waiting for a debug connection|Unable to start the app on the device|The log reader stopped unexpectedly|Failed to foreground app; open returned 1" \
    "$log_file"
}

run_integration_file_with_retry() {
  local test_file="$1"
  local max_attempts=3
  local attempt=1

  while (( attempt <= max_attempts )); do
    local log_file
    log_file="$(mktemp -t fpaint_integration_test.XXXXXX.log)"

    cleanup_desktop_test_processes
    echo "Attempt $attempt/$max_attempts: $test_file"

    if run_integration_file_once "$test_file" "$log_file"; then
      rm -f "$log_file"
      return 0
    fi

    if (( attempt == max_attempts )); then
      echo "Integration test failed after $max_attempts attempts: $test_file"
      echo "Last attempt log: $log_file"
      return 1
    fi

    if is_transient_launch_failure "$log_file"; then
      echo "Detected transient macOS launch/attach failure. Retrying: $test_file"
      rm -f "$log_file"
    else
      echo "Integration test failed with non-transient error: $test_file"
      echo "Failure log: $log_file"
      return 1
    fi

    ((attempt++))
  done
}

for test_file in "${integration_files[@]}"; do
  echo "Running integration test: $test_file"
  run_integration_file_with_retry "$test_file"
done

echo "All unit and integration tests passed."
