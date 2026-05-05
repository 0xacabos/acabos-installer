# Development Platform Primitive Spec

This document defines the current phase of ACABOS.

ACABOS at this stage is a deterministic, GPU-aware development substrate for building the later ownership, certification, and bus-based ACAB-OS model. It is not yet the final ACAB-OS computational model.

## Purpose

The current platform exists to provide a stable base for developing later systems such as:

- ACAB bus
- Muklux
- ownership semantics
- certification semantics
- deterministic runtime collapse
- DSP/kernel integration work

The installer and runtime stack should therefore optimize for determinism, explicit service topology, hardware awareness, and auditable first-boot results.

## Non-Goals

This phase does not attempt to fully implement:

- the final ACAB bus
- the final ownership state machine
- the final certification engine
- mission-critical / life-critical promotion semantics
- the final console substrate replacing `bcon`
- full AMD parity
- full Intel GPU parity
- cross-Linux/FreeBSD unified DRM ownership

Those are later layers that will build on the primitives defined here.

## Supported Default Stack

### Native

- `mistral.rs`
- `ollama`
- `jupyter`

### Containerized

- `qdrant`
- `localai`
- `comfyui`

### Not Part Of The Default Supported Stack

- `ollama-webui`
- `stable-diffusion-webui`
- `text-generation-webui`
- `whisper-asr`
- `ai-toolbox`

## Required System Invariants

The development platform should guarantee:

### Host invariants

- Debian 13 target system
- encrypted ZFS root
- UEFI boot
- explicit service topology
- no hidden hugepage reservation by default

### Installer invariants

- deterministic stage machine
- resumable install flow
- deterministic live installer medium
- text-mode launcher
- recovery shell availability
- no reliance on ad hoc live-environment package state

### Runtime invariants

- native `mistral.rs` installed
- native `ollama` installed
- native `jupyter` installed securely and disabled by default
- retained support services defined for `qdrant`, `localai`, and `comfyui`
- first-boot runtime validation writes explicit readiness results

## Hardware Support Policy

### Supported

- NVIDIA GPU systems

### Experimental

- AMD GPU systems
- Intel GPU systems

### Unsupported edge case

- systems with no usable GPU at all

Important distinction:

- GPU presence is assumed as part of the ACABOS platform design.
- Runtime certification is based on whether a valid GPU-governed state can be established.

## Runtime Model

ACABOS uses a two-step activation model.

### Install time

The installer:

- assembles the target system
- installs runtimes and service definitions
- lays down first-boot scaffolding
- avoids claiming runtime success before live validation

### First boot

The live installed system:

- regenerates machine identity and SSH host keys
- validates runtime assumptions on actual hardware
- validates retained services sequentially
- enables only services that pass
- produces auditable readiness output

This first-boot phase is the current practical form of deterministic collapse for the development platform.

## Required Platform Primitives

The platform should expose the following primitives for later systems to consume.

### Deterministic installer medium

A build-capable, GPU-aware ACABOS live environment with a text launcher and recovery path.

### Deterministic stage machine

The installer remains ordered, resumable, probe-aware, and auditable.

### Hardware discovery

The installer can detect and record:

- block devices
- pools
- boot mode
- GPU vendor/model/count
- support tier

### GPU-aware runtime branching

The runtime stack can distinguish supported, experimental, and fallback paths based on detected GPU characteristics.

### Stable service topology

The system maintains a clear split between native services and retained containerized support services.

### First-boot readiness artifacts

At minimum:

- `/etc/acabos/runtime-readiness.tsv`
- `/etc/acabos/runtime-readiness.log`

These provide machine-readable and human-readable evidence of first-boot runtime validation.

### User onboarding artifacts

Each installed user should receive:

- `~/RELEASE-NOTES.md`
- `~/FIRST-STEPS.md`

These communicate the stack, support tier, and initial enablement instructions.

## Console Direction

Near term:

- preferred accelerated console path may use `bcon`
- plain TTY remains the recovery path

Long term:

- `bcon` is transitional
- Muklux is the intended final console substrate

## Runtime Artifact Direction

Required now:

- `/etc/acabos/runtime-readiness.tsv`
- `/etc/acabos/runtime-readiness.log`

Strongly recommended next:

- `/etc/acabos/runtime-capability.json`

That JSON should stay intentionally lightweight in this phase and expose only the capability data needed by future ACAB bus integration.

## Success Condition For This Phase

This phase is successful when ACABOS is a deterministic, GPU-aware, service-disciplined development platform that can reliably support later implementation of:

- ACAB bus
- Muklux
- ownership semantics
- certification semantics
- deterministic runtime collapse

## Relationship To The Larger Vision

This platform is not the end state.

It is the substrate that makes the end state achievable without repeatedly re-solving installer, runtime, and hardware-governance problems.
