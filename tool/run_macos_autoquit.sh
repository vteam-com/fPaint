#!/usr/bin/env bash
set -euo pipefail

echo "--- macOS RELEASE (auto-quit runner)"

log_file="$(mktemp -t fpaint_macos_release_run.XXXXXX.log)"
runner_pid=""
tail_pid=""
app_pid=""

cleanup() {
  if [[ -n "$tail_pid" ]] && kill -0 "$tail_pid" 2>/dev/null; then
    kill "$tail_pid" 2>/dev/null || true
  fi

  if [[ -f "$log_file" ]]; then
    rm -f "$log_file"
  fi
}

trap cleanup EXIT

flutter run --release -d macos >"$log_file" 2>&1 &
runner_pid="$!"

tail -n +1 -f "$log_file" &
tail_pid="$!"

while kill -0 "$runner_pid" 2>/dev/null; do
  if [[ -z "$app_pid" ]]; then
    app_pid="$(grep -Eo 'fPaint\[[0-9]+:' "$log_file" | sed -E 's/[^0-9]//g' | tail -n 1 || true)"
  else
    if ! ps -p "$app_pid" >/dev/null 2>&1; then
      echo
      echo "Detected fPaint exit (pid $app_pid). Stopping Flutter runner..."
      kill -INT "$runner_pid" 2>/dev/null || true
      break
    fi
  fi

  sleep 1
done

wait "$runner_pid" || true
