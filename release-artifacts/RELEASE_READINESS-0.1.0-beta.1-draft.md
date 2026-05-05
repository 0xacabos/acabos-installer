# ACABOS Release Readiness - 0.1.0-beta.1 (Draft)

Based on evidence gathered during `0.1.0-alpha.2` validation runs.

## Release Metadata

- Release tag: `0.1.0-beta.1` (draft)
- Channel: beta
- Date (UTC): 2026-04-20
- Prepared by: OpenCode
- Installer commit/ref: workspace snapshot after alpha.2 packaging
- Notes link: `docs/release-notes-0.1.0-alpha.2.md`

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
- `lib/stage_finalize.sh` now prompts for password or consumes `ACABOS_USER_PASSWORD`.
- `lib/stage_base_install.sh` no longer seeds a static root password.
- `passwd -l root` path observed in FINALIZE logs.

## Gate 2: Stage Machine Correctness (Must Pass)

- [x] `STAGE_ORDER` matches docs.
- [x] Each stage has exactly one probe.
- [x] Successful-stage probes are skip-safe.
- [x] Resume from each stage boundary advances correctly (validated on active failure points).
- [x] `FINALIZE` resume behavior documented.

Status: **PASS (with noted design tradeoff)**

Evidence:
- Docs aligned in `README.md`, `docs/architecture.md`, `docs/stage-reference.md`.
- Resume runs confirmed re-entry probe behavior and safe re-runs.

## Gate 3: Idempotency and Recovery (Must Pass)

- [x] Repeat `--resume` after transient failures is safe.
- [x] Chroot mount/unmount is balanced on success/failure paths.
- [x] EFI and pool import/export remain consistent after retries.
- [x] All stage logs and SHA256 sidecars are present.

Status: **PASS**

Evidence:
- Multiple stage retries during AI/INFERENCE/VALIDATION convergence.
- Log sidecars present under `state/logs/*.sha256` and copied to target.

## Gate 4: Hardware Matrix (Must Pass)

- [ ] At least 2 NVMe models validated.
- [ ] At least 2 NVIDIA generations validated.
- [ ] Secure Boot handling validated or documented unsupported.
- [x] Doctor runtime/container checks pass on physical hosts.

Status: **FAIL (coverage gap)**

Evidence:
- Strong evidence on one primary host only.

## Gate 5: Performance and Build Determinism (Should Pass)

- [x] CUDA arch/cap settings are config-driven.
- [x] Build logs include selected architecture/capability.
- [ ] No `-arch=native` fallback warnings in release runs.

Status: **PARTIAL**

Evidence:
- `config/mistral.version` now carries `MISTRAL_CUDA_COMPUTE_CAP` and `LLAMA_CUDA_ARCHITECTURES`.
- Historical fallback warnings observed prior to pinning; need clean confirmation run for beta evidence.

## Bootability Hardening Evidence

- [x] Authoritative ZFSBootMenu bundle exists at `/EFI/zbm/zfsbootmenu.EFI`.
- [x] EFI fallback loader exists at `/EFI/BOOT/BOOTX64.EFI` (compatibility-only).
- [x] BOOT_CHAIN uses `generate-zbm` bundle generation and prunes non-authoritative backups.
- [x] Probe logic validates `/EFI/zbm/zfsbootmenu.EFI` and optional component initramfs artifacts.

Evidence:
- Runtime verification on target host showed bundled EFI artifact generated and readable as PE/COFF.
- EFI contents verified with:
  - `/EFI/zbm/zfsbootmenu.EFI`
  - `/EFI/zbm/zfsbootmenu-bootmenu`
  - `/EFI/zbm/initramfs-bootmenu.img`
  - `/EFI/BOOT/BOOTX64.EFI`
- Code references:
  - `lib/stage_boot_chain.sh` (`generate-zbm` bundle generation + compatibility fallback copy)
  - `lib/probes.sh` (authoritative bundle probe at `/EFI/zbm/zfsbootmenu.EFI`)

## Gate 6: Observability and Forensics (Must Pass)

- [x] Per-stage logs include timestamps and severity.
- [x] Manifest and logs copied to target system.
- [x] Doctor summary includes pass/fail/warn/skip counts.

Status: **PASS**

Evidence:
- FINALIZE copies artifacts into `/opt/acab/logs/install/` and `/opt/acab/manifests/`.

## Gate 7: Documentation Fidelity (Must Pass)

- [x] README matches current stage count/options.
- [x] Architecture and stage-reference docs match code.
- [x] Known non-ideal behavior documented.
- [x] Behavior changes include doc updates in same PR/session.

Status: **PASS**

Evidence:
- Updated docs set plus readiness/release templates and release notes.

## Exception / Waiver Log

| Gate | Exception | Risk | Owner | Expiry | Approval |
|---|---|---|---|---|---|
| Gate 2 | FINALIZE intentionally re-runs on resume | low/moderate operator surprise | maintainer | next probe-hardening cycle | pending |

## Final Decision

- Production bare-metal: **FAIL** (Gate 4 blocker)
- Controlled lab/dev: **PASS with waiver**
- Decision owner: pending maintainer signoff
- Decision date (UTC): pending
- Follow-up actions:
  1. Complete matrix: second NVMe, second NVIDIA generation, Secure Boot behavior statement.
  2. Capture a clean beta build log confirming no `-arch=native` fallback warnings.
