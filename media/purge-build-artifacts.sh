#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGETS=(
  "$ROOT_DIR/state"
  "$ROOT_DIR/media/out"
  "$ROOT_DIR/media/work"
  "$ROOT_DIR/media/tmp"
  "$ROOT_DIR/media/live-build/.build"
  "$ROOT_DIR/media/live-build/binary"
  "$ROOT_DIR/media/live-build/cache"
  "$ROOT_DIR/media/live-build/chroot"
  "$ROOT_DIR/media/live-build/config/hooks/normal"
  "$ROOT_DIR/media/live-build/config/includes.chroot/opt/installer"
)
GLOBS=(
  "$ROOT_DIR/media"/*.iso
  "$ROOT_DIR/media"/*.img
  "$ROOT_DIR/media"/*.qcow2
  "$ROOT_DIR/media/live-build"/binary.*
  "$ROOT_DIR/media/live-build"/chroot.*
  "$ROOT_DIR/media/live-build"/live-image-*.iso
  "$ROOT_DIR/media/live-build"/live-image-*.hybrid.iso
  "$ROOT_DIR/media/live-build"/live-image-*.packages
  "$ROOT_DIR/media/live-build"/live-image-*.files
  "$ROOT_DIR/media/live-build/config/package-lists/live.list.chroot"
  "$ROOT_DIR/media/live-build/config/binary"
  "$ROOT_DIR/media/live-build/config/bootstrap"
  "$ROOT_DIR/media/live-build/config/chroot"
  "$ROOT_DIR/media/live-build/config/common"
  "$ROOT_DIR/media/live-build/config/source"
  "$ROOT_DIR/media/live-build/config/hooks/live/0010-disable-kexec-tools.hook.chroot"
  "$ROOT_DIR/media/live-build/config/hooks/live/0050-disable-sysvinit-tmpfs.hook.chroot"
)

execute=false
if [[ "${1:-}" == "--execute" ]]; then
  execute=true
fi

printf 'ACABOS artifact purge (%s mode)\n' "$([[ "$execute" == true ]] && echo execute || echo dry-run)"

for path in "${TARGETS[@]}"; do
  if [[ -e "$path" ]]; then
    printf 'target: %s\n' "$path"
    if [[ "$execute" == true ]]; then
      rm -rf "$path"
    fi
  fi
done

shopt -s nullglob
for pattern in "${GLOBS[@]}"; do
  for path in $pattern; do
    printf 'target: %s\n' "$path"
    if [[ "$execute" == true ]]; then
      rm -f "$path"
    fi
  done
done
shopt -u nullglob

if [[ "$execute" == true ]]; then
  mkdir -p "$ROOT_DIR/media/out" "$ROOT_DIR/media/work" "$ROOT_DIR/media/tmp"
  printf 'Purge complete. Recreated media working directories.\n'
else
  printf 'Dry-run complete. Re-run with --execute to remove listed artifacts.\n'
fi
