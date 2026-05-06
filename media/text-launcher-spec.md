# ACABOS Text-Mode Launcher Spec

This document defines the installer-medium boot-time launcher behaviour.

## Purpose

The launcher is the operator-facing entry point for the ACABOS installer medium.

It replaces:
- raw root shell after boot
- “figure it out yourself” live environment UX

with a deterministic text-mode menu.

## Requirements

### Functional

- present a menu within 30 seconds of live-environment boot completion
- offer at minimum:
  - Start Installer
  - Resume Installer
  - Hardware Diagnostics
  - Recovery Shell
- allow keyboard-only navigation
- respect the installer’s existing `--resume` and `--shell` semantics
- never block the operator from reaching a recovery shell

### Non-functional

- text-only (no GUI dependency)
- lightweight (no heavy runtime before installer starts)
- survive console loss / GPU state changes gracefully
- fall back to a plain shell if the preferred console frontend fails

## Menu Layout

```
============================================
  ACABOS Installer
  Debian 13 GPU-Aware AI Workstation
============================================

  1) Start Installer
  2) Resume Installer
  3) Hardware Diagnostics
  4) Recovery Shell

  Choice [1-4]:
```

## Menu Entries

### 1. Start Installer

Executes:
```bash
sudo /opt/installer/acabos-install
```

If `--skip-gpu-validation` is needed (e.g., VM without passthrough):
- the operator can type `1 --skip-gpu-validation`
- or the menu can offer an explicit sub-option before launching

### 2. Resume Installer

Executes:
```bash
sudo /opt/installer/acabos-install --resume
```

### 3. Hardware Diagnostics

Displays a read-only summary:

```
=== Block Devices ===
<lsblk or by-id summary>

=== ZFS Pools ===
<zpool list>

=== GPU ===
Vendor:     nvidia
Model:      NVIDIA GeForce RTX 4070
Count:      1
Tier:       supported
Runtime:    cuda
Validation: full

=== Network ===
<ip addr / connectivity check>

=== Memory ===
Total:      32 GB
Free:       ~12 GB
Hugepages:  not reserved (0)
Swap:       off
```

This page should not mutate anything.

### 4. Recovery Shell

Drops to a root shell:

```bash
exec bash
```

The operator can return to the launcher by typing `exit` or `launcher`.

## Console Frontend Policy

### Preferred: `bcon`

When `bcon` is installed and the GPU runtime supports it, the launcher should render inside `bcon`.

This provides:
- GPU-accelerated rendering on real TTY
- modern terminal UX (true color, mouse, etc.)
- a distinctive ACABOS console identity

### Fallback: Plain TTY

If `bcon` cannot start (driver not loaded, GPU state broken, AMD/Intel experimental path, etc.), the launcher must fall back to a plain TTY shell menu.

This fallback is for **resilience**. It does not imply that ACABOS supports GPU-less installs.

## Launch Sequence

### At Boot

1. systemd reaches `multi-user.target`
2. `acab-launcher.service` starts
3. launcher detects GPU posture
4. attempts `bcon` if supported
5. falls back to plain TTY if needed
6. presents menu

### Service Configuration

The launcher should be managed via a systemd service:

```ini
[Unit]
Description=ACABOS Installer Launcher
After=network-online.target
Wants=network-online.target

[Service]
Type=idle
ExecStart=/usr/local/bin/acab-launcher
StandardInput=tty
StandardOutput=tty
TTYPath=/dev/tty1
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## Launcher Script Behaviour

Pseudocode:

```bash
attempt_bcon_if_supported

while true; do
    show_menu
    read choice
    case "$choice" in
        1) launch_installer ;;
        2) launch_installer --resume ;;
        3) show_diagnostics ;;
        4) exec bash ;;
        *) echo "Invalid choice" ;;
    esac
done
```

After the installer exits, the launcher should return to the menu, not reboot immediately.

## Diagnostics Screen

Should be implemented as a read-only data dump that sources from:

- `/proc` / `sysfs`
- `lspci`
- `zpool` / `zfs`
- `ip`
- `free`
- optionally the existing GPU policy detection logic

No new state should be written during diagnostics.

## Integration With Installer

The launcher should set `ACABOS_INSTALLER_LAUNCHED_BY_MEDIUM=true` so the installer can optionally record that fact in the manifest.

## Validation

### L1 (VM without GPU passthrough)

- launcher appears
- menu is navigable
- start / resume / diag / shell all work
- fallback to plain TTY is used (no `bcon`)

### L2 (VM with GPU passthrough)

- launcher appears
- `bcon` is the preferred console frontend
- menu renders inside `bcon`
- GPU diag shows correct NVIDIA info
- installer can be launched from inside `bcon`

### L3 (bare metal)

Same as L2, on real hardware.

## Future Direction

- richer diagnostics (SMART details, NVMe health, GPU temperature / power)
- network configuration helper in the launcher
- optional “quick validation” mode that runs a subset of checks before install
- graphical launcher option via a minimal framebuffer UI (only if ACABOS later wants it)