# ACABOS Installer

ACABOS Installer is a stateful Bash installer for building a Debian Trixie AI workstation on encrypted ZFS.

## What It Builds

- Encrypted ZFS root (`aes-256-gcm`, passphrase unlock at boot)
- ZFSBootMenu boot flow generated with dracut
- NVIDIA Open DKMS driver + `nvidia-driver-cuda` + CUDA 13.2 + cuDNN 9.19.0
- Native AI runtime stack:
  - `mistral.rs`
  - `ollama`
  - `jupyter` on `/opt/ai-venv`
- Containerized support services:
  - `qdrant`
  - `localai`
  - `comfyui`

## Target Platform

| Component | Requirement |
|---|---|
| CPU | x86_64 |
| GPU | NVIDIA Ada Lovelace target (compute capability 8.9) |
| RAM | 32 GB minimum |
| Boot | UEFI |
| Disk | Install target selected from `/dev/disk/by-id` |

Compute capability is configured in `config/mistral.version` (`MISTRAL_CUDA_COMPUTE_CAP=89`, `LLAMA_CUDA_ARCHITECTURES=89`).

## CLI

```text
Usage: ./acabos-install [OPTIONS]

Options:
  --resume              Resume interrupted install
  --skip-gpu-validation Skip NVIDIA runtime validation (for VM/lab)
  --shell               Drop to recovery shell before starting
  --help                Show this help
```

## Quick Start

```bash
sudo ./acabos-install
sudo ./acabos-install --resume
sudo ./acabos-install --skip-gpu-validation
sudo ./acabos-install --shell
sudo ACABOS_USER_PASSWORD='choose-a-strong-password' ./acabos-install --resume
```

## Stage Pipeline

The installer runs 13 ordered stages:

```text
PREFLIGHT -> INPUT -> DISK_SAFETY -> ZFS_CREATE -> BASE_INSTALL
-> BOOT_CHAIN -> NVIDIA_BRINGUP -> PODMAN_SUBSTRATE -> DESKTOP_SUBSTRATE
-> AI_SUBSTRATE -> INFERENCE_SUBSTRATE -> VALIDATION -> FINALIZE
```

- Stages marked `success` are probe-checked before resume skip.
- Failed or in-progress stages are re-run.
- `FINALIZE` is conservative and re-runs on resume by design (`probe_stage FINALIZE` returns non-zero).

## Post-Install

1. Reboot.
2. In ZFSBootMenu, unlock the pool passphrase.
3. Login as the configured non-root user.
4. Change password on first login (forced by `chage -d 0`).
5. Allow the first-boot provisioning service to complete runtime validation.
6. Validate with:

```bash
sudo /opt/acab/doctor/acabos-doctor
```

## Runtime Activation Model

ACABOS uses a two-step activation model:

1. The installer assembles the target system, installs runtimes, and writes service definitions.
2. First boot performs runtime validation on the actual hardware, validates retained container services,
   and enables only the services that pass.

This keeps the install image coherent while deferring GPU/container truth to the live system.

## Repository Layout

```text
acabos-install                 # entrypoint + stage orchestration
lib/common.sh                  # logging, state, prompt, timeout, chroot helpers
lib/topology.sh                # dataset topology and ZFS property model
lib/probes.sh                  # resume re-entry probes
lib/stage_*.sh                 # stage implementations
lib/detect_virt.sh             # physical vs virtual runtime detection
doctor/acabos-doctor           # invariant checker (22 checks, 7 domains)
config/                        # installer and runtime config payloads
docs/                          # architecture, stage reference, release docs
state/                         # runtime state, logs, generated manifest
release-artifacts/             # packaged installer release tarballs + checksums
```

## Config Inventory

`config/` contains 34 entries across APT, boot chain, NVIDIA, desktop, Podman, AI, and finalization.

See `docs/config-reference.md` for full per-file ownership and stage usage.

## Documentation

- `docs/architecture.md`
- `docs/stage-reference.md`
- `docs/config-reference.md`
- `docs/platform-primitive-spec.md`
- `docs/implementation-roadmap.md`
- `docs/glossary.md`
- `docs/test-checklist.md`
- `docs/deployment-readiness.md`
- `docs/release-readiness-template.md`
- `CONTRIBUTING.md`
- `AGENTS.md`

## Installer Medium

- `media/medium-design.md`
- `media/live-package-manifest.md`
- `media/text-launcher-spec.md`
- `media/build-medium.sh`
- `media/purge-build-artifacts.sh`

Historical changelog is archived at `CHANGES.md.archive`.
