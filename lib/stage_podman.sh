#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# PODMAN_SUBSTRATE -- Install full Podman container toolchain, configs, generate CDI spec.
# Packages: podman, podman-compose, podman-docker, buildah, skopeo, crun, etc.
# Configs: containers.conf, storage.conf, registries.conf
# CDI: nvidia-ctk cdi generate for GPU container access
# Re-entry probe: lib/probes.sh probe_podman()
run_podman() {
  log "=== PODMAN_SUBSTRATE ==="

  local target="/mnt/install"

  log "Installing Podman container toolchain..."
  chroot_mount "$target"
  run_timeout "$LONG_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get install -y \
    podman podman-compose podman-docker \
    buildah skopeo crun \
    slirp4netns fuse-overlayfs catatonit passt \
    containernetworking-plugins netavark aardvark-dns \
    || { chroot_umount "$target"; fail "Podman toolchain installation failed"; }
  log "Podman toolchain installed."

  log "Validating Podman..."
  run_timeout "$SHORT_TIMEOUT" chroot "$target" podman info >/dev/null 2>&1 \
    || { chroot_umount "$target"; fail "podman info failed"; }
  log "Podman validated."

  log "Installing Podman configuration..."
  mkdir -p "${target}/etc/containers"
  cp "${INSTALLER_DIR}/config/podman/containers.conf" "${target}/etc/containers/containers.conf"
  cp "${INSTALLER_DIR}/config/podman/storage.conf" "${target}/etc/containers/storage.conf"
  cp "${INSTALLER_DIR}/config/podman/registries.conf" "${target}/etc/containers/registries.conf"
  log "Podman config installed."

  log "Generating NVIDIA CDI spec..."
  mkdir -p "${target}/etc/cdi"
  if command -v nvidia-ctk >/dev/null 2>&1; then
    run_timeout "$SHORT_TIMEOUT" nvidia-ctk cdi generate --output "${target}/etc/cdi/nvidia.yaml" 2>/dev/null \
      || warn "CDI spec generation failed (will be generated on first boot)"
  else
    run_timeout "$SHORT_TIMEOUT" chroot "$target" bash -c 'command -v nvidia-ctk >/dev/null 2>&1 && nvidia-ctk cdi generate --output /etc/cdi/nvidia.yaml' 2>/dev/null \
      || warn "CDI spec generation failed (will be generated on first boot)"
  fi
  log "CDI spec generation attempted."

  chroot_umount "$target"
  log "PODMAN_SUBSTRATE complete."
  return 0
}
