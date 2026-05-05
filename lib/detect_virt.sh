#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# detect_virt.sh -- multi-signal hypervisor detection.
#
# detect_runtime_context() returns "physical" or "virtual".
# Uses three signals; 2+ required to classify as virtual:
#   1. CPU hypervisor flag in /proc/cpuinfo
#   2. systemd-detect-virt --vm returning non-"none"
#   3. DMI product name matching VMware|VirtualBox|QEMU|KVM|Xen|Hyper-V|Amazon EC2
#
# Used by NVIDIA_BRINGUP to decide runtime validation strictness
# and by acabos-doctor for context-aware GPU checks.

detect_runtime_context() {
  local signals=0

  grep -q hypervisor /proc/cpuinfo 2>/dev/null && ((signals++)) || true

  if command -v systemd-detect-virt >/dev/null 2>&1; then
    local virt
    virt=$(systemd-detect-virt --vm 2>/dev/null || echo "none")
    if [[ "$virt" != "none" && -n "$virt" ]]; then
      ((signals++)) || true
    fi
  fi

  local dmi
  dmi=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
  case "$dmi" in
    *VMware*|*VirtualBox*|*QEMU*|*KVM*|*Xen*|*Hyper-V*|*Amazon*EC2*)
      ((signals++)) || true
      ;;
  esac

  if [[ $signals -ge 2 ]]; then
    echo "virtual"
  else
    echo "physical"
  fi
}
