# ACABOS Installer 0.1.0-beta.1

Release channel: beta
Date (UTC): 2026-04-20

## Summary

- Promoted from `0.1.0-alpha.2` packaging stream with stage-machine and documentation alignment improvements retained.
- Includes production-readiness gate documents and a pre-filled beta readiness draft.
- Keeps deterministic CUDA build configuration for `mistral.rs` and `llama.cpp` through config pins.

## What Is Included

- Installer/runtime improvements carried forward from alpha.2:
  - Resume and idempotency hardening in stage execution paths.
  - Locale hardening (`LANG/LC_ALL=C.UTF-8`) for installer and chrooted APT operations.
  - Explicit CUDA architecture/capability configuration:
    - `MISTRAL_CUDA_COMPUTE_CAP`
    - `LLAMA_CUDA_ARCHITECTURES`
- Documentation set aligned with current behavior:
  - `README.md`
  - `docs/architecture.md`
  - `docs/stage-reference.md`
  - `CONTRIBUTING.md`
  - `docs/deployment-readiness.md`
  - `docs/release-readiness-template.md`
  - `docs/release-readiness-0.1.0-beta.1-draft.md`

## Validation Snapshot

- Full stage flow completion demonstrated in prior validation pass.
- Doctor summary during validation context: 14 pass, 0 fail, 3 warn, 3 skip.

## Known Constraints Before Stable

- Security gate blocker remains: static bootstrap credential path in FINALIZE needs replacement with secure credential onboarding.
- Hardware matrix expansion is still required for production-grade signoff.
- Beta evidence should include a clean build log confirming no CUDA `-arch=native` fallback warnings.

## Artifacts

- Package: `release-artifacts/acabos-installer-0.1.0-beta.1.tar.gz`
- Checksum: `release-artifacts/acabos-installer-0.1.0-beta.1.tar.gz.sha256`
- Readiness draft: `release-artifacts/RELEASE_READINESS-0.1.0-beta.1-draft.md`
