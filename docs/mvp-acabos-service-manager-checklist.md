# ACABOS Service Manager MVP Implementation Checklist

This checklist converts `docs/mvp-acabos-service-manager.md` into implementation tasks with acceptance criteria and test coverage.

## 0) Project Setup

- [ ] Initialize Rust workspace for `acabos-services`
- [ ] Add crates: `ratatui`, `crossterm`, `clap`, `tokio`, `zbus`, `serde`, `serde_json`, `rusqlite`, `nvml-wrapper`
- [ ] Define module boundaries: `systemd`, `podman`, `logs`, `diagnostics`, `gpu`, `audit`, `tui`, `cli`
- [ ] Add `justfile` or `Makefile` tasks for build/test/lint/release
- [ ] Add CI workflow for `fmt`, `clippy`, unit tests

Definition of done:

- [ ] `cargo build` succeeds
- [ ] `cargo test` succeeds
- [ ] `cargo clippy -- -D warnings` succeeds

Test cases:

- [ ] Fresh clone builds on target host
- [ ] Binary runs with `--help`

---

## 1) Service Registry and Domain Model

- [ ] Implement canonical service registry for all MVP services
- [ ] Include scope (`system`/`user`), unit name, ports, GPU requirement, health probe, volume names
- [ ] Add typed model for runtime status (`active`, `inactive`, `failed`, etc.)
- [ ] Add typed model for action results and error classes

Definition of done:

- [ ] Registry includes all required services (`ollama`, `ollama-webui`, `localai`, `qdrant`, `whisper-asr`, `ai-toolbox`, `text-generation-webui`, `comfyui`, `stable-diffusion`, `ollama-user`, `acab-inference`)
- [ ] Invalid service key returns clear validation error

Test cases:

- [ ] Registry lookup success for each service
- [ ] Unknown service lookup fails predictably

---

## 2) Context and Privilege Handling

- [ ] Implement context manager (`system` vs `user`)
- [ ] Auto-detect default context
- [ ] Add explicit context override flags in CLI
- [ ] Enforce permission checks for system operations

Definition of done:

- [ ] Tool never runs user action against system units accidentally
- [ ] Tool never runs system action against user units accidentally
- [ ] Context is visible in TUI header and CLI output

Test cases:

- [ ] Attempt system action without privileges yields permission error code
- [ ] `ollama-user` operations route through user scope only

---

## 3) systemd Integration Layer

- [ ] Implement unit introspection via D-Bus
- [ ] Implement actions: start/stop/restart/enable/disable/reload
- [ ] Implement state polling and transition timestamp retrieval
- [ ] Implement dependency checks (e.g., `ollama-webui` dependency on `ollama`)

Definition of done:

- [ ] Lifecycle actions work for each managed service
- [ ] State model reflects actual systemd state

Test cases:

- [ ] Start/stop/restart cycle for a test unit
- [ ] Enable/disable persists across daemon reload

---

## 4) Podman Integration Layer

- [ ] Connect to Podman socket API
- [ ] Implement container inspection: image, mounts, restart count, status
- [ ] Implement image pull operation
- [ ] Implement safe recreate operation (preserve volumes by default)
- [ ] Implement factory reset operation (remove container + selected volumes + re-pull + recreate)

Definition of done:

- [ ] Podman state is merged with systemd state in service detail output
- [ ] Factory reset requires explicit typed confirmation

Test cases:

- [ ] Recreate preserves named volumes
- [ ] Factory reset destroys only declared targets
- [ ] Pull failure returns actionable error

---

## 5) Runtime Instrumentation and Metrics

- [ ] Implement CPU and memory collection per service/container
- [ ] Implement uptime and restart trend tracking
- [ ] Implement health endpoint probes per service
- [ ] Add degraded state logic when endpoint fails but unit is active

Definition of done:

- [ ] Dashboard renders state + core metrics for all services
- [ ] Health degradation appears visually and in CLI JSON mode

Test cases:

- [ ] Simulated endpoint failure marks service degraded
- [ ] Metrics refresh remains stable under load

---

## 6) GPU Telemetry and Runtime Validation

- [ ] Integrate NVML for GPU state (temperature, utilization, memory)
- [ ] Map GPU data to GPU-enabled services
- [ ] Implement CDI runtime validity checks
- [ ] Raise diagnostics when GPU service has no GPU visibility

Definition of done:

- [ ] GPU services show VRAM gauge in TUI and numeric stats in CLI
- [ ] Missing CDI/device mapping surfaces as diagnostic alert

Test cases:

- [ ] GPU unavailable path produces clear diagnosis
- [ ] GPU available path reports expected telemetry

---

## 7) Logs and Parsing Engine

- [ ] Implement journal reader for service-scoped logs
- [ ] Add live follow mode
- [ ] Add filters: severity, time range, regex, keyword
- [ ] Add export function for filtered log slices
- [ ] Implement parser signatures:
  - [ ] `cuda_out_of_memory`
  - [ ] `nvidia_cdi_missing`
  - [ ] `port_already_in_use`
  - [ ] `image_pull_failed`
  - [ ] `upstream_dependency_unreachable`
  - [ ] `permission_denied_mount`
  - [ ] `model_not_found`

Definition of done:

- [ ] Log view remains responsive while following streams
- [ ] Parser returns confidence, likely cause, and next actions

Test cases:

- [ ] Fixture logs trigger expected signatures
- [ ] Unknown log content yields "no known signature" cleanly

---

## 8) Volume and Data Management

- [ ] Implement per-service volume inventory
- [ ] Add size estimation for each volume
- [ ] Add backup/archive command for selected service volumes
- [ ] Add restore command from backup bundle
- [ ] Add guarded volume purge command

Definition of done:

- [ ] Operator can backup and restore at least one service volume end-to-end
- [ ] Purge requires strong confirmation and records audit event

Test cases:

- [ ] Backup archive contains expected service volume data
- [ ] Restore rebuilds expected files

---

## 9) Plugin and Adjacent Tooling Tasks

- [ ] Implement plugin operation abstraction (list/install/remove)
- [ ] Implement Ollama model tasks
- [ ] Implement ComfyUI custom node tasks
- [ ] Implement Stable Diffusion extension tasks
- [ ] Implement Text Generation WebUI extension/model tasks
- [ ] Implement AI Toolbox package task runner

Definition of done:

- [ ] At least Ollama, ComfyUI, and Stable Diffusion plugin flows are functional
- [ ] Plugin operations include source/provenance in output and audit records

Test cases:

- [ ] Install/remove cycle for one plugin/model per supported service
- [ ] Invalid plugin source is rejected safely

---

## 10) Audit Trail (SQLite)

- [ ] Create audit schema (actor, host, scope, service, action, args, result, duration, correlation_id, timestamp)
- [ ] Write audit event for all lifecycle, purge, archive, plugin, and config actions
- [ ] Implement audit query command
- [ ] Implement JSON/CSV export

Definition of done:

- [ ] Every mutating operation leaves an audit record
- [ ] Exported audit data is parseable and complete

Test cases:

- [ ] Action execution creates expected DB row
- [ ] Export output validates as JSON/CSV

---

## 11) CLI Surface

- [ ] Implement all MVP CLI commands and flags
- [ ] Provide `--json` support where applicable
- [ ] Implement stable exit code semantics
- [ ] Add shell completion generation
- [ ] Add command help examples

Definition of done:

- [ ] CLI supports scriptable automation for all core operations
- [ ] Exit codes match spec (`0`, `1`, `2`, `3`, `4`)

Test cases:

- [ ] Golden output tests for key commands
- [ ] Exit code tests for success/failure/permission mismatch

---

## 12) TUI Surface

- [ ] Implement dashboard with status cards/table
- [ ] Implement service detail pane
- [ ] Implement logs view with filtering and diagnostics overlay
- [ ] Implement actions view (including factory reset)
- [ ] Implement volume management view
- [ ] Implement plugin management view
- [ ] Implement audit explorer view
- [ ] Implement keybindings and help modal

Definition of done:

- [ ] All required views are reachable without mouse
- [ ] Core actions available from keyboard shortcuts
- [ ] TUI remains usable over SSH terminal

Test cases:

- [ ] Snapshot tests for major render states
- [ ] Keyboard navigation integration tests

---

## 13) Safety and Validation Guardrails

- [ ] Implement destructive action confirmation flows
- [ ] Implement dry-run previews for reset/purge/archive operations
- [ ] Validate config edits before apply
- [ ] Redact secrets from logs and exports

Definition of done:

- [ ] No destructive operation executes without explicit user confirmation
- [ ] Unsafe or invalid config changes are blocked with explanation

Test cases:

- [ ] Cancel path does not mutate system state
- [ ] Invalid config edit is rejected with non-zero exit code

---

## 14) Packaging and Delivery

- [ ] Build release binary for target architecture
- [ ] Install binary at `/usr/local/bin/acabos-services`
- [ ] Generate and install shell completions
- [ ] Provide man page and quickstart docs
- [ ] Publish release artifact checksums

Definition of done:

- [ ] Operator can install and run tool with no additional runtime dependencies
- [ ] Documentation covers first-use workflow

Test cases:

- [ ] Fresh system install smoke test
- [ ] Quickstart flow reproduces expected output

---

## 15) MVP Final Acceptance Gate

All items below must be true before MVP is considered complete:

- [ ] Dual-context management works (system + user)
- [ ] Full lifecycle control works for all listed services
- [ ] Dashboard provides real-time operational view
- [ ] Logs can be streamed, filtered, and diagnosed
- [ ] Factory reset is safe, explicit, and audited
- [ ] Plugin workflows are operational for required services
- [ ] Audit export works and is complete
- [ ] CLI automation behavior is stable and documented

---

## Suggested First Sprint Cut (Practical)

If you want this moving fast, start with this thin vertical slice:

- [ ] Service registry + context manager
- [ ] systemd start/stop/status
- [ ] basic dashboard + detail pane
- [ ] logs follow + one diagnostic signature (`port_already_in_use`)
- [ ] audit writes for lifecycle actions

Then expand into reset workflows, volume tooling, and plugins.
