# ACABOS Implementation Roadmap

This document captures the current refactor state, the decisions already locked in, and the remaining execution order.

## Locked Product Decisions

### Native services

- `mistral.rs`
- `ollama`
- `jupyter`

### Containerized services

- `qdrant`
- `localai`
- `comfyui`

### Removed from default install path

- `ollama-webui`
- `stable-diffusion-webui`
- `text-generation-webui`
- `whisper-asr`
- `ai-toolbox`

### Runtime behavior

- install-time assembles the target
- first boot validates runtime and enables selectively
- Jupyter is localhost-only, token-authenticated, and disabled by default
- hugepages are not reserved by default

### Hardware support posture

- NVIDIA: supported
- AMD: experimental
- Intel GPU: experimental
- no usable GPU: unsupported edge case

## Work Already Completed

### 1. Docs and scope narrowing

Updated installer docs to reflect the narrower supported stack and the two-step activation model.

### 2. Hugepages removed from default path

- default hugepages sysctl no longer applied
- doctor no longer expects hugepages by default

### 3. SSH default fixed

- Debian service naming corrected to `ssh.service`
- SSH remains enabled by default
- X11 forwarding disabled in shipped hardening config

### 4. Native Ollama path added

- native install/version config added
- native `ollama.service` added
- old user-level Ollama container path removed

### 5. Native Jupyter path added

- secure localhost-only Jupyter config
- native `acab-jupyter.service`
- token generation and user-specific notebook root wiring

### 6. `mistral.rs` service redesign

- broken `acab-inference.service` removed from installer generation path
- `acab-inference@.service` added
- example profile scaffold added
- `model-manager serve` now starts a service profile instead of using a broken direct command

### 7. Retained quadlets reduced and pinned

- only `qdrant`, `localai`, and `comfyui` retained
- digest pinning added
- unsupported `Device=` usage replaced with `AddDevice=`

### 8. First-boot runtime validation rewritten

- writes readiness TSV/log
- regenerates CDI if available
- runs Podman and GPU smoke validation
- pulls retained images sequentially
- validates retained services sequentially
- enables only services that become active

### 9. Version coherence tightened

- PyTorch wheel index moved to config
- NVIDIA test container image moved to config
- docs updated to describe the intended host-toolchain vs wheel/runtime split

### 10. Onboarding docs added

- templates for `RELEASE-NOTES.md` and `FIRST-STEPS.md`
- copied into `/etc/skel`
- rendered with build-specific data in `FINALIZE`

## Remaining Major Workstreams

## Workstream A: GPU detection and branching

Goal:
- detect GPU vendor deterministically
- write GPU support/runtime fields into installer state
- gate runtime behavior on support tier

Needed work:
- add GPU state fields
- detect in preflight
- gate `NVIDIA_BRINGUP`
- branch first-boot validation by support tier
- surface support tier into user docs and readiness outputs

## Workstream B: Deterministic installer medium

Goal:
- stop depending on an ambient live environment
- ship a deterministic ACABOS installer medium

Needed work:
- define live package manifest
- choose medium build mechanism
- design text-mode launcher
- split media preflight vs host preflight
- bundle `/opt/installer` into the medium

## Workstream C: End-to-end validation

Goal:
- prove the refactor works in practice

Needed work:
- rehearse runtime behavior on current host
- run fresh VM installer test
- run fresh bare-metal test
- refine any service/runtime failures observed in readiness logs

## Recommended Execution Order

1. Implement GPU detection and branching
2. Validate current refactor on this host where safe
3. Validate current refactor in a VM from a fresh install
4. Design/build deterministic installer medium
5. Validate the installer medium in VM
6. Validate on bare metal

## Runtime Validation Ladder

### Current host rehearsal

Use the existing system to validate:

- native `ollama`
- native `jupyter`
- `mistral-rs doctor`
- `acab-inference@` service behavior
- retained container runtime behavior
- first-boot readiness logic

### VM validation

Use VM to prove:

- stage ordering
- file placement
- service scaffolding
- onboarding docs rendering
- installer and resume behavior

### Bare-metal validation

Use bare metal to prove:

- full supported NVIDIA path
- container runtime behavior
- service enablement correctness
- memory behavior after hugepage removal

## Main Risks

### `localai`

Most likely to remain runtime-fragile even with a valid image/tag.

### `comfyui`

Likely to need the most practical runtime validation on real hardware.

### GPU branching

The refactor is now coherent on NVIDIA-first assumptions, but AMD/Intel branching still needs to be made explicit.

### Installer medium complexity

The media build path is net-new and should be treated as its own workstream, not a casual add-on.

## Short-Term Definition Of Done

The refactor phase is effectively complete when:

- current installer payload passes VM and host-runtime validation
- GPU branching is implemented and logged cleanly
- the deterministic installer medium plan is specified clearly enough to implement

## Medium-Term Definition Of Done

The platform primitive phase is complete when:

- deterministic installer medium exists
- text launcher works
- media preflight and host preflight are distinct
- NVIDIA supported path is proven on fresh bare metal

## Long-Term Follow-On

This platform phase should directly support future development of:

- ACAB bus
- Muklux
- richer ownership semantics
- certification state
- deterministic runtime collapse logic
