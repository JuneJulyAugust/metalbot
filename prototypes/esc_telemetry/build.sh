#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PROJECT_NAME="ESCScanner"
SCHEME="$PROJECT_NAME"
CONFIG="${CONFIG:-Debug}"
DERIVED_DATA="$SCRIPT_DIR/.derivedData"
BUILD_DIR="$SCRIPT_DIR/Build"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/$PROJECT_NAME"
SESSION_LABEL="${SESSION_LABEL:-}"

usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
  generate    Generate the Xcode project from project.yml
  build       Build the app and copy it to Build/$PROJECT_NAME.app
  open        Open the copied app bundle in Finder
  launch      Build, copy, and open the app bundle
  clean       Remove copied app and derived data

Options:
  --release   Use the Release configuration
  --session-label <label>  Tag the run and write a separate log file
EOF
    exit 1
}

ensure_project() {
    if [[ ! -d "$PROJECT_NAME.xcodeproj" ]]; then
        xcodegen generate
    fi
}

build_app() {
    ensure_project

    xcodebuild \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration "$CONFIG" \
        -derivedDataPath "$DERIVED_DATA" \
        build

    local built_app="$DERIVED_DATA/Build/Products/$CONFIG/$PROJECT_NAME.app"
    if [[ ! -d "$built_app" ]]; then
        echo "Built app not found: $built_app"
        exit 1
    fi

    mkdir -p "$BUILD_DIR"
    rm -rf "$APP_PATH"
    ditto "$built_app" "$APP_PATH"
    ensure_bluetooth_usage_description "$APP_PATH/Contents/Info.plist"
    echo "Copied app to $APP_PATH"
}

ensure_bluetooth_usage_description() {
    local plist_path="$1"
    local usage_text="We need Bluetooth to connect to the ESC telemetry."

    if /usr/libexec/PlistBuddy -c "Set :NSBluetoothAlwaysUsageDescription $usage_text" "$plist_path" >/dev/null 2>&1; then
        return
    fi

    /usr/libexec/PlistBuddy -c "Add :NSBluetoothAlwaysUsageDescription string $usage_text" "$plist_path"
}

open_app() {
    if [[ ! -d "$APP_PATH" ]]; then
        echo "Missing app bundle: $APP_PATH"
        exit 1
    fi

    open "$APP_PATH"
}

launch_app() {
    if [[ ! -d "$APP_PATH" ]]; then
        echo "Missing app bundle: $APP_PATH"
        exit 1
    fi

    if [[ -n "$SESSION_LABEL" ]]; then
        open "$APP_PATH" --args --session-label "$SESSION_LABEL"
    else
        open "$APP_PATH"
    fi

    echo "Launched $PROJECT_NAME"
}

clean() {
    rm -rf "$APP_PATH" "$DERIVED_DATA"
}

COMMAND="${COMMAND:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --release)
            CONFIG="Release"
            shift
            ;;
        --session-label)
            if [[ $# -lt 2 ]]; then
                echo "Missing value for --session-label"
                exit 1
            fi
            SESSION_LABEL="$2"
            shift 2
            ;;
        generate|build|open|launch|clean)
            COMMAND="$1"
            shift
            ;;
        --)
            shift
            break
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    COMMAND="build"
fi

case "$COMMAND" in
    generate)
        xcodegen generate
        ;;
    build)
        build_app
        ;;
    open)
        open_app
        ;;
    launch)
        build_app
        launch_app
        ;;
    clean)
        clean
        ;;
    *)
        usage
        ;;
esac
