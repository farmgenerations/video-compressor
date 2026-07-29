#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_HOME="${TARGET_HOME:-$HOME}"
APP_DIR="$TARGET_HOME/Library/Application Support/CleanShot Compressor"
ACTION_DIR="$TARGET_HOME/Library/Scripts/Folder Action Scripts"
COMPRESSOR="$APP_DIR/compress-new-videos.sh"
ACTION_SCRIPT="$ACTION_DIR/Compress CleanShot Videos.scpt"
SETTINGS_FILE="$APP_DIR/settings.sh"
OPEN_SETUP="${OPEN_SETUP:-1}"

if [[ "${WATCH_FOLDER+set}" == "set" ]]; then
    SELECTED_WATCH_FOLDER="$WATCH_FOLDER"
else
    SELECTED_WATCH_FOLDER=""
fi

pause() {
    if [[ -t 0 ]]; then
        printf '\nPress Return to close this window.'
        read -r _
    fi
}

fail() {
    printf '\nInstallation failed: %s\n' "$1" >&2
    pause
    exit 1
}

if [[ "$(uname -s)" != "Darwin" ]]; then
    fail "This installer requires macOS."
fi

if ! command -v ffmpeg >/dev/null 2>&1 \
    && [[ ! -x /opt/homebrew/bin/ffmpeg ]] \
    && [[ ! -x /usr/local/bin/ffmpeg ]]; then
    if command -v brew >/dev/null 2>&1; then
        printf 'ffmpeg is required. Install it now with Homebrew? [Y/n] '
        read -r answer
        case "$answer" in
            n|N|no|NO) fail "Install ffmpeg with: brew install ffmpeg" ;;
            *) brew install ffmpeg ;;
        esac
    else
        fail "Install Homebrew from https://brew.sh, then run: brew install ffmpeg"
    fi
fi

if [[ -z "$SELECTED_WATCH_FOLDER" ]]; then
    if [[ "$TARGET_HOME" == "$HOME" && -t 0 ]]; then
        SELECTED_WATCH_FOLDER="$(/usr/bin/osascript \
            -e 'POSIX path of (choose folder with prompt "Choose the folder CleanShot Compressor should watch" default location (path to downloads folder))')" \
            || fail "No watch folder was selected."
    else
        SELECTED_WATCH_FOLDER="$TARGET_HOME/Downloads"
        mkdir -p "$SELECTED_WATCH_FOLDER"
    fi
fi

SELECTED_WATCH_FOLDER="${SELECTED_WATCH_FOLDER%/}"
[[ -d "$SELECTED_WATCH_FOLDER" ]] || fail "Watch folder does not exist: $SELECTED_WATCH_FOLDER"

mkdir -p "$APP_DIR" "$ACTION_DIR"
cp "$SCRIPT_DIR/compress-new-videos.sh" "$COMPRESSOR"
chmod 755 "$COMPRESSOR"
/usr/bin/osacompile -o "$ACTION_SCRIPT" "$SCRIPT_DIR/Compress CleanShot Videos.applescript"

{
    printf '# Managed by install.command. Rerun the installer to change this value.\n'
    printf 'WATCH_FOLDER=%q\n' "$SELECTED_WATCH_FOLDER"
} > "$SETTINGS_FILE"

if [[ ! -f "$APP_DIR/config.sh" ]]; then
    cp "$SCRIPT_DIR/config.example" "$APP_DIR/config.sh"
fi

if [[ "$TARGET_HOME" == "$HOME" ]]; then
    /usr/bin/defaults write com.apple.FolderActionsDispatcher folderActionsEnabled -bool true
fi

printf '\nInstalled CleanShot Compressor.\n\n'
printf 'Watch folder: %s\n\n' "$SELECTED_WATCH_FOLDER"
printf 'Finish setup in Folder Actions Setup:\n'
printf '  1. Confirm Enable Folder Actions is on.\n'
printf '  2. Click + under the left list and choose:\n'
printf '     %s\n' "$SELECTED_WATCH_FOLDER"
printf '  3. Click + under the right list and choose Compress CleanShot Videos.scpt.\n\n'
printf 'If changing folders, remove the script from the previously watched folder.\n\n'

if [[ "$TARGET_HOME" == "$HOME" && "$OPEN_SETUP" == "1" \
    && -d "/System/Library/CoreServices/Applications/Folder Actions Setup.app" ]]; then
    open "$SELECTED_WATCH_FOLDER"
    open -a "Folder Actions Setup"
fi

printf 'Original videos remain untouched. Output naming is controlled by config.sh.\n'
pause
