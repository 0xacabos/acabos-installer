# Config Reference

This document describes files under `config/` and which stage consumes them.

## Version Pins

- `config/mistral.version`: Version and build flags for mistral.rs and llama.cpp (`MISTRAL_VERSION`, `MISTRAL_FEATURES`, `RUST_MIN_VERSION`, `MISTRAL_CUDA_COMPUTE_CAP`, `LLAMA_CUDA_ARCHITECTURES`). Used by `AI_SUBSTRATE` and `INFERENCE_SUBSTRATE`.
- `config/cudnn.version`: cuDNN local repo package URL, SHA256, and package name. Used by `INFERENCE_SUBSTRATE`.
- `config/pytorch.version`: pinned PyTorch wheel index selection for `/opt/ai-venv`. Used by `AI_SUBSTRATE`.
- `config/nvidia-test-container.version`: pinned NVIDIA CUDA test image used for container runtime smoke validation. Used by `AI_SUBSTRATE` and first-boot runtime validation.

## APT Trust and Sources

- `config/apt-sources.list`: target system Debian + backports sources. Used by `BASE_INSTALL`.
- `config/apt-preferences`: pin policy for backports/NVIDIA cohorts. Used by `PREFLIGHT` (host) and `BASE_INSTALL` (target).
- `config/apt-trust.conf`: APT trust hardening (`AllowUnauthenticated false`, etc.). Used by `BASE_INSTALL`.
- `config/nvidia-container-toolkit.list`: target repo source for NVIDIA container toolkit. Used by `NVIDIA_BRINGUP`.
- `config/nvidia-keyring.sha256`: expected SHA256 for extracted NVIDIA CUDA keyring. Used by `PREFLIGHT`.

## Boot and ZFS

- `config/dracut.conf.d/zfs.conf`: dracut module policy for ZFS boot image. Used by `BOOT_CHAIN`.
- `config/zfsbootmenu-config.yaml`: `generate-zbm` configuration for bundled EFI and optional component images. Used by `BOOT_CHAIN`.
- `config/zfs-tuning.conf`: ZFS module tuning in target (`/etc/modprobe.d/zfs.conf`). Used by `BOOT_CHAIN`.

## NVIDIA Runtime Configuration

- `config/cuda-env.sh`: CUDA environment variables (`PATH`, `LD_LIBRARY_PATH`, etc.). Used by `NVIDIA_BRINGUP`.
- `config/cuda-ldconfig.conf`: CUDA and NVIDIA library paths for dynamic linker. Used by `NVIDIA_BRINGUP`.
- `config/nvidia-power.service`: persistence/eco mode service unit. Used by `NVIDIA_BRINGUP`.
- `config/nvidia-modprobe/nvidia.conf`: core NVIDIA module options. Used by `BOOT_CHAIN`.
- `config/nvidia-modprobe/nvidia-drm.conf`: DRM modeset/fbdev options. Used by `BOOT_CHAIN`.
- `config/nvidia-modprobe/nvidia-uvm.conf`: UVM module options. Used by `BOOT_CHAIN`.
- `config/nvidia-udev/70-nvidia.rules`: device-node permissions/ownership rules. Used by `BOOT_CHAIN`.

## System Tuning

- `config/sysctl/99-hugepages.conf`: optional hugepage settings for future opt-in performance profiles. Not installed by default.
- `config/sysctl/99-performance.conf`: TCP/memory/perf sysctls. Used by `BOOT_CHAIN`.
- `config/ssh-hardening.conf`: sshd include file for the default SSH policy. Used by `BASE_INSTALL`.

## Podman

- `config/podman/containers.conf`: global engine defaults. Used by `PODMAN_SUBSTRATE` and copied to skel in `DESKTOP_SUBSTRATE`.
- `config/podman/storage.conf`: storage driver options. Used by `PODMAN_SUBSTRATE`.
- `config/podman/registries.conf`: allowed registries and policy. Used by `PODMAN_SUBSTRATE`.

## Desktop User Experience

- `config/desktop-packages.list`: package list for Sway desktop substrate. Used by `DESKTOP_SUBSTRATE`.
- `config/sway/config`: base Sway config copied to `/etc/skel`. Used by `DESKTOP_SUBSTRATE`.
- `config/sway/config.d/nvidia`: NVIDIA-specific Sway environment additions. Used by `DESKTOP_SUBSTRATE`.
- `config/sway/config.d/input`: keyboard and pointer defaults. Used by `DESKTOP_SUBSTRATE`.
- `config/sway/config.d/output`: monitor/background defaults. Used by `DESKTOP_SUBSTRATE`.
- `config/waybar/config`: Waybar module layout. Used by `DESKTOP_SUBSTRATE`.
- `config/waybar/style.css`: Waybar styling. Used by `DESKTOP_SUBSTRATE`.
- `config/waybar/scripts/nvidia.sh`: Waybar custom NVIDIA status script. Used by `DESKTOP_SUBSTRATE`.
- `config/sway-nvidia`: launch wrapper for NVIDIA Wayland environment. Used by `DESKTOP_SUBSTRATE`.
- `config/start-desktop`: convenience launcher script. Used by `DESKTOP_SUBSTRATE`.
- `config/bashrc-aliases`: shell aliases appended to `/etc/skel/.bashrc`. Used by `DESKTOP_SUBSTRATE`.

## AI and Inference

- `config/ai-system-packages.list`: system-level AI package list. Used by `AI_SUBSTRATE`.
- `config/ai-venv-requirements.txt`: Python requirements for `/opt/ai-venv`. Used by `AI_SUBSTRATE`.
- `config/jupyter/jupyter_server_config.py`: Jupyter server defaults. Used by `AI_SUBSTRATE`.

## Quadlets (`config/quadlets/`)

Installed by `AI_SUBSTRATE` into `/etc/containers/systemd/` for the retained containerized support stack:

- `comfyui.container`
- `localai.container`
- `qdrant.container`

Other historical quadlets are not part of the default supported install surface.

## Finalization and Manifest

- `config/sudoers-acabos`: sudo policy include file. Used by `FINALIZE`.
- `config/first-boot.service`: one-shot bootstrap service unit. Used by `FINALIZE`.
- `config/first-boot-setup`: first-boot setup script. Used by `FINALIZE`.
- `config/motd`: login MOTD content. Used by `FINALIZE`.
- `config/issue`: `/etc/issue` banner content. Used by `FINALIZE`.
- `config/manifest-template.jq`: install manifest template. Used by `FINALIZE`.
