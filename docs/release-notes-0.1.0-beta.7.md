# ACABOS Installer 0.1.0-beta.7

Release channel: beta
Date (UTC): 2026-04-20

## Summary

- Introduces ABI cohort compatibility as a formal design primitive and enforced preflight hard gate.
- Extends documentation contracts so this invariant is explicit across architecture, stage reference, README, and readiness gates.

## Key Changes Since 0.1.0-beta.6

- PREFLIGHT now enforces an ABI cohort gate before destructive stages:
  - running-kernel headers required
  - kernel/ZFS/dracut cohort installed from `trixie-backports`
  - exact ZFS kernel module/userspace version match required
- PREFLIGHT applies live APT cohort policy and installs ABI cohort packages from `trixie-backports`.
- `probe_preflight` now validates ABI cohort invariants in resume checks.

## Design Primitive Documentation

- `docs/architecture.md`: ABI cohort compatibility added as a first-class design primitive.
- `docs/stage-reference.md`: PREFLIGHT contract expanded with ABI gate semantics.
- `README.md`: operator-facing ABI Compatibility Gate section added.
- `docs/deployment-readiness.md`: readiness evidence expanded for ABI gate reporting.
- `CHANGES.md`: change history updated.

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.7.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.7.tar.gz.sha256`
