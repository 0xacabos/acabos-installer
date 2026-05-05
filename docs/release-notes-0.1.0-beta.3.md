# ACABOS Installer 0.1.0-beta.3

Release channel: beta
Date (UTC): 2026-04-20

## Summary

- Re-issued beta package with credential hardening and prompt-flow remediation.
- Removes remaining hardcoded installer credentials and restores real destructive confirmations.

## Key Changes Since 0.1.0-beta.2

- Security and credentials:
  - Removed hardcoded root password seeding in BASE_INSTALL.
  - Removed hardcoded user password in FINALIZE.
  - FINALIZE now requires explicit password setup via interactive prompt or `ACABOS_USER_PASSWORD` for non-interactive runs.
  - Enforced first-login password rotation for non-root user.
- Prompting and UX:
  - Re-enabled confirmation gating (`prompt_confirm`).
  - Added optional `gum` prompt integration with shell fallback.
  - Unified prompt helpers for text/select/password flows.
  - Updated stage failure recovery choice flow to use shared prompt helpers.
- Documentation:
  - Updated README, architecture, stage reference, and change log to match current behavior.

## Bootability and Prior Hardening Carried Forward

- EFI registration includes explicit `initrd=` argument.
- Fallback loader is installed at `/EFI/BOOT/BOOTX64.EFI`.
- Probe compatibility supports `initramfs-*` and `initramfs.img`.

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.3.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.3.tar.gz.sha256`
