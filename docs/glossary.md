# ACABOS Glossary

This file records canonical names and terms used across the installer and planning docs.

## Canonical Names

### ACABOS
The current installer-driven Debian 13 AI workstation substrate.

### ACAB bus
The future control/orchestration layer that will consume platform primitives exposed by ACABOS.

### Muklux
The intended future GPU-accelerated console substrate and terminal multiplexer. Replaces earlier accidental spellings such as “MokLoks”.

### `bcon`
An interim GPU-capable Linux console terminal frontend that may serve as the preferred installer-medium UI before Muklux exists.

## Runtime Terms

### Supported
Validated and intended to work as part of the default ACABOS path.

### Experimental
Install continues and runtime may be attempted, but behavior is not treated as a first-class invariant.

### CPU fallback
The machine remains usable for development/runtime in CPU mode even if the desired acceleration path is not validated.

### Runtime readiness
The first-boot result set describing what was validated, what passed, what failed, and what was skipped.

### Runtime capability
A machine-readable description of what the installed system can currently support. Planned future artifact.

## Service Topology Terms

### Native service
A service installed and managed directly on the host via systemd.

### Containerized support service
A retained auxiliary/runtime service managed via Podman and systemd quadlets.

## Current Supported Stack

### Native
- `mistral.rs`
- `ollama`
- `jupyter`

### Containerized
- `qdrant`
- `localai`
- `comfyui`

## Hardware Policy Terms

### NVIDIA
Primary supported GPU path.

### AMD
Experimental GPU path.

### Intel GPU
Experimental GPU path with likely CPU inference fallback until explicitly validated.

### No usable GPU
Unsupported edge case for ACABOS proper.
