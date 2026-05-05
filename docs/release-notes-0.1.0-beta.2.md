# ACABOS Installer 0.1.0-beta.2

Release channel: beta
Date (UTC): 2026-04-20

## Summary

- Re-issued beta package with UEFI boot-path reliability fixes.
- Ensures both NVRAM boot entry and fallback boot path are handled by installer logic.

## Key Fixes Since 0.1.0-beta.1

- `BOOT_CHAIN` now registers EFI boot entry with explicit initrd argument.
- `BOOT_CHAIN` now installs fallback UEFI loader at `\EFI\BOOT\BOOTX64.EFI`.
- Boot-chain validation now warns if fallback loader is missing.
- Re-entry probe logic now accepts both `initramfs-*` and `initramfs.img` naming patterns.

## Validation Notes

- EFI partition contains ZFSBootMenu kernel + initramfs artifacts.
- ACABOS EFI entry present in firmware boot table with initrd argument.
- Fallback boot file verified at EFI default path.

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.2.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.2.tar.gz.sha256`
