# Stage Reference

This document maps each installer stage to implemented behavior in `lib/stage_*.sh`.

Global resume rules:

- `success` stages are probe-checked before skip.
- `failed` and `in_progress` stages are re-run.
- FINALIZE always re-runs on resume (`probe_stage FINALIZE` returns non-zero).

## PREFLIGHT

- Verifies required host binaries.
- Enumerates `/dev/disk/by-id` candidates.
- Installs host backports cohort (`linux-image`, headers, ZFS, dracut).
- Installs host UI dependencies (`gum`, `fzf`).
- Enforces ABI cohort gate (headers, backports provenance, ZFS module/userspace match).
- Fetches NVIDIA CUDA keyring package and validates SHA256.
- Fetches NVIDIA container toolkit key.
- Copies NVIDIA keyring to host keyring path.
- Probe checks binaries, keyring integrity, backports availability, and ZFS ABI coherence.

## INPUT

- Selects target disk (interactive `fzf` preview when available).
- Generates and confirms pool name `ACABROOT-XXXX`.
- Prompts for hostname and username.
- Creates install ID and initializes state file.
- Probe validates required state fields and disk path.

## DISK_SAFETY

- Revalidates target disk path.
- Requires typed disk basename confirmation.
- Wipes disk (`sgdisk --zap-all`, `wipefs -a`).
- Exports/destroys imported pools as cleanup guard.
- Probe ensures expected post-wipe condition.

## ZFS_CREATE

- Creates GPT partitions: EFI + ZFS.
- Creates encrypted pool with fixed `ashift=12`.
- Builds datasets from `lib/topology.sh`.
- Sets bootfs to `${pool}/ROOT/acabos`.
- Creates 64G swap zvol `${pool}/swap`.
- Transitions temporary raw key to passphrase and shreds keyfile.
- Probe enforces exact dataset topology, property values, and encryption state.

## BASE_INSTALL

- Bootstraps target root via `mmdebstrap`.
- Seeds APT source, trust, and pinning configs.
- Installs base system packages, ZFS toolchain, Python toolchain, and UX tools.
- Mounts EFI and writes `/etc/fstab`.
- Writes ssh hardening and host baseline files.
- Runs DKMS autoinstall in chroot.
- Probe verifies target shell, kernel package, and boot artifacts.

## BOOT_CHAIN

- Installs ZFSBootMenu from source tarball.
- Installs dracut, ZBM config payloads, and `systemd-boot-efi` (UEFI stub provider).
- Installs NVIDIA modprobe/udev + performance sysctl + ZFS tuning files.
- Uses `generate-zbm` as the authoritative artifact generator.
- Generates bundled EFI artifact at `/EFI/zbm/zfsbootmenu.EFI`.
- Attempts best-effort EFI NVRAM registration via `efibootmgr` targeting `\EFI\zbm\zfsbootmenu.EFI`.
- Optionally creates `/EFI/BOOT/BOOTX64.EFI` as a compatibility-only fallback artifact.
- Validates bundle format and, when present, component initramfs `/init` + ZFS content.

## NVIDIA_BRINGUP

- Configures NVIDIA and container toolkit repos in target chroot.
- Installs Open DKMS driver, `nvidia-driver-cuda`, CUDA toolkit/libs, and runtime packages.
- Installs `nvidia-container-toolkit` and runtime config.
- Installs CUDA environment and ldconfig payloads.
- Enables `nvidia-persistenced` and `nvidia-power.service`.
- Performs build and runtime validation.
- Probe checks NVIDIA module files, toolkit install, and CUDA env file.

## PODMAN_SUBSTRATE

- Installs Podman/buildah/skopeo/networking stack in chroot.
- Installs container config payloads.
- Generates CDI spec as best effort.
- Probe runs `podman info` in chroot and checks config presence.

## DESKTOP_SUBSTRATE

- Installs packages listed in `config/desktop-packages.list`.
- Installs Sway/Waybar user defaults into `/etc/skel`.
- Installs `sway-nvidia` and `start-desktop` launch scripts.
- Appends aliases to `/etc/skel/.bashrc`.
- Creates user workspace directories under `/etc/skel`.
- Probe checks sway/waybar package and config presence.

## AI_SUBSTRATE

- Installs system AI packages from `config/ai-system-packages.list`.
- Installs `uv`, creates `/opt/ai-venv`, installs Python dependencies.
- Installs PyTorch from CUDA wheel index.
- Builds llama.cpp with CUDA architectures from `config/mistral.version`.
- Installs helper scripts (`model-manager`, `gpu-benchmark`, `ai-services`, `ai-shell`, `ai-stack`, `test-nvidia-container`).
- Installs quadlets and Jupyter server config.
- Probe validates venv, llama binary, and quadlet file presence.

## INFERENCE_SUBSTRATE

- Sources `config/cudnn.version` and `config/mistral.version`.
- Downloads and verifies cuDNN local repo package.
- Installs Rust toolchain and enforces minimum version.
- Builds `mistralrs-cli` from source via `cargo install`.
- Installs binary at `/opt/acab/bin/mistral-rs`.
- Writes model manifest, `acab-inference@.service`, and example profile scaffolding.
- Probe checks binary and cuDNN library presence.

## VALIDATION

- Mounts EFI into target.
- Bind-mounts installer tree into chroot runtime path.
- Runs `doctor/acabos-doctor` in pre-finalize mode (`ACABOS_DOCTOR_PRE_FINALIZE=true`).
- Fails stage if any severity `fail` doctor checks fail.

## FINALIZE

- Prompts for user password (or uses `ACABOS_USER_PASSWORD`).
- Creates non-root user and required groups.
- Sets password and forces first-login password rotation (`chage -d 0`).
- Locks root account.
- Prepares user configuration ownership and installs first-boot/runtime scaffolding.
- Installs sudoers, first-boot service/script, MOTD, and `/etc/issue`.
- Generates install manifest and copies logs/manifest into target.
- Runs cleanup and exports pool.
