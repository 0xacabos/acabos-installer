#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# DESKTOP_SUBSTRATE -- Install Sway + Waybar desktop with NVIDIA optimization.
# Packages: read from config/desktop-packages.list (one per line).
# Configs: sway, waybar, sway-nvidia wrapper, start-desktop launcher, bashrc aliases.
# Re-entry probe: lib/probes.sh probe_desktop()
run_desktop() {
  log "=== DESKTOP_SUBSTRATE ==="

  local target="/mnt/install"

  log "Reading desktop package list..."
  local pkg_file="${INSTALLER_DIR}/config/desktop-packages.list"
  [[ -f "$pkg_file" ]] || fail "Desktop package list not found: ${pkg_file}"
  local pkgs
  pkgs=$(grep -v '^\s*#' "$pkg_file" | grep -v '^\s*$')
  [[ -n "$pkgs" ]] || fail "Desktop package list is empty"
  log "  Packages: $(echo "$pkgs" | wc -w) packages"

  log "Installing desktop packages..."
  chroot_mount "$target"
  run_timeout "$BUILD_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get install -y $pkgs \
    || { chroot_umount "$target"; fail "Desktop package installation failed"; }
  chroot_umount "$target"
  log "Desktop packages installed."

  local skel_home="${target}/etc/skel"
  mkdir -p "$skel_home"

  log "Installing Sway configuration..."
  mkdir -p "${skel_home}/.config/sway/config.d"
  cp "${INSTALLER_DIR}/config/sway/config" "${skel_home}/.config/sway/config"
  cp "${INSTALLER_DIR}/config/sway/config.d/nvidia" "${skel_home}/.config/sway/config.d/nvidia"
  cp "${INSTALLER_DIR}/config/sway/config.d/input" "${skel_home}/.config/sway/config.d/input"
  cp "${INSTALLER_DIR}/config/sway/config.d/output" "${skel_home}/.config/sway/config.d/output"
  log "  Sway config installed."

  log "Installing Waybar configuration..."
  mkdir -p "${skel_home}/.config/waybar/scripts"
  cp "${INSTALLER_DIR}/config/waybar/config" "${skel_home}/.config/waybar/config"
  cp "${INSTALLER_DIR}/config/waybar/style.css" "${skel_home}/.config/waybar/style.css"
  cp "${INSTALLER_DIR}/config/waybar/scripts/nvidia.sh" "${skel_home}/.config/waybar/scripts/nvidia.sh"
  chmod 755 "${skel_home}/.config/waybar/scripts/nvidia.sh"
  log "  Waybar config installed."

  log "Installing desktop scripts..."
  cp "${INSTALLER_DIR}/config/sway-nvidia" "${target}/usr/local/bin/sway-nvidia"
  chmod 755 "${target}/usr/local/bin/sway-nvidia"
  cp "${INSTALLER_DIR}/config/start-desktop" "${target}/usr/local/bin/start-desktop"
  chmod 755 "${target}/usr/local/bin/start-desktop"
  log "  Desktop scripts installed."

  log "Installing bashrc aliases..."
  [[ -f "${skel_home}/.bashrc" ]] || touch "${skel_home}/.bashrc"
  cat "${INSTALLER_DIR}/config/bashrc-aliases" >> "${skel_home}/.bashrc"
  log "  Bashrc aliases appended."

  log "Installing onboarding documents..."
  cp "${INSTALLER_DIR}/config/RELEASE-NOTES.md.template" "${skel_home}/RELEASE-NOTES.md"
  cp "${INSTALLER_DIR}/config/FIRST-STEPS.md.template" "${skel_home}/FIRST-STEPS.md"
  log "  Onboarding documents installed."

  log "Installing user podman config skeleton..."
  mkdir -p "${skel_home}/.config/containers"
  cp "${INSTALLER_DIR}/config/podman/containers.conf" "${skel_home}/.config/containers/containers.conf"
  log "  User podman config skeleton installed."

  log "Creating user XDG directories..."
  mkdir -p "${skel_home}/Documents"
  mkdir -p "${skel_home}/Downloads"
  mkdir -p "${skel_home}/Projects"
  mkdir -p "${skel_home}/.local/share"
  mkdir -p "${skel_home}/workspace/models/checkpoints"
  mkdir -p "${skel_home}/workspace/models/loras"
  mkdir -p "${skel_home}/workspace/models/embeddings"
  mkdir -p "${skel_home}/workspace/datasets/images"
  mkdir -p "${skel_home}/workspace/datasets/text"
  mkdir -p "${skel_home}/workspace/datasets/audio"
  mkdir -p "${skel_home}/workspace/datasets/video"
  mkdir -p "${skel_home}/workspace/projects"
  mkdir -p "${skel_home}/workspace/notebooks"
  mkdir -p "${skel_home}/workspace/scripts"
  log "  User directories created."

  log "Validating desktop installation..."
  chroot_mount "$target"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" dpkg-query -W -f='${Status}' sway 2>/dev/null | grep -q "installed" \
    || { chroot_umount "$target"; fail "sway package not installed"; }
  run_timeout "$SHORT_TIMEOUT" chroot "$target" dpkg-query -W -f='${Status}' waybar 2>/dev/null | grep -q "installed" \
    || { chroot_umount "$target"; fail "waybar package not installed"; }
  chroot_umount "$target"
  [[ -f "${target}/usr/local/bin/sway-nvidia" ]] || fail "sway-nvidia script not found"
  [[ -f "${target}/usr/local/bin/start-desktop" ]] || fail "start-desktop script not found"
  [[ -f "${skel_home}/.config/sway/config" ]] || fail "sway config not found"

  log "DESKTOP_SUBSTRATE complete."
  return 0
}
