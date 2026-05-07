#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

STATE_DIR="/var/tmp/acabos-vfio-lab"
ACTION=""
GPU_BDF=""
AUDIO_BDF=""
GPU_DRIVER_OVERRIDE=""
AUDIO_DRIVER_OVERRIDE=""
ASSUME_YES=false

log_info() { printf '[INFO] %s\n' "$1"; }
log_warn() { printf '[WARN] %s\n' "$1"; }
log_error() { printf '[ERROR] %s\n' "$1" >&2; }
die() { log_error "$1"; exit 1; }

show_help() {
cat <<'HELP'
ACABOS VFIO GPU Bind Helper

Temporarily binds a GPU (and optional audio function) to vfio-pci for QEMU,
and restores host drivers afterward.

Usage:
  ./media/qemu-lab/vfio-gpu-bind-helper.sh <action> [options]

Actions:
  scan                            Show NVIDIA PCI devices and driver bindings
  status --gpu BDF [--audio BDF]  Show status for selected GPU/audio functions
  bind --gpu BDF [--audio BDF]    Bind selected devices to vfio-pci
  unbind --gpu BDF [--audio BDF]  Restore devices back to host drivers

Options:
  --gpu BDF               GPU PCI address, e.g. 0000:01:00.0 or 01:00.0
  --audio BDF             Audio PCI address (optional; defaults to same slot .1)
  --gpu-driver DRIVER     Host driver override for GPU when unbinding
  --audio-driver DRIVER   Host driver override for audio when unbinding
  --yes                   Skip confirmation prompt for bind/unbind
  --help                  Show this help

Notes:
  - bind/unbind requires root
  - state is saved under /var/tmp/acabos-vfio-lab
  - this script does not edit kernel cmdline or initramfs
HELP
}

normalize_pci_bdf() {
  local raw="$1"
  if [[ "$raw" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$ ]]; then
    printf '%s\n' "${raw,,}"; return
  fi
  if [[ "$raw" =~ ^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$ ]]; then
    printf '0000:%s\n' "${raw,,}"; return
  fi
  die "Invalid PCI BDF: ${raw} (expected 0000:01:00.0 or 01:00.0)"
}

state_file_for_gpu() {
  local bdf="$1" safe
  safe="${bdf//:/_}"; safe="${safe//./_}"
  printf '%s/%s.state\n' "$STATE_DIR" "$safe"
}

ensure_device_exists() { [[ -d "/sys/bus/pci/devices/$1" ]] || die "PCI device not found: $1"; }
current_driver() {
  local driver_link="/sys/bus/pci/devices/$1/driver"
  [[ -L "$driver_link" ]] && basename "$(readlink "$driver_link")" || printf 'none\n'
}
current_iommu_group() {
  local group_link="/sys/bus/pci/devices/$1/iommu_group"
  [[ -L "$group_link" ]] && basename "$(readlink "$group_link")" || printf 'none\n'
}

auto_detect_audio_bdf() {
  local candidate_audio="${1%.*}.1"
  if [[ -z "$AUDIO_BDF" && -d "/sys/bus/pci/devices/${candidate_audio}" ]]; then
    AUDIO_BDF="$candidate_audio"
  fi
}

require_root_for_mutation() {
  if [[ "$ACTION" == "bind" || "$ACTION" == "unbind" ]]; then
    [[ "$EUID" -eq 0 ]] || die "Action '$ACTION' requires root"
  fi
}

confirm_mutation() {
  [[ "$ASSUME_YES" == true ]] && return
  printf '\n[WARN] This can disrupt host graphics/audio if you pick active devices.\n'
  printf '[WARN] Action: %s\n' "$ACTION"
  printf '[WARN] GPU:    %s\n' "$GPU_BDF"
  [[ -n "$AUDIO_BDF" ]] && printf '[WARN] Audio:  %s\n' "$AUDIO_BDF"
  printf '\nType yes to continue: '
  local answer; read -r answer
  [[ "$answer" == "yes" ]] || die "Cancelled"
}

save_state() {
  mkdir -p "$STATE_DIR"
  cat > "$1" <<STATE
STATE_GPU_BDF=${GPU_BDF}
STATE_GPU_DRIVER=$2
STATE_AUDIO_BDF=${AUDIO_BDF}
STATE_AUDIO_DRIVER=$3
STATE
}

show_scan() {
  printf 'PCI BDF              Vendor   Device   Driver        IOMMU\n'
  printf '%-20s %-8s %-8s %-13s %-5s\n' '-------------------' '------' '------' '------------' '-----'
  local path bdf vendor device driver group
  for path in /sys/bus/pci/devices/*; do
    bdf="$(basename "$path")"
    vendor="$(<"${path}/vendor")"
    device="$(<"${path}/device")"
    [[ "$vendor" == "0x10de" ]] || continue
    driver="$(current_driver "$bdf")"
    group="$(current_iommu_group "$bdf")"
    printf '%-20s %-8s %-8s %-13s %-5s\n' "$bdf" "$vendor" "$device" "$driver" "$group"
  done
}

show_status() {
  ensure_device_exists "$GPU_BDF"
  auto_detect_audio_bdf "$GPU_BDF"
  printf 'GPU   %s  driver=%s  iommu=%s\n' "$GPU_BDF" "$(current_driver "$GPU_BDF")" "$(current_iommu_group "$GPU_BDF")"
  if [[ -n "$AUDIO_BDF" ]]; then
    ensure_device_exists "$AUDIO_BDF"
    printf 'AUDIO %s  driver=%s  iommu=%s\n' "$AUDIO_BDF" "$(current_driver "$AUDIO_BDF")" "$(current_iommu_group "$AUDIO_BDF")"
  fi
}

bind_device_to_vfio() {
  local bdf="$1" driver
  driver="$(current_driver "$bdf")"
  [[ "$driver" != "none" ]] && printf '%s' "$bdf" > "/sys/bus/pci/devices/${bdf}/driver/unbind"
  printf 'vfio-pci' > "/sys/bus/pci/devices/${bdf}/driver_override"
  printf '%s' "$bdf" > /sys/bus/pci/drivers_probe
  [[ "$(current_driver "$bdf")" == "vfio-pci" ]] || die "Failed to bind ${bdf} to vfio-pci"
}

restore_device_driver() {
  local bdf="$1" target_driver="$2" driver
  driver="$(current_driver "$bdf")"
  [[ "$driver" != "none" ]] && printf '%s' "$bdf" > "/sys/bus/pci/devices/${bdf}/driver/unbind"
  printf '' > "/sys/bus/pci/devices/${bdf}/driver_override"
  if [[ -n "$target_driver" && "$target_driver" != "none" ]]; then
    modprobe "$target_driver" >/dev/null 2>&1 || true
    [[ -d "/sys/bus/pci/drivers/${target_driver}" ]] && printf '%s' "$bdf" > "/sys/bus/pci/drivers/${target_driver}/bind" 2>/dev/null || true
  fi
  [[ "$(current_driver "$bdf")" == "none" ]] && printf '%s' "$bdf" > /sys/bus/pci/drivers_probe
}

bind_action() {
  require_root_for_mutation
  ensure_device_exists "$GPU_BDF"
  auto_detect_audio_bdf "$GPU_BDF"
  [[ -n "$AUDIO_BDF" ]] && ensure_device_exists "$AUDIO_BDF"
  confirm_mutation
  local state_file gpu_driver audio_driver
  state_file="$(state_file_for_gpu "$GPU_BDF")"
  gpu_driver="$(current_driver "$GPU_BDF")"
  audio_driver=""
  [[ -n "$AUDIO_BDF" ]] && audio_driver="$(current_driver "$AUDIO_BDF")"
  modprobe vfio-pci
  bind_device_to_vfio "$GPU_BDF"
  [[ -n "$AUDIO_BDF" ]] && bind_device_to_vfio "$AUDIO_BDF"
  save_state "$state_file" "$gpu_driver" "$audio_driver"
  log_info "Bound device(s) to vfio-pci"
  log_info "Saved restore state: ${state_file}"
  show_status
}

unbind_action() {
  require_root_for_mutation
  ensure_device_exists "$GPU_BDF"
  auto_detect_audio_bdf "$GPU_BDF"
  local state_file saved_gpu_driver="" saved_audio_bdf="" saved_audio_driver=""
  state_file="$(state_file_for_gpu "$GPU_BDF")"
  if [[ -f "$state_file" ]]; then
    # shellcheck disable=SC1090
    source "$state_file"
    saved_gpu_driver="${STATE_GPU_DRIVER:-}"
    saved_audio_bdf="${STATE_AUDIO_BDF:-}"
    saved_audio_driver="${STATE_AUDIO_DRIVER:-}"
  fi
  [[ -n "$saved_audio_bdf" && -z "$AUDIO_BDF" ]] && AUDIO_BDF="$saved_audio_bdf"
  [[ -n "$AUDIO_BDF" ]] && ensure_device_exists "$AUDIO_BDF"
  confirm_mutation
  local gpu_target audio_target
  gpu_target="${GPU_DRIVER_OVERRIDE:-${saved_gpu_driver}}"
  audio_target="${AUDIO_DRIVER_OVERRIDE:-${saved_audio_driver}}"
  restore_device_driver "$GPU_BDF" "$gpu_target"
  [[ -n "$AUDIO_BDF" ]] && restore_device_driver "$AUDIO_BDF" "$audio_target"
  [[ -f "$state_file" ]] && rm -f "$state_file"
  log_info "Restored device(s) back to host probing"
  show_status
}

parse_args() {
  [[ $# -gt 0 ]] || { show_help; exit 1; }
  [[ "$1" == "--help" ]] && { show_help; exit 0; }
  ACTION="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gpu) [[ -n "${2:-}" && "${2:-}" != --* ]] || die "--gpu requires a value"; GPU_BDF="$(normalize_pci_bdf "$2")"; shift 2 ;;
      --audio) [[ -n "${2:-}" && "${2:-}" != --* ]] || die "--audio requires a value"; AUDIO_BDF="$(normalize_pci_bdf "$2")"; shift 2 ;;
      --gpu-driver) [[ -n "${2:-}" && "${2:-}" != --* ]] || die "--gpu-driver requires a value"; GPU_DRIVER_OVERRIDE="$2"; shift 2 ;;
      --audio-driver) [[ -n "${2:-}" && "${2:-}" != --* ]] || die "--audio-driver requires a value"; AUDIO_DRIVER_OVERRIDE="$2"; shift 2 ;;
      --yes) ASSUME_YES=true; shift ;;
      --help) show_help; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
  case "$ACTION" in
    scan) ;;
    status|bind|unbind) [[ -n "$GPU_BDF" ]] || die "--gpu is required for action '$ACTION'" ;;
    *) die "Unknown action: $ACTION" ;;
  esac
}

main() {
  parse_args "$@"
  case "$ACTION" in
    scan) show_scan ;;
    status) show_status ;;
    bind) bind_action ;;
    unbind) unbind_action ;;
  esac
}

main "$@"
