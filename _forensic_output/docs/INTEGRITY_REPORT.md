# INTEGRITY REPORT

## Scope

Observed inconsistencies, drift, non-determinism risks, and hidden state points from workspace files only.

## Findings

1. Top-level `local` usage in non-function context (hard runtime error risk).

- Evidence: `acabos-install` uses `local` in top-level `if [[ "$RESUME" == "true" ]]` block (`local stored_version`, `local resume_result`, `local resume_stage`, `local status`).
- Evidence: `doctor/acabos-doctor` uses `local` in top-level `for` loop (`local domain`, `local result_line`, `local func`, `local result`, `local status`, `local desc`).
- Impact: Bash emits `local: can only be used in a function`; with `set -e` this can terminate execution.
- Classification: architectural contradiction / deterministic failure path.

2. Stage count documentation drift.

- Evidence: `README.md` section "Installation Stages" says 11 stages and omits `DESKTOP_SUBSTRATE` and `AI_SUBSTRATE` in sequence text.
- Evidence: `acabos-install` and `docs/architecture.md` define 13 stages including both.
- Impact: operator expectation mismatch and forensic ambiguity.
- Classification: documentation contradiction.

3. Missing referenced spec file.

- Evidence: multiple comments reference `docs/acabos-installer-spec.md`.
- Evidence: file is not present in workspace tree.
- Impact: unverifiable stage contract references.
- Classification: incomplete feature/documentation drift.

4. Hidden state dependence on live/target mutable environment.

- Evidence: stages depend on current host package availability, network reachability, repo availability, and mutable external package indices.
- Impact: reproducibility drift across execution dates and environments.
- Classification: non-deterministic behavior surface.

5. Security posture drift in Jupyter default config.

- Evidence: `config/jupyter/jupyter_server_config.py` sets empty token/password and `allow_origin="*"` on `0.0.0.0`.
- Impact: unauthenticated remote access risk if exposed.
- Classification: architectural contradiction with hardened-install intent.

## Dead Code / Redundant Logic Signals

- `ACABOS_DEV_MODE` is exported in `acabos-install`; no evidence in inspected stage scripts that branch on it.
- `config/quadlets/ai-services.pod` exists; no direct copy/use logic specific to pod orchestration beyond generic quadlet copy.

## Hidden State Inventory

- Runtime state file: `state/install-state.json`.
- Stage logs and hashes: `state/logs/*.log` and `state/logs/*.sha256`.
- External repo mutable state: Debian/NVIDIA/cuDNN package indices and artifacts.
- Hardware state: detected disks, GPU PCI state, virtual/physical detection signals.
