# ACABOS Release Readiness Template

Use this template for each alpha/beta/release-candidate build.

## Release Metadata

- Release tag:
- Channel: alpha / beta / rc / stable
- Date (UTC):
- Prepared by:
- Installer commit/ref:
- Notes link:

## Target Matrix

| Host ID | CPU | GPU | RAM | NVMe | Firmware | Secure Boot | Result |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
| | | | | | | | |

## Gate 1: Security Baseline (Must Pass)

- [ ] No hardcoded installer credentials in stage code.
- [ ] User password flow matches docs and runtime output.
- [ ] Root lock and sudo policy match documented behavior.
- [ ] APT trust is keyring-scoped only (`signed-by=`, `--keyring=`).
- [ ] No unauthenticated package path is enabled.

Evidence:
- Command/output references:
- Log references:

## Gate 2: Stage Machine Correctness (Must Pass)

- [ ] `STAGE_ORDER` matches docs.
- [ ] Each stage has exactly one probe.
- [ ] Successful-stage probes are skip-safe.
- [ ] Resume from each stage boundary advances correctly.
- [ ] `FINALIZE` resume behavior documented.

Evidence:
- Resume test matrix link:
- Probe matrix link:

## Gate 3: Idempotency and Recovery (Must Pass)

- [ ] Repeat `--resume` after transient failures is safe.
- [ ] Chroot mount/unmount is balanced on success/failure paths.
- [ ] EFI and pool import/export remain consistent after retries.
- [ ] All stage logs and SHA256 sidecars are present.

Evidence:
- Retry run logs:
- Integrity checks:

## Gate 4: Hardware Matrix (Must Pass)

- [ ] At least 2 NVMe models validated.
- [ ] At least 2 NVIDIA generations validated.
- [ ] Secure Boot handling validated or documented unsupported.
- [ ] Doctor runtime/container checks pass on physical hosts.

Evidence:
- Host reports:
- Doctor outputs:

## Gate 5: Performance and Build Determinism (Should Pass)

- [ ] CUDA arch/cap settings are config-driven.
- [ ] Build logs include selected architecture/capability.
- [ ] No `-arch=native` fallback warnings in release runs.

Evidence:
- Build log excerpts:
- Config pin references:

## Gate 6: Observability and Forensics (Must Pass)

- [ ] Per-stage logs include timestamps and severity.
- [ ] Manifest and logs copied to target system.
- [ ] Doctor summary includes pass/fail/warn/skip counts.

Evidence:
- `/opt/acab/logs/install/` verification:
- `/opt/acab/manifests/` verification:

## Gate 7: Documentation Fidelity (Must Pass)

- [ ] README matches current stage count/options.
- [ ] Architecture and stage-reference docs match code.
- [ ] Known non-ideal behavior documented.
- [ ] Behavior changes include doc updates in same PR.

Evidence:
- Doc diff references:

## Exception / Waiver Log

| Gate | Exception | Risk | Owner | Expiry | Approval |
|---|---|---|---|---|---|
| | | | | | |

## Final Decision

- Production bare-metal: PASS / FAIL
- Controlled lab/dev: PASS / FAIL
- Decision owner:
- Decision date (UTC):
- Follow-up actions:
