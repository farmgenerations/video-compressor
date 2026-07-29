# CleanShot Compressor

[![CI](https://github.com/khevamann/cleanshot-compressor/actions/workflows/ci.yml/badge.svg)](https://github.com/khevamann/cleanshot-compressor/actions/workflows/ci.yml)

Automatically create small, shareable MP4 copies when CleanShot X adds new
recordings to your Downloads folder. Compression runs entirely on your Mac with
ffmpeg; nothing is uploaded.

## Features

- Detects CleanShot recordings from their embedded application metadata.
- Ignores videos created by Loom and other applications.
- Keeps the original recording unchanged.
- Creates `<original name> compressed.mp4` beside the original.
- Encodes H.264 at CRF 27, up to 720p and 30 fps.
- Mixes multiple CleanShot audio tracks to mono AAC at 64 kbps.
- Shows a macOS notification when compression finishes.

## Requirements

- macOS
- CleanShot X
- [Homebrew](https://brew.sh)
- ffmpeg; the installer offers to install it through Homebrew when missing

## Install

1. Download the ZIP from the [latest release](https://github.com/khevamann/cleanshot-compressor/releases/latest).
2. Unzip it.
3. Double-click `install.command`.
4. In Folder Actions Setup, turn on **Enable Folder Actions**.
5. Click **+** below the left list and choose **Downloads**.
6. Click **+** below the right list and choose `Compress CleanShot Videos.scpt`.

If macOS blocks the installer, Control-click `install.command`, choose **Open**,
and confirm **Open**. This is expected for a small, unsigned shell-script
installer downloaded outside the App Store.

New CleanShot recordings added to Downloads will now produce a compressed copy.
Existing recordings are not processed automatically.

## Customize Compression

The installer creates:

```text
~/Library/Application Support/CleanShot Compressor/config.sh
```

Edit that file to change the defaults:

| Setting | Default | Purpose |
| --- | --- | --- |
| `VIDEO_CRF` | `27` | Higher values make smaller, lower-quality files. Try 23–30. |
| `VIDEO_PRESET` | `slow` | Use `medium` for faster encoding and slightly larger files. |
| `MAX_HEIGHT` | `720` | Maximum output height in pixels. |
| `MAX_FPS` | `30` | Maximum output frame rate. |
| `AUDIO_BITRATE` | `64k` | AAC audio bitrate. |
| `NOTIFICATIONS` | `1` | Set to `0` to disable completion notifications. |

Changes apply to the next recording; reinstalling is unnecessary.

## How It Works

macOS Folder Actions calls `Compress CleanShot Videos.scpt` when a new item
appears in Downloads. The AppleScript passes the item to
`compress-new-videos.sh`. The shell script waits for CleanShot to finish writing
the file, verifies the CleanShot metadata, and then runs ffmpeg.

The relevant source files are:

- `compress-new-videos.sh`: detection, stability checks, and ffmpeg settings
- `Compress CleanShot Videos.applescript`: Folder Action entry point
- `config.example`: user-adjustable defaults
- `install.command`: installation and Folder Actions setup
- `uninstall.command`: removal without deleting recordings
- `scripts/build-release.sh`: reproducible release ZIP creation

## Development

Clone the repository:

```bash
git clone https://github.com/khevamann/cleanshot-compressor.git
cd cleanshot-compressor
```

Validate the shell scripts and compile the Folder Action:

```bash
bash -n compress-new-videos.sh install.command uninstall.command scripts/build-release.sh
osacompile -o /tmp/Compress-CleanShot-Videos.scpt "Compress CleanShot Videos.applescript"
```

Build the same ZIP produced by GitHub Actions:

```bash
./scripts/build-release.sh dev
```

The archive will be written to `dist/CleanShot-Compressor-dev.zip`.

### Change the Compressor

- Change runtime defaults in both `compress-new-videos.sh` and `config.example`.
- Change the ffmpeg command in `compress_video`.
- Change CleanShot detection in `is_cleanshot_video`.
- Change file readiness behavior in `wait_until_stable`.
- Run the validation commands and test with a real CleanShot recording.

To test one file without attaching the Folder Action:

```bash
STABLE_SECONDS=0 NOTIFICATIONS=0 \
  ./compress-new-videos.sh --file "$HOME/Downloads/example.mp4"
```

The test file must contain CleanShot's metadata or it will be intentionally
ignored.

## Automated Builds and Releases

The CI workflow validates and builds a ZIP on every push and pull request. The
ZIP is available as a workflow artifact.

To publish a GitHub release, push a version tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The release workflow validates the project, builds the installer ZIP, creates a
GitHub release, attaches the ZIP, and generates release notes automatically.

## Uninstall

Double-click `uninstall.command` and follow its prompt. It preserves existing
videos and `~/Library/Logs/CleanShot Compressor.log`.
