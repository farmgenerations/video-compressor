#!/bin/bash

set -u

APP_DIR="${APP_DIR:-$HOME/Library/Application Support/CleanShot Compressor}"
LOG_FILE="${LOG_FILE:-$HOME/Library/Logs/CleanShot Compressor.log}"
CONFIG_FILE="${CONFIG_FILE:-$APP_DIR/config.sh}"
SETTINGS_FILE="${SETTINGS_FILE:-$APP_DIR/settings.sh}"
WATCH_FOLDER="${WATCH_FOLDER:-}"
STABLE_SECONDS="${STABLE_SECONDS:-12}"
NOTIFICATIONS="${NOTIFICATIONS:-1}"
VIDEO_CRF="${VIDEO_CRF:-27}"
VIDEO_PRESET="${VIDEO_PRESET:-slow}"
MAX_HEIGHT="${MAX_HEIGHT:-720}"
MAX_FPS="${MAX_FPS:-30}"
AUDIO_BITRATE="${AUDIO_BITRATE:-64k}"
OUTPUT_SUFFIX="${OUTPUT_SUFFIX:- compressed}"
OUTPUT_DIRECTORY="${OUTPUT_DIRECTORY:-}"
LOCK_DIR="$APP_DIR/encode.lock"

if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

if [[ -f "$SETTINGS_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$SETTINGS_FILE"
fi

mkdir -p "$APP_DIR" "$(dirname "$LOG_FILE")"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

find_tool() {
    local tool_name="$1"
    local candidate

    candidate="$(command -v "$tool_name" 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    for candidate in "/opt/homebrew/bin/$tool_name" "/usr/local/bin/$tool_name"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

FFMPEG="${FFMPEG:-$(find_tool ffmpeg || true)}"
FFPROBE="${FFPROBE:-$(find_tool ffprobe || true)}"

is_cleanshot_video() {
    local source_file="$1"
    local software_tag

    software_tag="$($FFPROBE -v error \
        -show_entries 'format_tags=com.apple.quicktime.software' \
        -of default=noprint_wrappers=1:nokey=1 \
        "$source_file" 2>/dev/null)"

    [[ "$software_tag" == CleanShot\ X* ]]
}

notify_complete() {
    local output_name="$1"

    [[ "$NOTIFICATIONS" == "0" ]] && return
    /usr/bin/osascript \
        -e 'on run argv' \
        -e 'display notification ((item 1 of argv) & " is ready") with title "CleanShot compression complete"' \
        -e 'end run' \
        "$output_name" >/dev/null 2>&1 || true
}

is_open_for_writing() {
    /usr/sbin/lsof -F a "$1" 2>/dev/null | grep -Eq '^a(w|u)$'
}

wait_until_stable() {
    local source_file="$1"
    local previous_size="-1"
    local current_size
    local modified_at
    local age_seconds
    local stable_checks=0
    local attempt

    for (( attempt = 0; attempt < 9000; attempt++ )); do
        [[ -f "$source_file" ]] || return 1
        current_size="$(stat -f '%z' "$source_file" 2>/dev/null)" || return 1
        modified_at="$(stat -f '%m' "$source_file" 2>/dev/null)" || return 1
        age_seconds=$(( $(date +%s) - modified_at ))

        if [[ "$current_size" == "$previous_size" ]] \
            && (( age_seconds >= STABLE_SECONDS )) \
            && ! is_open_for_writing "$source_file"; then
            stable_checks=$(( stable_checks + 1 ))
        else
            stable_checks=0
        fi

        (( stable_checks >= 2 )) && return 0
        previous_size="$current_size"
        sleep 4
    done

    return 1
}

compress_video() {
    local source_file="$1"
    local source_stem
    local output_directory
    local output_file
    local temporary_file
    local audio_count
    local video_filter="fps=${MAX_FPS},scale=-2:'min(${MAX_HEIGHT}\\,ih)':flags=lanczos"
    local mix_inputs=""
    local mix_filter
    local audio_index
    local -a command

    source_stem="$(basename "${source_file%.*}")"
    output_directory="${OUTPUT_DIRECTORY:-$(dirname "$source_file")}"
    mkdir -p "$output_directory"
    output_file="$output_directory/${source_stem}${OUTPUT_SUFFIX}.mp4"
    temporary_file="$output_directory/${source_stem}.compressing.$$.mp4"

    if [[ -e "$output_file" ]]; then
        log "Skipped because output already exists: $output_file"
        return 0
    fi

    audio_count="$($FFPROBE -v error -select_streams a \
        -show_entries stream=index -of csv=p=0 "$source_file" 2>/dev/null \
        | wc -l | tr -d '[:space:]')"
    audio_count="${audio_count:-0}"

    command=(
        /usr/bin/nice -n 10 "$FFMPEG"
        -hide_banner -loglevel error
        -i "$source_file"
        -map 0:v:0
        -vf "$video_filter"
        -c:v libx264 -preset "$VIDEO_PRESET" -crf "$VIDEO_CRF"
        -pix_fmt yuv420p
    )

    if (( audio_count == 0 )); then
        command+=( -an )
    elif (( audio_count == 1 )); then
        command+=( -map 0:a:0 -c:a aac -b:a "$AUDIO_BITRATE" -ac 1 )
    else
        for (( audio_index = 0; audio_index < audio_count; audio_index++ )); do
            mix_inputs="${mix_inputs}[0:a:${audio_index}]"
        done
        mix_filter="${mix_inputs}amix=inputs=${audio_count}:duration=longest:normalize=0,alimiter=limit=0.95[a]"
        command+=( -filter_complex "$mix_filter" -map '[a]' -c:a aac -b:a "$AUDIO_BITRATE" -ac 1 )
    fi

    command+=( -movflags +faststart -y "$temporary_file" )

    log "Compressing: $source_file"
    if "${command[@]}" >> "$LOG_FILE" 2>&1 \
        && "$FFPROBE" -v error -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 "$temporary_file" >/dev/null 2>&1; then
        mv "$temporary_file" "$output_file"
        log "Created: $output_file ($(du -h "$output_file" | awk '{print $1}'))"
        notify_complete "$(basename "$output_file")"
        return 0
    fi

    rm -f "$temporary_file"
    log "Compression failed: $source_file"
    return 1
}

process_single_file() {
    local source_file="$1"
    local base_name
    local source_directory
    local normalized_watch_folder

    [[ -f "$source_file" ]] || return 0
    base_name="$(basename "$source_file")"

    if [[ -n "$WATCH_FOLDER" ]]; then
        source_directory="$(cd "$(dirname "$source_file")" 2>/dev/null && pwd -P)" || return 0
        normalized_watch_folder="$(cd "$WATCH_FOLDER" 2>/dev/null && pwd -P)" || return 0
        [[ "$source_directory" == "$normalized_watch_folder" ]] || return 0
    fi

    if [[ -n "$OUTPUT_SUFFIX" && "$base_name" == *"${OUTPUT_SUFFIX}.mp4" ]]; then
        return 0
    fi

    case "$base_name" in
        *.compressing.*.mp4) return 0 ;;
        *.mp4|*.MP4|*.mov|*.MOV) ;;
        *) return 0 ;;
    esac

    wait_until_stable "$source_file" || return 1
    is_cleanshot_video "$source_file" || return 0
    compress_video "$source_file"
}

acquire_lock() {
    local attempt
    local lock_age
    local lock_modified_at
    local owner_pid

    for (( attempt = 0; attempt < 9000; attempt++ )); do
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            printf '%s\n' "$$" > "$LOCK_DIR/pid"
            trap 'rm -f "$LOCK_DIR/pid"; rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
            return 0
        fi

        if [[ -f "$LOCK_DIR/pid" ]]; then
            owner_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
            if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
                sleep 4
                continue
            fi

            rm -f "$LOCK_DIR/pid"
            rmdir "$LOCK_DIR" 2>/dev/null || true
            continue
        fi

        lock_modified_at="$(stat -f '%m' "$LOCK_DIR" 2>/dev/null || echo 0)"
        lock_age=$(( $(date +%s) - lock_modified_at ))
        if (( lock_age >= 30 )); then
            rmdir "$LOCK_DIR" 2>/dev/null || true
            continue
        fi

        sleep 4
    done

    return 1
}

if [[ "${1:-}" != "--file" || -z "${2:-}" ]]; then
    printf 'Usage: %s --file /path/to/video\n' "$0" >&2
    exit 2
fi

if [[ -z "$FFMPEG" || -z "$FFPROBE" || ! -x "$FFMPEG" || ! -x "$FFPROBE" ]]; then
    log "ffmpeg or ffprobe is unavailable. Install ffmpeg with Homebrew."
    exit 1
fi

acquire_lock || exit 1
process_single_file "$2"
