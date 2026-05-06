#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# FINALIZE -- Write manifest, create user, install first-boot service, export pool.
# Terminal stage. No re-entry probe.
run_finalize() {
  log "=== FINALIZE ==="

  local pool_name target_disk hostname install_id username
  pool_name=$(state_get_field "pool_name")
  target_disk=$(state_get_field "target_disk")
  hostname=$(state_get_field "hostname")
  install_id=$(state_get_field "install_id")
  username=$(state_get_field "username")
  local gpu_vendor gpu_support_tier gpu_runtime_target gpu_validation_policy gpu_model gpu_detected gpu_count
  gpu_vendor=$(state_get_field "gpu_vendor" 2>/dev/null || echo "unknown")
  gpu_support_tier=$(state_get_field "gpu_support_tier" 2>/dev/null || echo "experimental")
  gpu_runtime_target=$(state_get_field "gpu_runtime_target" 2>/dev/null || echo "unknown")
  gpu_validation_policy=$(state_get_field "gpu_validation_policy" 2>/dev/null || echo "limited")
  gpu_model=$(state_get_field "gpu_model" 2>/dev/null || echo "unknown")
  gpu_detected=$(state_get_field "gpu_detected" 2>/dev/null || echo "false")
  gpu_count=$(state_get_field "gpu_count" 2>/dev/null || echo "0")
  local target="/mnt/install"
  local user_password="${ACABOS_USER_PASSWORD:-}"

  if [[ -z "$user_password" ]]; then
    if is_interactive; then
      local password_confirm
      user_password=$(prompt_password "Enter initial password for ${username}")
      [[ -n "$user_password" ]] || fail "User password cannot be empty."
      password_confirm=$(prompt_password "Confirm password for ${username}")
      [[ "$user_password" == "$password_confirm" ]] || fail "Password confirmation did not match."
    else
      fail "No interactive TTY for password prompt. Set ACABOS_USER_PASSWORD to continue."
    fi
  fi

  log "Creating non-root user: ${username}..."
  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" useradd -m -s /bin/bash -G sudo,plugdev,netdev,audio,video,systemd-journal "$username" \
    || { chroot_umount "$target"; fail "Failed to create user ${username}"; }
  printf '%s:%s\n' "$username" "$user_password" | run_timeout "$SHORT_TIMEOUT" chroot "$target" chpasswd \
    || { chroot_umount "$target"; fail "Failed to set initial password"; }
  run_timeout "$SHORT_TIMEOUT" chroot "$target" chage -d 0 "$username" \
    || warn "Failed to require password rotation for user ${username}"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" loginctl enable-linger "$username" 2>/dev/null \
    || warn "Failed to enable linger for user ${username}"
  chroot_umount "$target"
  user_password=""
  log "User ${username} created (forced password change on first login)."

  log "Locking root account..."
  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" passwd -l root 2>/dev/null || warn "Failed to lock root account"
  chroot_umount "$target"
  log "Root account locked."

  local user_home="${target}/home/${username}"
  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" chown -R "${username}:${username}" "/home/${username}" \
    || warn "Failed to set ownership on user home"
  chroot_umount "$target"
  log "User home ownership set."

  log "Preparing user configuration ownership..."
  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" mkdir -p "/home/${username}/.config" \
    || warn "Failed to create user .config"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" mkdir -p "/home/${username}/workspace/notebooks" \
    || warn "Failed to create user notebooks directory"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" chown -R "${username}:${username}" "/home/${username}/.config" \
    || warn "Failed to set ownership on user .config"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" chown -R "${username}:${username}" "/home/${username}/workspace" \
    || warn "Failed to set ownership on user workspace"
  if [[ -f "${target}/etc/acabos/jupyter.env" ]]; then
    grep -v '^ACABOS_JUPYTER_USER=' "${target}/etc/acabos/jupyter.env" | grep -v '^ACABOS_JUPYTER_ROOT=' > "${target}/etc/acabos/jupyter.env.tmp" || true
    mv "${target}/etc/acabos/jupyter.env.tmp" "${target}/etc/acabos/jupyter.env"
  fi
  cat >> "${target}/etc/acabos/jupyter.env" <<EOF
ACABOS_JUPYTER_USER=${username}
ACABOS_JUPYTER_ROOT=/home/${username}/workspace/notebooks
EOF
  {
    printf 'ACAB_GPU_DETECTED=%q\n' "$gpu_detected"
    printf 'ACAB_GPU_VENDOR=%q\n' "$gpu_vendor"
    printf 'ACAB_GPU_MODEL=%q\n' "$gpu_model"
    printf 'ACAB_GPU_COUNT=%q\n' "$gpu_count"
    printf 'ACAB_GPU_SUPPORT_TIER=%q\n' "$gpu_support_tier"
    printf 'ACAB_GPU_RUNTIME_TARGET=%q\n' "$gpu_runtime_target"
    printf 'ACAB_GPU_VALIDATION_POLICY=%q\n' "$gpu_validation_policy"
  } > "${target}/etc/acabos/gpu-policy.env"
  chroot_umount "$target"
  log "User configuration ownership prepared."

  log "Installing sudoers configuration..."
  cp "${INSTALLER_DIR}/config/sudoers-acabos" "${target}/etc/sudoers.d/99-acabos"
  chmod 440 "${target}/etc/sudoers.d/99-acabos"
  log "Sudoers configured."

  log "Installing first-boot service..."
  cp "${INSTALLER_DIR}/config/first-boot.service" "${target}/etc/systemd/system/first-boot.service"
  cp "${INSTALLER_DIR}/config/first-boot-setup" "${target}/usr/local/bin/first-boot-setup"
  chmod 755 "${target}/usr/local/bin/first-boot-setup"
  mkdir -p "${target}/etc/acabos"
  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" systemctl enable first-boot.service 2>/dev/null \
    || warn "Failed to enable first-boot service"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" systemctl enable NetworkManager 2>/dev/null \
    || warn "Failed to enable NetworkManager"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" systemctl enable apparmor 2>/dev/null \
    || warn "Failed to enable apparmor"
  chroot_umount "$target"
  log "First-boot service installed."

  log "Creating MOTD..."
  cp "${INSTALLER_DIR}/config/motd" "${target}/etc/motd"
  log "MOTD installed."

  log "Installing /etc/issue..."
  cp "${INSTALLER_DIR}/config/issue" "${target}/etc/issue" \
    || fail "Failed to install /etc/issue"
  log "/etc/issue installed."

  log "Generating install manifest..."

  local kernel_ver headers_ver zfs_ver nvidia_ver podman_ver
  local py_ver torch_ver mistral_ver ollama_ver
  chroot_mount "$target"
  kernel_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" dpkg-query -W -f='${Version}' linux-image-amd64 2>/dev/null || echo "unknown")
  headers_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" dpkg-query -W -f='${Version}' linux-headers-amd64 2>/dev/null || echo "unknown")
  zfs_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" dpkg-query -W -f='${Version}' zfsutils-linux 2>/dev/null || echo "unknown")
  nvidia_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" dpkg-query -W -f='${Version}' nvidia-driver 2>/dev/null || echo "unknown")
  podman_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" podman --version 2>/dev/null | awk '{print $3}' || echo "unknown")
  py_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" /opt/ai-venv/bin/python --version 2>/dev/null | awk '{print $2}' || echo "unknown")
  torch_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" /opt/ai-venv/bin/python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo "unknown")
  mistral_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" /opt/acab/bin/mistral-rs --version 2>/dev/null | awk '{print $2}' || echo "unknown")
  ollama_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" /usr/local/bin/ollama --version 2>/dev/null | awk '{print $NF}' || echo "unknown")
  chroot_umount "$target"

  local jupyter_token
  jupyter_token=$(grep '^ACABOS_JUPYTER_TOKEN=' "${target}/etc/acabos/jupyter.env" 2>/dev/null | cut -d= -f2- || echo "unknown")
  local native_services_json='["mistral.rs","ollama","jupyter"]'
  local container_services_json='["qdrant","localai","comfyui"]'
  local graphics_cohort_json='[]'
  if [[ "$gpu_runtime_target" == "cuda" ]]; then
    graphics_cohort_json=$(jq -n --arg nv "$nvidia_ver" '[{name: "nvidia-driver", version: $nv, status: "installed"}]')
  fi

  local log_artifacts="[]"
  local logged_stage
  for logged_stage in "${!STAGE_LOG_HASHES[@]}"; do
    local entry="${STAGE_LOG_HASHES[$logged_stage]}"
    local log_path log_hash
    log_path=$(echo "$entry" | cut -d'|' -f2)
    log_hash=$(echo "$entry" | cut -d'|' -f3)
    log_artifacts=$(echo "$log_artifacts" | jq \
      --arg p "/opt/acab/logs/install/$(basename "$log_path")" \
      --arg h "$log_hash" \
      '. += [{"path": $p, "kind": "install_log", "sha256": $h}]')
  done

  local pool_guid
  pool_guid=$(zpool get -H -o value guid "$pool_name" 2>/dev/null || echo "unknown")

  jq -n \
    --arg sv "acabos-install-manifest/v2" \
    --arg mk "install_manifest" \
    --arg iid "$install_id" \
    --arg ts "$(iso_timestamp)" \
    --arg hn "$hostname" \
    --arg td "$target_disk" \
    --arg pn "$pool_name" \
    --arg pg "$pool_guid" \
    --arg kv "$kernel_ver" \
    --arg hv "$headers_ver" \
    --arg zv "$zfs_ver" \
    --arg nv "$nvidia_ver" \
    --arg pv "$podman_ver" \
    --arg tv "$TOPOLOGY_VERSION" \
    --arg dsv "$DOCTOR_SCHEMA_VERSION" \
    --arg un "$username" \
    --arg pyv "$py_ver" \
    --arg tv2 "$torch_ver" \
    --arg gd "$gpu_detected" \
    --arg gv "$gpu_vendor" \
    --arg gm "$gpu_model" \
    --arg gc "$gpu_count" \
    --arg gst "$gpu_support_tier" \
    --arg grt "$gpu_runtime_target" \
    --arg gvp "$gpu_validation_policy" \
    --argjson nsvcs "$native_services_json" \
    --argjson csvcs "$container_services_json" \
    --argjson egfx "$graphics_cohort_json" \
    --argjson la "$log_artifacts" \
    -f "${INSTALLER_DIR}/config/manifest-template.jq" \
    > "${MANIFEST_DIR}/install-manifest.json"

  log "Manifest generated."

  log "Copying manifest into installed system..."
  mkdir -p "${target}/opt/acab/manifests" "${target}/opt/acab/logs/install"
  cp "${MANIFEST_DIR}/install-manifest.json" "${target}/opt/acab/manifests/install-manifest.json"
  log "Manifest copied."

  log "Copying logs into installed system..."
  for logf in "${LOG_DIR}/"*.log; do
    [[ -f "$logf" ]] || continue
    cp "$logf" "${target}/opt/acab/logs/install/"
  done
  for hashf in "${LOG_DIR}/"*.sha256; do
    [[ -f "$hashf" ]] || continue
    cp "$hashf" "${target}/opt/acab/logs/install/"
  done
  log "Logs copied."

  log "Rendering user onboarding documents..."
  local release_notes="${target}/home/${username}/RELEASE-NOTES.md"
  local first_steps="${target}/home/${username}/FIRST-STEPS.md"
  if [[ -f "$release_notes" ]]; then
    sed -i \
      -e "s/__ACAB_HOSTNAME__/${hostname}/g" \
      -e "s/__ACAB_USERNAME__/${username}/g" \
      -e "s/__ACAB_KERNEL__/${kernel_ver}/g" \
      -e "s/__ACAB_NVIDIA__/${nvidia_ver}/g" \
      -e "s/__ACAB_PODMAN__/${podman_ver}/g" \
      -e "s/__ACAB_PYTHON__/${py_ver}/g" \
      -e "s/__ACAB_TORCH__/${torch_ver}/g" \
      -e "s/__ACAB_MISTRAL__/${mistral_ver}/g" \
      -e "s/__ACAB_OLLAMA__/${ollama_ver}/g" \
      -e "s/__ACAB_GPU_VENDOR__/${gpu_vendor}/g" \
      -e "s/__ACAB_GPU_TIER__/${gpu_support_tier}/g" \
      -e "s/__ACAB_GPU_RUNTIME__/${gpu_runtime_target}/g" \
      "$release_notes"
  fi
  if [[ -f "$first_steps" ]]; then
    sed -i \
      -e "s/__ACAB_USERNAME__/${username}/g" \
      -e "s/__ACAB_JUPYTER_TOKEN__/${jupyter_token}/g" \
      -e "s/__ACAB_GPU_VENDOR__/${gpu_vendor}/g" \
      -e "s/__ACAB_GPU_TIER__/${gpu_support_tier}/g" \
      -e "s/__ACAB_GPU_RUNTIME__/${gpu_runtime_target}/g" \
      "$first_steps"
  fi
  log "Onboarding documents rendered."

  log "Running best-effort post-install cleanup..."
  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get clean 2>/dev/null || warn "apt-get clean failed"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get autoclean 2>/dev/null || warn "apt-get autoclean failed"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" updatedb 2>/dev/null || warn "updatedb failed"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" update-desktop-database /usr/share/applications 2>/dev/null || warn "update-desktop-database failed"
  chroot_umount "$target"
  log "Cleanup complete."

  log "Resetting ROOT dataset mountpoint for installed system..."
  zfs unmount "${pool_name}/ROOT/acabos" 2>/dev/null || true
  run_timeout "$SHORT_TIMEOUT" zfs set mountpoint=/ "${pool_name}/ROOT/acabos" \
    || fail "Failed to reset mountpoint on ${pool_name}/ROOT/acabos"
  log "ROOT dataset mountpoint reset to /."

  log "Exporting pool..."
  run_timeout "$SHORT_TIMEOUT" zpool export "$pool_name" \
    || fail "Failed to export pool ${pool_name}"
  log "Pool exported."

  echo ""
  echo "============================================"
  echo "  ACABOS INSTALL COMPLETE"
  echo "============================================"
  echo "  Pool:     ${pool_name}"
  echo "  Disk:     /dev/disk/by-id/${target_disk}"
  echo "  Hostname: ${hostname}"
  echo "  User:     ${username}"
  echo "  Kernel:   ${kernel_ver}"
  echo "  ZFS:      ${zfs_ver}"
  echo "  NVIDIA:   ${nvidia_ver}"
  echo "  Podman:   ${podman_ver}"
  echo "  Python:   ${py_ver}"
  echo "  PyTorch:  ${torch_ver}"
  echo ""
  echo "  Post-install steps:"
  echo "  1. Reboot the system."
  echo "  2. At the ZFSBootMenu prompt, enter your"
  echo "     passphrase to unlock ${pool_name}."
  echo "  3. Login as ${username} with the password"
  echo "     configured during installation."
  echo "  4. Change the password when prompted on first login."
  echo "  5. Run start-desktop to launch Sway."
  echo "============================================"

  log "FINALIZE complete."
  return 0
}
