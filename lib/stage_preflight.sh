#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# PREFLIGHT -- Verify live environment, fetch keyrings, configure host APT.
# Re-entry probe: lib/probes.sh probe_preflight()
run_preflight() {
  log "=== PREFLIGHT ==="

  log "Checking required binaries..."
  local binaries=(zpool zfs mmdebstrap dracut hexdump curl sgdisk wipefs lsinitrd jq dosfsck sha256sum timeout stat apt-get apt-cache modinfo modprobe lsmod dkms lspci)
  for bin in "${binaries[@]}"; do
    require_binary "$bin"
  done
  log "All required binaries found."

  log "Enumerating block devices..."
  local disk_count=0
  while IFS= read -r dev; do
    [[ -z "$dev" ]] && continue
    local model serial size
    model=$(disk_model "$dev")
    serial=$(disk_serial "$dev")
    size=$(disk_size "$dev")
    log "  ${dev}  model=${model}  serial=${serial}  size=${size}"
    disk_count=$((disk_count + 1))
  done < <(disks_by_id)
  [[ "$disk_count" -gt 0 ]] || fail "No block devices found via /dev/disk/by-id/"
  log "Found ${disk_count} candidate disk(s)."

  log "Detecting GPU support posture..."
  local gpu_policy gpu_vendor gpu_model gpu_count gpu_support_tier gpu_runtime_target gpu_validation_policy
  gpu_policy="$(detect_gpu_policy_json)"
  gpu_vendor=$(echo "$gpu_policy" | jq -r '.gpu_vendor')
  gpu_model=$(echo "$gpu_policy" | jq -r '.gpu_model')
  gpu_count=$(echo "$gpu_policy" | jq -r '.gpu_count')
  gpu_support_tier=$(echo "$gpu_policy" | jq -r '.gpu_support_tier')
  gpu_runtime_target=$(echo "$gpu_policy" | jq -r '.gpu_runtime_target')
  gpu_validation_policy=$(echo "$gpu_policy" | jq -r '.gpu_validation_policy')
  log "  GPU vendor: ${gpu_vendor} (tier=${gpu_support_tier}, runtime=${gpu_runtime_target}, count=${gpu_count})"
  [[ "$gpu_model" != "none" ]] && log "  GPU model(s): ${gpu_model}"
  case "$gpu_vendor" in
    nvidia)
      log "  NVIDIA path selected as the supported runtime target."
      ;;
    amd)
      warn "  AMD GPU detected. Install will continue, but GPU acceleration is experimental."
      ;;
    intel)
      warn "  Intel GPU detected. Install will continue, but GPU acceleration is experimental and inference may fall back to CPU."
      ;;
    mixed)
      if [[ "$gpu_runtime_target" == "cuda" ]]; then
        log "  Mixed GPU environment detected; NVIDIA will be treated as the primary runtime target."
      else
        warn "  Mixed GPU environment detected; non-NVIDIA path is experimental."
      fi
      ;;
    none)
      if [[ "${ACABOS_SKIP_GPU_VALIDATION:-false}" == "true" ]]; then
        warn "  No usable GPU detected, but --skip-gpu-validation is active. Continuing for lab/testing."
      else
        fail "No usable GPU detected. ACABOS requires a GPU-governed system unless --skip-gpu-validation is explicitly used for lab/testing."
      fi
      ;;
    *)
      warn "  GPU detection returned an unknown state. Install will continue cautiously."
      ;;
  esac

  log "Detecting existing ZFS pools..."
  local imported
  imported=$(zpool list -H -o name 2>/dev/null || echo "")
  if [[ -n "$imported" ]]; then
    log "Currently imported pools:"
    echo "$imported" | while IFS= read -r pool; do
      log "  ${pool}"
    done
  else
    log "No ZFS pools currently imported."
  fi

  local importable
  importable=$(zpool import 2>/dev/null | grep "pool:" | awk '{print $2}' || echo "")
  if [[ -n "$importable" ]]; then
    log "Importable pools detected (not currently imported):"
    echo "$importable" | while IFS= read -r pool; do
      log "  ${pool}"
    done
  else
    log "No importable pools detected."
  fi

  log "Checking network connectivity..."
  run_timeout "$SHORT_TIMEOUT" curl -fsSL -o /dev/null http://deb.debian.org/debian/ 2>/dev/null \
    || fail "Cannot reach Debian archive. Network connectivity required."
  log "Network connectivity confirmed."

  log "Applying live APT cohort policy..."
  cp "${INSTALLER_DIR}/config/apt-preferences" /etc/apt/preferences.d/99-acabos-live-cohort \
    || fail "Failed to install live APT cohort policy"

  log "Refreshing APT metadata..."
  run_timeout "$MEDIUM_TIMEOUT" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get update \
    || fail "Failed to update APT metadata"
  local apt_policy
  apt_policy=$(apt-cache policy 2>/dev/null || true)
  [[ "$apt_policy" == *"trixie-backports"* ]] \
    || fail "trixie-backports source not available in live APT configuration"

  log "Installing ABI cohort tooling from trixie-backports..."
  local running_kernel
  running_kernel=$(uname -r)
  run_timeout "$BUILD_TIMEOUT" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get install -y -t trixie-backports \
    linux-image-amd64 linux-headers-amd64 "linux-headers-${running_kernel}" zfsutils-linux zfs-dkms zfs-dracut dracut \
    || fail "Failed to install ABI cohort packages from trixie-backports"

  log "Installing interactive UI dependencies (gum, fzf)..."
  run_timeout "$MEDIUM_TIMEOUT" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get install -y gum fzf \
    || fail "Failed to install required UI dependencies: gum, fzf"
  require_binary gum
  require_binary fzf
  log "UI dependencies installed: gum, fzf."

  log "Running ABI cohort compatibility gate..."
  check_abi_cohort_gate
  log "ABI cohort compatibility gate passed."

  log "Verifying Debian archive keyring..."
  local debian_keyring="/usr/share/keyrings/debian-archive-keyring.gpg"
  [[ -f "$debian_keyring" ]] || fail "Debian archive keyring not found: ${debian_keyring}"
  log "Debian archive keyring found."

  log "Fetching NVIDIA repository keyring..."
  local nvidia_keyring_deb_url="https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb"
  run_timeout "$MEDIUM_TIMEOUT" bash -c "curl -fsSL '${nvidia_keyring_deb_url}' -o /tmp/cuda-keyring.deb && dpkg-deb -x /tmp/cuda-keyring.deb /tmp/cuda-keyring-extracted && cp /tmp/cuda-keyring-extracted/usr/share/keyrings/cuda-archive-keyring.gpg '${STATE_DIR}/nvidia-archive-keyring.gpg' && rm -rf /tmp/cuda-keyring.deb /tmp/cuda-keyring-extracted" \
    || fail "Failed to fetch NVIDIA keyring from ${nvidia_keyring_deb_url}"

  log "Verifying NVIDIA keyring SHA256..."
  local expected_sha actual_sha
  expected_sha=$(awk '/^[0-9a-f]/ {print $1}' "${INSTALLER_DIR}/config/nvidia-keyring.sha256")
  actual_sha=$(sha256sum "${STATE_DIR}/nvidia-archive-keyring.gpg" | awk '{print $1}')
  [[ "$expected_sha" == "$actual_sha" ]] || fail "NVIDIA keyring SHA256 mismatch: expected=${expected_sha} actual=${actual_sha}"
  log "NVIDIA keyring SHA256 verified."

  log "Installing NVIDIA repo into host live system APT..."
  local host_sources_d="/etc/apt/sources.list.d"
  local host_keyrings_d="/usr/share/keyrings"
  # NVIDIA repo not added to host APT to avoid key issues; key available for target
  cp "${STATE_DIR}/nvidia-archive-keyring.gpg" "${host_keyrings_d}/nvidia-archive-keyring.gpg"
  log "NVIDIA keyring copied to host."

  log "Fetching NVIDIA Container Toolkit keyring..."
  local nvidia_ctk_keyring_url="https://nvidia.github.io/libnvidia-container/gpgkey"
  run_timeout "$MEDIUM_TIMEOUT" curl -fsSL -o "${STATE_DIR}/nvidia-container-toolkit.gpg" "$nvidia_ctk_keyring_url" \
    || fail "Failed to fetch NVIDIA Container Toolkit keyring"
  log "NVIDIA Container Toolkit keyring fetched."

  log "PREFLIGHT complete."
  return 0
}

package_installed_from_backports() {
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

check_abi_cohort_gate() {
  local running_kernel
  running_kernel=$(uname -r)
  log "  Live kernel: ${running_kernel}"

  local header_status
  header_status=$(dpkg-query -W -f='${Status}' "linux-headers-${running_kernel}" 2>/dev/null || true)
  [[ "$header_status" == "install ok installed" ]] \
    || fail "ABI gate failed: linux-headers-${running_kernel} is not installed"
  log "  Matching headers installed: linux-headers-${running_kernel}"

  local cohort_pkgs=(linux-image-amd64 linux-headers-amd64 zfsutils-linux zfs-dkms zfs-dracut)
  local pkg
  for pkg in "${cohort_pkgs[@]}"; do
    package_installed_from_backports "$pkg" \
      || fail "ABI gate failed: ${pkg} is not installed from trixie-backports"
    log "  Cohort package pinned to backports: ${pkg}"
  done

  dpkg-query -W -f='${Status}' dracut 2>/dev/null | grep -q "install ok installed" \
    || fail "ABI gate failed: dracut is not installed"
  log "  dracut installed (uses backports-preferred policy when available)."

  run_timeout "$SHORT_TIMEOUT" modprobe zfs 2>/dev/null || fail "ABI gate failed: unable to load zfs kernel module"
  lsmod | awk '$1 == "zfs" {found=1} END {exit found ? 0 : 1}' \
    || fail "ABI gate failed: zfs module not loaded after modprobe"

  local zfs_kmod_version
  if [[ -r /sys/module/zfs/version ]]; then
    zfs_kmod_version=$(cat /sys/module/zfs/version)
  else
    zfs_kmod_version=$(modinfo -F version zfs 2>/dev/null || true)
  fi
  [[ -n "$zfs_kmod_version" ]] || fail "ABI gate failed: could not determine zfs kernel module version"

  local zfs_user_version
  zfs_user_version=$(zfs version 2>/dev/null | awk '/^zfs-/ {sub(/^zfs-/, "", $1); print $1; exit}')
  [[ -n "$zfs_user_version" ]] || fail "ABI gate failed: could not determine zfs userspace version"

  log "  ZFS kernel module version: ${zfs_kmod_version}"
  log "  ZFS userspace version: ${zfs_user_version}"
  [[ "$zfs_kmod_version" == "$zfs_user_version" ]] \
    || fail "ABI gate failed: zfs module/userspace version mismatch (${zfs_kmod_version} != ${zfs_user_version})"
}
