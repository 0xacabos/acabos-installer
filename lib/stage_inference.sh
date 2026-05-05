#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# INFERENCE_SUBSTRATE -- Install cuDNN, Rust toolchain, build mistral.rs from source.
# Phase 1: cuDNN 9.19.0 via debian12 local repo installer (1.5GB download, SHA256 verified)
# Phase 2: rustup + Rust toolchain (>= 1.88)
# Phase 3: cargo install mistralrs-cli --features cuda,cudnn,flash-attn (~10-30 min build)
# Phase 4: Model manifest + templated systemd service/profile scaffolding
# Re-entry probe: lib/probes.sh probe_inference()
run_inference() {
  log "=== INFERENCE_SUBSTRATE ==="

  local target="/mnt/install"

  source "${INSTALLER_DIR}/config/cudnn.version"
  source "${INSTALLER_DIR}/config/mistral.version"

  log "Phase 1: Installing cuDNN ${CUDNN_VERSION}..."
  local cudnn_deb="/tmp/${CUDNN_LOCAL_REPO}"
  log "  Downloading cuDNN local repo installer..."
  run_timeout "$LONG_TIMEOUT" curl -fsSL -o "$cudnn_deb" "$CUDNN_URL" \
    || fail "Failed to download cuDNN from ${CUDNN_URL}"

  log "  Verifying cuDNN SHA256..."
  local cudnn_actual_sha
  cudnn_actual_sha=$(sha256sum "$cudnn_deb" | awk '{print $1}')
  [[ "$cudnn_actual_sha" == "$CUDNN_SHA256" ]] \
    || fail "cuDNN SHA256 mismatch: expected=${CUDNN_SHA256} actual=${cudnn_actual_sha}"
  log "  cuDNN SHA256 verified."

  chroot_mount "$target"

  cp "$cudnn_deb" "${target}/tmp/${CUDNN_LOCAL_REPO}"
  run_timeout "$LONG_TIMEOUT" chroot "$target" dpkg -i "/tmp/${CUDNN_LOCAL_REPO}" \
    || { chroot_umount "$target"; fail "cuDNN local repo dpkg install failed"; }
  rm -f "${target}/tmp/${CUDNN_LOCAL_REPO}" "$cudnn_deb"

  local cudnn_gpg_src="${target}${CUDNN_REPO_DIR}/${CUDNN_GPG_KEY}"
  [[ -f "$cudnn_gpg_src" ]] \
    || { chroot_umount "$target"; fail "cuDNN GPG key not found at ${cudnn_gpg_src}"; }
  cp "$cudnn_gpg_src" "${target}/usr/share/keyrings/${CUDNN_GPG_KEY}"

  run_timeout "$MEDIUM_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get update \
    || { chroot_umount "$target"; fail "apt-get update failed after cuDNN repo install"; }

  run_timeout "$LONG_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get install -y "$CUDNN_META_PACKAGE" \
    || { chroot_umount "$target"; fail "cuDNN metapackage install failed: ${CUDNN_META_PACKAGE}"; }

  local cudnn_lib_check
  cudnn_lib_check=$(find "${target}/usr/lib" -name 'libcudnn.so' 2>/dev/null | head -1 || echo "")
  [[ -n "$cudnn_lib_check" ]] \
    || { chroot_umount "$target"; fail "libcudnn.so not found after cuDNN install"; }
  log "  cuDNN installed: ${cudnn_lib_check}"

  chroot_umount "$target"
  log "Phase 1 complete: cuDNN installed."

  log "Phase 2: Installing Rust toolchain..."
  chroot_mount "$target"

  run_timeout "$MEDIUM_TIMEOUT" chroot "$target" bash -c \
    'curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable' \
    || { chroot_umount "$target"; fail "rustup install failed"; }

  local rust_ver
  rust_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" bash -c 'source /root/.cargo/env && rustc --version' 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
  [[ -n "$rust_ver" ]] || { chroot_umount "$target"; fail "rustc --version returned empty after install"; }
  if [[ "$(printf '%s\n%s\n' "$RUST_MIN_VERSION" "$rust_ver" | sort -V | head -1)" != "$RUST_MIN_VERSION" ]]; then
    chroot_umount "$target"
    fail "Rust version too old: installed=${rust_ver}, required>=${RUST_MIN_VERSION}"
  fi
  log "  Rust installed: ${rust_ver}"

  chroot_umount "$target"
  log "Phase 2 complete: Rust toolchain installed."

  log "Phase 3: Building mistral.rs ${MISTRAL_VERSION}..."
  log "  Features: ${MISTRAL_FEATURES}"
  log "  CUDA compute capability: ${MISTRAL_CUDA_COMPUTE_CAP}"
  log "  This will take 10-30 minutes depending on hardware."

  chroot_mount "$target"

  run_timeout "$BUILD_TIMEOUT" chroot "$target" bash -c \
    "source /root/.cargo/env && PATH='/usr/local/cuda/bin:'\"\$PATH\" CUDACXX='/usr/local/cuda/bin/nvcc' CUDA_COMPUTE_CAP='${MISTRAL_CUDA_COMPUTE_CAP}' CUDA_ROOT='/usr/local/cuda' CUDA_PATH='/usr/local/cuda' cargo install mistralrs-cli@${MISTRAL_VERSION} --features '${MISTRAL_FEATURES}'" \
    || { chroot_umount "$target"; fail "cargo install mistralrs-cli failed"; }

  local mistral_bin="${target}/root/.cargo/bin/mistralrs"
  [[ -x "$mistral_bin" ]] \
    || { chroot_umount "$target"; fail "mistralrs binary not found at ${mistral_bin}"; }
  log "  mistral.rs binary built: $(ls -la "$mistral_bin" | awk '{print $5}') bytes"

  local install_dir="${target}/opt/acab/bin"
  mkdir -p "$install_dir"
  cp "$mistral_bin" "${install_dir}/mistral-rs"
  chmod 755 "${install_dir}/mistral-rs"
  log "  Installed to /opt/acab/bin/mistral-rs."

  chroot_umount "$target"
  log "Phase 3 complete: mistral.rs built and installed."

  log "Phase 4: Creating model manifest..."
  mkdir -p "${target}/opt/acab/models/manifests"
  jq -n \
    --arg ver "$MISTRAL_VERSION" \
    --arg features "$MISTRAL_FEATURES" \
    '{
      profile_id: "acabos-mistral-default",
      runtime: "mistral.rs",
      version: $ver,
      features: $features,
      format: "safetensors",
      acceleration: "cuda",
      cudnn: true,
      flash_attention: true,
      network_access: false,
      requires_policy_gate: true
    }' > "${target}/opt/acab/models/manifests/model-manifest.json"
  log "Model manifest created."

  log "Phase 5: Creating templated systemd service and profile scaffolding..."
  mkdir -p "${target}/etc/systemd/system" "${target}/etc/acabos/inference"
  cp "${INSTALLER_DIR}/config/acab-inference@.service" "${target}/etc/systemd/system/acab-inference@.service"
  cp "${INSTALLER_DIR}/config/inference/example.env" "${target}/etc/acabos/inference/example.env"
  log "Templated service and example profile created."

  log "INFERENCE_SUBSTRATE complete."
  return 0
}
