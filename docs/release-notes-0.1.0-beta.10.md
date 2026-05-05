# ACABOS Installer 0.1.0-beta.10

Release channel: beta
Date (UTC): 2026-04-21

## Summary

- Canonicalizes BOOT_CHAIN around bundled ZFSBootMenu EFI generation and validates a full reinstall/resume flow through FINALIZE on `/dev/nvme0n1`.

## Key Changes Since 0.1.0-beta.9

- BOOT_CHAIN hardening in `lib/stage_boot_chain.sh`:
  - Fixed chroot command detection for `generate-zbm` using `bash -lc`.
  - Added `systemd-boot-efi` dependency in target chroot for UEFI stub availability.
  - Remounts ESP after chroot unmount before artifact validation.
  - Prunes non-authoritative backup artifacts under `/EFI/zbm` to avoid rerun space pressure.
  - Made initramfs inspection pipefail-safe and validation robust.
  - Treats EFI NVRAM registration as best-effort when EFI runtime variables are unavailable.
- Updated doctor boot invariant in `doctor/acabos-doctor`:
  - `INV-BOOT-001` now validates authoritative bundle `/boot/efi/EFI/zbm/zfsbootmenu.EFI`.
- Documentation reconciliation for canonical boot behavior:
  - Updated architecture, stage reference, release-readiness, and carried-forward release notes wording.

## Validation

- Fresh install on `/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_2TB_S7M4NL0XB09028A` completed successfully through FINALIZE.
- Pre-finalize doctor run during `VALIDATION`:
  - `17 pass, 0 fail, 4 warn, 1 skip`
- ESP evidence captured:
  - `/EFI/zbm/zfsbootmenu.EFI` recognized as PE32+ EFI executable
  - `/EFI/zbm/initramfs-bootmenu.img`
  - `/EFI/zbm/zfsbootmenu-bootmenu`

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.10.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.10.tar.gz.sha256`
