# DATA FLOW

## Inputs

- Operator inputs: selected disk by-id basename, pool-name acceptance, hostname, username, destructive confirmations.
- Live environment inputs: binaries, network reachability, Debian keyring, block devices, existing pools.
- Remote inputs: NVIDIA keyring, NVIDIA container toolkit keyring, cuDNN installer, package repositories, git repos (`llama.cpp`, optional `cuda-samples`).
- Config-file inputs under `config/`: package lists, APT trust/pinning, service/unit templates, boot settings, manifest template variables.

## Transformations

- State transformations: JSON state transitions written via `jq` in `lib/common.sh`.
- Storage transformations: disk partition table rewrite, EFI filesystem creation, encrypted ZFS pool/dataset/zvol creation.
- Filesystem transformations in target root (`/mnt/install`): package installation, config deployment, service enablement, toolchain installs, runtime binaries.
- Build transformations: DKMS module build, llama.cpp build, `cargo install mistralrs-cli` build.
- Validation transformations: doctor checks evaluate runtime conditions and generate pass/warn/fail/skip outputs.

## Outputs

- Runtime logs: `state/logs/<STAGE>.log` and associated `.sha256`.
- Installer state: `state/install-state.json`.
- Final manifest: `state/manifest/install-manifest.json`, then copied to `/opt/acab/manifests/install-manifest.json` in target.
- Target runtime assets under `/opt/acab`, `/opt/ai-venv`, `/opt/llama-cpp`, `/etc/containers/systemd`, `/etc/systemd/system`.
- Final operational state: exported ZFS pool and post-install instructions.

## Control/Data Coupling Points

- `state/install-state.json` is both control-plane and data-plane for stage ordering and retries.
- `config/manifest-template.jq` binds runtime-collected variables into final manifest schema.
- `lib/topology.sh` and `probe_zfs_create()` form a create/verify coupling contract.
- `detect_runtime_context()` affects strict vs warning behavior for GPU runtime checks.
