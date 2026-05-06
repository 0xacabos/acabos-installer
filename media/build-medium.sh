#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEDIA_DIR="$ROOT_DIR/media"
LB_DIR="$MEDIA_DIR/live-build"
OUT_DIR="$MEDIA_DIR/out"
WORK_DIR="$MEDIA_DIR/work"
TMP_DIR="$MEDIA_DIR/tmp"
PAYLOAD_DIR="$LB_DIR/config/includes.chroot/opt/installer"
ARCHIVES_DIR="$LB_DIR/config/archives"
LOG_FILE="$WORK_DIR/build.log"
ISO_BASENAME="acabos-installer-amd64.iso"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

stage_payload() {
  rm -rf "$PAYLOAD_DIR"
  mkdir -p "$PAYLOAD_DIR"
  rsync -a --delete \
    --exclude '.git' \
    --exclude 'state' \
    --exclude 'media/out' \
    --exclude 'media/work' \
    --exclude 'media/tmp' \
    --exclude 'media/live-build/config/includes.chroot/opt/installer' \
    "$ROOT_DIR"/ "$PAYLOAD_DIR"/
}

stage_archives() {
  mkdir -p "$ARCHIVES_DIR"
  install -m 0644 /usr/share/keyrings/cuda-archive-keyring.gpg "$ARCHIVES_DIR/cuda-archive.key"
  install -m 0644 /usr/share/keyrings/nvidia-container-toolkit.gpg "$ARCHIVES_DIR/nvidia-container-toolkit.key"
}

main() {
  require sudo
  require lb
  require rsync
  require tee
  require install
  mkdir -p "$OUT_DIR" "$WORK_DIR" "$TMP_DIR"

  stage_payload
  stage_archives

  pushd "$LB_DIR" >/dev/null
  sudo lb clean --purge 2>&1 | tee "$LOG_FILE"
  sudo rm -f config/binary config/bootstrap config/chroot config/common config/source config/package-lists/live.list.chroot
  sudo ./auto/config 2>&1 | tee -a "$LOG_FILE"
  sudo ./auto/build 2>&1 | tee -a "$LOG_FILE"
  popd >/dev/null

  local built_iso
  built_iso="$(find "$LB_DIR" -maxdepth 1 -type f -name '*.iso' | head -1 || true)"
  [[ -n "$built_iso" ]] || { echo 'No ISO artifact produced by live-build.' >&2; exit 1; }
  cp "$built_iso" "$OUT_DIR/$ISO_BASENAME"
  echo "ISO ready: $OUT_DIR/$ISO_BASENAME"
}

main "$@"
