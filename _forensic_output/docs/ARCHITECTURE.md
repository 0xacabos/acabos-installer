# ARCHITECTURE

## Execution Graph (Observed)

`acabos-install`
-> `lib/common.sh` + `lib/topology.sh` + `lib/detect_virt.sh` + `lib/probes.sh`
-> stage modules in strict order
-> `doctor/acabos-doctor` (during VALIDATION)
-> manifest generation (`config/manifest-template.jq`) in FINALIZE

## Control Boundaries

- Boundary A (Host live environment): destructive disk operations, pool imports/exports, key fetches, apt index on host.
- Boundary B (Target chroot): package/bootstrap/build/write operations under `/mnt/install`.
- Boundary C (Post-install runtime): doctor checks, generated system services, copied artifacts.

## Implicit Contracts and Assumptions

- `/dev/disk/by-id` exists and provides stable identifiers.
- `jq` is present and functional for all state/manifest writes.
- `/mnt/install` is the active altroot target mount.
- NVIDIA and cuDNN repos remain reachable and expected package names remain valid.
- `cargo install mistralrs-cli@<version>` remains compatible with selected Rust and CUDA stack.

## Coupling Points

- Tight coupling between stage code and specific path constants (`/mnt/install`, `/opt/acab`, `/etc/...`).
- Tight coupling between config file names and stage copy/install steps.
- Tight coupling between doctor checks and final filesystem layout.
- Tight coupling between version pins (`config/cudnn.version`, `config/mistral.version`) and build/install behavior.

## Semantic Classification

### Domain

- Primary domain: installer/provisioning system for AI workstation runtime.
- Secondary domains: boot-chain provisioning, GPU enablement, container orchestration substrate, local inference substrate, compliance/invariant validation.

### Criticality

- `MISSION_CRITICAL`: `acabos-install`, `lib/common.sh`, destructive storage stages, boot-chain stage, finalization stage.
- `DEGRADED`: desktop and AI convenience substrate stages (`lib/stage_desktop.sh`, `lib/stage_ai.sh`) in relation to baseline bootability.
- `NON_CRITICAL`: visual/UI helper scripts (`config/waybar/scripts/nvidia.sh`, `config/start-desktop`) for core system bring-up.
- `LIFE_CRITICAL`: none evidenced.

### ACABOS Alignment Mapping

- Governed Execution Plane: `acabos-install` + state machine in `lib/common.sh`.
- Policy Evaluation: `doctor/acabos-doctor` invariant checks and severity handling.
- Trust/Attestation: key/hash verification (`config/nvidia-keyring.sha256`, cuDNN SHA check, log SHA256 generation).
- Storage (ZFS/state): `lib/topology.sh`, `lib/stage_zfs_create.sh`, state JSON/log artifacts.
- Runtime/Orchestration: NVIDIA + Podman + inference + quadlets (`lib/stage_nvidia_bringup.sh`, `lib/stage_podman.sh`, `lib/stage_inference.sh`, `config/quadlets/*`).
- Interface (TUI/API): CLI prompts in `acabos-install`/stages and local inference service unit in `lib/stage_inference.sh`.
