#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# AI_SUBSTRATE -- Install Python ML venv (via uv), llama.cpp, native AI services, retained container services.
# Phase 1: Install uv + create /opt/ai-venv
# Phase 2: Install PyTorch from CUDA wheel index
# Phase 3: Install ML packages from requirements file
# Phase 4: Install ML packages from requirements file
# Phase 5: Clone + build llama.cpp with CUDA
# Phase 6: Install native Ollama
# Phase 7: Install AI utility scripts
# Phase 8: Install retained container quadlets
# Phase 9: Install Jupyter configuration and service
# Re-entry probe: lib/probes.sh probe_ai()
run_ai() {
  log "=== AI_SUBSTRATE ==="

  local target="/mnt/install"
  source "${INSTALLER_DIR}/config/mistral.version"
  source "${INSTALLER_DIR}/config/ollama.version"
  source "${INSTALLER_DIR}/config/pytorch.version"
  source "${INSTALLER_DIR}/config/nvidia-test-container.version"
  local llama_cuda_architectures="${LLAMA_CUDA_ARCHITECTURES:-${MISTRAL_CUDA_COMPUTE_CAP:-89}}"

  log "Phase 1: Installing system AI packages..."
  local pkg_file="${INSTALLER_DIR}/config/ai-system-packages.list"
  [[ -f "$pkg_file" ]] || fail "AI system package list not found: ${pkg_file}"
  local sys_pkgs
  sys_pkgs=$(grep -v '^\s*#' "$pkg_file" | grep -v '^\s*$')
  [[ -n "$sys_pkgs" ]] || fail "AI system package list is empty"

  chroot_mount "$target"
  run_timeout "$LONG_TIMEOUT" chroot "$target" env LANG=C.UTF-8 LC_ALL=C.UTF-8 apt-get install -y $sys_pkgs \
    || { chroot_umount "$target"; fail "AI system package installation failed"; }
  chroot_umount "$target"
  log "Phase 1 complete: System AI packages installed."

  log "Phase 2: Installing uv and creating Python venv..."
  chroot_mount "$target"

  run_timeout "$MEDIUM_TIMEOUT" chroot "$target" bash -c \
    'curl -fsSL https://astral.sh/uv/install.sh | env CARGO_HOME=/opt/uv UV_INSTALL_DIR=/opt/uv sh' \
    || { chroot_umount "$target"; fail "uv installation failed"; }

  local uv_bin="${target}/opt/uv/bin/uv"
  [[ -x "$uv_bin" ]] || { chroot_umount "$target"; fail "uv binary not found at ${uv_bin}"; }
  log "  uv installed: $("${uv_bin}" --version 2>/dev/null || echo 'unknown')"

  if [[ -x "${target}/opt/ai-venv/bin/python" ]]; then
    log "  Existing /opt/ai-venv detected; reusing it."
  else
    run_timeout "$MEDIUM_TIMEOUT" chroot "$target" /opt/uv/bin/uv venv --python 3 /opt/ai-venv \
      || { chroot_umount "$target"; fail "Failed to create /opt/ai-venv"; }
  fi

  [[ -f "${target}/opt/ai-venv/bin/python" ]] || { chroot_umount "$target"; fail "ai-venv python not found"; }
  local py_ver
  py_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" /opt/ai-venv/bin/python --version 2>/dev/null || echo "unknown")
  log "  Python venv created: ${py_ver}"

  chroot_umount "$target"
  log "Phase 2 complete: uv + Python venv ready."

  log "Phase 3: Installing PyTorch from pinned wheel index..."
  chroot_mount "$target"

  run_timeout "$BUILD_TIMEOUT" chroot "$target" /opt/uv/bin/uv pip install \
    --python /opt/ai-venv/bin/python \
    torch torchvision torchaudio \
    --index-url "${PYTORCH_INDEX_URL}" \
    || { chroot_umount "$target"; fail "PyTorch installation failed"; }

  local torch_ver
  torch_ver=$(run_timeout "$SHORT_TIMEOUT" chroot "$target" /opt/ai-venv/bin/python -c \
    'import torch; print(torch.__version__)' 2>/dev/null || echo "unknown")
  log "  PyTorch installed: ${torch_ver}"

  chroot_umount "$target"
  log "Phase 3 complete: PyTorch installed."

  log "Phase 4: Installing ML packages from requirements..."
  local req_file="${INSTALLER_DIR}/config/ai-venv-requirements.txt"
  [[ -f "$req_file" ]] || fail "AI venv requirements not found: ${req_file}"

  cp "$req_file" "${target}/tmp/ai-requirements.txt"
  chroot_mount "$target"

  run_timeout "$BUILD_TIMEOUT" chroot "$target" /opt/uv/bin/uv pip install \
    --python /opt/ai-venv/bin/python \
    -r /tmp/ai-requirements.txt \
    || { chroot_umount "$target"; fail "ML packages installation failed"; }

  rm -f "${target}/tmp/ai-requirements.txt"
  log "  ML packages installed."

  log "  Creating ai-python and ai-pip symlinks..."
  ln -sf /opt/ai-venv/bin/python "${target}/usr/local/bin/ai-python"
  ln -sf /opt/ai-venv/bin/pip "${target}/usr/local/bin/ai-pip"
  log "  Symlinks created."

  chroot_umount "$target"
  log "Phase 4 complete: ML packages installed."

  log "Phase 5: Building llama.cpp with CUDA..."
  log "  llama.cpp CUDA architectures: ${llama_cuda_architectures}"
  chroot_mount "$target"

  run_timeout "$LONG_TIMEOUT" chroot "$target" bash -c \
    '[ -d /opt/llama-cpp/.git ] || git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /opt/llama-cpp' \
    || { chroot_umount "$target"; fail "Failed to clone llama.cpp"; }

  run_timeout "$BUILD_TIMEOUT" chroot "$target" env LLAMA_CUDA_ARCHITECTURES="$llama_cuda_architectures" bash -c \
    'export PATH=/usr/local/cuda/bin:$PATH; cd /opt/llama-cpp && rm -rf build && cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="$LLAMA_CUDA_ARCHITECTURES" -DCUDAToolkit_ROOT=/usr/local/cuda -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release -j"$(nproc)"' \
    || { chroot_umount "$target"; fail "llama.cpp build failed"; }

  [[ -x "${target}/opt/llama-cpp/build/bin/llama-cli" ]] || { chroot_umount "$target"; fail "llama.cpp llama-cli binary not found"; }
  [[ -x "${target}/opt/llama-cpp/build/bin/llama-quantize" ]] || warn "llama.cpp llama-quantize binary not found"

  ln -sf /opt/llama-cpp/build/bin/llama-cli "${target}/usr/local/bin/llama" \
    || warn "Failed to create llama symlink"
  ln -sf /opt/llama-cpp/build/bin/llama-quantize "${target}/usr/local/bin/llama-quantize" \
    || warn "Failed to create llama-quantize symlink"

  run_timeout "$LONG_TIMEOUT" chroot "$target" bash -c \
    'git clone --depth 1 https://github.com/NVIDIA/cuda-samples.git /opt/cuda-samples' 2>/dev/null \
    || warn "Failed to clone optional CUDA samples"

  chroot_umount "$target"
  log "Phase 5 complete: llama.cpp built and installed."

  log "Phase 6: Installing native Ollama..."
  chroot_mount "$target"

  run_timeout "$LONG_TIMEOUT" chroot "$target" bash -c \
    'mkdir -p /usr/local /usr/local/bin && curl --fail --show-error --location --progress-bar "'"${OLLAMA_ARCHIVE_URL}"'" | tar -xzf - -C /usr/local' \
    || { chroot_umount "$target"; fail "Failed to install Ollama binary"; }

  run_timeout "$SHORT_TIMEOUT" chroot "$target" bash -c \
    'id ollama >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin -U -m -d /usr/share/ollama ollama' \
    || { chroot_umount "$target"; fail "Failed to create ollama user"; }

  run_timeout "$SHORT_TIMEOUT" chroot "$target" bash -c \
    'getent group render >/dev/null 2>&1 && usermod -a -G render ollama || true; getent group video >/dev/null 2>&1 && usermod -a -G video ollama || true' \
    || warn "Failed to add ollama user to supplementary groups"

  cp "${INSTALLER_DIR}/config/ollama.service" "${target}/etc/systemd/system/ollama.service"
  run_timeout "$SHORT_TIMEOUT" chroot "$target" systemctl enable ollama.service 2>/dev/null \
    || warn "Failed to enable ollama.service in target"

  [[ -x "${target}/usr/local/bin/ollama" ]] || { chroot_umount "$target"; fail "Ollama binary not found after install"; }
  chroot_umount "$target"
  log "Phase 6 complete: native Ollama installed."

  log "Phase 7: Installing AI utility scripts..."
  mkdir -p "${target}/usr/local/bin"

  cat > "${target}/usr/local/bin/model-manager" << 'MODEL_MGR'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
echo "ACABOS Model Manager"
echo "Usage: model-manager [download|list|serve] <model>"
echo "  download <model>  - Download model from HuggingFace"
echo "  list              - List cached models"
echo "  serve <profile>   - Start a mistral.rs profile via systemd"
echo ""
if [[ $# -eq 0 ]]; then
    exit 0
fi
CMD="$1"
shift
case "$CMD" in
    download)
        [[ $# -ge 1 ]] || { echo "Usage: model-manager download <model-name>"; exit 1; }
        /opt/ai-venv/bin/python - "$1" <<'PY'
import os
import sys
from huggingface_hub import snapshot_download

model = sys.argv[1]
target = os.path.join('/opt/acab/models', model)
snapshot_download(repo_id=model, local_dir=target)
PY
        ;;
    list)
        ls -la /opt/acab/models/ 2>/dev/null || echo "No models found."
        ;;
    serve)
        [[ $# -ge 1 ]] || { echo "Usage: model-manager serve <profile>"; exit 1; }
        systemctl start "acab-inference@$1.service"
        systemctl status "acab-inference@$1.service" --no-pager
        ;;
    *)
        echo "Unknown command: $CMD"
        exit 1
        ;;
esac
MODEL_MGR
  chmod 755 "${target}/usr/local/bin/model-manager"

  cat > "${target}/usr/local/bin/gpu-benchmark" << 'GPU_BENCH'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
echo "=== ACABOS GPU Benchmark ==="
echo ""
echo "GPU Information:"
nvidia-smi --query-gpu=name,driver_version,memory.total,temperature.gpu --format=csv,noheader
echo ""
echo "CUDA Information:"
/opt/ai-venv/bin/python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')" 2>/dev/null || echo "CUDA check failed"
echo ""
echo "Running PyTorch matrix multiply benchmark..."
/opt/ai-venv/bin/python -c "
import torch
import time
if not torch.cuda.is_available():
    print('CUDA not available, skipping GPU benchmark')
    exit(0)
device = torch.device('cuda')
sizes = [1024, 2048, 4096]
for s in sizes:
    a = torch.randn(s, s, device=device)
    b = torch.randn(s, s, device=device)
    torch.cuda.synchronize()
    start = time.time()
    for _ in range(10):
        c = torch.mm(a, b)
    torch.cuda.synchronize()
    elapsed = time.time() - start
    print(f'  {s}x{s} matrix multiply x10: {elapsed:.4f}s ({10*2*s**3/elapsed/1e12:.2f} TFLOPS)')
" 2>/dev/null || echo "Benchmark failed"
echo ""
echo "Benchmark complete."
GPU_BENCH
  chmod 755 "${target}/usr/local/bin/gpu-benchmark"

  cat > "${target}/usr/local/bin/ai-services" << 'AI_SVC'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
ACTION="${1:-status}"
NATIVE_SERVICES=(ollama)
CONTAINER_SERVICES=(comfyui localai qdrant)
case "$ACTION" in
    start|stop|restart|status|logs)
        for svc in "${NATIVE_SERVICES[@]}" "${CONTAINER_SERVICES[@]}"; do
            systemctl "$ACTION" "${svc}.service" 2>/dev/null || true
        done
        ;;
    pull)
        for svc in "${CONTAINER_SERVICES[@]}"; do
            unit_path="/etc/containers/systemd/${svc}.container"
            [[ -f "$unit_path" ]] || continue
            image=$(grep '^Image=' "$unit_path" | cut -d= -f2)
            [[ -n "$image" ]] && podman pull "$image" 2>/dev/null || true
        done
        ;;
    *)
        echo "Usage: ai-services {start|stop|restart|status|logs|pull}"
        exit 1
        ;;
esac
AI_SVC
  chmod 755 "${target}/usr/local/bin/ai-services"

  cat > "${target}/usr/local/bin/ai-shell" << 'AI_SHELL'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
container="${1:-localai}"
exec podman exec -it "$container" /bin/bash
AI_SHELL
  chmod 755 "${target}/usr/local/bin/ai-shell"

  cat > "${target}/usr/local/bin/ai-stack" << 'AI_STACK'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
cmd="${1:-status}"
case "$cmd" in
  up)
    systemctl start ollama.service qdrant.service localai.service comfyui.service
    ;;
  down)
    systemctl stop ollama.service qdrant.service localai.service comfyui.service
    ;;
  status)
    systemctl status ollama.service qdrant.service localai.service comfyui.service --no-pager
    ;;
  *)
    echo "Usage: ai-stack {up|down|status}"
    exit 1
    ;;
esac
AI_STACK
  chmod 755 "${target}/usr/local/bin/ai-stack"

  cat > "${target}/usr/local/bin/test-nvidia-container" << 'TEST_GPU'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
podman run --rm --device nvidia.com/gpu=all docker.io/nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
TEST_GPU
  sed -i "s#docker.io/nvidia/cuda:12.4.1-base-ubuntu22.04#${NVIDIA_TEST_CONTAINER_IMAGE}#" "${target}/usr/local/bin/test-nvidia-container"
  chmod 755 "${target}/usr/local/bin/test-nvidia-container"

  log "Phase 7 complete: AI utility scripts installed."

  log "Phase 8: Installing container quadlets..."
  local quadlet_dir="${target}/etc/containers/systemd"
  mkdir -p "$quadlet_dir"

  local retained_quadlets=(qdrant.container localai.container comfyui.container)
  local quadlet_name
  for quadlet_name in "${retained_quadlets[@]}"; do
    cp "${INSTALLER_DIR}/config/quadlets/${quadlet_name}" "${quadlet_dir}/${quadlet_name}"
    log "  Installed quadlet: ${quadlet_name}"
  done

  chroot_mount "$target"
  run_timeout "$MEDIUM_TIMEOUT" chroot "$target" systemctl daemon-reload 2>/dev/null \
    || warn "systemctl daemon-reload failed in chroot"
  chroot_umount "$target"
  log "Phase 8 complete: Container quadlets installed."

  log "Phase 9: Installing Jupyter configuration..."
  mkdir -p "${target}/etc/jupyter"
  cp "${INSTALLER_DIR}/config/jupyter/jupyter_server_config.py" "${target}/etc/jupyter/jupyter_server_config.py"
  mkdir -p "${target}/etc/acabos"
  local jupyter_token
  jupyter_token=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
  cat > "${target}/etc/acabos/jupyter.env" <<EOF
ACABOS_JUPYTER_TOKEN=${jupyter_token}
EOF
  cp "${INSTALLER_DIR}/config/jupyter/acab-jupyter.service" "${target}/etc/systemd/system/acab-jupyter.service"
  log "Phase 9 complete: Jupyter configured."

  log "Validating AI substrate..."
  [[ -f "${target}/opt/ai-venv/bin/python" ]] || fail "ai-venv python not found"
  [[ -L "${target}/usr/local/bin/ai-python" ]] || fail "ai-python symlink not found"
  [[ -f "${target}/opt/llama-cpp/build/bin/llama-cli" ]] || fail "llama.cpp binary not found"
  [[ -x "${target}/usr/local/bin/ollama" ]] || fail "ollama binary not found"
  [[ -f "${target}/etc/systemd/system/ollama.service" ]] || fail "ollama service not found"
  [[ -f "${target}/etc/jupyter/jupyter_server_config.py" ]] || fail "jupyter config not found"
  [[ -f "${target}/etc/systemd/system/acab-jupyter.service" ]] || fail "jupyter service not found"

  log "AI_SUBSTRATE complete."
  return 0
}
