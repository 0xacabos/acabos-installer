#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# common.sh -- shared utilities for the ACABOS installer.
#
# Provides: logging, state management (JSON), timeout wrapper, chroot helpers,
#           disk utilities, log hashing, version constants, global ERR trap.
#
# Timeout constants:
#   SHORT_TIMEOUT  (30s)   -- probes, status checks, small operations
#   MEDIUM_TIMEOUT (120s)  -- keyring fetch, apt update, generate-zbm
#   LONG_TIMEOUT   (600s)  -- apt install, mmdebstrap, cuDNN download
#   BUILD_TIMEOUT  (3600s) -- cargo install (mistral.rs ~10-30 min build)
#
# State management uses jq to read/write state/install-state.json.
# All state functions expect init_paths() to have been called first.

readonly STATE_VERSION="acabos-install-state/v1"
readonly TOPOLOGY_VERSION="acabos-zfs-topology/v2"
readonly DOCTOR_SCHEMA_VERSION="acabos-doctor-invariants/v2"

readonly SHORT_TIMEOUT=30
readonly MEDIUM_TIMEOUT=120
readonly LONG_TIMEOUT=600
readonly BUILD_TIMEOUT=3600
readonly KILL_DELAY=5

INSTALLER_DIR=""
STATE_DIR=""
LOG_DIR=""
MANIFEST_DIR=""
CURRENT_STAGE=""

declare -A STAGE_LOG_HASHES=()

_on_err() {
  local line="$1" src="$2" fn="$3"
  err "Unhandled error in ${src}:${fn} at line ${line}"
  if [[ -n "$CURRENT_STAGE" ]]; then
    state_fail_stage "Unhandled error at line ${line}" 2>/dev/null || true
  fi
  exit 1
}

trap '_on_err $LINENO "${BASH_SOURCE[0]}" "${FUNCNAME[0]:-toplevel}"' ERR

init_paths() {
  INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  STATE_DIR="${INSTALLER_DIR}/state"
  LOG_DIR="${STATE_DIR}/logs"
  MANIFEST_DIR="${STATE_DIR}/manifest"
  mkdir -p "$LOG_DIR" "$MANIFEST_DIR"
  export PATH="/usr/local/sbin:/usr/sbin:/sbin:${PATH}"
  export LANG="C.UTF-8"
  export LC_ALL="C.UTF-8"
}

run_timeout() {
  local timeout_s="$1"; shift
  local rc=0
  timeout --kill-after="${KILL_DELAY}s" "${timeout_s}s" "$@" || rc=$?
  case "$rc" in
    0) return 0 ;;
    124)
      err "Command timed out after ${timeout_s}s: $*"
      return 124
      ;;
    137)
      err "Command killed after ${timeout_s}s+${KILL_DELAY}s: $*"
      return 137
      ;;
    *)
      return "$rc"
      ;;
  esac
}

log() {
  local msg
  msg="$(date -u +%Y-%m-%dT%H:%M:%SZ) [INFO] $*"
  echo "$msg"
  if [[ -n "$CURRENT_STAGE" && -n "$LOG_DIR" ]]; then
    echo "$msg" >> "${LOG_DIR}/${CURRENT_STAGE}.log"
  fi
}

warn() {
  local msg
  msg="$(date -u +%Y-%m-%dT%H:%M:%SZ) [WARN] $*"
  echo "$msg" >&2
  if [[ -n "$CURRENT_STAGE" && -n "$LOG_DIR" ]]; then
    echo "$msg" >> "${LOG_DIR}/${CURRENT_STAGE}.log"
  fi
}

err() {
  local msg
  msg="$(date -u +%Y-%m-%dT%H:%M:%SZ) [ERR ] $*"
  echo "$msg" >&2
  if [[ -n "$CURRENT_STAGE" && -n "$LOG_DIR" ]]; then
    echo "$msg" >> "${LOG_DIR}/${CURRENT_STAGE}.log"
  fi
}

fail() {
  err "$*"
  exit 1
}

require_binary() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || fail "Required binary not found: ${name}"
}

prompt_confirm() {
  local prompt_text="$1"
  if can_use_gum; then
    gum confirm "$prompt_text"
    return $?
  fi
  prompt_yn "$prompt_text"
}

prompt_yn() {
  local prompt_text="$1"
  local response
  read -r -p "${prompt_text} [y/N]: " response
  response=$(echo "$response" | tr -d ' \t\n\r')
  [[ "$response" == "y" || "$response" == "Y" ]]
}

is_interactive() {
  [[ -t 0 && -t 1 ]]
}

can_use_gum() {
  is_interactive && command -v gum >/dev/null 2>&1
}

can_use_fzf() {
  is_interactive && command -v fzf >/dev/null 2>&1
}

prompt_text() {
  local prompt_text="$1"
  local default_value="${2:-}"
  if can_use_gum; then
    if [[ -n "$default_value" ]]; then
      gum input --prompt "${prompt_text}: " --value "$default_value"
    else
      gum input --prompt "${prompt_text}: "
    fi
    return 0
  fi

  local response
  if [[ -n "$default_value" ]]; then
    read -r -p "${prompt_text} [${default_value}]: " response
    response="${response:-$default_value}"
  else
    read -r -p "${prompt_text}: " response
  fi
  echo "$response"
}

prompt_select() {
  local prompt_text="$1"
  shift
  local options=("$@")
  if [[ ${#options[@]} -eq 0 ]]; then
    return 1
  fi

  if can_use_gum; then
    printf '%s\n' "${options[@]}" | gum choose --header "$prompt_text"
    return $?
  fi

  if ! is_interactive; then
    local raw_choice
    read -r raw_choice || return 1
    local opt
    for opt in "${options[@]}"; do
      if [[ "$raw_choice" == "$opt" ]]; then
        echo "$opt"
        return 0
      fi
    done
    if [[ "$raw_choice" =~ ^[0-9]+$ ]] && (( raw_choice >= 1 && raw_choice <= ${#options[@]} )); then
      echo "${options[$((raw_choice - 1))]}"
      return 0
    fi
    return 1
  fi

  echo "$prompt_text"
  local i=1
  local option
  for option in "${options[@]}"; do
    echo "  ${i}) ${option}"
    i=$((i + 1))
  done
  local choice
  read -r -p "Choice [1-${#options[@]}]: " choice
  [[ "$choice" =~ ^[0-9]+$ ]] || return 1
  (( choice >= 1 && choice <= ${#options[@]} )) || return 1
  echo "${options[$((choice - 1))]}"
}

prompt_password() {
  local prompt_text="$1"
  if can_use_gum; then
    gum input --password --prompt "${prompt_text}: "
    return $?
  fi

  if [[ -t 0 ]]; then
    local response
    read -r -s -p "${prompt_text}: " response
    echo ""
    echo "$response"
    return 0
  fi

  return 1
}

prompt_select_disk() {
  local prompt_text="$1"
  shift
  local options=("$@")
  if [[ ${#options[@]} -eq 0 ]]; then
    return 1
  fi

  if can_use_fzf; then
    local preview_script
    preview_script=$(mktemp)
    cat > "$preview_script" << 'PREVIEW'
#!/usr/bin/env bash
set -Eeuo pipefail

selected="${1:-}"
disk_by_id="/dev/disk/by-id/${selected}"
disk_real="$(readlink -f "$disk_by_id" 2>/dev/null || true)"

echo "Disk by-id: $disk_by_id"
echo "Resolved: ${disk_real:-unresolved}"
echo ""

if [[ -z "$disk_real" ]]; then
  exit 0
fi

echo "== lsblk =="
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,PARTUUID,UUID,MOUNTPOINTS "$disk_real" 2>/dev/null || true
echo ""

echo "== sgdisk -p =="
sgdisk -p "$disk_real" 2>/dev/null || true
echo ""

echo "== blkid =="
blkid "$disk_real" 2>/dev/null || true
while IFS= read -r part; do
  [[ "$part" == "$disk_real" ]] && continue
  blkid "$part" 2>/dev/null || true
done < <(lsblk -nrpo NAME "$disk_real" 2>/dev/null || true)
PREVIEW
    chmod 700 "$preview_script"

    local selected
    selected=$(printf '%s\n' "${options[@]}" | fzf \
      --prompt='Disk > ' \
      --height='80%' \
      --layout='reverse' \
      --border \
      --header "$prompt_text" \
      --preview "$preview_script {}" \
      --preview-window='right,60%,wrap')
    local rc=$?

    rm -f "$preview_script"
    if [[ $rc -ne 0 || -z "$selected" ]]; then
      return 1
    fi
    echo "$selected"
    return 0
  fi

  prompt_select "$prompt_text" "${options[@]}"
}

iso_timestamp() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

state_init() {
  local install_id="$1"
  local pool_name="$2"
  local target_disk="$3"
  local hostname="$4"
  local username="${5:-ai}"
  jq -n \
    --arg sv "$STATE_VERSION" \
    --arg iid "$install_id" \
    --arg pn "$pool_name" \
    --arg td "$target_disk" \
    --arg hn "$hostname" \
    --arg un "$username" \
    '{
      state_version: $sv,
      install_id: $iid,
      current_stage: "INIT",
      pool_name: $pn,
      target_disk: $td,
      hostname: $hn,
      username: $un,
      stages: {}
    }' > "${STATE_DIR}/install-state.json"
}

state_read() {
  if [[ ! -f "${STATE_DIR}/install-state.json" ]]; then
    echo ""
    return 1
  fi
  cat "${STATE_DIR}/install-state.json"
}

state_set_stage() {
  local stage="$1"
  CURRENT_STAGE="$stage"
  local ts
  ts="$(iso_timestamp)"
  local state
  state="$(state_read)" || state='{"current_stage": "INIT", "stages": {}}'
  echo "$state" | jq \
    --arg s "$stage" \
    --arg t "$ts" \
    '.current_stage = $s | .stages[$s] = {status: "in_progress", started_at: $t}' \
    > "${STATE_DIR}/install-state.json"
}

state_complete_stage() {
  local stage="$1"
  local ts
  ts="$(iso_timestamp)"
  local state
  state="$(state_read)" || fail "Cannot read state file"
  echo "$state" | jq \
    --arg s "$stage" \
    --arg t "$ts" \
    '.current_stage = $s | .stages[$s].status = "success" | .stages[$s].ended_at = $t' \
    > "${STATE_DIR}/install-state.json"
  CURRENT_STAGE=""
}

state_fail_stage() {
  local detail="$1"
  local ts
  ts="$(iso_timestamp)"
  local state
  state="$(state_read)" || return 1
  echo "$state" | jq \
    --arg s "$CURRENT_STAGE" \
    --arg t "$ts" \
    --arg d "$detail" \
    '.current_stage = $s | .stages[$s].status = "failed" | .stages[$s].ended_at = $t | .stages[$s].error = $d' \
    > "${STATE_DIR}/install-state.json" 2>/dev/null || true
}

state_get_field() {
  local field="$1"
  local state
  state="$(state_read)" || return 1
  echo "$state" | jq -r ".$field"
}

state_set_field() {
  local field="$1"
  local value="$2"
  local state
  state="$(state_read)" || fail "Cannot read state file"
  echo "$state" | jq --arg f "$field" --arg v "$value" '.[$f] = $v' > "${STATE_DIR}/install-state.json"
}

detect_gpu_policy_json() {
  local detection_source="none"
  local gpu_lines=""
  if command -v lspci >/dev/null 2>&1; then
    gpu_lines=$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)
    [[ -n "$gpu_lines" ]] && detection_source="lspci"
  fi
  if [[ -z "$gpu_lines" ]] && command -v lshw >/dev/null 2>&1; then
    gpu_lines=$(lshw -C display 2>/dev/null | grep -E 'product:|vendor:' || true)
    [[ -n "$gpu_lines" ]] && detection_source="lshw"
  fi

  local gpu_detected="false"
  local gpu_vendor="none"
  local gpu_model="none"
  local gpu_count="0"
  local gpu_support_tier="unsupported"
  local gpu_runtime_target="cpu"
  local gpu_validation_policy="skip-gpu-runtime"

  local has_nvidia=false
  local has_amd=false
  local has_intel=false

  if [[ -n "$gpu_lines" ]]; then
    gpu_detected="true"
    gpu_model=""
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      gpu_count="$((gpu_count + 1))"
      gpu_model+="${line}; "
      if echo "$line" | grep -qi 'nvidia'; then
        has_nvidia=true
      fi
      if echo "$line" | grep -Eqi 'amd|ati|advanced micro devices'; then
        has_amd=true
      fi
      if echo "$line" | grep -qi 'intel'; then
        has_intel=true
      fi
    done <<< "$gpu_lines"
    gpu_model="${gpu_model%; }"

    if $has_nvidia && ! $has_amd && ! $has_intel; then
      gpu_vendor="nvidia"
      gpu_support_tier="supported"
      gpu_runtime_target="cuda"
      gpu_validation_policy="full"
    elif ! $has_nvidia && $has_amd && ! $has_intel; then
      gpu_vendor="amd"
      gpu_support_tier="experimental"
      gpu_runtime_target="rocm"
      gpu_validation_policy="limited"
    elif ! $has_nvidia && ! $has_amd && $has_intel; then
      gpu_vendor="intel"
      gpu_support_tier="experimental"
      gpu_runtime_target="cpu"
      gpu_validation_policy="limited"
    elif $has_nvidia || $has_amd || $has_intel; then
      gpu_vendor="mixed"
      if $has_nvidia; then
        gpu_support_tier="supported"
        gpu_runtime_target="cuda"
        gpu_validation_policy="full"
      elif $has_amd; then
        gpu_support_tier="experimental"
        gpu_runtime_target="rocm"
        gpu_validation_policy="limited"
      else
        gpu_support_tier="experimental"
        gpu_runtime_target="cpu"
        gpu_validation_policy="limited"
      fi
    else
      gpu_vendor="unknown"
      gpu_support_tier="experimental"
      gpu_runtime_target="unknown"
      gpu_validation_policy="limited"
    fi
  fi

  jq -n \
    --arg gpu_detected "$gpu_detected" \
    --arg gpu_vendor "$gpu_vendor" \
    --arg gpu_model "$gpu_model" \
    --arg gpu_count "$gpu_count" \
    --arg gpu_support_tier "$gpu_support_tier" \
    --arg gpu_runtime_target "$gpu_runtime_target" \
    --arg gpu_detection_source "$detection_source" \
    --arg gpu_validation_policy "$gpu_validation_policy" \
    '{
      gpu_detected: $gpu_detected,
      gpu_vendor: $gpu_vendor,
      gpu_model: $gpu_model,
      gpu_count: $gpu_count,
      gpu_support_tier: $gpu_support_tier,
      gpu_runtime_target: $gpu_runtime_target,
      gpu_detection_source: $gpu_detection_source,
      gpu_validation_policy: $gpu_validation_policy
    }'
}

state_get_stage_status() {
  local stage="$1"
  local state
  state="$(state_read)" || return 1
  echo "$state" | jq -r ".stages.${stage}.status // \"\""
}

finalize_stage_log() {
  local stage="$1"
  local log="${LOG_DIR}/${stage}.log"
  if [[ -f "$log" ]]; then
    local hash
    hash=$(sha256sum "$log" | cut -d' ' -f1)
    echo "${hash}" > "${log}.sha256"
    STAGE_LOG_HASHES["$stage"]="${stage}|${log}|${hash}"
  fi
}

chroot_mount() {
  local target="$1"
  mountpoint -q "${target}/proc" 2>/dev/null || mount --bind /proc "${target}/proc"
  mountpoint -q "${target}/sys" 2>/dev/null || mount --bind /sys "${target}/sys"
  mountpoint -q "${target}/dev" 2>/dev/null || mount --bind /dev "${target}/dev"
}

chroot_umount() {
  local target="$1"
  local bind_mounts
  bind_mounts=$(mount | grep "${target}" | grep -v " zfs " | awk '{print $3}' | sort -r)
  if [[ -n "$bind_mounts" ]]; then
    while IFS= read -r m; do
      umount -R "$m" 2>/dev/null || true
    done <<< "$bind_mounts"
  fi
  mountpoint -q "${target}/proc" && umount -R "${target}/proc" 2>/dev/null || true
  mountpoint -q "${target}/sys" && umount -R "${target}/sys" 2>/dev/null || true
  mountpoint -q "${target}/dev" && umount -R "${target}/dev" 2>/dev/null || true
}

prepare_dataset_rerun() {
  local pool_name="$1"
  local dataset="${pool_name}/ROOT/acabos"
  local mountpoint="/mnt/install"

  mountpoint -q "$mountpoint" && umount -R "$mountpoint" 2>/dev/null || true

  local bind_mounts
  bind_mounts=$(mount | grep "$mountpoint" | grep -v "zfs" || true)
  if [[ -n "$bind_mounts" ]]; then
    err "Stale bind mounts detected under ${mountpoint}:"
    echo "$bind_mounts" >&2
    err "Manual cleanup required. Aborting."
    return 1
  fi

  zfs destroy -r "$dataset" 2>/dev/null || true
  zfs create -o mountpoint=/ -o canmount=noauto "$dataset"
  zfs mount "$dataset"

  local contents
  contents=$(ls -A "$mountpoint" 2>/dev/null || true)
  if [[ -n "$contents" ]]; then
    err "Dataset ${dataset} is not empty after recreation. Aborting."
    return 1
  fi
  log "Dataset ${dataset} destroyed, recreated, verified empty."
}

disks_by_id() {
  local disks=()
  for dev in /dev/disk/by-id/*; do
    if [[ -b "$dev" && ! "$dev" =~ -part[0-9]+$ ]]; then
      disks+=("$dev")
    fi
  done
  printf '%s\n' "${disks[@]}" | sort
}

disk_model() {
  local by_id="$1"
  local kernel_name
  kernel_name=$(basename "$(readlink -f "$by_id")")
  cat "/sys/block/${kernel_name}/device/model" 2>/dev/null || echo "unknown"
}

disk_serial() {
  local by_id="$1"
  local kernel_name
  kernel_name=$(basename "$(readlink -f "$by_id")")
  cat "/sys/block/${kernel_name}/device/serial" 2>/dev/null || \
    udevadm info --query=property --name="$by_id" 2>/dev/null | grep ID_SERIAL= | cut -d= -f2 || echo "unknown"
}

disk_size() {
  local by_id="$1"
  local kernel_name
  kernel_name=$(basename "$(readlink -f "$by_id")")
  cat "/sys/block/${kernel_name}/size" 2>/dev/null | awk '{printf "%.0f GB\n", $1 * 512 / 1073741824}'
}

disk_kernel_name() {
  local by_id="$1"
  basename "$(readlink -f "$by_id")"
}

write_log_separator() {
  local stage="$1"
  local log="${LOG_DIR}/${stage}.log"
  {
    echo ""
    echo "═══════════════════════════════════════════"
    echo "STAGE RETRY: $(iso_timestamp)"
    echo "═══════════════════════════════════════════"
    echo ""
  } >> "$log" 2>/dev/null || true
}

init_paths
