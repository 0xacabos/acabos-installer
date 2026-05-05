# SYSTEM OVERVIEW

## Observed Facts

- Workspace contains an executable Bash installer entrypoint (`acabos-install`) and stage modules (`lib/stage_*.sh`) implementing a resumable state machine.
- Stage sequence implemented in code is 13 stages: `PREFLIGHT -> INPUT -> DISK_SAFETY -> ZFS_CREATE -> BASE_INSTALL -> BOOT_CHAIN -> NVIDIA_BRINGUP -> PODMAN_SUBSTRATE -> DESKTOP_SUBSTRATE -> AI_SUBSTRATE -> INFERENCE_SUBSTRATE -> VALIDATION -> FINALIZE`.
- Persistent installer state is stored in `state/install-state.json` (created at runtime) and manipulated via `jq` utilities in `lib/common.sh`.
- Re-entry/skip logic is implemented by per-stage probes in `lib/probes.sh` and dispatched by `probe_stage()`.
- Target system root during installation is `/mnt/install`; chroot operations and bind mounts are centralized in `lib/common.sh`.
- Post-install invariant checking is implemented by `doctor/acabos-doctor` as a dependency-aware check graph with skip semantics.

## Component Inventory

- Orchestration code: `acabos-install`, `lib/common.sh`, `lib/probes.sh`, `lib/topology.sh`, `lib/detect_virt.sh`.
- Stage implementations: `lib/stage_preflight.sh`, `lib/stage_input.sh`, `lib/stage_disk_safety.sh`, `lib/stage_zfs_create.sh`, `lib/stage_base_install.sh`, `lib/stage_boot_chain.sh`, `lib/stage_nvidia_bringup.sh`, `lib/stage_podman.sh`, `lib/stage_desktop.sh`, `lib/stage_ai.sh`, `lib/stage_inference.sh`, `lib/stage_validation.sh`, `lib/stage_finalize.sh`.
- Runtime validator: `doctor/acabos-doctor`.
- Declarative config set under `config/` (APT, kernel/boot, NVIDIA, Podman, quadlets, desktop, service units, template data).
- Documentation set: `README.md`, `CONTRIBUTING.md`, `docs/architecture.md`, `docs/stage-reference.md`.

## Execution Boundaries (Observed)

- Host live environment boundary: package index updates, key fetches, block-device operations, ZFS pool management.
- Target chroot boundary (`/mnt/install`): package installs, file deployment, service enablement, runtime component build/install.
- Post-install boundary: exported pool and persisted artifacts (`/opt/acab/manifests/install-manifest.json`, copied logs).

## No-Inference Notes

- This document only records structures and behavior directly visible in workspace files.
- Intent, recommendations, and drift findings are isolated in other forensic outputs.
