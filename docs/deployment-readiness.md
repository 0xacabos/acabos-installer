# Deployment Readiness

This checklist is the release gate for bare-metal deployment.

Use this file as a pass/fail rubric, not guidance-only prose.

For a fillable release artifact, use `docs/release-readiness-template.md`.

## Scope

- Target: physical x86_64 UEFI systems with NVIDIA GPUs.
- Goal: deterministic unattended install with resumability and auditable outcomes.

## Gate 1: Security Baseline (Must Pass)

- No hardcoded installer credentials in any stage code.
- User password flow is explicit and enforced as documented.
- Root lock and sudo policy behavior match docs and runtime output.
- APT trust remains keyring-scoped only (`signed-by=`, `--keyring=`).
- No ambient trust overrides or unauthenticated package paths.

Evidence:
- `grep` over `lib/` and `config/` for static passwords/tokens.
- Install logs showing keyring-scoped APT operations.

## Gate 2: Stage Machine Correctness (Must Pass)

- `STAGE_ORDER` in `acabos-install` matches `docs/stage-reference.md`.
- Every stage has exactly one re-entry probe.
- Probes for successful stages are skip-safe and deterministic.
- Resume from each stage boundary produces expected next stage.
- `FINALIZE` resume behavior is explicitly documented (currently re-runs).
- PREFLIGHT ABI cohort gate is enforced as a hard pre-destructive invariant.

Evidence:
- Table test: force stop after each stage, run `--resume`, record outcome.
- Probe pass/fail matrix stored with release artifacts.
- Preflight log captures kernel/headers/ZFS module/userspace ABI gate report.

## Gate 3: Idempotency and Recovery (Must Pass)

- Re-running `--resume` after transient failures does not corrupt target state.
- Chroot mount/unmount paths are balanced in success and failure branches.
- EFI artifacts and pool import/export behavior remain consistent after retries.
- Stage logs are generated for each attempt with SHA256 sidecars.

Evidence:
- At least 3 full install+resume stress runs on one host.
- Verify `state/logs/*.log` and `state/logs/*.log.sha256` for each stage.

## Gate 4: Hardware Matrix (Must Pass)

- Validate on at least:
  - 2 NVMe models
  - 2 NVIDIA generations (target + one adjacent generation)
  - 1 system with Secure Boot off (or documented unsupported state)
- Validate GPU runtime and container runtime checks via `acabos-doctor`.

Evidence:
- Per-host install reports with doctor output attached.

## Gate 5: Performance and Build Determinism (Should Pass)

- CUDA arch settings are config-driven and explicit.
- ZFS pool policy is explicit and documented (`ashift=12` fixed across supported drive classes).
- `mistral.rs` and `llama.cpp` build paths log architecture/capability used.
- No fallback warnings indicating unknown GPU architecture in release runs.

Evidence:
- Build logs free of `-arch=native` fallback warnings.
- Config pins recorded in release notes (`config/*.version`).
- Storage policy reference present in `README.md` and `docs/architecture.md`.

## Gate 6: Observability and Forensics (Must Pass)

- Per-stage timestamps, status transitions, and errors are visible in logs.
- Install manifest and logs are copied into target system at finalize.
- Doctor results are recorded and include pass/fail/warn/skip counts.

Evidence:
- Verify `/opt/acab/logs/install/` and `/opt/acab/manifests/` in target.

## Gate 7: Documentation Fidelity (Must Pass)

- README stage count/options match current code.
- `docs/architecture.md` and `docs/stage-reference.md` match implementation.
- Known non-ideal behavior is documented as intentional or as a TODO.
- Behavior changes include docs updates in the same PR.

Evidence:
- Release PR checklist includes explicit doc-drift signoff.

## Release Decision

- Production bare-metal: all Must Pass gates pass.
- Controlled lab/dev deployment: Security Baseline + Stage Machine Correctness must pass; remaining failures require explicit waiver.
