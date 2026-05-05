# EXECUTION MODEL

## Procedural Flow (Installer)

1. `acabos-install` loads shared modules and stage implementations.
2. CLI options set `ACABOS_SKIP_GPU_VALIDATION`, `ACABOS_DEV_MODE`, resume behavior, and shell entry behavior.
3. Non-resume path: iterate `STAGE_ORDER` and execute `run_stage_with_state(stage, function)`.
4. Resume path: read persisted state, probe current stage with `probe_stage`, then continue from computed point.
5. Each stage wraps execution with state updates (`in_progress`, `success`, `failed`), stage-specific log files, and retry/shell/abort recovery prompts.
6. Final success emits completion message.

## State Model

State file location: `state/install-state.json`.

Observed fields initialized by `state_init()`:

- `state_version`
- `install_id`
- `current_stage`
- `pool_name`
- `target_disk`
- `hostname`
- `username`
- `stages` (per-stage execution metadata)

Per-stage transitions:

- Start: `status=in_progress`, `started_at=<iso8601>`
- Success: `status=success`, `ended_at=<iso8601>`
- Failure: `status=failed`, `ended_at=<iso8601>`, `error=<detail>`

## Re-entry Probe Model

- Probe dispatcher: `probe_stage()` in `lib/probes.sh`.
- Probe success (`0`) means stage can be skipped during resume.
- Probe failure means state and on-disk reality diverge; operator gets recovery options.
- ZFS probe performs bidirectional topology verification and property drift detection.

## Doctor Validation Model

- Check registry (`CHECKS`) maps invariant IDs to functions.
- Dependency graph (`CHECK_DEPS`) enforces prerequisite checks.
- Result statuses observed: `pass`, `warn`, `fail`, `skip`.
- Skip semantics: failed prerequisite marks dependent checks as `skip`.
- Exit code policy: non-zero if any `fail` is present.

## Execution Roles by Module

- `lib/common.sh`: runtime substrate (timeouts, logging, state persistence, chroot management).
- `lib/topology.sh`: declarative topology materialization for ZFS stage/probe consistency.
- `lib/detect_virt.sh`: context sensor used by GPU validation logic.
- `lib/probes.sh`: resume-gating probe adapters and stage-level verification.
- `lib/stage_*.sh`: side-effecting installation stages.
- `doctor/acabos-doctor`: post-install (and pre-finalize) invariant checker.
