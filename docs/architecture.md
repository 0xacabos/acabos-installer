# Architecture

## Runtime Model

The installer is a Bash state machine orchestrated by `acabos-install`.

- Ordered stages are defined by `STAGE_ORDER` in `acabos-install`.
- State is persisted to `state/install-state.json`.
- Resume safety uses stage re-entry probes in `lib/probes.sh`.

### Stage Order

```text
PREFLIGHT -> INPUT -> DISK_SAFETY -> ZFS_CREATE -> BASE_INSTALL
-> BOOT_CHAIN -> NVIDIA_BRINGUP -> PODMAN_SUBSTRATE -> DESKTOP_SUBSTRATE
-> AI_SUBSTRATE -> INFERENCE_SUBSTRATE -> VALIDATION -> FINALIZE
```

## Version Constants

Defined in `lib/common.sh`:

- `STATE_VERSION="acabos-install-state/v1"`
- `TOPOLOGY_VERSION="acabos-zfs-topology/v2"`
- `DOCTOR_SCHEMA_VERSION="acabos-doctor-invariants/v2"`

The doctor binary (`doctor/acabos-doctor`) also declares `DOCTOR_SCHEMA="acabos-doctor-invariants/v2"`.

## State and Resume

State carries install metadata and per-stage status/timestamps:

- `state_version`, `install_id`, `current_stage`
- `pool_name`, `target_disk`, `hostname`, `username`
- `.stages.<STAGE>.status`, `.started_at`, `.ended_at`

Resume semantics:

- `success` stages are probe-checked before skip.
- `failed` and `in_progress` stages are re-run.
- `FINALIZE` probe always returns non-zero, so FINALIZE re-runs on resume.

## Prompting and UX

Prompt primitives live in `lib/common.sh`:

- `prompt_confirm`, `prompt_yn`, `prompt_text`, `prompt_select`, `prompt_password`
- `prompt_select_disk` uses `fzf` preview in interactive TTY mode
- `gum` and `fzf` are optional at runtime but installed by PREFLIGHT

## Storage Topology

`lib/topology.sh` defines 19 datasets/zvol targets under pool `ACABROOT-XXXX`.

Top-level shape:

- `${pool}/ROOT/acabos` mounted at `/` (`canmount=noauto`)
- `${pool}/opt/acab/{models,state,logs}`
- `${pool}/opt/ai-venv`, `${pool}/opt/llama-cpp`
- `${pool}/var/lib/containers`, `${pool}/var/lib/acab`
- `${pool}/var/log`, `${pool}/var/cache`, `${pool}/var/tmp`
- `${pool}/home`
- `${pool}/swap` zvol (64G created in ZFS_CREATE)

Policy constraints:

- Fixed `ashift=12`
- No `org.zfsbootmenu:keysource`
- Temporary keyfile is shredded after passphrase transition
- Encryption ends as `keyformat=passphrase`, `keylocation=prompt`

## Boot Chain

BOOT_CHAIN configures and validates:

- dracut: `config/dracut.conf.d/zfs.conf`
- ZFSBootMenu: `config/zfsbootmenu-config.yaml`
- UEFI stub provider: `systemd-boot-efi` in target chroot
- NVIDIA modprobe/udev policies and sysctl tuning
- EFI payload generation under `/boot/efi/EFI/zbm` via `generate-zbm`

Boot registration behavior:

- Attempts best-effort NVRAM entry registration via `efibootmgr` to `\EFI\zbm\zfsbootmenu.EFI` when EFI runtime variables are available.
- Uses bundled EFI artifact (`zfsbootmenu.EFI`) as authoritative boot path.
- Optional `/EFI/BOOT/BOOTX64.EFI` is treated as compatibility-only fallback.

This avoids dependence on firmware `initrd=` argument handling in direct EFI-stub kernel launches.

## Package and Trust Model

APT trust is explicit and keyring-scoped.

- Host preflight installs backports cohort and keyrings.
- Host does not add NVIDIA repo sources in PREFLIGHT.
- Target chroot gets NVIDIA/CUDA and container toolkit sources during NVIDIA_BRINGUP.
- cuDNN installs during `INFERENCE_SUBSTRATE` and is validated against the target CUDA/runtime matrix.
- PyTorch is installed from a pinned wheel index selected independently of the host toolkit version and validated against the ACABOS driver/runtime matrix.

## Substrate Layers

- NVIDIA_BRINGUP: Open DKMS driver, `nvidia-driver-cuda`, CUDA stack, container toolkit, runtime validation
- PODMAN_SUBSTRATE: Podman runtime for retained support services (`qdrant`, `localai`, `comfyui`)
- DESKTOP_SUBSTRATE: Sway/Waybar and `/etc/skel` user environment
- AI_SUBSTRATE: `/opt/ai-venv`, PyTorch stack, llama.cpp, Jupyter config, and retained container definitions
- INFERENCE_SUBSTRATE: cuDNN + Rust + source build of mistral.rs to `/opt/acab/bin/mistral-rs`

## Supported Runtime Split

The supported default stack is intentionally narrow:

- Native services:
  - `mistral.rs`
  - `ollama`
  - `jupyter`
- Containerized services:
  - `qdrant`
  - `localai`
  - `comfyui`

Other previously shipped AI services are not part of the default supported install surface.

## Validation and Finalization

VALIDATION runs `doctor/acabos-doctor` inside chroot with `ACABOS_DOCTOR_PRE_FINALIZE=true`.

FINALIZE performs:

- Non-root user creation and password setup
- Forced password rotation (`chage -d 0`)
- Root account lock
- First-boot service installation
- Manifest generation via `config/manifest-template.jq`
- Stage log and manifest copy into target filesystem
- Pool export

After installation, the first-boot service performs runtime provisioning on the live system:

- machine identity regeneration
- SSH host key regeneration
- container runtime/CDI validation on the running kernel
- sequential pull and smoke validation of retained containerized services
- readiness reporting and selective enablement of passing services

## Doctor System

`doctor/acabos-doctor` executes 22 checks across 7 domains:

- storage, boot, graphics, runtime, desktop, system, manifest

Checks use dependency-based skip semantics to prevent cascade noise.
