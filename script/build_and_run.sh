#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="SwiftUIReference"
APP_NAME="SwiftUIReference"
SCHEME="SwiftUIReference"
BUNDLE_ID="com.transfinite.SwiftUIReference"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/$PROJECT_NAME.xcodeproj"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/$PROJECT_NAME-DerivedData}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT_DIR/.build/screenshots}"
CONFIGURATION="${CONFIGURATION:-Debug}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
CODE_SIGN_STYLE="${CODE_SIGN_STYLE:-Manual}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

MODE="macos"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro Max}"
IPAD_SIMULATOR_NAME="${IPAD_SIMULATOR_NAME:-iPad Pro 13-inch (M5)}"
SIMULATOR_ID="${SIMULATOR_ID:-}"
BUILD_ONLY=0
DEBUG=0
LOGS=0
TELEMETRY=0
TAKE_SCREENSHOT=0
VERIFY=0

usage() {
  cat <<USAGE
usage: ./script/build_and_run.sh [macos|iphone|ipad] [options]

Builds with xcodebuild and launches the requested platform.

Modes:
  macos               Build and launch the macOS app. Default.
  iphone, ios         Build, install, and launch on an iPhone simulator.
  ipad                Build, install, and launch on an iPad simulator.

Options:
  --build-only        Build without launching.
  --configuration X   Build configuration. Default: Debug.
  --simulator NAME    iOS simulator name. Default: iPhone 17 Pro Max.
  --simulator-id ID   iOS simulator UDID. Overrides --simulator.
  --screenshot        Capture an iOS simulator screenshot after launch.
  --verify            Verify the app process/container after launch.
  --logs              Stream process logs after launch.
  --telemetry         Stream logs for subsystem == $BUNDLE_ID after launch.
  --debug             Build, then launch the macOS binary under lldb.
  -h, --help          Show this help.

Environment overrides:
  DERIVED_DATA_PATH, SCREENSHOT_DIR, CONFIGURATION, CODE_SIGN_IDENTITY,
  CODE_SIGN_STYLE, DEVELOPMENT_TEAM, SIMULATOR_NAME, IPAD_SIMULATOR_NAME,
  SIMULATOR_ID
USAGE
}

while (($#)); do
  case "$1" in
    macos|--macos)
      MODE="macos"
      ;;
    iphone|ios|--iphone|--ios)
      MODE="iphone"
      ;;
    ipad|--ipad)
      MODE="ipad"
      ;;
    --build-only)
      BUILD_ONLY=1
      ;;
    --configuration)
      shift
      CONFIGURATION="${1:?missing value for --configuration}"
      ;;
    --simulator)
      shift
      SIMULATOR_NAME="${1:?missing value for --simulator}"
      ;;
    --simulator-id)
      shift
      SIMULATOR_ID="${1:?missing value for --simulator-id}"
      ;;
    --screenshot)
      TAKE_SCREENSHOT=1
      ;;
    --verify)
      VERIFY=1
      ;;
    --logs)
      LOGS=1
      ;;
    --telemetry)
      TELEMETRY=1
      ;;
    --debug)
      DEBUG=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$MODE" == "ipad" && -z "${SIMULATOR_ID}" && "${SIMULATOR_NAME}" == "iPhone 17 Pro Max" ]]; then
  SIMULATOR_NAME="$IPAD_SIMULATOR_NAME"
fi

build_macos() {
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
    CODE_SIGN_STYLE="$CODE_SIGN_STYLE" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    build
}

macos_app_path() {
  printf '%s/Build/Products/%s/%s.app\n' "$DERIVED_DATA_PATH" "$CONFIGURATION" "$APP_NAME"
}

launch_macos() {
  local app_path
  app_path="$(macos_app_path)"

  pkill -x "$APP_NAME" >/dev/null 2>&1 || true

  if ((DEBUG)); then
    lldb -- "$app_path/Contents/MacOS/$APP_NAME"
  else
    /usr/bin/open -n "$app_path"
  fi
}

verify_macos() {
  sleep 1
  pgrep -x "$APP_NAME" >/dev/null
}

simctl_device() {
  if [[ -n "$SIMULATOR_ID" ]]; then
    printf '%s\n' "$SIMULATOR_ID"
  else
    printf '%s\n' "$SIMULATOR_NAME"
  fi
}

ios_destination() {
  if [[ -n "$SIMULATOR_ID" ]]; then
    printf 'platform=iOS Simulator,id=%s\n' "$SIMULATOR_ID"
  else
    printf 'platform=iOS Simulator,name=%s\n' "$SIMULATOR_NAME"
  fi
}

ios_app_path() {
  printf '%s/Build/Products/%s-iphonesimulator/%s.app\n' "$DERIVED_DATA_PATH" "$CONFIGURATION" "$APP_NAME"
}

build_ios() {
  local destination
  destination="$(ios_destination)"

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
    CODE_SIGN_STYLE="$CODE_SIGN_STYLE" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    build
}

launch_ios() {
  local device app_path
  device="$(simctl_device)"
  app_path="$(ios_app_path)"

  xcrun simctl boot "$device" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$device" -b
  /usr/bin/open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl install "$device" "$app_path"
  xcrun simctl launch "$device" "$BUNDLE_ID"
}

verify_ios() {
  local device
  device="$(simctl_device)"
  xcrun simctl get_app_container "$device" "$BUNDLE_ID" app >/dev/null
}

screenshot_ios() {
  local device safe_name screenshot_path
  device="$(simctl_device)"
  safe_name="$(printf '%s' "$device" | tr -cs '[:alnum:]' '-')"
  screenshot_path="$SCREENSHOT_DIR/$APP_NAME-$MODE-$safe_name.png"

  mkdir -p "$SCREENSHOT_DIR"
  xcrun simctl io "$device" screenshot "$screenshot_path"
  echo "Screenshot: $screenshot_path"
}

stream_logs() {
  if [[ "$MODE" == "macos" ]]; then
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
  else
    xcrun simctl spawn "$(simctl_device)" log stream --info --style compact --predicate "process == \"$APP_NAME\""
  fi
}

stream_telemetry() {
  if [[ "$MODE" == "macos" ]]; then
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
  else
    xcrun simctl spawn "$(simctl_device)" log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
  fi
}

case "$MODE" in
  macos)
    build_macos
    if ((BUILD_ONLY)); then
      exit 0
    fi
    launch_macos
    if ((VERIFY)); then
      verify_macos
    fi
    ;;
  iphone|ipad)
    build_ios
    if ((BUILD_ONLY)); then
      exit 0
    fi
    launch_ios
    if ((VERIFY)); then
      verify_ios
    fi
    if ((TAKE_SCREENSHOT)); then
      screenshot_ios
    fi
    ;;
  *)
    echo "Unsupported mode: $MODE" >&2
    exit 2
    ;;
esac

if ((LOGS)); then
  stream_logs
fi

if ((TELEMETRY)); then
  stream_telemetry
fi
