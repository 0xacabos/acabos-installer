# ACABOS Installer 0.1.0-alpha.2

Release channel: alpha
Date (UTC): 2026-04-20

## Highlights

- Completed a full second-pass bare-metal install run targeting `/dev/nvme0n1` through all 13 stages.
- Hardened resume behavior and stage idempotency across AI, inference, boot-chain, and validation paths.
- Added locale hardening (`C.UTF-8`) globally and on chrooted APT calls to reduce host-locale leakage.
- Made CUDA tuning explicit and config-driven for both `mistral.rs` and `llama.cpp`.
- Updated docs to align with runtime behavior and added deployment/release readiness gate docs.

## Included Changes

- Stage correctness and idempotency:
  - `lib/stage_ai.sh`: fixed package list handling, uv pathing, venv reuse, idempotent clone, explicit CUDA toolkit/compiler wiring, explicit llama CUDA architectures from config.
  - `lib/stage_boot_chain.sh`: improved EFI mount handling before image generation/validation.
  - `lib/stage_inference.sh`: explicit CUDA env for `cargo install`, configurable compute capability.
  - `doctor/acabos-doctor`: fixed script-scope issues, adjusted dependency traversal behavior, and improved pool/endpoint check semantics for installer context.
- Configuration:
  - `config/mistral.version`: added `MISTRAL_CUDA_COMPUTE_CAP` and `LLAMA_CUDA_ARCHITECTURES` pins.
- Locale stability:
  - `lib/common.sh` and apt stages: `LANG=C.UTF-8`, `LC_ALL=C.UTF-8`.
- Documentation:
  - Updated `README.md`, `docs/architecture.md`, `docs/stage-reference.md`, `CONTRIBUTING.md`.
  - Added `docs/deployment-readiness.md` and `docs/release-readiness-template.md`.

## Validation Snapshot

- Final run result: installer reached `All stages completed successfully`.
- Doctor summary (pre-finalize context): 14 pass, 0 fail, 3 warn, 3 skip.

## Known Limitations (Mapped to Readiness Gates)

- Gate 1 (Security Baseline): `lib/stage_finalize.sh` still sets a hardcoded bootstrap password and logs messaging that can imply forced rotation behavior; this should be replaced with a secure first-boot credential flow.
- Gate 2 (Stage Machine Correctness): `FINALIZE` probe intentionally returns non-zero and re-runs on resume; this is documented but non-ideal for strict FSM purity.
- Gate 4 (Hardware Matrix): validation evidence is currently strongest on the tested target class; broader matrix coverage is still required for production signoff.
- Gate 5 (Performance Determinism): CUDA architecture is now pinned/configurable, but release signoff should require log evidence that no `-arch=native` fallback warnings occurred on target hardware.

## Upgrade / Rollout Notes

- Prefer controlled lab deployment for this alpha.
- Use `docs/deployment-readiness.md` + `docs/release-readiness-template.md` as release gates before beta/stable promotion.
