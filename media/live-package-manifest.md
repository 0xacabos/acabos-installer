# ACABOS Installer Medium — Live Package Manifest

This document defines the package set required for the deterministic ACABOS installer medium.

## Purpose

The installer medium is a build-capable, GPU-aware Debian 13 live environment that:

- boots into a text-mode launcher
- contains `/opt/installer`
- can run all installer stages without ambient dependency guessing
- provides a recovery shell and hardware diagnostics
- includes a full build toolchain, CUDA toolkit, `nvcc`, cuDNN, and Rust

It is **not** the final ACABOS workstation — it is the environment that reliably builds one.

## Package Groups

### A. Core Live Environment

Shell and core utilities inherited from Debian live base plus these explicit additions:

- `bash`
- `coreutils`
- `findutils`
- `grep`
- `sed`
- `awk`
- `procps`
- `util-linux`
- `kbd`
- `console-setup`
- `jq`
- `curl`
- `ca-certificates`
- `gum`
- `fzf`
- `tmux`
- `less`
- `file`
- `tree`
- `rsync`
- `strace`
- `lsof`

### B. Disk / EFI / Partitioning

- `gdisk`
- `parted`
- `dosfstools`
- `efibootmgr`
- `nvme-cli`
- `smartmontools`

### C. Networking

- `network-manager`
- `wpasupplicant`
- `iw`
- `wireless-tools`
- `iproute2`
- `iputils-ping`
- `dnsutils`
- `ethtool`

### D. Hardware Diagnostics

- `pciutils`
- `usbutils`
- `lshw`
- `lm-sensors`

### E. ZFS / Install Substrate

- `zfsutils-linux`
- `zfs-dkms`
- `zfs-dracut`
- `dracut`
- `mmdebstrap`
- `dkms`
- `kmod`
- `binutils`

### F. Full Build Toolchain

#### C/C++

- `build-essential`
- `pkg-config`
- `make`
- `cmake`
- `cmake-doc`
- `ninja-build`
- `meson`
- `git`
- `clang`
- `lld`
- `gdb`
- `valgrind`
- `libssl-dev`

#### Rust

- `rustc`
- `cargo`

#### Python Build/Runtime

- `python3`
- `python3-pip`
- `python3-venv`
- `python3-dev`
- `python3-full`
- `python-is-python3`

### G. Podman / Container Runtime

- `podman`
- `buildah`
- `skopeo`
- `crun`
- `slirp4netns`
- `fuse-overlayfs`
- `netavark`
- `aardvark-dns`
- `passt`
- `containernetworking-plugins`

### H. NVIDIA Supported Overlay

#### Driver / Runtime

- `nvidia-kernel-open-dkms`
- `nvidia-driver`
- `nvidia-driver-cuda`
- `nvidia-persistenced`
- `libnvidia-egl-wayland1`
- `nvidia-container-toolkit`

#### CUDA Toolchain

- `cuda-toolkit-13-2`
- `cuda-libraries-13-2`
- `cuda-libraries-dev-13-2`
- `cuda-command-line-tools-13-2`
- `cuda-nvml-dev-13-2`

#### cuDNN

- `libcudnn9-cuda-13`
- `libcudnn9-dev-cuda-13`
- `libcudnn9-headers-cuda-13`

## Packages Intentionally Not Included

- No desktop/GUI packages (`sway`, `waybar`, `thunar`, etc.)
- No AI workstation runtime (Jupyter, PyTorch, `mistral.rs`, `ollama`, retained containers)
- No full AMD ROCm stack yet
- No full Intel GPU acceleration stack yet

Those belong to the installed target system, not the installer medium.

## AMD / Intel Posture

- **AMD:** detection only for v1 medium; no full ROCm live stack yet
- **Intel GPU:** detection only; CPU fallback supported; GPU acceleration experimental

These paths follow the same policy as the main installer.

## Future Expansion

A future `acabos-installer-heavy.iso` could optionally include:

- full AMD ROCm live path
- full Intel GPU live path
- pre-baked development environment
- additional rescue/forensic tooling