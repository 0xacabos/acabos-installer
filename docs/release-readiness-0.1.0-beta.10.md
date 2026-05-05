# ACABOS Release Readiness - 0.1.0-beta.10 (Draft)

Based on evidence gathered during canonical BOOT_CHAIN validation and a full installer run completed on 2026-04-21.

## Release Metadata

- Release tag: `0.1.0-beta.10` (draft)
- Channel: beta
- Date (UTC): 2026-04-21
- Prepared by: OpenCode
- Installer commit/ref: workspace snapshot after beta.10 packaging
- Notes link: `docs/release-notes-0.1.0-beta.10.md`

## Target Matrix

| Host ID | CPU | GPU | RAM | NVMe | Firmware | Secure Boot | Result |
|---|---|---|---|---|---|---|---|
| primary-dev-rig | x86_64 | NVIDIA RTX 4070 class | 32 GB | Samsung 990 EVO 2TB | UEFI | not recorded | PASS |
| secondary host | pending | pending | pending | pending | pending | pending | pending |

## Gate 1: Security Baseline (Must Pass)

- [x] No hardcoded installer credentials in stage code.
- [x] User password flow matches docs and runtime output.
- [x] Root lock and sudo policy match documented behavior.
- [x] APT trust is keyring-scoped only (`signed-by=`, `--keyring=`).
- [x] No unauthenticated package path is enabled.

Status: **PASS**

Evidence:
- `FINALIZE` required explicit non-interactive password input when TTY was unavailable (`ACABOS_USER_PASSWORD`).
- Root account lock path executed during `FINALIZE`.

## Gate 2: Stage Machine Correctness (Must Pass)

- [x] `STAGE_ORDER` matches docs.
- [x] Each stage has exactly one probe.
- [x] Successful-stage probes are skip-safe.
- [x] Resume from each stage boundary advances correctly (validated across repeated BOOT_CHAIN retries).
- [x] `FINALIZE` resume behavior documented.

Status: **PASS (with noted design tradeoff)**

Evidence:
- `state/install-state.json` shows successful progression through all 13 stages.
- `FINALIZE` still intentionally re-runs on resume by probe design.

## Gate 3: Idempotency and Recovery (Must Pass)

- [x] Repeat `--resume` after transient failures is safe.
- [x] Chroot mount/unmount is balanced on success/failure paths.
- [x] EFI and pool import/export remain consistent after retries.
- [x] All stage logs and SHA256 sidecars are present.

Status: **PASS**

Evidence:
- BOOT_CHAIN was resumed multiple times while fixing edge cases (`generate-zbm` detection, EFI remount, initramfs validation, EFI registration behavior) and then completed successfully.

## Gate 4: Hardware Matrix (Must Pass)

- [ ] At least 2 NVMe models validated.
- [ ] At least 2 NVIDIA generations validated.
- [ ] Secure Boot handling validated or documented unsupported.
- [x] Doctor runtime/container checks pass on physical hosts.

Status: **FAIL (coverage gap)**

Evidence:
- Strong validation evidence on one host and one NVMe/GPU combination only.

## Gate 5: Performance and Build Determinism (Should Pass)

- [x] CUDA arch/cap settings are config-driven.
- [x] Build logs include selected architecture/capability.
- [ ] No `-arch=native` fallback warnings in release runs.

Status: **PARTIAL**

Evidence:
- Build logs showed configured compute capability in inference build flow.
- Determinism warning-free evidence still needs dedicated capture for signoff.

## Bootability Hardening Evidence

- [x] Authoritative ZFSBootMenu bundle exists at `/EFI/zbm/zfsbootmenu.EFI`.
- [x] EFI fallback loader exists at `/EFI/BOOT/BOOTX64.EFI` (compatibility-only).
- [x] BOOT_CHAIN uses `generate-zbm` bundle generation and prunes non-authoritative backups.
- [x] Probe logic validates `/EFI/zbm/zfsbootmenu.EFI` and optional component initramfs artifacts.

Evidence:
- `file` confirms `/EFI/zbm/zfsbootmenu.EFI` is a PE32+ EFI executable.
- EFI contents verified:
  - `/EFI/zbm/zfsbootmenu.EFI`
  - `/EFI/zbm/zfsbootmenu-bootmenu`
  - `/EFI/zbm/initramfs-bootmenu.img`
  - `/EFI/BOOT/BOOTX64.EFI`
- `efibootmgr -v` did not expose an ACABOS entry in this runtime; BOOT_CHAIN now handles EFI registration as best-effort.

## Gate 6: Observability and Forensics (Must Pass)

- [x] Per-stage logs include timestamps and severity.
- [x] Manifest and logs copied to target system.
- [x] Doctor summary includes pass/fail/warn/skip counts.

Status: **PASS**

Evidence:
- `VALIDATION` doctor summary: `17 pass, 0 fail, 4 warn, 1 skip`.
- `FINALIZE` completed manifest/log copy and pool export.

## Gate 7: Documentation Fidelity (Must Pass)

- [x] README matches current stage count/options.
- [x] Architecture and stage-reference docs match code.
- [x] Known non-ideal behavior documented.
- [x] Behavior changes include doc updates in same PR/session.

Status: **PASS**

Evidence:
- Updated docs include architecture, stage reference, release notes, and readiness docs for canonical bundled-EFI boot behavior.

## Exception / Waiver Log

| Gate | Exception | Risk | Owner | Expiry | Approval |
|---|---|---|---|---|---|
| Gate 2 | FINALIZE intentionally re-runs on resume | low/moderate operator surprise | maintainer | next probe-hardening cycle | pending |
| Gate 4 | Single-host validation coverage | moderate release confidence risk | maintainer | before stable candidate | pending |

## Final Decision

- Production bare-metal: **FAIL** (Gate 4 blocker)
- Controlled lab/dev: **PASS with waiver**
- Decision owner: pending maintainer signoff
- Decision date (UTC): pending
- Follow-up actions:
  1. Validate on second NVMe model and second NVIDIA generation.
  2. Record Secure Boot support stance (validated or explicitly unsupported).
  3. Capture dedicated determinism evidence with no `-arch=native` fallback warnings.
