#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ANDROID_APP_ID="com.vteam.fpaint"
PREFERRED_ANDROID_TEST_EMULATOR_NAME="fpaint_tablet_api_36"
TEST_DEVICE_PLATFORM_ANDROID="android"
TEST_DEVICE_PLATFORM_MACOS="macos"
FLUTTER_TEST_DEVICE_ID="${FLUTTER_TEST_DEVICE_ID:-}"
FLUTTER_TEST_EMULATOR_NAME="${FLUTTER_TEST_EMULATOR_NAME:-}"
FLUTTER_TEST_DEVICE_PLATFORM=""
AVAILABLE_ANDROID_EMULATORS=""
STARTED_EMULATOR_DEVICE_ID=""
STARTED_EMULATOR_NAME=""
ANDROID_SDK_ROOT_PATH="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ANDROID_AVD_HOME_PATH="$HOME/.android/avd"
ANDROID_AVD_METADATA_FILE_EXTENSION=".ini"
ANDROID_AVD_CONFIG_FILE_NAME="config.ini"
ANDROID_AVDMANAGER_RELATIVE_PATH="cmdline-tools/latest/bin/avdmanager"
ANDROID_TABLET_DEVICE_PROFILE_NAME="pixel_tablet"
ANDROID_TABLET_KEYWORD="tablet"
ANDROID_TEST_SYSTEM_IMAGE_PACKAGE="system-images;android-36;google_apis_playstore;arm64-v8a"
ANDROID_AVD_CONFIG_KEY_PATH="path"
ANDROID_AVD_CONFIG_KEY_DISPLAY_NAME="avd.ini.displayname"
ANDROID_AVD_CONFIG_KEY_DEVICE_NAME="hw.device.name"
ANDROID_AVD_CREATE_PROMPT_RESPONSE="no"
ANDROID_REQUIRED_JAVA_MAJOR_VERSION="17"
JAVA_HOME_CANDIDATE="${JAVA_HOME:-}"
JAVA_HOME_COMMAND_PATH="/usr/libexec/java_home"
JAVA_VERSION_PREFIX_LEGACY="1"
ANDROID_INTEGRATION_TEST_GRADLE_OPTS="-Dorg.gradle.daemon=false"
ARTIFACT_FILE_EXTENSION="jpg"
ORA_ARTIFACT_FILE_EXTENSION="ora"
TEST_ARTIFACT_FILENAME_PREFIX="integration_test_"
ARTIFACT_STAGE_DIR_NAME="integration_test_screenshots"
FINAL_ARTWORK_ARTIFACT_FILENAME="final.$ORA_ARTIFACT_FILE_EXTENSION"
FINAL_RENDERED_ARTIFACT_FILENAME="integration_test_final_rendered.$ARTIFACT_FILE_EXTENSION"
ANDROID_SCREENSHOT_STAGE_DIR="files/$ARTIFACT_STAGE_DIR_NAME"
LOCAL_SCREENSHOT_STAGE_DIR="$ROOT_DIR/$ARTIFACT_STAGE_DIR_NAME"
SCREENSHOT_OUTPUT_DIR="$ROOT_DIR/test"
FINAL_ARTWORK_HOST_PATH="$SCREENSHOT_OUTPUT_DIR/$FINAL_ARTWORK_ARTIFACT_FILENAME"
FINAL_RENDERED_HOST_PATH="$SCREENSHOT_OUTPUT_DIR/$FINAL_RENDERED_ARTIFACT_FILENAME"
ANDROID_BOOT_COMPLETED_PROPERTY_NAME="sys.boot_completed"
ANDROID_BOOT_COMPLETED_PROPERTY_VALUE="1"
EMULATOR_DISCOVERY_RETRY_COUNT="60"
EMULATOR_BOOT_RETRY_COUNT="60"
EMULATOR_SHUTDOWN_RETRY_COUNT="30"
EMULATOR_RETRY_DELAY_SECONDS="2"
ARTIFACT_POLL_INTERVAL_SECONDS="0.2"

echo "== fPaint test runner =="

echo "Checking Flutter installation..."
if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter is not installed or not in PATH"
  exit 1
fi

echo "Checking Android tooling..."
if ! command -v adb >/dev/null 2>&1; then
  echo "Error: adb is not installed or not in PATH"
  exit 1
fi

if [[ -z "$FLUTTER_TEST_DEVICE_ID" ]] && ! command -v emulator >/dev/null 2>&1; then
  echo "Error: Android emulator CLI is not installed or not in PATH"
  exit 1
fi

extract_java_major_version() {
  local java_version="$1"

  awk -v java_version="$java_version" '
    BEGIN {
      split(java_version, version_parts, ".")

      if (version_parts[1] == "1") {
        print version_parts[2]
        exit
      }

      print version_parts[1]
    }
  '
}

read_java_version_from_home() {
  local java_home_path="$1"

  [[ -n "$java_home_path" ]] || return 1
  [[ -x "$java_home_path/bin/java" ]] || return 1

  "$java_home_path/bin/java" -version 2>&1 | awk -F '"' '/version/ { print $2; exit }'
}

java_home_matches_required_version() {
  local java_home_path="$1"
  local java_version=""
  local java_major_version=""

  java_version="$(read_java_version_from_home "$java_home_path")" || return 1
  [[ -n "$java_version" ]] || return 1

  java_major_version="$(extract_java_major_version "$java_version")"
  [[ "$java_major_version" == "$ANDROID_REQUIRED_JAVA_MAJOR_VERSION" ]]
}

resolve_android_java_home() {
  if java_home_matches_required_version "$JAVA_HOME_CANDIDATE"; then
    printf '%s' "$JAVA_HOME_CANDIDATE"
    return 0
  fi

  if [[ -x "$JAVA_HOME_COMMAND_PATH" ]]; then
    "$JAVA_HOME_COMMAND_PATH" -v "$ANDROID_REQUIRED_JAVA_MAJOR_VERSION"
    return 0
  fi

  return 1
}

configure_android_build_java() {
  local resolved_java_home=""

  resolved_java_home="$(resolve_android_java_home)" || {
    echo "Error: Android test builds require Java $ANDROID_REQUIRED_JAVA_MAJOR_VERSION"
    echo "Install a matching JDK and set JAVA_HOME before running tool/test.sh"
    exit 1
  }

  export JAVA_HOME="$resolved_java_home"
  export PATH="$JAVA_HOME/bin:$PATH"
}

refresh_flutter_devices() {
  echo "Checking Flutter device availability..."
  if ! devices_output="$(flutter devices 2>&1)"; then
    echo "Error: unable to list Flutter devices"
    echo "$devices_output"
    exit 1
  fi
}

cleanup_on_exit() {
  local exit_code="$?"

  trap - EXIT
  stop_started_emulator
  exit "$exit_code"
}

trap cleanup_on_exit EXIT

find_device_line_by_id() {
  local target_device_id="$1"

  printf '%s\n' "$devices_output" | awk -F ' • ' -v target_device_id="$target_device_id" '
    {
      device_id = $2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", device_id)
      if (device_id == target_device_id) {
        print
        exit
      }
    }
  '
}

refresh_available_android_emulators() {
  if ! AVAILABLE_ANDROID_EMULATORS="$(emulator -list-avds)"; then
    echo "Error: unable to list Android emulators"
    exit 1
  fi
}

read_android_emulator_metadata_path() {
  local emulator_name="$1"
  local metadata_path="$ANDROID_AVD_HOME_PATH/$emulator_name$ANDROID_AVD_METADATA_FILE_EXTENSION"

  if [[ ! -f "$metadata_path" ]]; then
    return 1
  fi

  printf '%s' "$metadata_path"
}

read_android_emulator_metadata_value() {
  local emulator_name="$1"
  local config_key="$2"
  local metadata_path=""

  metadata_path="$(read_android_emulator_metadata_path "$emulator_name")" || return 1

  awk -F '=' -v config_key="$config_key" '
    {
      key = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)

      if (key == config_key) {
        value = substr($0, index($0, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    }
  ' "$metadata_path"
}

read_android_emulator_config_path() {
  local emulator_name="$1"
  local emulator_avd_path=""

  emulator_avd_path="$(read_android_emulator_metadata_value "$emulator_name" "$ANDROID_AVD_CONFIG_KEY_PATH")" || return 1
  [[ -n "$emulator_avd_path" ]] || return 1

  printf '%s/%s' "$emulator_avd_path" "$ANDROID_AVD_CONFIG_FILE_NAME"
}

read_android_emulator_config_value() {
  local emulator_name="$1"
  local config_key="$2"
  local config_path=""

  config_path="$(read_android_emulator_config_path "$emulator_name")" || return 1
  [[ -f "$config_path" ]] || return 1

  awk -F '=' -v config_key="$config_key" '
    {
      key = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)

      if (key == config_key) {
        value = substr($0, index($0, "=") + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        print value
        exit
      }
    }
  ' "$config_path"
}

android_emulator_value_has_tablet_keyword() {
  local value="$1"

  [[ -n "$value" ]] || return 1
  printf '%s\n' "$value" | grep -iq "$ANDROID_TABLET_KEYWORD"
}

android_emulator_is_tablet() {
  local emulator_name="$1"
  local emulator_display_name=""
  local emulator_device_name=""

  if android_emulator_value_has_tablet_keyword "$emulator_name"; then
    return 0
  fi

  emulator_display_name="$(read_android_emulator_config_value "$emulator_name" "$ANDROID_AVD_CONFIG_KEY_DISPLAY_NAME" 2>/dev/null || true)"
  if android_emulator_value_has_tablet_keyword "$emulator_display_name"; then
    return 0
  fi

  emulator_device_name="$(read_android_emulator_config_value "$emulator_name" "$ANDROID_AVD_CONFIG_KEY_DEVICE_NAME" 2>/dev/null || true)"
  if android_emulator_value_has_tablet_keyword "$emulator_device_name"; then
    return 0
  fi

  return 1
}

resolve_android_sdk_tool_path() {
  local relative_tool_path="$1"
  local tool_path="$ANDROID_SDK_ROOT_PATH/$relative_tool_path"

  if [[ ! -x "$tool_path" ]]; then
    return 1
  fi

  printf '%s' "$tool_path"
}

ensure_preferred_android_tablet_emulator_exists() {
  local avdmanager_path=""

  refresh_available_android_emulators
  if emulator_name_exists "$PREFERRED_ANDROID_TEST_EMULATOR_NAME"; then
    return 0
  fi

  avdmanager_path="$(resolve_android_sdk_tool_path "$ANDROID_AVDMANAGER_RELATIVE_PATH")" || {
    echo "Error: no Android tablet emulator is configured and avdmanager was not found"
    echo "Expected Android SDK root: $ANDROID_SDK_ROOT_PATH"
    exit 1
  }

  echo "Creating Android tablet emulator: $PREFERRED_ANDROID_TEST_EMULATOR_NAME"
  if ! printf '%s\n' "$ANDROID_AVD_CREATE_PROMPT_RESPONSE" | "$avdmanager_path" create avd \
    --force \
    --name "$PREFERRED_ANDROID_TEST_EMULATOR_NAME" \
    --package "$ANDROID_TEST_SYSTEM_IMAGE_PACKAGE" \
    --device "$ANDROID_TABLET_DEVICE_PROFILE_NAME"; then
    echo "Error: failed to create Android tablet emulator '$PREFERRED_ANDROID_TEST_EMULATOR_NAME'"
    echo "Required system image: $ANDROID_TEST_SYSTEM_IMAGE_PACKAGE"
    exit 1
  fi

  refresh_available_android_emulators
  if ! emulator_name_exists "$PREFERRED_ANDROID_TEST_EMULATOR_NAME"; then
    echo "Error: Android tablet emulator '$PREFERRED_ANDROID_TEST_EMULATOR_NAME' was not registered after creation"
    exit 1
  fi
}

infer_device_platform_from_line() {
  local device_line="$1"

  case "$device_line" in
    *android*)
      printf '%s' "$TEST_DEVICE_PLATFORM_ANDROID"
      ;;
    *darwin*)
      printf '%s' "$TEST_DEVICE_PLATFORM_MACOS"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

list_running_android_emulator_device_ids() {
  adb devices | awk '$1 ~ /^emulator-[0-9]+$/ { print $1 }'
}

read_android_emulator_name() {
  local emulator_device_id="$1"

  adb -s "$emulator_device_id" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d '\r' | awk 'NF { print; exit }'
}

list_running_android_emulator_names() {
  local emulator_device_id=""
  local emulator_name=""

  while IFS= read -r emulator_device_id; do
    [[ -n "$emulator_device_id" ]] || continue
    emulator_name="$(read_android_emulator_name "$emulator_device_id")"
    [[ -n "$emulator_name" ]] || continue
    printf '%s\n' "$emulator_name"
  done < <(list_running_android_emulator_device_ids)
}

emulator_name_exists() {
  local emulator_name="$1"

  printf '%s\n' "$AVAILABLE_ANDROID_EMULATORS" | grep -Fxq "$emulator_name"
}

emulator_name_is_stopped() {
  local emulator_name="$1"
  local running_emulator_names="$2"

  ! printf '%s\n' "$running_emulator_names" | grep -Fxq "$emulator_name"
}

select_first_stopped_tablet_emulator_name() {
  local running_emulator_names="$1"
  local emulator_name=""

  while IFS= read -r emulator_name; do
    [[ -n "$emulator_name" ]] || continue

    if android_emulator_is_tablet "$emulator_name" && emulator_name_is_stopped "$emulator_name" "$running_emulator_names"; then
      printf '%s' "$emulator_name"
      return 0
    fi
  done <<< "$AVAILABLE_ANDROID_EMULATORS"

  return 1
}

find_running_test_emulator_device_id() {
  local requested_emulator_name="$1"
  local emulator_device_id=""
  local emulator_name=""
  local device_line=""

  if ! devices_output="$(flutter devices 2>&1)"; then
    echo "Error: unable to list Flutter devices" >&2
    echo "$devices_output" >&2
    return 1
  fi

  while IFS= read -r emulator_device_id; do
    [[ -n "$emulator_device_id" ]] || continue

    emulator_name="$(read_android_emulator_name "$emulator_device_id")"
    [[ -n "$emulator_name" ]] || continue

    if [[ -n "$requested_emulator_name" ]] && [[ "$emulator_name" != "$requested_emulator_name" ]]; then
      continue
    fi

    if ! android_emulator_is_tablet "$emulator_name"; then
      continue
    fi

    device_line="$(find_device_line_by_id "$emulator_device_id")"
    [[ -n "$device_line" ]] || continue

    printf '%s' "$emulator_device_id"
    return 0
  done < <(list_running_android_emulator_device_ids)

  return 1
}

select_test_emulator_name() {
  local requested_emulator_name="$FLUTTER_TEST_EMULATOR_NAME"
  local running_emulator_names=""
  local emulator_name=""

  refresh_available_android_emulators
  running_emulator_names="$(list_running_android_emulator_names)"

  if [[ -n "$requested_emulator_name" ]]; then
    if ! emulator_name_exists "$requested_emulator_name"; then
      echo "Error: requested Android emulator '$requested_emulator_name' is not configured" >&2
      echo "Available emulators:" >&2
      printf '%s\n' "$AVAILABLE_ANDROID_EMULATORS" >&2
      return 1
    fi

    if ! android_emulator_is_tablet "$requested_emulator_name"; then
      echo "Error: requested Android emulator '$requested_emulator_name' is not a tablet AVD" >&2
      return 1
    fi

    if printf '%s\n' "$running_emulator_names" | grep -Fxq "$requested_emulator_name"; then
      echo "Error: requested Android emulator '$requested_emulator_name' is already running but not available to Flutter" >&2
      echo "Set FLUTTER_TEST_DEVICE_ID explicitly or restart the emulator." >&2
      return 1
    fi

    printf '%s' "$requested_emulator_name"
    return
  fi

  if emulator_name_exists "$PREFERRED_ANDROID_TEST_EMULATOR_NAME" &&
    android_emulator_is_tablet "$PREFERRED_ANDROID_TEST_EMULATOR_NAME" &&
    emulator_name_is_stopped "$PREFERRED_ANDROID_TEST_EMULATOR_NAME" "$running_emulator_names"; then
    printf '%s' "$PREFERRED_ANDROID_TEST_EMULATOR_NAME"
    return
  fi

  if emulator_name="$(select_first_stopped_tablet_emulator_name "$running_emulator_names")"; then
    printf '%s' "$emulator_name"
    return
  fi

  ensure_preferred_android_tablet_emulator_exists
  running_emulator_names="$(list_running_android_emulator_names)"
  if emulator_name_is_stopped "$PREFERRED_ANDROID_TEST_EMULATOR_NAME" "$running_emulator_names"; then
    printf '%s' "$PREFERRED_ANDROID_TEST_EMULATOR_NAME"
    return
  fi

  if emulator_name="$(select_first_stopped_tablet_emulator_name "$running_emulator_names")"; then
    printf '%s' "$emulator_name"
    return
  fi

  echo "Error: no Android tablet emulator is available for testing" >&2
  echo "Available emulators:" >&2
  printf '%s\n' "$AVAILABLE_ANDROID_EMULATORS" >&2
  return 1
}

find_running_emulator_device_id_by_name() {
  local target_emulator_name="$1"
  local current_emulator_device_id=""
  local current_emulator_name=""
  local attempt_index="0"

  for ((attempt_index = 1; attempt_index <= EMULATOR_DISCOVERY_RETRY_COUNT; attempt_index++)); do
    while IFS= read -r current_emulator_device_id; do
      [[ -n "$current_emulator_device_id" ]] || continue

      current_emulator_name="$(read_android_emulator_name "$current_emulator_device_id")"

      if [[ "$current_emulator_name" == "$target_emulator_name" ]]; then
        printf '%s' "$current_emulator_device_id"
        return 0
      fi
    done < <(list_running_android_emulator_device_ids)

    sleep "$EMULATOR_RETRY_DELAY_SECONDS"
  done

  return 1
}

wait_for_android_emulator_boot() {
  local emulator_device_id="$1"
  local boot_completed=""
  local attempt_index="0"

  adb -s "$emulator_device_id" wait-for-device >/dev/null

  for ((attempt_index = 1; attempt_index <= EMULATOR_BOOT_RETRY_COUNT; attempt_index++)); do
    boot_completed="$(adb -s "$emulator_device_id" shell getprop "$ANDROID_BOOT_COMPLETED_PROPERTY_NAME" 2>/dev/null | tr -d '\r')"

    if [[ "$boot_completed" == "$ANDROID_BOOT_COMPLETED_PROPERTY_VALUE" ]]; then
      return 0
    fi

    sleep "$EMULATOR_RETRY_DELAY_SECONDS"
  done

  return 1
}

wait_for_android_emulator_shutdown() {
  local emulator_device_id="$1"
  local attempt_index="0"

  for ((attempt_index = 1; attempt_index <= EMULATOR_SHUTDOWN_RETRY_COUNT; attempt_index++)); do
    if ! adb devices | awk '{ print $1 }' | grep -Fxq "$emulator_device_id"; then
      return 0
    fi

    sleep "$EMULATOR_RETRY_DELAY_SECONDS"
  done

  return 1
}

launch_test_emulator() {
  local emulator_name="$1"

  echo "Launching Android emulator: $emulator_name"
  if ! flutter emulators --launch "$emulator_name" --cold; then
    echo "Error: failed to launch Android emulator '$emulator_name'"
    exit 1
  fi

  STARTED_EMULATOR_NAME="$emulator_name"
  if ! STARTED_EMULATOR_DEVICE_ID="$(find_running_emulator_device_id_by_name "$emulator_name")"; then
    echo "Error: timed out waiting for Android emulator '$emulator_name' to appear"
    exit 1
  fi

  echo "Waiting for Android emulator boot: $STARTED_EMULATOR_DEVICE_ID"
  if ! wait_for_android_emulator_boot "$STARTED_EMULATOR_DEVICE_ID"; then
    echo "Error: Android emulator '$emulator_name' did not finish booting"
    exit 1
  fi

  refresh_flutter_devices
  if [[ -z "$(find_device_line_by_id "$STARTED_EMULATOR_DEVICE_ID")" ]]; then
    echo "Error: launched Android emulator '$emulator_name' is not visible to Flutter"
    echo "$devices_output"
    exit 1
  fi

  FLUTTER_TEST_DEVICE_ID="$STARTED_EMULATOR_DEVICE_ID"
  FLUTTER_TEST_DEVICE_PLATFORM="$TEST_DEVICE_PLATFORM_ANDROID"
}

stop_started_emulator() {
  if [[ -z "$STARTED_EMULATOR_DEVICE_ID" ]]; then
    return
  fi

  echo "Stopping Android emulator: $STARTED_EMULATOR_NAME ($STARTED_EMULATOR_DEVICE_ID)"
  adb -s "$STARTED_EMULATOR_DEVICE_ID" emu kill >/dev/null 2>&1 || true
  wait_for_android_emulator_shutdown "$STARTED_EMULATOR_DEVICE_ID" || true
}

select_test_device() {
  local requested_device_id="$FLUTTER_TEST_DEVICE_ID"
  local resolved_device_id=""
  local resolved_device_line=""
  local resolved_device_platform=""
  local running_emulator_device_id=""
  local running_emulator_name=""
  local selected_emulator_name=""

  if [[ -n "$requested_device_id" ]]; then
    refresh_flutter_devices
    resolved_device_line="$(find_device_line_by_id "$requested_device_id")"
    if [[ -z "$resolved_device_line" ]]; then
      echo "Error: target Flutter device '$requested_device_id' is not available"
      echo "Available devices:"
      echo "$devices_output"
      exit 1
    fi
    resolved_device_id="$requested_device_id"
  else
    if running_emulator_device_id="$(find_running_test_emulator_device_id "$FLUTTER_TEST_EMULATOR_NAME")"; then
      running_emulator_name="$(read_android_emulator_name "$running_emulator_device_id")"
      echo "Reusing running Android emulator: $running_emulator_name ($running_emulator_device_id)"
      resolved_device_id="$running_emulator_device_id"
      resolved_device_platform="$TEST_DEVICE_PLATFORM_ANDROID"
    else
      if ! selected_emulator_name="$(select_test_emulator_name)"; then
        exit 1
      fi
      launch_test_emulator "$selected_emulator_name"
      resolved_device_id="$FLUTTER_TEST_DEVICE_ID"
      resolved_device_platform="$FLUTTER_TEST_DEVICE_PLATFORM"
    fi
  fi

  if [[ -n "$resolved_device_line" ]]; then
    resolved_device_platform="$(infer_device_platform_from_line "$resolved_device_line")"
    if [[ -z "$resolved_device_platform" ]]; then
      echo "Error: tool/test.sh supports Android emulators by default; set FLUTTER_TEST_DEVICE_ID to override explicitly"
      echo "Selected device: $resolved_device_id"
      echo "Available devices:"
      echo "$devices_output"
      exit 1
    fi
  fi

  FLUTTER_TEST_DEVICE_ID="$resolved_device_id"
  FLUTTER_TEST_DEVICE_PLATFORM="$resolved_device_platform"
}

select_test_device

if [[ "$FLUTTER_TEST_DEVICE_PLATFORM" == "$TEST_DEVICE_PLATFORM_ANDROID" ]]; then
  configure_android_build_java
fi

echo "Selected Flutter test device: $FLUTTER_TEST_DEVICE_ID ($FLUTTER_TEST_DEVICE_PLATFORM)"

echo "Running unit tests..."
flutter test --reporter=compact

echo "Running integration tests on $FLUTTER_TEST_DEVICE_PLATFORM device $FLUTTER_TEST_DEVICE_ID..."
integration_files=()
while IFS= read -r f; do
  integration_files+=("$f")
done < <(find integration_test -maxdepth 1 -type f -name "*_test.dart" | sort)

if [[ ${#integration_files[@]} -eq 0 ]]; then
  echo "No integration test files found under integration_test/"
  exit 1
fi

cleanup_test_processes() {
  if [[ "$FLUTTER_TEST_DEVICE_PLATFORM" == "$TEST_DEVICE_PLATFORM_ANDROID" ]]; then
    adb -s "$FLUTTER_TEST_DEVICE_ID" shell am force-stop "$ANDROID_APP_ID" >/dev/null 2>&1 || true
  fi
}

clear_android_internal_screenshot_dir() {
  adb -s "$FLUTTER_TEST_DEVICE_ID" shell run-as "$ANDROID_APP_ID" sh -c \
    "mkdir -p '$ANDROID_SCREENSHOT_STAGE_DIR' && rm -f '$ANDROID_SCREENSHOT_STAGE_DIR'/*.${ARTIFACT_FILE_EXTENSION} '$ANDROID_SCREENSHOT_STAGE_DIR'/*.${ORA_ARTIFACT_FILE_EXTENSION}" \
    >/dev/null 2>&1 || true
}

collect_android_internal_screenshots() {
  collect_android_internal_screenshot_file "$FINAL_ARTWORK_ARTIFACT_FILENAME"
  collect_android_internal_screenshot_file "$FINAL_RENDERED_ARTIFACT_FILENAME"
}

jpeg_file_is_valid() {
  local file_path="$1"
  local jpeg_header=""

  [[ -s "$file_path" ]] || return 1

  jpeg_header="$(xxd -p -l 2 "$file_path" 2>/dev/null | tr -d '\n')"
  [[ "$jpeg_header" == "ffd8" ]]
}

ora_file_is_valid() {
  local file_path="$1"

  [[ -s "$file_path" ]] || return 1
  unzip -tq "$file_path" >/dev/null 2>&1
}

artifact_file_is_valid() {
  local artifact_filename="$1"
  local file_path="$2"

  case "$artifact_filename" in
    *.$ARTIFACT_FILE_EXTENSION)
      jpeg_file_is_valid "$file_path"
      ;;
    *.$ORA_ARTIFACT_FILE_EXTENSION)
      ora_file_is_valid "$file_path"
      ;;
    *)
      return 1
      ;;
  esac
}

try_collect_android_internal_screenshot_file() {
  local artifact_filename="$1"
  local artifact_source_path="$2"
  local target_file="$SCREENSHOT_OUTPUT_DIR/$artifact_filename"
  local temp_file=""

  temp_file="$(mktemp "$ROOT_DIR/.artifact_pull.XXXXXX")"

  if adb -s "$FLUTTER_TEST_DEVICE_ID" exec-out run-as "$ANDROID_APP_ID" cat \
    "$artifact_source_path" > "$temp_file" 2>/dev/null && artifact_file_is_valid "$artifact_filename" "$temp_file"; then
    mv "$temp_file" "$target_file"
    return 0
  fi

  rm -f "$temp_file"
  return 1
}

collect_android_internal_screenshot_file() {
  local artifact_filename="$1"
  local relative_source_path="$ANDROID_SCREENSHOT_STAGE_DIR/$artifact_filename"
  local absolute_source_path="/data/user/0/$ANDROID_APP_ID/files/$ARTIFACT_STAGE_DIR_NAME/$artifact_filename"

  if try_collect_android_internal_screenshot_file "$artifact_filename" "$relative_source_path"; then
    return
  fi

  try_collect_android_internal_screenshot_file "$artifact_filename" "$absolute_source_path" || true
}

run_android_integration_file_with_artifact_collection() {
  local test_file="$1"
  local log_file="$2"
  local integration_test_gradle_opts=""
  local flutter_test_pid=""
  local flutter_test_exit_code="0"

  integration_test_gradle_opts="$ANDROID_INTEGRATION_TEST_GRADLE_OPTS"
  if [[ -n "${GRADLE_OPTS:-}" ]]; then
    integration_test_gradle_opts="$integration_test_gradle_opts $GRADLE_OPTS"
  fi

  (
    env GRADLE_OPTS="$integration_test_gradle_opts" \
      flutter test "$test_file" --reporter=compact -d "$FLUTTER_TEST_DEVICE_ID" 2>&1 | tee "$log_file"
  ) &
  flutter_test_pid="$!"

  while kill -0 "$flutter_test_pid" >/dev/null 2>&1; do
    collect_android_internal_screenshots
    sleep "$ARTIFACT_POLL_INTERVAL_SECONDS"
  done

  set +e
  wait "$flutter_test_pid"
  flutter_test_exit_code="$?"
  set -e

  collect_android_internal_screenshots
  return "$flutter_test_exit_code"
}

prepare_integration_screenshot_dirs() {
  mkdir -p "$SCREENSHOT_OUTPUT_DIR"
  rm -f "$SCREENSHOT_OUTPUT_DIR"/${TEST_ARTIFACT_FILENAME_PREFIX}*.${ARTIFACT_FILE_EXTENSION} >/dev/null 2>&1 || true
  rm -f "$SCREENSHOT_OUTPUT_DIR"/final.${ORA_ARTIFACT_FILE_EXTENSION} >/dev/null 2>&1 || true

  if [[ "$FLUTTER_TEST_DEVICE_PLATFORM" == "$TEST_DEVICE_PLATFORM_ANDROID" ]]; then
    clear_android_internal_screenshot_dir
    return
  fi

  rm -rf "$LOCAL_SCREENSHOT_STAGE_DIR"
  mkdir -p "$LOCAL_SCREENSHOT_STAGE_DIR"
}

collect_integration_screenshots() {
  mkdir -p "$SCREENSHOT_OUTPUT_DIR"

  if [[ "$FLUTTER_TEST_DEVICE_PLATFORM" == "$TEST_DEVICE_PLATFORM_ANDROID" ]]; then
    collect_android_internal_screenshots
    return
  fi

  if compgen -G "$LOCAL_SCREENSHOT_STAGE_DIR/*.${ARTIFACT_FILE_EXTENSION}" >/dev/null; then
    cp "$LOCAL_SCREENSHOT_STAGE_DIR"/*.${ARTIFACT_FILE_EXTENSION} "$SCREENSHOT_OUTPUT_DIR"/
  fi

  if compgen -G "$LOCAL_SCREENSHOT_STAGE_DIR"/*.${ORA_ARTIFACT_FILE_EXTENSION} >/dev/null; then
    cp "$LOCAL_SCREENSHOT_STAGE_DIR"/*.${ORA_ARTIFACT_FILE_EXTENSION} "$SCREENSHOT_OUTPUT_DIR"/
  fi
}

run_integration_file_once() {
  local test_file="$1"
  local log_file="$2"

  if [[ "$FLUTTER_TEST_DEVICE_PLATFORM" == "$TEST_DEVICE_PLATFORM_ANDROID" ]]; then
    run_android_integration_file_with_artifact_collection "$test_file" "$log_file"
    return
  fi

  flutter test "$test_file" --reporter=compact -d "$FLUTTER_TEST_DEVICE_ID" 2>&1 | tee "$log_file"
}

prepare_integration_screenshot_dirs

for test_file in "${integration_files[@]}"; do
  echo "Running integration test: $test_file"
  log_file="$(mktemp -t fpaint_integration_test.XXXXXX.log)"
  cleanup_test_processes
  if run_integration_file_once "$test_file" "$log_file"; then
    collect_integration_screenshots
    rm -f "$log_file"
  else
    collect_integration_screenshots
    echo "Integration test failed: $test_file"
    echo "Failure log: $log_file"
    exit 1
  fi
done

echo "Integration JPG artifacts mirrored to: $SCREENSHOT_OUTPUT_DIR"
if [[ -f "$FINAL_ARTWORK_HOST_PATH" ]]; then
  echo "Final ORA artifact: $FINAL_ARTWORK_HOST_PATH"
fi
if [[ -f "$FINAL_RENDERED_HOST_PATH" ]]; then
  echo "Final rendered JPG artifact: $FINAL_RENDERED_HOST_PATH"
fi
echo "All unit and integration tests passed."
