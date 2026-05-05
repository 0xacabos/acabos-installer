#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# BOOT_CHAIN -- Configure ZFSBootMenu and generate bundled EFI artifact.
# Re-entry probe: lib/probes.sh probe_boot_chain()
run_boot_chain() {
  log "=== BOOT_CHAIN ==="

  local pool_name
  pool_name=$(state_get_field "pool_name")
  local target_disk
  target_disk=$(state_get_field "target_disk")
  local gpu_runtime_target
  gpu_runtime_target=$(state_get_field "gpu_runtime_target" 2>/dev/null || echo "cpu")
  local target="/mnt/install"
  local zbm_profile="${ACABOS_ZBM_PROFILE:-default}"
  local zbm_config_source
  local zfs_import_mode
  local zbm_include_zpool_cache

  case "$zbm_profile" in
    default)
      zbm_config_source="${INSTALLER_DIR}/config/zfsbootmenu-config.yaml"
      zfs_import_mode="${ACABOS_ZFS_IMPORT_MODE:-cache}"
      zbm_include_zpool_cache="${ACABOS_ZBM_INCLUDE_ZPOOL_CACHE:-true}"
      ;;
    bringup)
      zbm_config_source="${INSTALLER_DIR}/config/zfsbootmenu-config.bringup.yaml"
      zfs_import_mode="${ACABOS_ZFS_IMPORT_MODE:-scan}"
      zbm_include_zpool_cache="${ACABOS_ZBM_INCLUDE_ZPOOL_CACHE:-false}"
      ;;
    *)
      fail "Unknown ACABOS_ZBM_PROFILE: ${zbm_profile} (expected: default|bringup)"
      ;;
  esac

  case "$zfs_import_mode" in
    cache|scan)
      ;;
    *)
      fail "Invalid ACABOS_ZFS_IMPORT_MODE: ${zfs_import_mode} (expected: cache|scan)"
      ;;
  esac

  case "$zbm_include_zpool_cache" in
    true|false)
      ;;
    *)
      fail "Invalid ACABOS_ZBM_INCLUDE_ZPOOL_CACHE: ${zbm_include_zpool_cache} (expected: true|false)"
      ;;
  esac

  log "ZBM profile: ${zbm_profile}"
  log "ZFS import mode: ${zfs_import_mode}"
  log "Include zpool.cache in ZBM initramfs: ${zbm_include_zpool_cache}"

  log "Mounting ROOT dataset for post-bootstrap stages..."
  run_timeout "$SHORT_TIMEOUT" zfs set mountpoint="${target}" "${pool_name}/ROOT/acabos" \
    || fail "Failed to set mountpoint for ${pool_name}/ROOT/acabos"
  run_timeout "$SHORT_TIMEOUT" zfs mount "${pool_name}/ROOT/acabos" 2>/dev/null || true
  mountpoint -q "$target" || fail "Target mountpoint ${target} is not mounted"

  log "Installing ZFSBootMenu from source..."
  local zbm_version="v3.1.0"
  chroot_mount "$target"
  run_timeout "$MEDIUM_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get update \
    || { chroot_umount "$target"; fail "apt-get update failed in target"; }
  run_timeout "$MEDIUM_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get install -y perl kexec-tools libsort-versions-perl libyaml-pp-perl libboolean-perl systemd-boot-efi \
    || { chroot_umount "$target"; fail "Failed to install ZFSBootMenu dependencies"; }
  run_timeout "$MEDIUM_TIMEOUT" chroot "$target" bash -c "curl -fsSL https://github.com/zbm-dev/zfsbootmenu/archive/refs/tags/${zbm_version}.tar.gz | tar xz -C /tmp && cd /tmp/zfsbootmenu-* && make install" \
    || { chroot_umount "$target"; fail "ZFSBootMenu installation failed"; }
  run_timeout "$SHORT_TIMEOUT" chroot "$target" rm -rf /tmp/zfsbootmenu-* || true
  chroot_umount "$target"
  log "ZFSBootMenu ${zbm_version} installed."

  log "Installing dracut configuration..."
  cp "${INSTALLER_DIR}/config/dracut.conf.d/zfs.conf" "${target}/etc/dracut.conf.d/zfs.conf" \
    || fail "Failed to install dracut config"
  log "dracut config installed."

  log "Installing ZFSBootMenu generate-zbm configuration..."
  mkdir -p "${target}/etc/zfsbootmenu"
  cp "${zbm_config_source}" "${target}/etc/zfsbootmenu/config.yaml" \
    || fail "Failed to install ZFSBootMenu config"
  log "ZFSBootMenu config installed."

  log "Installing /etc/default/zfs..."
  mkdir -p "${target}/etc/zfs"
  if [[ "${zbm_include_zpool_cache}" == "true" ]]; then
    log "  Populating zpool.cache from live pool ${pool_name}..."
    zpool set cachefile="${target}/etc/zfs/zpool.cache" "${pool_name}" \
      || warn "Failed to populate zpool.cache for ${pool_name}"
  else
    rm -f "${target}/etc/zfs/zpool.cache"
  fi
  cat > "${target}/etc/default/zfs" << ZFS_DEFAULT
ZFS_IMPORT='${zfs_import_mode}'
ZFS_MOUNT='yes'
ZFS_SHARE='yes'
ZFS_VERBOSE='no'
ZFS_DEFAULT
  log "/etc/default/zfs installed."

  log "Installing ZFSBootMenu dracut conf.d..."
  mkdir -p "${target}/etc/zfsbootmenu/dracut.conf.d"
  cat > "${target}/etc/zfsbootmenu/dracut.conf.d/10-acabos.conf" << 'ZBM_DRACUT'
add_dracutmodules+=" zfs zfsbootmenu "
omit_dracutmodules+=" nvidia "
install_items+=" /etc/default/zfs "
ZBM_DRACUT
  if [[ "${zbm_include_zpool_cache}" == "true" ]]; then
    cat >> "${target}/etc/zfsbootmenu/dracut.conf.d/10-acabos.conf" << 'ZBM_CACHE'
install_items+=" /etc/zfs/zpool.cache "
ZBM_CACHE
  fi
  log "ZFSBootMenu dracut conf.d installed."

  if [[ "$gpu_runtime_target" == "cuda" ]]; then
    log "Installing NVIDIA modprobe configurations..."
    cp "${INSTALLER_DIR}/config/nvidia-modprobe/nvidia.conf" "${target}/etc/modprobe.d/nvidia.conf"
    cp "${INSTALLER_DIR}/config/nvidia-modprobe/nvidia-drm.conf" "${target}/etc/modprobe.d/nvidia-drm.conf"
    cp "${INSTALLER_DIR}/config/nvidia-modprobe/nvidia-uvm.conf" "${target}/etc/modprobe.d/nvidia-uvm.conf"
    log "  NVIDIA modprobe configs installed."

    log "Installing NVIDIA udev rules..."
    cp "${INSTALLER_DIR}/config/nvidia-udev/70-nvidia.rules" "${target}/etc/udev/rules.d/70-nvidia.rules"
    log "  NVIDIA udev rules installed."
  else
    log "Skipping NVIDIA modprobe and udev policy installation for runtime target: ${gpu_runtime_target}."
  fi

  log "Installing sysctl tuning..."
  cp "${INSTALLER_DIR}/config/sysctl/99-performance.conf" "${target}/etc/sysctl.d/99-performance.conf"
  log "  Sysctl tuning installed."

  log "Installing ZFS module tuning..."
  cp "${INSTALLER_DIR}/config/zfs-tuning.conf" "${target}/etc/modprobe.d/zfs.conf"
  log "  ZFS module tuning installed."

  local efi_part="/dev/disk/by-id/${target_disk}-part1"
  mkdir -p "${target}/boot/efi"
  if ! mountpoint -q "${target}/boot/efi"; then
    run_timeout "$SHORT_TIMEOUT" mount "$efi_part" "${target}/boot/efi" \
      || fail "Failed to mount EFI partition at ${target}/boot/efi"
  fi

  local generation_efi_src
  generation_efi_src=$(findmnt -n -o SOURCE "${target}/boot/efi" 2>/dev/null || echo "")
  [[ -n "$generation_efi_src" ]] || fail "Unable to resolve EFI source before image generation"

  log "Generating ZFSBootMenu artifacts with generate-zbm..."
  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" bash -lc 'command -v generate-zbm >/dev/null 2>&1' \
    || { chroot_umount "$target"; fail "generate-zbm not found in target"; }
  run_timeout "$LONG_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 generate-zbm \
    || { chroot_umount "$target"; fail "generate-zbm failed"; }
  chroot_umount "$target"
  if ! mountpoint -q "${target}/boot/efi"; then
    run_timeout "$SHORT_TIMEOUT" mount "$efi_part" "${target}/boot/efi" \
      || fail "Failed to remount EFI partition after generate-zbm"
  fi

  if [[ "$zbm_profile" == "bringup" ]]; then
    log "Bringup assertion: verifying bundled EFI contains rd.break=pre-mount..."
    local cmdline_dump embedded_cmdline
    cmdline_dump=$(mktemp "${STATE_DIR}/zbm-cmdline.XXXXXX")
    run_timeout "$SHORT_TIMEOUT" objcopy --dump-section ".cmdline=${cmdline_dump}" "${target}/boot/efi/EFI/zbm/zfsbootmenu.EFI" \
      || { rm -f "$cmdline_dump"; fail "Bringup assertion failed: unable to dump .cmdline section from /EFI/zbm/zfsbootmenu.EFI"; }
    embedded_cmdline=$(tr -d '\0' < "$cmdline_dump" 2>/dev/null || true)
    rm -f "$cmdline_dump"
    grep -q 'rd.break=pre-mount' <<< "$embedded_cmdline" \
      || fail "Bringup assertion failed: .cmdline section in /EFI/zbm/zfsbootmenu.EFI does not contain rd.break=pre-mount"
  fi

  log "Pruning non-authoritative backup artifacts from /EFI/zbm..."
  rm -f "${target}/boot/efi/EFI/zbm/zfsbootmenu-backup.EFI" \
        "${target}/boot/efi/EFI/zbm/zfsbootmenu-bootmenu-backup" \
        "${target}/boot/efi/EFI/zbm/initramfs-bootmenu-backup.img" || true
  log "ZFSBootMenu artifacts generated."

  log "Validating EFI partition and generated boot artifacts..."
  validate_efi_partition

  log "Installing compatibility fallback artifact (non-authoritative)..."
  mkdir -p "${target}/boot/efi/EFI/BOOT"
  if cp "${target}/boot/efi/EFI/zbm/zfsbootmenu.EFI" "${target}/boot/efi/EFI/BOOT/BOOTX64.EFI"; then
    warn "Compatibility-only fallback copied to /EFI/BOOT/BOOTX64.EFI; authoritative loader remains /EFI/zbm/zfsbootmenu.EFI"
  else
    warn "Failed to install compatibility-only fallback at /EFI/BOOT/BOOTX64.EFI"
  fi

  if [[ "$zbm_profile" == "bringup" ]]; then
    log "Bringup assertion: verifying fallback BOOTX64.EFI matches authoritative bundle..."
    local bundle_sha fallback_sha
    bundle_sha=$(sha256sum "${target}/boot/efi/EFI/zbm/zfsbootmenu.EFI" 2>/dev/null | awk '{print $1}')
    fallback_sha=$(sha256sum "${target}/boot/efi/EFI/BOOT/BOOTX64.EFI" 2>/dev/null | awk '{print $1}')
    [[ -n "$bundle_sha" && -n "$fallback_sha" && "$bundle_sha" == "$fallback_sha" ]] \
      || fail "Bringup assertion failed: /EFI/BOOT/BOOTX64.EFI hash does not match /EFI/zbm/zfsbootmenu.EFI"
  fi

  if command -v efibootmgr >/dev/null 2>&1; then
    if [[ -d /sys/firmware/efi/efivars ]]; then
      log "Registering authoritative EFI boot entry..."
      if register_efi_boot_entry; then
        verify_efi_boot_entry || warn "EFI boot entry verification failed"
      else
        warn "EFI boot entry registration failed; firmware may require manual boot entry setup"
      fi
    else
      warn "UEFI runtime variables are unavailable; skipping EFI boot entry registration"
    fi
  else
    warn "efibootmgr not available in live environment; skipping EFI boot entry registration"
  fi

  local registration_efi_src
  registration_efi_src=$(findmnt -n -o SOURCE "${target}/boot/efi" 2>/dev/null || echo "")
  if [[ -n "$registration_efi_src" && "$registration_efi_src" != "$generation_efi_src" ]]; then
    warn "EFI source changed between generation (${generation_efi_src}) and registration (${registration_efi_src})"
  fi

  log "Running pool import test..."
  local pool_exported
  pool_exported=$(zpool list -H -o name 2>/dev/null | grep -c "^${pool_name}$" || echo "0")
  if [[ "$pool_exported" -gt 0 ]]; then
    run_timeout "$SHORT_TIMEOUT" zpool export "$pool_name" || warn "Failed to export pool for import test"
    chroot_mount "$target"
    run_timeout "$SHORT_TIMEOUT" chroot "$target" zpool import -N -o readonly=on "$pool_name" \
      || { chroot_umount "$target"; warn "Pool import test failed (non-fatal for altroot installs)"; }
    run_timeout "$SHORT_TIMEOUT" zpool import "$pool_name" -R /mnt/install 2>/dev/null \
      || warn "Failed to restore writable pool import after import test"
    chroot_umount "$target"
  fi

  log "BOOT_CHAIN complete."
  return 0
}

register_efi_boot_entry() {
  local efi_mount="/mnt/install/boot/efi"
  local efi_src
  efi_src=$(findmnt -n -o SOURCE "$efi_mount" 2>/dev/null || echo "")
  [[ -n "$efi_src" ]] || return 1

  local efi_dev
  efi_dev=$(readlink -f "$efi_src" 2>/dev/null || echo "")
  [[ -n "$efi_dev" && -b "$efi_dev" ]] || return 1

  local efi_disk
  efi_disk=$(lsblk -no PKNAME "$efi_dev" 2>/dev/null | head -1 || echo "")
  [[ -n "$efi_disk" ]] || return 1

  local efi_partnum
  efi_partnum=$(lsblk -no PARTNUM "$efi_dev" 2>/dev/null | head -1 || echo "")
  [[ -n "$efi_partnum" ]] || return 1

  local efi_loader="${efi_mount}/EFI/zbm/zfsbootmenu.EFI"
  [[ -r "$efi_loader" && -s "$efi_loader" ]] || return 1

  local loader_rel='\EFI\zbm\zfsbootmenu.EFI'
  run_timeout "$SHORT_TIMEOUT" efibootmgr -c -d "/dev/${efi_disk}" -p "$efi_partnum" \
    -L "ACABOS ZFSBootMenu" -l "$loader_rel" >/dev/null 2>&1 || return 1
  return 0
}

verify_efi_boot_entry() {
  local entry
  entry=$(efibootmgr -v 2>/dev/null | grep -F "ACABOS ZFSBootMenu" | head -1 || true)
  [[ -n "$entry" ]] || return 1

  local entry_lc
  entry_lc=$(printf '%s' "$entry" | tr '[:upper:]' '[:lower:]')
  [[ "$entry_lc" == *"\\efi\\zbm\\zfsbootmenu.efi"* ]] || {
    warn "EFI entry does not reference expected loader path: ${entry}"
    return 1
  }
  log "EFI boot entry verified: ${entry}"
  return 0
}

validate_efi_partition() {
  local efi_mount="/mnt/install/boot/efi"
  local efi_device
  efi_device=$(findmnt -n -o SOURCE "$efi_mount" 2>/dev/null || echo "")
  [[ -n "$efi_device" ]] || fail "EFI partition not mounted"

  run_timeout "$SHORT_TIMEOUT" dosfsck -n "$efi_device" 2>&1 || warn "dosfsck reported issues (may be benign)"

  local bundle="${efi_mount}/EFI/zbm/zfsbootmenu.EFI"
  [[ -r "$bundle" && -s "$bundle" ]] || fail "Bundled EFI artifact missing/empty: ${bundle}"

  local bundle_type
  bundle_type=$(file -b "$bundle" 2>/dev/null || echo "")
  if [[ ! "$bundle_type" =~ PE32|EFI ]]; then
    fail "Bundled EFI artifact is not recognized as PE/COFF EFI executable: ${bundle_type}"
  fi

  local total_size=0
  local f
  for f in "${efi_mount}/EFI/zbm/"*; do
    [[ -f "$f" ]] || continue
    case "$(basename "$f")" in
      *backup*)
        continue
        ;;
    esac
    local sz
    sz=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
    total_size=$((total_size + sz))
  done
  local margin=$(( total_size / 10 ))
  local required=$(( total_size + margin ))
  local free_bytes
  free_bytes=$(df -B1 -P "$efi_mount" 2>/dev/null | awk 'NR==2{print $4}')
  if [[ -n "$free_bytes" && "$free_bytes" -lt "$required" ]]; then
    fail "EFI partition insufficient free space: ${free_bytes} bytes free, ${required} bytes required"
  fi

  local component_initramfs
  component_initramfs=$(ls -1 "${efi_mount}/EFI/zbm/initramfs"* 2>/dev/null | head -1 || true)
  if [[ -n "$component_initramfs" ]]; then
    local initramfs_listing
    initramfs_listing=$(run_timeout "$SHORT_TIMEOUT" lsinitrd "$component_initramfs" 2>/dev/null) \
      || fail "Unable to inspect component initramfs: ${component_initramfs}"
    grep -qE '(^|[[:space:]])init$' <<< "$initramfs_listing" \
      || fail "Component initramfs missing /init: ${component_initramfs}"
    grep -q zfs <<< "$initramfs_listing" \
      || fail "Component initramfs missing ZFS content: ${component_initramfs}"
  else
    warn "No component initramfs found under /EFI/zbm; relying on bundled EFI artifact"
  fi

  if [[ -s "${efi_mount}/EFI/BOOT/BOOTX64.EFI" ]]; then
    local fallback_type
    fallback_type=$(file -b "${efi_mount}/EFI/BOOT/BOOTX64.EFI" 2>/dev/null || echo "")
    if [[ ! "$fallback_type" =~ PE32|EFI ]]; then
      warn "Compatibility fallback exists but is not recognized as EFI executable: ${fallback_type}"
    fi
  else
    warn "Compatibility fallback missing at /EFI/BOOT/BOOTX64.EFI"
  fi

  log "EFI partition validated: authoritative bundle present, executable format verified, space OK."
}
