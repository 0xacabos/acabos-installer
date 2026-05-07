#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LAB_DIR="${SCRIPT_DIR}/build"
PROJECT_DIR="${ROOT_DIR}"
ISO_PATH="${ROOT_DIR}/media/out/acabos-installer-amd64.iso"
NVME_DISK_PATH="${LAB_DIR}/nvme-test.qcow2"
NVME_DISK_SIZE="120G"
UEFI_VARS_PATH="${LAB_DIR}/OVMF_VARS.fd"
RAM_MB="8192"
CPU_COUNT="4"
MOUNT_TAG="acabos_installer"
USE_UEFI=true
RESET_UEFI_VARS=false
RECREATE_NVME_DISK=false
NO_KVM=false
DRY_RUN=false
VFIO_GPU=""
VFIO_GPU_AUDIO=""
VFIO_GPU_ROMFILE=""
VFIO_PRIMARY=false

log_info() { printf '[INFO] %s\n' "$1"; }
log_warn() { printf '[WARN] %s\n' "$1"; }
log_error() { printf '[ERROR] %s\n' "$1" >&2; }
die() { log_error "$1"; exit 1; }

show_help() {
cat <<'HELP'
ACABOS QEMU Installer Lab

Boot the ACABOS installer ISO in QEMU with:
- a virtual NVMe disk for installer testing
- an optional shared project folder via 9p
- optional UEFI firmware via OVMF
- optional NVIDIA GPU passthrough via VFIO

Usage:
  ./media/qemu-lab/run-qemu-installer-lab.sh [options]

Options:
  --ram MB                RAM in MB (default: 8192)
  --cpus N                Number of vCPUs (default: 4)
  --nvme-size SIZE        NVMe qcow2 size (default: 120G)
  --nvme-disk PATH        NVMe qcow2 path (default: media/qemu-lab/build/nvme-test.qcow2)
  --recreate-nvme         Delete and recreate NVMe disk image
  --project-dir PATH      Host project path to share into guest
  --mount-tag TAG         9p mount tag visible in guest (default: acabos_installer)
  --iso PATH              Override ISO path (default: media/out/acabos-installer-amd64.iso)
  --bios                  Boot with BIOS instead of UEFI
  --reset-uefi-vars       Recreate writable UEFI vars file
  --no-kvm                Disable KVM acceleration
  --vfio-gpu BDF          Pass through GPU PCI device (e.g. 0000:01:00.0)
  --vfio-gpu-audio BDF    Pass through GPU audio PCI device
  --vfio-romfile PATH     Use a specific GPU ROM file for passthrough
  --vfio-primary          Make passthrough GPU primary (-vga none, x-vga=on)
  --dry-run               Print QEMU command and exit
  --help                  Show this help

Guest mount command:
  sudo modprobe 9pnet_virtio
  sudo mkdir -p /mnt/host-project
  sudo mount -t 9p -o trans=virtio,version=9p2000.L acabos_installer /mnt/host-project
HELP
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_value() {
  local opt="$1" val="${2:-}"
  [[ -n "$val" && "$val" != --* ]] || die "Option ${opt} requires a value"
}

normalize_pci_bdf() {
  local raw="$1"
  if [[ "$raw" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$ ]]; then
    printf '%s\n' "${raw,,}"
    return
  fi
  if [[ "$raw" =~ ^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]$ ]]; then
    printf '0000:%s\n' "${raw,,}"
    return
  fi
  die "Invalid PCI BDF: ${raw} (expected 0000:01:00.0 or 01:00.0)"
}

pci_driver_name() {
  local driver_link="/sys/bus/pci/devices/$1/driver"
  if [[ -L "$driver_link" ]]; then
    basename "$(readlink "$driver_link")"
  else
    printf 'none\n'
  fi
}

detect_ovmf() {
  local code vars
  while IFS='|' read -r code vars; do
    if [[ -f "$code" && -f "$vars" ]]; then
      printf '%s|%s\n' "$code" "$vars"
      return 0
    fi
  done <<'OVMF'
/usr/share/OVMF/OVMF_CODE.fd|/usr/share/OVMF/OVMF_VARS.fd
/usr/share/OVMF/OVMF_CODE_4M.fd|/usr/share/OVMF/OVMF_VARS_4M.fd
/usr/share/edk2-ovmf/x64/OVMF_CODE.fd|/usr/share/edk2-ovmf/x64/OVMF_VARS.fd
/usr/share/edk2-ovmf/OVMF_CODE.fd|/usr/share/edk2-ovmf/OVMF_VARS.fd
OVMF
  return 1
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ram) require_value "$1" "${2:-}"; RAM_MB="$2"; shift 2 ;;
      --cpus) require_value "$1" "${2:-}"; CPU_COUNT="$2"; shift 2 ;;
      --nvme-size) require_value "$1" "${2:-}"; NVME_DISK_SIZE="$2"; shift 2 ;;
      --nvme-disk) require_value "$1" "${2:-}"; NVME_DISK_PATH="$2"; shift 2 ;;
      --recreate-nvme) RECREATE_NVME_DISK=true; shift ;;
      --project-dir) require_value "$1" "${2:-}"; PROJECT_DIR="$2"; shift 2 ;;
      --mount-tag) require_value "$1" "${2:-}"; MOUNT_TAG="$2"; shift 2 ;;
      --iso) require_value "$1" "${2:-}"; ISO_PATH="$2"; shift 2 ;;
      --bios) USE_UEFI=false; shift ;;
      --reset-uefi-vars) RESET_UEFI_VARS=true; shift ;;
      --no-kvm) NO_KVM=true; shift ;;
      --vfio-gpu) require_value "$1" "${2:-}"; VFIO_GPU="$2"; shift 2 ;;
      --vfio-gpu-audio) require_value "$1" "${2:-}"; VFIO_GPU_AUDIO="$2"; shift 2 ;;
      --vfio-romfile) require_value "$1" "${2:-}"; VFIO_GPU_ROMFILE="$2"; shift 2 ;;
      --vfio-primary) VFIO_PRIMARY=true; shift ;;
      --dry-run) DRY_RUN=true; shift ;;
      --help) show_help; exit 0 ;;
      *) die "Unknown option: $1" ;;
    esac
  done
}

validate_args() {
  [[ "$RAM_MB" =~ ^[0-9]+$ ]] || die "--ram must be numeric MB"
  [[ "$CPU_COUNT" =~ ^[0-9]+$ ]] || die "--cpus must be numeric"
  [[ -d "$PROJECT_DIR" ]] || die "Project directory not found: $PROJECT_DIR"
  [[ -f "$ISO_PATH" ]] || die "ISO not found: $ISO_PATH (build it with ./media/build-medium.sh first)"

  if [[ -n "$VFIO_GPU" ]]; then
    VFIO_GPU="$(normalize_pci_bdf "$VFIO_GPU")"
    if [[ -z "$VFIO_GPU_AUDIO" ]]; then
      local candidate_audio="${VFIO_GPU%.*}.1"
      [[ -d "/sys/bus/pci/devices/${candidate_audio}" ]] && VFIO_GPU_AUDIO="$candidate_audio"
    else
      VFIO_GPU_AUDIO="$(normalize_pci_bdf "$VFIO_GPU_AUDIO")"
    fi

    [[ "$USE_UEFI" == true ]] || die "--vfio-gpu requires UEFI"
    [[ "$NO_KVM" == false ]] || die "--vfio-gpu requires KVM"
    [[ -d "/sys/bus/pci/devices/${VFIO_GPU}" ]] || die "VFIO GPU not found: ${VFIO_GPU}"
    if [[ -n "$VFIO_GPU_AUDIO" ]]; then
      [[ -d "/sys/bus/pci/devices/${VFIO_GPU_AUDIO}" ]] || die "VFIO GPU audio device not found: ${VFIO_GPU_AUDIO}"
    fi
    if [[ -n "$VFIO_GPU_ROMFILE" ]]; then
      [[ -f "$VFIO_GPU_ROMFILE" ]] || die "VFIO ROM file not found: ${VFIO_GPU_ROMFILE}"
    fi

    local gpu_driver
    gpu_driver="$(pci_driver_name "$VFIO_GPU")"
    if [[ "$gpu_driver" != "vfio-pci" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log_warn "GPU ${VFIO_GPU} is bound to '${gpu_driver}', not vfio-pci"
      else
        die "GPU ${VFIO_GPU} is bound to '${gpu_driver}', not vfio-pci"
      fi
    fi

    if [[ -n "$VFIO_GPU_AUDIO" ]]; then
      local audio_driver
      audio_driver="$(pci_driver_name "$VFIO_GPU_AUDIO")"
      if [[ "$audio_driver" != "vfio-pci" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
          log_warn "Audio ${VFIO_GPU_AUDIO} is bound to '${audio_driver}', not vfio-pci"
        else
          die "Audio ${VFIO_GPU_AUDIO} is bound to '${audio_driver}', not vfio-pci"
        fi
      fi
    fi
  fi
}

create_nvme_disk() {
  mkdir -p "$(dirname "$NVME_DISK_PATH")"
  if [[ "$RECREATE_NVME_DISK" == true && -f "$NVME_DISK_PATH" ]]; then
    log_info "Removing existing NVMe disk due to --recreate-nvme"
    rm -f "$NVME_DISK_PATH"
  fi
  if [[ ! -f "$NVME_DISK_PATH" ]]; then
    log_info "Creating NVMe disk: ${NVME_DISK_PATH} (${NVME_DISK_SIZE})"
    qemu-img create -f qcow2 "$NVME_DISK_PATH" "$NVME_DISK_SIZE" >/dev/null
  else
    log_info "Using existing NVMe disk: ${NVME_DISK_PATH}"
  fi
}

prepare_uefi() {
  local ovmf_pair ovmf_code ovmf_vars_template
  ovmf_pair="$(detect_ovmf || true)"
  [[ -n "$ovmf_pair" ]] || die "UEFI requested, but OVMF firmware was not found. Install package: ovmf"
  ovmf_code="${ovmf_pair%%|*}"
  ovmf_vars_template="${ovmf_pair##*|}"
  if [[ "$RESET_UEFI_VARS" == true || ! -f "$UEFI_VARS_PATH" ]]; then
    mkdir -p "$(dirname "$UEFI_VARS_PATH")"
    cp "$ovmf_vars_template" "$UEFI_VARS_PATH"
    chmod u+w "$UEFI_VARS_PATH" || true
  fi
  printf '%s|%s\n' "$ovmf_code" "$UEFI_VARS_PATH"
}

print_guest_instructions() {
cat <<INSTRUCTIONS

[INFO] Guest instructions once the ACABOS installer medium boots:
  Optional shared project mount:
    sudo modprobe 9pnet_virtio
    sudo mkdir -p /mnt/host-project
    sudo mount -t 9p -o trans=virtio,version=9p2000.L ${MOUNT_TAG} /mnt/host-project

[INFO] Suggested workflow inside the guest:
  1. Use the launcher on tty1.
  2. Choose Hardware Diagnostics / Recovery Shell as needed.
  3. For L1 runs, use --skip-gpu-validation in the installer when appropriate.
INSTRUCTIONS
}

run_qemu() {
  local ovmf_pair ovmf_code ovmf_vars
  local machine_accel="tcg"
  local cpu_model="max"
  local -a cmd=( qemu-system-x86_64 )

  if [[ "$NO_KVM" == false && -r /dev/kvm && -w /dev/kvm ]]; then
    machine_accel="kvm:tcg"
    cpu_model="host"
    cmd+=( -enable-kvm )
    log_info "KVM acceleration enabled"
  else
    log_warn "KVM not available; using software acceleration (TCG)"
  fi

  cmd+=(
    -machine "q35,accel=${machine_accel}"
    -cpu "$cpu_model"
    -smp "$CPU_COUNT"
    -m "$RAM_MB"
    -name "acabos-installer-lab"
    -boot "menu=on"
    -cdrom "$ISO_PATH"
    -drive "if=none,id=nvme0,file=${NVME_DISK_PATH},format=qcow2"
    -device "nvme,drive=nvme0,serial=ACABOS-NVME-TEST"
    -virtfs "local,path=${PROJECT_DIR},mount_tag=${MOUNT_TAG},security_model=none,id=hostshare"
    -netdev "user,id=net0"
    -device "virtio-net-pci,netdev=net0"
    -device "virtio-rng-pci"
    -device "qemu-xhci"
    -device "usb-tablet"
  )

  if [[ -n "$VFIO_GPU" ]]; then
    local vfio_gpu_opts
    vfio_gpu_opts="host=${VFIO_GPU},multifunction=on"
    if [[ "$VFIO_PRIMARY" == true ]]; then
      vfio_gpu_opts+=",x-vga=on"
      cmd+=( -vga none )
    fi
    if [[ -n "$VFIO_GPU_ROMFILE" ]]; then
      vfio_gpu_opts+=",romfile=${VFIO_GPU_ROMFILE}"
    fi
    cmd+=( -device "vfio-pci,${vfio_gpu_opts}" )
    if [[ -n "$VFIO_GPU_AUDIO" ]]; then
      cmd+=( -device "vfio-pci,host=${VFIO_GPU_AUDIO}" )
    fi
  fi

  if [[ "$USE_UEFI" == true ]]; then
    ovmf_pair="$(prepare_uefi)"
    ovmf_code="${ovmf_pair%%|*}"
    ovmf_vars="${ovmf_pair##*|}"
    cmd+=(
      -drive "if=pflash,format=raw,readonly=on,file=${ovmf_code}"
      -drive "if=pflash,format=raw,file=${ovmf_vars}"
    )
  fi

  log_info "Launching QEMU lab"
  log_info "  ISO:       ${ISO_PATH}"
  log_info "  NVMe disk: ${NVME_DISK_PATH}"
  log_info "  Share dir: ${PROJECT_DIR}"
  log_info "  Mount tag: ${MOUNT_TAG}"
  if [[ -n "$VFIO_GPU" ]]; then
    log_info "  VFIO GPU:  ${VFIO_GPU}"
    [[ -n "$VFIO_GPU_AUDIO" ]] && log_info "  VFIO audio:${VFIO_GPU_AUDIO}"
    [[ "$VFIO_PRIMARY" == true ]] && log_info "  VFIO mode: primary GPU"
  fi

  print_guest_instructions

  if [[ "$DRY_RUN" == true ]]; then
    printf '[INFO] QEMU command:\n'
    printf '  %q' "${cmd[@]}"
    printf '\n'
    return 0
  fi

  exec "${cmd[@]}"
}

main() {
  parse_args "$@"
  validate_args

  if [[ "$DRY_RUN" == false ]]; then
    require_cmd qemu-img
    require_cmd qemu-system-x86_64
    if [[ -n "$VFIO_GPU" && ( ! -r /dev/kvm || ! -w /dev/kvm ) ]]; then
      die "VFIO passthrough requested, but /dev/kvm is not accessible"
    fi
  fi

  if [[ "$DRY_RUN" == true ]]; then
    mkdir -p "$LAB_DIR"
    [[ ! -f "$ISO_PATH" ]] && log_warn "ISO does not exist yet: ${ISO_PATH}"
    [[ ! -f "$NVME_DISK_PATH" ]] && log_warn "NVMe disk does not exist yet: ${NVME_DISK_PATH}"
  else
    create_nvme_disk
  fi

  run_qemu
}

main "$@"
