# ACABOS QEMU Lab

This directory contains the validation harness for the ACABOS installer ISO.

## Purpose

The QEMU lab supports two validation levels:

- **L1**: VM boot with no GPU passthrough
- **L2**: VM boot with NVIDIA GPU VFIO passthrough

The ISO under test is the locally built ACABOS installer medium:

```text
media/out/acabos-installer-amd64.iso
```

## Files

- `run-qemu-installer-lab.sh` — launches the installer ISO in QEMU
- `vfio-gpu-bind-helper.sh` — temporarily binds/unbinds NVIDIA devices to `vfio-pci`
- `build/` — lab runtime artifacts (qcow2, OVMF vars)

## L1: Basic VM Validation

```bash
./media/qemu-lab/run-qemu-installer-lab.sh
```

Recommended guest flow:
- boot the ACABOS installer medium
- verify launcher appears
- test diagnostics and recovery shell
- run installer with `--skip-gpu-validation` when appropriate

## L2: NVIDIA VFIO Validation

### 1. Scan devices

```bash
sudo ./media/qemu-lab/vfio-gpu-bind-helper.sh scan
```

### 2. Bind GPU/audio to vfio-pci

```bash
sudo ./media/qemu-lab/vfio-gpu-bind-helper.sh bind --gpu 0000:01:00.0 --yes
```

### 3. Launch passthrough VM

```bash
./media/qemu-lab/run-qemu-installer-lab.sh \
  --vfio-gpu 0000:01:00.0 \
  --vfio-gpu-audio 0000:01:00.1 \
  --vfio-primary
```

### 4. Restore host drivers after test

```bash
sudo ./media/qemu-lab/vfio-gpu-bind-helper.sh unbind --gpu 0000:01:00.0 --yes
```

## Prerequisites for L2

- IOMMU / VT-d enabled in firmware
- host kernel configured for VFIO
- host display available via Intel iGPU or other non-passthrough path
- `ovmf`, `qemu-system-x86_64`, and `qemu-img` installed
- NVIDIA GPU already bound to `vfio-pci` before launch

## Notes

- The QEMU harness is for validation; the `media/` build system remains the source of truth for ISO creation.
- The helper script does not edit kernel cmdline or initramfs.
- The VFIO path is specifically for validating the **supported NVIDIA runtime path**.
