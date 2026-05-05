# Contributing to ACABOS Installer

## Source of Truth

Code is authoritative. Documentation must be regenerated or updated to match implemented behavior.

When behavior changes, update at least:

- `README.md`
- `docs/architecture.md`
- `docs/stage-reference.md`
- `docs/config-reference.md` (if config ownership or meaning changes)

## Development Workflow

1. Implement change.
2. Run shell lint on modified scripts (`bash -n`).
3. Validate any modified `config/*.version` files by sourcing them.
4. Update docs in the same change.
5. If installer behavior changed materially, update release/readiness docs as needed.

## Shell Standards

All scripts follow:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
```

Use existing helpers from `lib/common.sh`:

- logging: `log`, `warn`, `err`, `fail`
- timeouts: `run_timeout "$SHORT_TIMEOUT"|"$MEDIUM_TIMEOUT"|"$LONG_TIMEOUT"|"$BUILD_TIMEOUT"`
- state: `state_get_field`, `state_set_stage`, `state_complete_stage`, `state_fail_stage`

Do not use `eval`.

## Core Constraints

- Disk paths: `/dev/disk/by-id` only.
- Pool naming: `ACABROOT-XXXX` (4 hex chars).
- APT trust: explicit keyrings and `signed-by`; no ambient trust.
- Encryption lifecycle: temporary keyfile only during pool creation, then passphrase + prompt keylocation.
- Topology changes require `TOPOLOGY_VERSION` bump in `lib/common.sh`.

## Stage Changes

To add a stage:

1. Create `lib/stage_<name>.sh` with `run_<name>()`.
2. Add `probe_<name>()` in `lib/probes.sh` and dispatch in `probe_stage()`.
3. Register stage order and function in `acabos-install`.
4. Source new stage file in `acabos-install`.
5. Add doctor checks if new invariants are introduced.
6. Update architecture/stage docs.

## Validation Commands

- Run installer: `sudo ./acabos-install [--resume] [--skip-gpu-validation] [--shell]`
- Run doctor: `sudo /opt/acab/doctor/acabos-doctor`
- Lint shell: `bash -n <file>`
- Validate version files: `source config/<name>.version`
