#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_HOME="${TARGET_HOME:-$HOME}"
APP_DIR="$TARGET_HOME/Library/Application Support/CleanShot Compressor"
ACTION_DIR="$TARGET_HOME/Library/Scripts/Folder Action Scripts"
COMPRESSOR="$APP_DIR/compress-new-videos.sh"
ACTION_SCRIPT="$ACTION_DIR/Compress CleanShot Videos.scpt"

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

mkdir -p "$APP_DIR" "$ACTION_DIR"
cp "$SCRIPT_DIR/compress-new-videos.sh" "$COMPRESSOR"
chmod 755 "$COMPRESSOR"
/usr/bin/osacompile -o "$ACTION_SCRIPT" "$SCRIPT_DIR/Compress CleanShot Videos.applescript"

if [[ ! -f "$APP_DIR/config.sh" ]]; then
    cp "$SCRIPT_DIR/config.example" "$APP_DIR/config.sh"
fi

printf '\nInstalled CleanShot Compressor.\n\n'
printf 'Finish setup in Folder Actions Setup:\n'
printf '  1. Turn on Enable Folder Actions.\n'
printf '  2. Click + under the left list and choose Downloads.\n'
printf '  3. Click + under the right list and choose Compress CleanShot Videos.scpt.\n\n'

if [[ "$TARGET_HOME" == "$HOME" && -d "/System/Library/CoreServices/Applications/Folder Actions Setup.app" ]]; then
    open -a "Folder Actions Setup"
fi

printf 'Original videos remain untouched. Compressed copies end in " compressed.mp4".\n'
pause
