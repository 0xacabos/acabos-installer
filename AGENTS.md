# ACABOS Installer Agent Guide

## Commands

- Run installer: `sudo ./acabos-install [--resume] [--skip-gpu-validation] [--shell]`
- Validate install: `sudo /opt/acab/doctor/acabos-doctor`
- Lint shell: `bash -n <file>`
- Validate version config: `source config/<name>.version`

## Architecture

- 13 ordered stages are defined by `STAGE_ORDER` in `acabos-install` and are authoritative.
- State is persisted in `state/install-state.json` and version-gated by `STATE_VERSION`.
- `lib/topology.sh` must be called with `build_topology "$pool_name"` before using topology globals.
- Doctor executes 22 checks across 7 domains with dependency-based skip semantics.
- `DOCTOR_SCHEMA_VERSION` in `common.sh` and `DOCTOR_SCHEMA` in `doctor/acabos-doctor` are both `acabos-doctor-invariants/v2`.

## Constraints

- Pool name format: `ACABROOT-XXXX`.
- Disk operations use `/dev/disk/by-id` only.
- APT trust must be explicit (`--keyring`, `signed-by`) with no ambient trust.
- NVIDIA/CUDA packages are sourced from NVIDIA repositories in target chroot.
- ZFS encryption must end in `keylocation=prompt` with no persistent keyfile.
- Increment `TOPOLOGY_VERSION` when topology structure changes.

## Code Conventions

- Script guard: `set -Eeuo pipefail` and `IFS=$'\n\t'`.
- Logging helpers: `log`, `warn`, `err`, `fail`.
- Timeouts: always use `run_timeout` with shared timeout constants.
- Dynamic dispatch: associative arrays, never `eval`.
- Stage state lifecycle: `state_set_stage` -> `state_complete_stage` or `state_fail_stage`.

## Adding a Stage

1. Create `lib/stage_<name>.sh` with `run_<name>()`.
2. Add probe in `lib/probes.sh` and register in `probe_stage()`.
3. Add to `STAGE_ORDER` and `STAGE_FUNCS` in `acabos-install`.
4. Source the new stage file in `acabos-install`.
5. Add doctor checks if new invariants are introduced.
6. Update `docs/stage-reference.md`.

## Runtime Gotchas

- Per-stage logs are hashed to `state/logs/<STAGE>.log.sha256`.
- `prepare_dataset_rerun` exists for BASE_INSTALL retries without repartitioning.
- FINALIZE probe returns non-zero by design, so FINALIZE re-runs on resume.
- Pool busy conditions between reruns can require reboot.
- Live environment must have matching kernel headers and loaded ZFS module before destructive stages.
