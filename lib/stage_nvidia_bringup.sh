#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# NVIDIA_BRINGUP -- Install NVIDIA OpenDKMS stack, container toolkit, CUDA environment.
# Phase 1: NVIDIA DKMS + driver + CUDA toolkit
# Phase 2: NVIDIA container toolkit + CDI spec
# Phase 3: CUDA environment configuration
# Phase 4: nvidia-persistenced + nvidia-power service
# Phase 5: Two-phase validation (build always hard-fail, runtime context-aware)
# Re-entry probe: lib/probes.sh probe_nvidia_bringup()
run_nvidia_bringup() {
  log "=== NVIDIA_BRINGUP ==="

  local target="/mnt/install"
  local skip_gpu_validation="${ACABOS_SKIP_GPU_VALIDATION:-false}"
  local gpu_vendor gpu_support_tier gpu_runtime_target gpu_validation_policy
  gpu_vendor=$(state_get_field "gpu_vendor" 2>/dev/null || echo "unknown")
  gpu_support_tier=$(state_get_field "gpu_support_tier" 2>/dev/null || echo "experimental")
  gpu_runtime_target=$(state_get_field "gpu_runtime_target" 2>/dev/null || echo "unknown")
  gpu_validation_policy=$(state_get_field "gpu_validation_policy" 2>/dev/null || echo "limited")

  source "${INSTALLER_DIR}/lib/detect_virt.sh"

  if [[ "$gpu_runtime_target" != "cuda" ]]; then
    warn "Skipping NVIDIA_BRINGUP: gpu_vendor=${gpu_vendor} support_tier=${gpu_support_tier} runtime_target=${gpu_runtime_target} validation_policy=${gpu_validation_policy}"
    return 0
  fi

  log "Checking for pre-Turing GPU..."
  local gpu_info
  gpu_info=$(lspci -nn 2>/dev/null | grep -i nvidia || echo "")
  if [[ -n "$gpu_info" ]]; then
    log "GPU detected: ${gpu_info}"
    local gpu_model
    gpu_model=$(echo "$gpu_info" | grep -oE '(RTX |GTX |GT )[0-9]+' | head -1 || echo "")
    if [[ -n "$gpu_model" ]]; then
      log "GPU model: ${gpu_model}"
    fi
  else
    warn "No NVIDIA GPU detected via lspci."
  fi

  log "Phase 0: Configuring NVIDIA APT repositories in target..."
  mkdir -p "${target}/usr/share/keyrings"
  cp "${STATE_DIR}/nvidia-archive-keyring.gpg" "${target}/usr/share/keyrings/cuda-archive-keyring.gpg"
  cp "${STATE_DIR}/nvidia-container-toolkit.gpg" "${target}/usr/share/keyrings/nvidia-container-toolkit.gpg"

  cat > "${target}/etc/apt/sources.list.d/nvidia-cuda.list" << 'NVIDIA_CUDA_REPO'
deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/ /
NVIDIA_CUDA_REPO
  cp "${INSTALLER_DIR}/config/nvidia-container-toolkit.list" "${target}/etc/apt/sources.list.d/nvidia-container-toolkit.list"

  chroot_mount "$target"
  run_timeout "$MEDIUM_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get update \
    || { chroot_umount "$target"; fail "apt-get update for NVIDIA repos failed"; }
  chroot_umount "$target"
  log "NVIDIA APT repositories configured."

  log "Phase 1: Installing NVIDIA packages..."
  chroot_mount "$target"
  run_timeout "$BUILD_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold install -y \
    nvidia-kernel-open-dkms \
    nvidia-driver \
    nvidia-driver-cuda \
    cuda-toolkit-13-2 \
    cuda-libraries-13-2 \
    cuda-libraries-dev-13-2 \
    cuda-command-line-tools-13-2 \
    cuda-nvml-dev-13-2 \
    nvidia-persistenced \
    libnvidia-egl-wayland1 \
    || { chroot_umount "$target"; fail "NVIDIA package installation failed"; }
  log "NVIDIA packages installed."
  log "Verifying NVIDIA DKMS build from package install..."

  local target_kernel_ver
  target_kernel_ver=$(ls "${target}/lib/modules/" | head -1)
  [[ -n "$target_kernel_ver" ]] || { chroot_umount "$target"; fail "Cannot determine target kernel version"; }

  local dkms_status_out
  dkms_status_out=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" dkms status nvidia 2>/dev/null || echo "")
  echo "$dkms_status_out" | grep "${target_kernel_ver}" | grep -q "installed" \
    || { chroot_umount "$target"; fail "NVIDIA DKMS not built for target kernel ${target_kernel_ver}: ${dkms_status_out}"; }
  log "NVIDIA DKMS verified for kernel ${target_kernel_ver}."

  log "Phase 2: Installing NVIDIA Container Toolkit..."
  chroot_mount "$target"
  run_timeout "$BUILD_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold install -y nvidia-container-toolkit \
    || { chroot_umount "$target"; fail "NVIDIA Container Toolkit installation failed"; }
  log "  nvidia-container-toolkit installed."

  mkdir -p "${target}/etc/nvidia-container-runtime"
  cat > "${target}/etc/nvidia-container-runtime/config.toml" << 'NVIDIA_CDI'
disable-cdi = false
[nvidia-container-cli]
ldconfig = "/sbin/ldconfig"

[nvidia-container-runtime]
debug = "/var/log/nvidia-container-runtime.log"

[cdi]
default-kind = "nvidia.com/gpu"
spec-dirs = ["/etc/cdi", "/var/run/cdi"]
NVIDIA_CDI
  log "  Container runtime config installed."
  chroot_umount "$target"
  log "Phase 2 complete: NVIDIA Container Toolkit installed."

  log "Phase 3: Configuring CUDA environment..."
  cp "${INSTALLER_DIR}/config/cuda-env.sh" "${target}/etc/profile.d/cuda.sh"
  chmod 755 "${target}/etc/profile.d/cuda.sh"

  cp "${INSTALLER_DIR}/config/cuda-ldconfig.conf" "${target}/etc/ld.so.conf.d/cuda.conf"

  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" ldconfig 2>/dev/null || warn "ldconfig failed"

  run_timeout "$SHORT_TIMEOUT" chroot "$target" bash -c 'ln -sf /usr/local/cuda/bin/nvcc /usr/local/bin/nvcc' 2>/dev/null \
    || warn "Failed to symlink nvcc into /usr/local/bin"
  chroot_umount "$target"
  log "Phase 3 complete: CUDA environment configured."

  log "Phase 4: Installing NVIDIA system services..."
  cp "${INSTALLER_DIR}/config/nvidia-power.service" "${target}/etc/systemd/system/nvidia-power.service"

  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" systemctl enable nvidia-persistenced 2>/dev/null || warn "nvidia-persistenced enable failed"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" systemctl enable nvidia-power.service 2>/dev/null || warn "nvidia-power.service enable failed"
  chroot_umount "$target"
  log "Phase 4 complete: NVIDIA services enabled."

  log "Phase 5: Build validation..."
  local kernel_ver
  kernel_ver=$(ls "${target}/lib/modules/" | head -1)
  [[ -n "$kernel_ver" ]] || fail "Cannot determine kernel version"

  local dkms_out
  chroot_mount "$target"
  dkms_out=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" dkms status nvidia 2>/dev/null || echo "")
  chroot_umount "$target"
  echo "$dkms_out" | grep -q "installed" || fail "NVIDIA DKMS not installed: ${dkms_out}"
  log "  DKMS status: installed"

  compgen -G "${target}/lib/modules/${kernel_ver}/updates/dkms/nvidia*.ko*" >/dev/null 2>&1 \
    || fail "NVIDIA module files not found under /lib/modules/${kernel_ver}/"
  log "  Module files present"

  log "Phase 5 build validation passed."

  log "Phase 5: Runtime validation..."
  local runtime_context
  runtime_context=$(detect_runtime_context)
  log "  Runtime context: ${runtime_context}"

  if [[ "$skip_gpu_validation" == "true" ]]; then
    runtime_context="virtual"
    log "  --skip-gpu-validation: forcing virtual semantics"
  fi

  if [[ "$runtime_context" == "physical" ]]; then
    log "  Running physical hardware validation..."

    local gpu_count
    gpu_count=$(lspci -nn 2>/dev/null | grep -ic nvidia || echo "0")
    if [[ "$gpu_count" -eq 0 ]]; then
      fail "No NVIDIA GPU detected on physical hardware"
    fi
    log "  GPU detected: count=${gpu_count}"

    PATH="/usr/sbin:/usr/bin:/sbin:/bin:$PATH" chroot "$target" dpkg -s nvidia-driver-cuda >/dev/null 2>&1 \
      || fail "nvidia-driver-cuda package not installed in target"
    PATH="/usr/sbin:/usr/bin:/sbin:/bin:$PATH" chroot "$target" bash -lc 'command -v nvidia-smi >/dev/null 2>&1' \
      || fail "nvidia-smi command not available in target"
    log "  nvidia-driver-cuda installed and nvidia-smi command present"

    log "  Physical hardware validation passed."
  else
    warn "  Virtual/unknown environment detected. Skipping runtime GPU validation."
    warn "  NVIDIA build validated but runtime not verified on real hardware."
    warn "  Run acabos-doctor after first boot on physical hardware."
  fi

  log "NVIDIA_BRINGUP complete."
  return 0
}
