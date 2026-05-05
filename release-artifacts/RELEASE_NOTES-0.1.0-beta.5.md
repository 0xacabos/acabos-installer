# ACABOS Installer 0.1.0-beta.5

Release channel: beta
Date (UTC): 2026-04-20

## Summary

- Documentation-focused reissue that records the fixed ZFS storage policy in release history.
- Confirms installer behavior does not branch on NVMe (`nvme*`) vs SATA (`sd*`) kernel naming for pool policy decisions.

## Key Documentation Additions Since 0.1.0-beta.4

- Explicitly documented fixed `ashift=12` policy across supported drive classes.
- Clarified that drive selection is based on `/dev/disk/by-id` and not kernel naming convention.
- Recorded that adaptive per-media `ashift` tuning is intentionally out of scope for this release.
- Added readiness-gate evidence language to verify storage policy documentation consistency.

## Files Updated for Policy Clarity

- `README.md` (`ZFS Pool Policy` section)
- `docs/architecture.md` (storage `ashift` policy)
- `docs/stage-reference.md` (`ZFS_CREATE` contract)
- `docs/deployment-readiness.md` (Gate 5 evidence)
- `CHANGES.md` (history entry)

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.5.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.5.tar.gz.sha256`
