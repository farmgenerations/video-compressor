#!/bin/bash

set -euo pipefail

TARGET_HOME="${TARGET_HOME:-$HOME}"
APP_DIR="$TARGET_HOME/Library/Application Support/CleanShot Compressor"
ACTION_SCRIPT="$TARGET_HOME/Library/Scripts/Folder Action Scripts/Compress CleanShot Videos.scpt"

pause() {
    if [[ -t 0 ]]; then
        printf '\nPress Return to continue.'
        read -r _
    fi
}

printf 'CleanShot Compressor uninstaller\n\n'

if [[ "$TARGET_HOME" == "$HOME" ]]; then
    printf 'Folder Actions Setup will open. Remove Compress CleanShot Videos\n'
    printf 'from every folder where it is attached, then return here.\n'
    open -a "Folder Actions Setup"
    pause
fi

rm -f "$ACTION_SCRIPT"
rm -f "$APP_DIR/compress-new-videos.sh" "$APP_DIR/config.sh" "$APP_DIR/settings.sh"
rmdir "$APP_DIR/encode.lock" 2>/dev/null || true
rmdir "$APP_DIR" 2>/dev/null || true

printf '\nUninstalled. Existing videos and the log file were preserved.\n'
pause
