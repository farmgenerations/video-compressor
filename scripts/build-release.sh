#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-dev}"
PACKAGE_NAME="CleanShot-Compressor"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/$PACKAGE_NAME"
ARCHIVE_PATH="$DIST_DIR/$PACKAGE_NAME-$VERSION.zip"

case "$VERSION" in
    *[!A-Za-z0-9._-]*)
        printf 'Invalid version: %s\n' "$VERSION" >&2
        exit 1
        ;;
esac

rm -rf "$STAGE_DIR"
rm -f "$ARCHIVE_PATH"
mkdir -p "$STAGE_DIR"
mkdir -p "$STAGE_DIR/docs"

for file in \
    "Compress CleanShot Videos.applescript" \
    README.md \
    compress-new-videos.sh \
    config.example \
    install.command \
    uninstall.command; do
    cp "$ROOT_DIR/$file" "$STAGE_DIR/$file"
done

cp "$ROOT_DIR/docs/macos-security-open-anyway.png" "$STAGE_DIR/docs/"

chmod 755 \
    "$STAGE_DIR/compress-new-videos.sh" \
    "$STAGE_DIR/install.command" \
    "$STAGE_DIR/uninstall.command"

(
    cd "$DIST_DIR"
    /usr/bin/zip -r -X "$(basename "$ARCHIVE_PATH")" "$PACKAGE_NAME" >/dev/null
)

rm -rf "$STAGE_DIR"
printf '%s\n' "$ARCHIVE_PATH"
