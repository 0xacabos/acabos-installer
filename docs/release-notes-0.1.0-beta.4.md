# ACABOS Installer 0.1.0-beta.4

Release channel: beta
Date (UTC): 2026-04-20

## Summary

- Adds hybrid interactive drive selection with `fzf` live preview and `gum` prompt flow.
- Makes `gum` and `fzf` required preflight dependencies installed during PREFLIGHT.

## Key Changes Since 0.1.0-beta.3

- PREFLIGHT:
  - Installs `gum` and `fzf` via APT.
  - Fails hard if either dependency cannot be installed.
  - Probe contract updated to require both binaries.
- INPUT:
  - Disk picker now uses `fzf` with live preview of `lsblk`, `sgdisk -p`, and `blkid` context.
  - Non-interactive fallback remains deterministic via stdin-compatible selectors.
- Prompting core:
  - Added `can_use_fzf` and `prompt_select_disk` helper primitives.
- Documentation:
  - Updated README, architecture, stage reference, and change log to capture the new UX/dependency contract.

## Security and Boot Hardening Carried Forward

- No hardcoded installer credentials in stage logic.
- FINALIZE password flow uses interactive prompt or `ACABOS_USER_PASSWORD` for non-interactive mode.
- Boot chain uses bundled ZFSBootMenu EFI at `/EFI/zbm/zfsbootmenu.EFI` as authoritative path, with optional compatibility fallback `/EFI/BOOT/BOOTX64.EFI`.

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.4.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.4.tar.gz.sha256`
