#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# ZFS_CREATE -- Partition disk, create encrypted ZFS pool, datasets, swap zvol, EFI.
# Constraints: ashift=12 (policy), no org.zfsbootmenu:keysource, no keyfile after install.
# Rollback: zpool destroy, re-run from DISK_SAFETY.
# Re-entry probe: lib/probes.sh probe_zfs_create() (bidirectional topology verification)
run_zfs_create() {
  log "=== ZFS_CREATE ==="

  local target_disk pool_name
  target_disk=$(state_get_field "target_disk")
  pool_name=$(state_get_field "pool_name")
  local disk_path="/dev/disk/by-id/${target_disk}"

  source "${INSTALLER_DIR}/lib/topology.sh"
  build_topology "$pool_name"

  local kname
  kname=$(disk_kernel_name "$disk_path")
  local phys_sector
  phys_sector=$(cat "/sys/block/${kname}/queue/physical_block_size" 2>/dev/null || echo "512")
  log "Disk physical sector size: ${phys_sector} bytes"
  if [[ "$phys_sector" -gt 4096 ]]; then
    warn "Physical sector size is ${phys_sector} bytes. ashift=12 (4K) may be suboptimal."
    warn "Proceeding with ashift=12 per policy."
  fi

  log "Partitioning disk: ${disk_path}"
  run_timeout "$SHORT_TIMEOUT" sgdisk -n 1:0:+512M -t 1:EF00 "${disk_path}" \
    || fail "Failed to create EFI partition"
  run_timeout "$SHORT_TIMEOUT" sgdisk -n 2:0:0 -t 2:BF00 "${disk_path}" \
    || fail "Failed to create ZFS partition"
  run_timeout "$SHORT_TIMEOUT" partprobe "${disk_path}" 2>/dev/null || warn "partprobe failed (continuing after short settle)"
  wait_for_partition_node "${disk_path}-part1" "$disk_path"
  wait_for_partition_node "${disk_path}-part2" "$disk_path"
  log "Partitions created: EFI (512M EF00) + ZFS (remaining BF00)"

  local efi_part="${disk_path}-part1"
  run_timeout "$SHORT_TIMEOUT" partprobe "${disk_path}" 2>/dev/null || warn "partprobe failed before formatting"
  wait_for_partition_node "$efi_part" "$disk_path"
  log "Formatting EFI partition..."
  wipefs -a "$efi_part" || warn "wipefs on EFI partition failed"
  mkfs.vfat -F 32 "$efi_part" || warn "Failed to format EFI partition, assuming already formatted"
  log "EFI partition formatted."

  log "Creating encrypted ZFS pool..."
  local keyfile="/tmp/acabos-pool-${pool_name}.key"
  dd if=/dev/urandom of="$keyfile" bs=32 count=1 2>/dev/null
  chmod 600 "$keyfile"

  local zfs_part="${disk_path}-part2"
  wait_for_partition_node "$zfs_part" "$disk_path"
  [[ -e "$zfs_part" ]] || fail "ZFS partition not found: ${zfs_part}"

  run_timeout "$MEDIUM_TIMEOUT" zpool create \
    -f \
    -o ashift=12 \
    -O encryption=aes-256-gcm \
    -O keyformat=raw \
    -O keylocation="file://${keyfile}" \
    -O compression=zstd \
    -O atime=off \
    -O xattr=sa \
    "${pool_name}" "$zfs_part" \
    || fail "Failed to create ZFS pool"
  log "Pool created: ${pool_name}"

  log "Creating datasets per topology..."
  for ds in "${TOPOLOGY_DATASETS[@]}"; do
    [[ "$ds" == "${pool_name}" ]] && continue
    [[ "$ds" == "${pool_name}/swap" ]] && continue

    local ds_props="${TOPOLOGY_PROPS[$ds]:-}"
    local create_args=()
    if [[ -n "$ds_props" ]]; then
      IFS=':' read -ra props <<< "$ds_props"
      for prop_eq in "${props[@]}"; do
        local prop="${prop_eq%%=*}"
        local val="${prop_eq##*=}"
        create_args+=(-o "${prop}=${val}")
      done
    fi

    log "  Creating dataset: ${ds}"
    zfs create -p "${create_args[@]+"${create_args[@]}"}" "$ds" || fail "Failed to create dataset: ${ds}"
  done
  log "All datasets created."

  log "Setting pool bootfs property..."
  run_timeout "$SHORT_TIMEOUT" zpool set bootfs="${pool_name}/ROOT/acabos" "${pool_name}" \
    || fail "Failed to set bootfs property"
  log "bootfs set: ${pool_name}/ROOT/acabos"

  local gpu_runtime_target
  gpu_runtime_target=$(state_get_field "gpu_runtime_target" 2>/dev/null || echo "cpu")
  local zbm_cmdline="ro"
  if [[ "$gpu_runtime_target" == "cuda" ]]; then
    zbm_cmdline="ro nvidia-drm.modeset=1"
  fi

  log "Setting ZFSBootMenu command line property on ROOT dataset..."
  run_timeout "$SHORT_TIMEOUT" zfs set org.zfsbootmenu:commandline="${zbm_cmdline}" "${pool_name}/ROOT" \
    || fail "Failed to set org.zfsbootmenu:commandline on ${pool_name}/ROOT"
  log "org.zfsbootmenu:commandline set on ${pool_name}/ROOT"

  local kcl
  kcl=$(zfs get -H -o value org.zfsbootmenu:commandline "${pool_name}/ROOT" 2>/dev/null || echo "")
  if [[ "$kcl" != "$zbm_cmdline" ]]; then
    log "WARNING: org.zfsbootmenu:commandline not set correctly on ${pool_name}/ROOT (got: ${kcl})"
  else
    log "ZBM commandline property verified on ${pool_name}/ROOT"
  fi

  log "Creating encrypted swap zvol..."
  local swap_size=64
  zfs create -V "${swap_size}G" -b "$(getconf PAGESIZE)" "${pool_name}/swap" \
    || fail "Failed to create swap zvol"
  log "Swap zvol created: ${pool_name}/swap (${swap_size}G)"

  log "Formatting swap zvol..."
  local swap_dev="/dev/zvol/${pool_name}/swap"
  [[ -e "$swap_dev" ]] || fail "Swap zvol device not found: ${swap_dev}"
  mkswap "$swap_dev" || fail "Failed to format swap zvol"
  log "Swap zvol formatted."

  log "Transitioning encryption to passphrase..."
  echo ""
  local passphrase="${ACABOS_ZFS_PASSPHRASE:-}"
  if [[ -z "$passphrase" ]]; then
    if is_interactive; then
      echo "Set ZFS encryption passphrase (you will enter this at every boot):"
      read -r -s -p "Passphrase: " passphrase
      echo ""
    else
      fail "No interactive TTY for passphrase prompt. Set ACABOS_ZFS_PASSPHRASE to continue."
    fi
  else
    log "Using ACABOS_ZFS_PASSPHRASE for ZFS encryption setup."
  fi
  [[ -n "$passphrase" ]] || fail "Passphrase cannot be empty."
  echo "$passphrase" | zfs change-key -o keyformat=passphrase -o keylocation=prompt "${pool_name}" \
    || fail "Failed to set passphrase encryption on ${pool_name}"
  local root_enc_root
  root_enc_root=$(zfs get -H -o value encryptionroot "${pool_name}/ROOT" 2>/dev/null || echo "")
  if [[ "$root_enc_root" == "${pool_name}/ROOT" ]]; then
    run_timeout "$SHORT_TIMEOUT" zfs change-key -i "${pool_name}/ROOT" \
      || fail "Failed to make ${pool_name}/ROOT inherit pool encryption key"
  elif [[ "$root_enc_root" == "${pool_name}" ]]; then
    log "${pool_name}/ROOT already inherits pool encryption key."
  else
    fail "Unexpected encryptionroot for ${pool_name}/ROOT: ${root_enc_root}"
  fi
  passphrase=""
  log "Encryption transitioned to passphrase prompt on ${pool_name}; ${pool_name}/ROOT now inherits pool key."

  log "Destroying temporary keyfile..."
  shred -u "$keyfile" || warn "Failed to shred keyfile ${keyfile}"
  log "Temporary keyfile destroyed."

  # EFI mount moved to BASE_INSTALL

  log "Verifying pool state..."
  zpool list -H "${pool_name}" >/dev/null 2>&1 || fail "Pool ${pool_name} not listed after creation"
  local enc_check
  enc_check=$(zfs get -H -o value encryption "${pool_name}/ROOT/acabos" 2>/dev/null || echo "off")
  [[ "$enc_check" != "off" ]] || fail "Encryption not active on ${pool_name}/ROOT/acabos"
  log "Pool and encryption verified."

  log "ZFS_CREATE complete."
  return 0
}

wait_for_partition_node() {
  local part_path="$1"
  local disk_path="$2"
  local tries=0

  while [[ ! -e "$part_path" ]]; do
    tries=$((tries + 1))
    if (( tries > 30 )); then
      fail "Partition node not found after settle: ${part_path}"
    fi
    run_timeout "$SHORT_TIMEOUT" partprobe "$disk_path" 2>/dev/null || true
    run_timeout "$SHORT_TIMEOUT" udevadm settle 2>/dev/null || true
    sleep 1
  done
}
