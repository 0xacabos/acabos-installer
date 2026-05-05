# ACABOS Installer 0.1.0-beta.8

Release channel: beta
Date (UTC): 2026-04-20

## Summary

- Rebuilds documentation from code as the source of truth and adds a complete config reference.
- Fixes doctor parsing/dependency issues and aligns NVIDIA package install/runtime validation with the current repository state.

## Key Changes Since 0.1.0-beta.7

- Removed dead installer flag `--dev-mode` from `acabos-install`.
- Reconciled doctor schema version constants to `acabos-doctor-invariants/v2`.
- Archived historical changelog as `CHANGES.md.archive`.
- Rewrote `README.md`, `docs/architecture.md`, `docs/stage-reference.md`, `CONTRIBUTING.md`, and `AGENTS.md` from current implementation.
- Added `docs/config-reference.md` covering all `config/` payloads and stage ownership.
- Fixed doctor parser robustness in `doctor/acabos-doctor`:
  - stable initramfs ZFS count handling
  - output sanitization for result parsing
  - corrected graphics dependency execution order
- Updated NVIDIA package handling to install `nvidia-driver-cuda` (provider of `nvidia-smi`) and validate both package and command presence.

## Validation

- Target-context doctor run (chroot) after fixes:
  - `20 pass, 0 fail, 2 warn, 0 skip`

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.8.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.8.tar.gz.sha256`
