#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# VALIDATION -- Run acabos-doctor for comprehensive invariant validation.
# Doctor: doctor/acabos-doctor (22 checks, dependency graph, skip semantics)
run_validation() {
  log "=== VALIDATION ==="

  local target_disk
  target_disk=$(state_get_field "target_disk")
  local target="/mnt/install"
  local bind_src="$INSTALLER_DIR"
  local bind_dst="${target}/run/acabos-installer"
  local efi_part="/dev/disk/by-id/${target_disk}-part1"

  log "Running acabos-doctor inside target chroot..."
  mkdir -p "${target}/boot/efi"
  if ! mountpoint -q "${target}/boot/efi"; then
    run_timeout "$SHORT_TIMEOUT" mount "$efi_part" "${target}/boot/efi" \
      || fail "Failed to mount EFI partition for validation"
  fi
  chroot_mount "$target"
  mkdir -p "$bind_dst"
  run_timeout "$SHORT_TIMEOUT" mountpoint -q "$bind_dst" || run_timeout "$SHORT_TIMEOUT" mount --bind "$bind_src" "$bind_dst" \
    || { chroot_umount "$target"; fail "Failed to bind-mount installer into target chroot"; }

  run_timeout "$MEDIUM_TIMEOUT" chroot "$target" env ACABOS_DOCTOR_PRE_FINALIZE=true /run/acabos-installer/doctor/acabos-doctor \
    || {
      run_timeout "$SHORT_TIMEOUT" umount -R "$bind_dst" 2>/dev/null || true
      chroot_umount "$target"
      fail "acabos-doctor reported failures"
    }

  run_timeout "$SHORT_TIMEOUT" umount -R "$bind_dst" 2>/dev/null || true
  chroot_umount "$target"

  log "VALIDATION complete."
  return 0
}
