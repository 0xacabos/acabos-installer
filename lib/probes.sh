#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# probes.sh -- re-entry probes for stage resume logic.
#
# Each probe verifies on-disk reality for its stage. Called by acabos-install
# during resume to determine if a stage can be safely skipped.
#
# probe_stage(stage) dispatches to the correct probe function.
# Probes return 0 on success (stage can be skipped), non-zero on failure.
#
# ZFS_CREATE probe is bidirectional: checks both missing expected datasets
# AND unexpected extra datasets, plus property drift. Error types:
#   dataset_missing:, dataset_unexpected:, property_drift:, encryption:

probe_preflight() {
  local binaries=(zpool zfs mmdebstrap dracut hexdump curl sgdisk wipefs lsinitrd jq dosfsck sha256sum timeout stat gum fzf apt-cache modinfo modprobe lsmod dkms)
  for bin in "${binaries[@]}"; do
    command -v "$bin" >/dev/null 2>&1 || return 1
  done

  local disk_count
  disk_count=$(ls /dev/disk/by-id/* 2>/dev/null | grep -v -- -part | wc -l)
  [[ "$disk_count" -gt 0 ]] || return 1

  if [[ -f "${STATE_DIR}/nvidia-archive-keyring.gpg" ]]; then
    local expected actual
    expected=$(cat "${INSTALLER_DIR}/config/nvidia-keyring.sha256" | awk '{print $1}')
    actual=$(sha256sum "${STATE_DIR}/nvidia-archive-keyring.gpg" | awk '{print $1}')
    [[ "$expected" == "$actual" ]] || return 1
  fi

  if [[ -f "${STATE_DIR}/nvidia-container-toolkit.gpg" ]]; then
    [[ -s "${STATE_DIR}/nvidia-container-toolkit.gpg" ]] || return 1
  fi

  local apt_policy
  apt_policy=$(apt-cache policy 2>/dev/null || true)
  [[ "$apt_policy" == *"trixie-backports"* ]] || return 1

  local running_kernel
  running_kernel=$(uname -r)
  dpkg-query -W -f='${Status}' "linux-headers-${running_kernel}" 2>/dev/null | grep -q "install ok installed" || return 1

  local cohort_pkgs=(linux-image-amd64 linux-headers-amd64 zfsutils-linux zfs-dkms zfs-dracut)
  local pkg
  for pkg in "${cohort_pkgs[@]}"; do
    preflight_pkg_from_backports "$pkg" || return 1
  done

  dpkg-query -W -f='${Status}' dracut 2>/dev/null | grep -q "install ok installed" || return 1

  [[ -r /sys/module/zfs/version ]] || return 1
  local zfs_kmod_version zfs_user_version
  zfs_kmod_version=$(cat /sys/module/zfs/version 2>/dev/null || true)
  zfs_user_version=$(zfs version 2>/dev/null | awk '/^zfs-/ {sub(/^zfs-/, "", $1); print $1; exit}')
  [[ -n "$zfs_kmod_version" && -n "$zfs_user_version" && "$zfs_kmod_version" == "$zfs_user_version" ]] || return 1

  return 0
}

preflight_pkg_from_backports() {
  local pkg="$1"
  local policy
  policy=$(apt-cache policy "$pkg" 2>/dev/null || true)
  [[ "$policy" == *"Installed: (none)"* ]] && return 1
  awk '
    /^[[:space:]]*\*\*\*/ {capture=1; next}
    capture && /trixie-backports/ {found=1; exit}
    capture && /^[[:space:]]*[0-9]+[[:space:]]+(http|\/var\/lib\/dpkg\/status)/ {next}
    capture && /^[^[:space:]]/ {capture=0}
    END {exit found ? 0 : 1}
  ' <<< "$policy"
}

probe_input() {
  local state
  state="$(state_read)" || return 1
  local pool_name target_disk hostname install_id username
  pool_name=$(echo "$state" | jq -r '.pool_name // ""')
  target_disk=$(echo "$state" | jq -r '.target_disk // ""')
  hostname=$(echo "$state" | jq -r '.hostname // ""')
  install_id=$(echo "$state" | jq -r '.install_id // ""')
  username=$(echo "$state" | jq -r '.username // ""')

  [[ -n "$pool_name" && "$pool_name" =~ ^ACABROOT-[0-9A-Fa-f]{4}$ ]] || return 1
  [[ -n "$target_disk" && -e "/dev/disk/by-id/${target_disk}" ]] || return 1
  [[ -n "$hostname" ]] || return 1
  [[ -n "$install_id" ]] || return 1
  [[ -n "$username" ]] || return 1

  return 0
}

probe_disk_safety() {
  local state
  state="$(state_read)" || return 1
  local target_disk
  target_disk=$(echo "$state" | jq -r '.target_disk // ""')
  [[ -n "$target_disk" ]] || return 1
  [[ -e "/dev/disk/by-id/${target_disk}" ]] || return 1

  local blkid_out
  blkid_out=$(blkid "/dev/disk/by-id/${target_disk}" 2>/dev/null || true)
  if [[ -n "$blkid_out" ]]; then
    local pool_name
    pool_name=$(echo "$state" | jq -r '.pool_name // ""')
    local zfs_status
    zfs_status=$(state_get_stage_status "ZFS_CREATE" 2>/dev/null || echo "")
    if [[ "$zfs_status" == "success" ]]; then
      return 0
    fi
    return 1
  fi
  return 0
}

probe_zfs_create() {
  local state
  state="$(state_read)" || return 1
  local pool_name
  pool_name=$(echo "$state" | jq -r '.pool_name // ""')
  [[ -n "$pool_name" ]] || return 1

  source "${INSTALLER_DIR}/lib/topology.sh"
  build_topology "$pool_name"

  local errors=()

  if ! zpool list -H -o name "${pool_name}" >/dev/null 2>&1 \
    && ! run_timeout "$SHORT_TIMEOUT" zpool import -N -o readonly=on "${pool_name}" >/dev/null 2>&1; then
    echo "FATAL:pool_does_not_import"
    return 1
  fi

  local encroot
  encroot=$(zfs get -H -o value encryptionroot "${pool_name}/ROOT/acabos" 2>/dev/null || echo "-")
  if [[ "$encroot" == "-" || -z "$encroot" ]]; then
    errors+=("encryption:not_active_on_ROOT_acabos")
  fi

  local actual_datasets
  actual_datasets=$(zfs list -H -o name -r "${pool_name}" 2>/dev/null | sort)
  local expected_sorted
  expected_sorted=$(get_topology_sorted)

  while IFS= read -r expected; do
    [[ -z "$expected" ]] && continue
    if ! echo "$actual_datasets" | grep -qx "$expected"; then
      errors+=("dataset_missing:${expected}")
    fi
  done <<< "$expected_sorted"

  while IFS= read -r actual; do
    [[ -z "$actual" ]] && continue
    if ! echo "$expected_sorted" | grep -qx "$actual"; then
      errors+=("dataset_unexpected:${actual}")
    fi
  done <<< "$actual_datasets"

  for ds in "${!TOPOLOGY_PROPS[@]}"; do
    local prop_str="${TOPOLOGY_PROPS[$ds]}"
    [[ -z "$prop_str" ]] && continue
    IFS=':' read -ra props <<< "$prop_str"
    for prop_eq in "${props[@]}"; do
      local prop="${prop_eq%%=*}"
      local expected_val="${prop_eq##*=}"
      local actual_val
      actual_val=$(zfs get -H -o value "$prop" "$ds" 2>/dev/null || echo "ERROR")
      if [[ "$actual_val" != "$expected_val" ]]; then
        errors+=("property_drift:${ds}:${prop}=${actual_val}:expected=${expected_val}")
      fi
    done
  done

  if [[ ${#errors[@]} -gt 0 ]]; then
    printf '%s\n' "${errors[@]}"
    return 1
  fi
  return 0
}

probe_base_install() {
  local root="/mnt/install"
  [[ -f "${root}/bin/bash" ]] || return 1
  compgen -G "${root}/boot/vmlinuz-*" >/dev/null 2>&1 || return 1

  local kernel_pkg
  kernel_pkg=$(chroot "$root" dpkg-query -W -f='${Status}' linux-image-amd64 2>/dev/null || echo "")
  [[ "$kernel_pkg" == *"installed"* ]] || return 1

  return 0
}

probe_boot_chain() {
  local efi="/mnt/install/boot/efi"
  local bundle="${efi}/EFI/zbm/zfsbootmenu.EFI"
  [[ -r "$bundle" && -s "$bundle" ]] || return 1

  local bundle_type
  bundle_type=$(file -b "$bundle" 2>/dev/null || echo "")
  [[ "$bundle_type" =~ PE32|EFI ]] || return 1

  local component_initramfs
  component_initramfs=$(ls -1 "${efi}/EFI/zbm/initramfs"* 2>/dev/null | head -1 || true)
  if [[ -n "$component_initramfs" ]]; then
    run_timeout "$SHORT_TIMEOUT" lsinitrd "$component_initramfs" 2>/dev/null | grep -q '/init' || return 1
    run_timeout "$SHORT_TIMEOUT" lsinitrd "$component_initramfs" 2>/dev/null | grep -q zfs || return 1
    run_timeout "$SHORT_TIMEOUT" lsinitrd "$component_initramfs" 2>/dev/null | grep -q zfsbootmenu || return 1
  fi

  [[ -f "/mnt/install/etc/modprobe.d/nvidia-drm.conf" ]] || return 1
  [[ -f "/mnt/install/etc/sysctl.d/99-performance.conf" ]] || return 1

  return 0
}

probe_nvidia_bringup() {
  local root="/mnt/install"
  local state
  state="$(state_read)" || return 1
  local kernel_ver
  kernel_ver=$(ls "${root}/lib/modules/" 2>/dev/null | head -1)
  [[ -n "$kernel_ver" ]] || return 1

  compgen -G "${root}/lib/modules/${kernel_ver}/updates/dkms/nvidia*.ko*" >/dev/null 2>&1 || return 1

  chroot "$root" dpkg-query -W -f='${Status}' nvidia-container-toolkit 2>/dev/null | grep -q "installed" || return 1

  [[ -f "${root}/etc/profile.d/cuda.sh" ]] || return 1

  return 0
}

probe_podman() {
  chroot_mount /mnt/install
  chroot /mnt/install podman info >/dev/null 2>&1 || {
    chroot_umount /mnt/install
    return 1
  }
  chroot_umount /mnt/install
  [[ -f "/mnt/install/etc/containers/containers.conf" ]] || return 1
  return 0
}

probe_desktop() {
  local root="/mnt/install"
  chroot "$root" dpkg-query -W -f='${Status}' sway 2>/dev/null | grep -q "installed" || return 1
  chroot "$root" dpkg-query -W -f='${Status}' waybar 2>/dev/null | grep -q "installed" || return 1
  [[ -f "${root}/usr/local/bin/sway-nvidia" ]] || return 1
  [[ -f "${root}/etc/skel/.config/sway/config" ]] || return 1
  [[ -f "${root}/etc/skel/.config/waybar/config" ]] || return 1
  return 0
}

probe_ai() {
  local root="/mnt/install"
  [[ -f "${root}/opt/ai-venv/bin/python" ]] || return 1
  [[ -f "${root}/usr/local/bin/ai-python" ]] || return 1
  [[ -x "${root}/opt/llama-cpp/build/bin/llama-cli" ]] || return 1
  [[ -x "${root}/usr/local/bin/ollama" ]] || return 1
  [[ -f "${root}/etc/systemd/system/ollama.service" ]] || return 1
  return 0
}

probe_inference() {
  [[ -x "/mnt/install/opt/acab/bin/mistral-rs" ]] || return 1
  find /mnt/install/usr -name 'libcudnn.so*' 2>/dev/null | grep -q . || return 1
  return 0
}

probe_validation() {
  local target="/mnt/install"
  local bind_src="$INSTALLER_DIR"
  local bind_dst="${target}/run/acabos-installer"

  chroot_mount "$target"
  mkdir -p "$bind_dst"
  run_timeout "$SHORT_TIMEOUT" mountpoint -q "$bind_dst" || run_timeout "$SHORT_TIMEOUT" mount --bind "$bind_src" "$bind_dst" \
    || { chroot_umount "$target"; return 1; }

  if ! run_timeout "$MEDIUM_TIMEOUT" chroot "$target" env ACABOS_DOCTOR_PRE_FINALIZE=true /run/acabos-installer/doctor/acabos-doctor >/dev/null 2>&1; then
    run_timeout "$SHORT_TIMEOUT" umount -R "$bind_dst" 2>/dev/null || true
    chroot_umount "$target"
    return 1
  fi

  run_timeout "$SHORT_TIMEOUT" umount -R "$bind_dst" 2>/dev/null || true
  chroot_umount "$target"
  return 0
}

probe_stage() {
  local stage="$1"
  case "$stage" in
    PREFLIGHT)       probe_preflight ;;
    INPUT)           probe_input ;;
    DISK_SAFETY)     probe_disk_safety ;;
    ZFS_CREATE)      probe_zfs_create ;;
    BASE_INSTALL)    probe_base_install ;;
    BOOT_CHAIN)      probe_boot_chain ;;
    NVIDIA_BRINGUP)  probe_nvidia_bringup ;;
    PODMAN_SUBSTRATE) probe_podman ;;
    DESKTOP_SUBSTRATE) probe_desktop ;;
    AI_SUBSTRATE)    probe_ai ;;
    INFERENCE_SUBSTRATE) probe_inference ;;
    VALIDATION)      probe_validation ;;
    FINALIZE)        return 1 ;;
    *)               return 1 ;;
  esac
}
