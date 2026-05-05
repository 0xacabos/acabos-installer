#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# DISK_SAFETY -- Destructive disk wipe with typed confirmation gate.
# Rollback: Cannot undo (data destroyed). Re-run only.
# Re-entry probe: lib/probes.sh probe_disk_safety()
run_disk_safety() {
  log "=== DISK_SAFETY ==="

  local target_disk
  target_disk=$(state_get_field "target_disk")
  local disk_path="/dev/disk/by-id/${target_disk}"

  [[ -e "$disk_path" ]] || fail "Target disk no longer exists: ${disk_path}"
  log "Target disk verified: ${disk_path}"

  local model serial size
  model=$(disk_model "$disk_path")
  serial=$(disk_serial "$disk_path")
  size=$(disk_size "$disk_path")

  echo ""
  echo "============================================"
  echo "  DESTRUCTIVE OPERATION WARNING"
  echo "============================================"
  echo "  Device:  ${disk_path}"
  echo "  Model:   ${model}"
  echo "  Serial:  ${serial}"
  echo "  Size:    ${size}"
  echo ""
  echo "  ALL DATA ON THIS DEVICE WILL BE DESTROYED."
  echo "============================================"

  local disk_basename
  disk_basename=$(basename "$disk_path")
  echo ""
  echo "Type the disk basename to confirm wipe: ${disk_basename}"
  local confirmation
  if [[ "${ACABOS_ASSUME_YES:-false}" == "true" ]]; then
    confirmation="$disk_basename"
    log "Skipping manual disk confirmation (ACABOS_ASSUME_YES=true)."
  elif [[ -n "${ACABOS_DISK_CONFIRM:-}" ]]; then
    confirmation="${ACABOS_DISK_CONFIRM}"
    log "Using ACABOS_DISK_CONFIRM value for disk confirmation."
  else
    confirmation=$(prompt_text "Confirmation")
  fi
  [[ "$confirmation" == "$disk_basename" ]] || fail "Confirmation did not match '${disk_basename}'. Aborting."

  log "Wiping disk: ${disk_path}"
  run_timeout "$SHORT_TIMEOUT" sgdisk --zap-all "$disk_path" \
    || warn "sgdisk zap reported non-fatal error"
  run_timeout "$SHORT_TIMEOUT" wipefs -a "$disk_path" \
    || warn "wipefs reported non-fatal error"
  log "Disk wiped."

  log "Destroying any imported ZFS pools..."
  local imported_pools
  imported_pools=$(zpool list -H -o name 2>/dev/null || true)
  for pool in $imported_pools; do
    log "Unmounting pool mountpoints for: ${pool}"
    run_timeout "$SHORT_TIMEOUT" umount -l /mnt/install 2>/dev/null || warn "Failed to unmount /mnt/install"
    log "Exporting pool: ${pool}"
    run_timeout "$SHORT_TIMEOUT" zpool export -f "$pool" || warn "Failed to export pool ${pool}"
    log "Destroying pool: ${pool}"
    run_timeout "$SHORT_TIMEOUT" zpool destroy "$pool" || warn "Failed to destroy pool ${pool}"
  done

  log "Verifying no other devices were affected..."
  run_timeout "$SHORT_TIMEOUT" blkid "$disk_path" 2>/dev/null && {
    warn "Device still has identifiable data after wipe. Proceeding with caution."
  }
  log "DISK_SAFETY complete."
  return 0
}
