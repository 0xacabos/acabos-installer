# ACABOS Installer 0.1.0-beta.9

Release channel: beta
Date (UTC): 2026-04-20

## Summary

- Fixes NVIDIA runtime command detection in chroot validation and confirms a full clean installer run from PREFLIGHT through FINALIZE on `/dev/nvme0n1`.

## Key Changes Since 0.1.0-beta.8

- Fixed `NVIDIA_BRINGUP` runtime check in `lib/stage_nvidia_bringup.sh`:
  - Replaced `chroot ... command -v nvidia-smi` with `chroot ... bash -lc 'command -v nvidia-smi ...'`.
  - This resolves false failures caused by `command` being a shell builtin.
- Completed full end-to-end reinstall validation on target disk (`/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_2TB_S7M4NL0XB09028A`).
- Added first-login operator notice mechanism in target runtime:
  - `~/notice.md` for user guidance
  - one-time display hook via `/etc/profile.d/acabos-first-login-notice.sh`

## Validation

- Full installer run completed successfully through FINALIZE.
- Post-finalize target-context doctor run:
  - `20 pass, 0 fail, 2 warn, 0 skip`

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.9.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.9.tar.gz.sha256`
