#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# INPUT -- Gather operator decisions: target disk, pool name, hostname.
# Re-entry probe: lib/probes.sh probe_input()
run_input() {
  log "=== INPUT ==="

  local assume_yes="${ACABOS_ASSUME_YES:-false}"

  log "Available disks:"
  local disks=()
  while IFS= read -r dev; do
    [[ -z "$dev" ]] && continue
    local model serial size
    model=$(disk_model "$dev")
    serial=$(disk_serial "$dev")
    size=$(disk_size "$dev")
    log "  $(basename "$dev")  model=${model}  serial=${serial}  size=${size}"
    disks+=("$(basename "$dev")")
  done < <(disks_by_id)

  echo ""
  local target_disk="${ACABOS_TARGET_DISK:-}"
  if [[ -z "$target_disk" ]]; then
    target_disk=$(prompt_select_disk "Select target disk by by-id basename (live partition preview enabled in fzf):" "${disks[@]}") \
      || fail "Disk selection aborted."
  else
    log "Using ACABOS_TARGET_DISK=${target_disk}"
  fi
  [[ -e "/dev/disk/by-id/${target_disk}" ]] || fail "Selected disk does not exist: /dev/disk/by-id/${target_disk}"
  log "Selected disk: ${target_disk}"

  local pool_name="${ACABOS_POOL_NAME:-}"
  while true; do
    if [[ -z "$pool_name" ]]; then
      local suffix
      suffix=$(hexdump -n 2 -e '2/1 "%02X"' /dev/urandom)
      pool_name="ACABROOT-${suffix}"
      log "Generated pool name: ${pool_name}"
    else
      [[ "$pool_name" =~ ^ACABROOT-[A-F0-9]{4}$ ]] || fail "Invalid ACABOS_POOL_NAME format: ${pool_name} (expected ACABROOT-XXXX)"
      log "Using pool name: ${pool_name}"
    fi

    local collision=0
    if zpool list -H -o name 2>/dev/null | grep -q "^${pool_name}$"; then
      collision=1
    fi
    if zpool import 2>/dev/null | grep "pool:" | awk '{print $2}' | grep -q "^${pool_name}$"; then
      collision=1
    fi
    if [[ $collision -gt 0 ]]; then
      warn "Pool name collision detected: ${pool_name}. Regenerating..."
      continue
    fi

    if [[ -n "${ACABOS_POOL_NAME:-}" || "$assume_yes" == "true" || ! is_interactive ]]; then
      break
    fi

    echo ""
    echo "Pool name: ${pool_name}"
    if prompt_yn "Accept this pool name?"; then
      break
    fi
    pool_name=""
  done
  log "Pool name confirmed: ${pool_name}"

  echo ""
  local hostname="${ACABOS_HOSTNAME:-}"
  if [[ -z "$hostname" ]]; then
    hostname=$(prompt_text "Enter hostname")
  else
    log "Using ACABOS_HOSTNAME=${hostname}"
  fi
  [[ -n "$hostname" ]] || fail "Hostname cannot be empty."
  log "Hostname: ${hostname}"

  echo ""
  local username="${ACABOS_USERNAME:-}"
  if [[ -z "$username" ]]; then
    username=$(prompt_text "Enter username for non-root account" "ai")
  else
    log "Using ACABOS_USERNAME=${username}"
  fi
  [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || fail "Invalid username: ${username}. Must start with lowercase letter or underscore, contain only lowercase letters, digits, underscores, hyphens."
  [[ "$username" != "root" && "$username" != "admin" ]] || fail "Username '${username}' is reserved."
  log "Username: ${username}"

  local timestamp
  timestamp=$(date -u +%Y%m%dT%H%M)
  local rand_suffix
  rand_suffix=$(hexdump -n 2 -e '2/1 "%02X"' /dev/urandom)
  local install_id="${timestamp}-${rand_suffix}"
  log "Install ID: ${install_id}"

  echo ""
  echo "============================================"
  echo "  INSTALL PLAN"
  echo "============================================"
  echo "  Target disk:    /dev/disk/by-id/${target_disk}"
  echo "  Pool name:      ${pool_name}"
  echo "  Hostname:       ${hostname}"
  echo "  Username:       ${username}"
  echo "  Install ID:     ${install_id}"
  echo "============================================"
  if [[ "$assume_yes" == "true" || ! is_interactive ]]; then
    local interactive_mode="false"
    if is_interactive; then
      interactive_mode="true"
    fi
    log "Skipping install-plan confirmation (ACABOS_ASSUME_YES=${assume_yes}, interactive=${interactive_mode})."
  else
    prompt_confirm "This will DESTROY ALL DATA on the selected disk. Review the plan above carefully."
  fi

  state_init "$install_id" "$pool_name" "$target_disk" "$hostname" "$username"
  local gpu_policy
  gpu_policy="$(detect_gpu_policy_json)"
  local field
  for field in gpu_detected gpu_vendor gpu_model gpu_count gpu_support_tier gpu_runtime_target gpu_detection_source gpu_validation_policy; do
    state_set_field "$field" "$(echo "$gpu_policy" | jq -r ".${field}")"
  done
  log "GPU policy recorded in installer state."
  log "State initialized. INPUT complete."
  return 0
}
