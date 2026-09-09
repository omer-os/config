#!/usr/bin/env bash
# lidcam — capture a webcam photo and send it to Telegram.
# Triggered on resume from suspend (lid open). See README in this dir.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${LIDCAM_CONFIG:-$DIR/config}"

if [[ ! -f "$CONFIG" ]]; then
    echo "lidcam: config not found at $CONFIG" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$CONFIG"

: "${BOT_TOKEN:?set BOT_TOKEN in config}"
: "${CHAT_ID:?set CHAT_ID in config}"
DEVICE="${DEVICE:-/dev/video0}"
WARMUP="${WARMUP:-12}"          # frames to discard so the sensor auto-exposes
LOG="${LOG:-$DIR/lidcam.log}"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# Wait for the camera device to be ready after resume.
for _ in $(seq 1 10); do
    [[ -e "$DEVICE" ]] && break
    sleep 1
done

IMG="$(mktemp /tmp/lidcam.XXXXXX.jpg)"
trap 'rm -f "$IMG"' EXIT

# Capture one frame, discarding WARMUP frames first for a properly exposed shot.
if ! ffmpeg -hide_banner -loglevel error \
    -f v4l2 -i "$DEVICE" \
    -vf "select=gte(n\,$WARMUP)" -frames:v 1 -q:v 3 -y "$IMG" 2>>"$LOG"; then
    log "capture FAILED from $DEVICE"
    exit 1
fi

HOST="$(hostname)"
WHEN="$(date '+%F %T %Z')"
IP="$(curl -s --max-time 5 https://api.ipify.org || echo 'unknown')"
CAPTION="📷 ${HOST} — ${WHEN}"$'\n'"IP: ${IP}"

if curl -s --max-time 30 \
    -F "chat_id=${CHAT_ID}" \
    -F "photo=@${IMG}" \
    -F "caption=${CAPTION}" \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto" > /dev/null; then
    log "sent OK ($WHEN, IP $IP)"
else
    log "telegram send FAILED ($WHEN)"
    exit 1
fi
