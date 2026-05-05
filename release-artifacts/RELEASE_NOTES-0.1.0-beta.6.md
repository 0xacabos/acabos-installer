# ACABOS Installer 0.1.0-beta.6

Release channel: beta
Date (UTC): 2026-04-20

## Summary

- Extends prompt-tooling availability to the installed target runtime for recursive idempotent operator UX.
- Keeps preflight hard requirement for `gum` and `fzf` in the live installer environment.

## Key Changes Since 0.1.0-beta.5

- `BASE_INSTALL` now includes `gum` and `fzf` in target-system package bootstrap.
- Documentation updated to reflect dual-environment availability:
  - live installer environment
  - installed target runtime

## Files Updated

- `lib/stage_base_install.sh`
- `README.md`
- `docs/architecture.md`
- `docs/stage-reference.md`
- `CHANGES.md`

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.6.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.6.tar.gz.sha256`
