# ACABOS Installer Medium — Design

This document defines the architecture, build strategy, and validation model for the deterministic ACABOS installer medium.

## Design Goals

The installer medium should be:

- **deterministic** — same ISO, same behaviour, every boot
- **text-first** — no desktop session
- **build-capable** — full compiler/toolchain/Rust/CUDA/cuDNN present
- **GPU-aware** — can detect and report GPU posture before install
- **rescue-capable** — recovery shell and diagnostics always available
- **resumable** — respect the existing stage-machine resume model

## Architecture

### Layer 1: Live Base

Debian 13 live userspace booted from the ISO.

Provides:
- kernel / initrd
- systemd
- networking
- console / TTY

### Layer 2: ACABOS Runtime Overlay

Packages installed on top of the live base (see `live-package-manifest.md`):

- installer tooling
- ZFS tooling
- build toolchain
- Podman
- NVIDIA + CUDA + cuDNN

### Layer 3: Launcher UX

Text-mode entry point that presents the operator with:

1. Start Installer
2. Resume Installer
3. Hardware Diagnostics
4. Recovery Shell

### Layer 4: Installer Payload

`/opt/installer` is bundled into the ISO and available at runtime.

The medium does **not** rebuild the installer — it carries a frozen release payload.

## Medium Build Strategy

### Recommended Tool

Use **Debian `live-build`** to produce the ISO.

Inputs:

- Debian 13 live base config
- live package manifest (from `live-package-manifest.md`)
- ACABOS installer payload (`/opt/installer` tree)
- launcher service + boot configuration
- branding / MOTD / issue

Output:

- `acabos-installer-<version>.iso`

### Build Pipeline (Future)

The medium build should eventually be automatable:

```
[installer payload] + [package manifest] + [live config]
    → live-build
    → ISO artifact
```

For v1, the repository now includes a semi-automated build entrypoint:

```bash
./media/build-medium.sh
```

This script stages `/opt/installer` into the live image, runs `lb clean`, `lb config`, and `lb build`, then copies the resulting ISO into `media/out/`.

## Boot Flow

1. ISO boots via UEFI
2. Kernel / initrd load
3. Live userspace comes up
4. Networking starts
5. Text launcher appears on primary console
6. Operator selects action
7. `acabos-install` runs from `/opt/installer`

## Launcher Design

The launcher is a text-mode menu, ideally rendered via `bcon` when the GPU path supports it.

### Menu Entries

#### Start Installer
Runs:
```bash
sudo /opt/installer/acabos-install
```

#### Resume Installer
Runs:
```bash
sudo /opt/installer/acabos-install --resume
```

#### Hardware Diagnostics

Displays:

- block devices
- ZFS pool state
- GPU vendor / model / count
- network connectivity
- memory / hugepage state

#### Recovery Shell

Drops to a root shell with the installer environment fully available.

### Preferred Console

When `bcon` is available and the GPU runtime path supports it, the launcher should run inside `bcon`.

Fallback:
- plain TTY for systems where `bcon` cannot start

This fallback is for **resilience**, not for “no GPU” support.

## Preflight Model

Once the installer medium exists, `PREFLIGHT` should be conceptually split:

### Media Preflight

Validates the live medium itself:

- `/opt/installer` exists
- required binaries exist
- live package cohort is correct
- ZFS tooling is present
- installer runtime assumptions hold

If this fails, the **ISO is wrong**.

### Host Preflight

Validates the target machine:

- block devices
- ZFS pools
- network reachability
- GPU vendor / support tier

If this fails, the **target is wrong or unsupported**.

This split makes failures much easier to diagnose.

## GPU Branching On The Medium

The medium carries full NVIDIA tooling and uses the same GPU detection policy as the main installer:

- **NVIDIA detected:** `supported`, full CUDA path, `bcon` preferred
- **AMD detected:** `experimental`, install continues, no `bcon` guarantee
- **Intel detected:** `experimental`, CPU fallback
- **No GPU:** fail unless `--skip-gpu-validation` is used

The first-boot on the installed system will re-validate GPU posture independently.

## VM Validation Strategy

### Level 1: VM Without GPU Passthrough

Purpose:
- validate medium boots
- validate launcher appears
- validate media preflight passes
- validate installer stages and file placement
- validate `--skip-gpu-validation` behaviour

Use:
```bash
sudo /opt/installer/acabos-install --skip-gpu-validation
```

### Level 2: VM With GPU Passthrough

Purpose:
- validate full NVIDIA path in a VM
- validate CDI generation, container GPU smoke test
- validate `mistral-rs doctor`
- validate retained service behaviour
- shorter feedback loop than bare metal

Prerequisites:

- IOMMU / VT-d enabled in firmware
- `intel_iommu=on` on host kernel command line
- NVIDIA RTX 4070 bound to `vfio-pci`
- host display via Intel UHD 630 iGPU
- QEMU / KVM with VFIO passthrough configured

Required kernel params:
```
intel_iommu=on iommu=pt vfio-pci.ids=10de:<device_id>
```

### Level 3: Bare Metal

Final truth. Same ISO, real hardware.

## Validation Ladder

```
L1 (VM, no GPU) → proves medium + installer structure
    ↓
L2 (VM, GPU passthrough) → proves NVIDIA runtime path
    ↓
L3 (bare metal) → proves real-world install
```

Each level gates the next.

## Success Criteria

### Medium v1

- ISO builds from the defined manifest
- ISO boots in VM (L1)
- text launcher appears
- media preflight passes
- `acabos-install` is launchable
- installer completes in L1
- installer completes in L2 (GPU passthrough)
- first-boot readiness report validates cleanly

## Future Direction

- full `live-build` automation
- CI-driven ISO release artifacts
- `acabos-installer-heavy.iso` with additional profiles
- signed / verified ISO distribution
- PXE / network-boot medium variant