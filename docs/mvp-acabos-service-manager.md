# ACABOS Service Manager MVP Request (TUI + CLI)

## 1) Executive Summary

Build a production-grade, operator-first management toolkit for ACABOS AI services, delivered as a single Rust binary that supports both:

- an interactive **TUI** (default mode), and
- a scriptable **CLI** (subcommands for automation).

The tool is the canonical control plane for service lifecycle, observability, troubleshooting, audit logging, and safe reset workflows across the installed container stack.

This MVP is intentionally opinionated:

- The source of truth is **systemd** service state (not `podman ps` alone).
- Every destructive operation is explicit, logged, and previewed.
- Diagnostics are first-class, not an afterthought.
- GPU health and container runtime correctness are mandatory runtime signals.

---

## 2) Product Definition

### Product Name

`acabos-services`

### Runtime Behavior

- `acabos-services` with no args launches the TUI.
- `acabos-services <subcommand>` runs CLI mode.

### Primary Goal

Provide end-to-end management and auditing for the ACABOS service suite:

- `ollama.service`
- `ollama-webui.service`
- `localai.service`
- `qdrant.service`
- `whisper-asr.service`
- `ai-toolbox.service`
- `text-generation-webui.service`
- `comfyui.service`
- `stable-diffusion.service`
- `ollama-user.service` (user scope)
- `acab-inference.service` (host-native inference service)

---

## 3) Required Technology Stack

### Core

- Rust stable
- `ratatui` for TUI rendering
- `crossterm` for terminal backend/input
- `clap` for CLI surface
- `tokio` for async orchestration

### Integrations

- `zbus` (or equivalent D-Bus crate) for systemd control/introspection
- Podman API via Unix socket (`/run/podman/podman.sock`)
- `nvml-wrapper` for NVIDIA telemetry
- `serde` + `serde_json` for state and exports
- `rusqlite` for local audit log database

### Packaging

- Single installable binary at `/usr/local/bin/acabos-services`
- Shell completions generated for bash/zsh/fish

---

## 4) Architecture (MVP)

```text
Operator
  |
  v
acabos-services (TUI/CLI)
  |-- systemd client (system scope + user scope)
  |-- podman client (socket API)
  |-- log ingestion (journalctl streams and historical pulls)
  |-- diagnostics engine (rules over logs + runtime signals)
  |-- gpu telemetry (NVML)
  `-- audit store (SQLite)
```

### Privilege Model

- **System scope** operations require root privileges.
- **User scope** operations target `systemctl --user` for `ollama-user.service`.
- Tool auto-detects scope and displays active context prominently.

### Service Source-of-Truth Model

- Runtime state: systemd unit status (`active`, `inactive`, `failed`, `activating`, `deactivating`).
- Runtime details: Podman inspect data (container ID, image hash, mounts, restart count).
- Health overlays: endpoint checks + GPU availability + dependency checks.

---

## 5) Managed Service Catalog (Baseline)

| Service | Scope | Purpose | Ports | GPU | Key Volume(s) |
|---|---|---|---|---|---|
| `ollama` | system | LLM backend | 11434 | yes | `ollama-data` |
| `ollama-webui` | system | Ollama UI | 8080 | no | `open-webui-data` |
| `localai` | system | OpenAI-compatible local API | 8081 | yes | `localai-models`, `localai-preload` |
| `qdrant` | system | Vector DB | 6333, 6334 | no | `qdrant-data` |
| `whisper-asr` | system | Speech-to-text API | 9000 | yes | `whisper-models` |
| `ai-toolbox` | system | PyTorch/Jupyter toolbox | 8888, 6006 | yes | `ai-projects`, `ai-models`, `ai-data` |
| `text-generation-webui` | system | LLM web UI/API | 7861, 5000 | yes | `tgwebui-models`, `tgwebui-loras`, `tgwebui-extensions` |
| `comfyui` | system | Workflow image generation UI | 8188 | yes | `comfyui-models`, `comfyui-output`, `comfyui-custom-nodes` |
| `stable-diffusion` | system | Stable Diffusion web service | 7860 | yes | `sd-models`, `sd-outputs`, `sd-extensions` |
| `ollama-user` | user | User-scoped Ollama | 11435 | yes | `ollama-user-data` |
| `acab-inference` | system | Host-native mistral.rs | 8012 | yes | host paths under `/opt/acab` |

---

## 6) Functional Requirements (Highly Opinionated)

## 6.1 Service Lifecycle Control

Must support for each service:

- Start
- Stop
- Restart
- Enable
- Disable
- Reload (if unit supports it)
- Recreate container (non-destructive to data volumes)
- Factory reset (destructive)

Factory reset workflow (mandatory guardrails):

1. Show exact resources to delete (container + named volumes).
2. Require typed confirmation phrase.
3. Execute ordered teardown.
4. Re-pull image.
5. Recreate and start.
6. Record operation in audit DB with operator, timestamp, and result.

## 6.2 Runtime State Instrumentation

Dashboard must expose at-a-glance status widgets:

- Service state pill (`active`, `inactive`, `failed`, etc.)
- Last transition timestamp
- Uptime timer
- Restart count (rolling window)
- CPU and memory gauge
- GPU memory gauge (if GPU service)
- Health endpoint status

Required visual language:

- Green: healthy active
- Yellow: degraded/warn
- Red: failed/unhealthy
- Gray: disabled/inactive

## 6.3 Bulk Actions

Support stack-level operations:

- Start all AI services
- Stop all AI services
- Restart failed only
- Pull all images
- Validate all health endpoints
- Snapshot and archive all logs

Bulk actions must show per-service progress and final rollup report.

## 6.4 Log Management and Parsing

Log subsystem must support:

- Live tail per service
- Historical range queries (last N min/hours/days)
- Regex filtering
- Severity filtering
- Keyword filters (GPU, CUDA, OOM, permission, timeout)
- Export to file

Must include a diagnostics parser with built-in failure signatures:

- NVIDIA CDI/device mapping issues
- Port bind conflicts
- Missing model files
- OOM and VRAM exhaustion
- Image pull/auth failures
- Permission and SELinux/AppArmor restrictions
- Dependency service unavailable (example: `ollama-webui` cannot reach `ollama`)

Each signature returns:

- confidence score
- likely cause
- immediate remediation steps

## 6.5 Archival and Purge Operations

Mandatory administrative operations:

- Purge old journals for selected services
- Archive logs to timestamped bundles
- Rotate and prune old archives by retention policy
- Export audit events to JSON/CSV

Every purge/archive action is audited and reversible where feasible.

## 6.6 Volume and Data Operations

Per-service data controls:

- List attached named volumes
- Show approximate size per volume
- Snapshot/backup volume contents
- Restore from backup
- Purge selected volume(s)

Destructive volume actions must require strong confirmation.

## 6.7 Configuration Operations

Manage quadlet-backed configuration safely:

- View resolved unit configuration
- View local unit file source
- Diff against default template
- Edit with validation
- Roll back to default
- Trigger `daemon-reload` and restart on successful update

Invalid config must never be applied silently.

## 6.8 Plugin and Adjacent Tooling Installation

MVP must include plugin/task runners for container-specific ecosystem tasks.

Examples:

- Ollama: pull/list/remove models
- ComfyUI: install/update/remove custom nodes
- Stable Diffusion: install/update/remove extensions
- Text Generation WebUI: extension management and model sync
- AI Toolbox: package install tasks (inside container)

Plugin operations must show provenance (source URL/repo) and audit record.

## 6.9 Audit Trail

Audit DB required for every operator action:

- actor
- host
- scope (system/user)
- service
- action
- arguments
- result (success/failure)
- execution time
- correlation ID

Audit events must be queryable in TUI and exportable via CLI.

---

## 7) CLI Specification (MVP)

```text
acabos-services status [--all|--service <name>] [--json]
acabos-services start <service|group>
acabos-services stop <service|group>
acabos-services restart <service|group>
acabos-services enable <service>
acabos-services disable <service>
acabos-services recreate <service> [--preserve-volumes]
acabos-services reset <service> [--factory] [--yes-i-know]

acabos-services logs <service> [--follow] [--since <duration>] [--grep <regex>] [--level <lvl>]
acabos-services diagnose <service> [--since <duration>] [--json]

acabos-services volumes list [--service <name>]
acabos-services volumes backup <service> --output <path>
acabos-services volumes restore <service> --input <path>
acabos-services volumes purge <service> [--volume <name>] [--yes-i-know]

acabos-services plugins list <service>
acabos-services plugins install <service> <plugin-or-model>
acabos-services plugins remove <service> <plugin-or-model>

acabos-services archive logs [--service <name>|--all] --output <path>
acabos-services archive audit --output <path>

acabos-services context show
acabos-services context set --scope <system|user>
```

Exit code policy:

- `0`: success
- `1`: operational failure
- `2`: usage/validation error
- `3`: partial success in bulk action
- `4`: permission/context mismatch

---

## 8) TUI Specification (MVP)

## 8.1 Layout

```text
+--------------------------------------------------------------------------------+
| ACABOS Services | Context: system | Host: <hostname> | Alerts: 2 | GPU: OK     |
+----------------------------------+---------------------------------------------+
| Service List                      | Service Detail                              |
|----------------------------------|---------------------------------------------|
| ollama            ACTIVE         | State: ACTIVE (healthy)                     |
| ollama-webui      DEGRADED       | Uptime: 02:14:55                            |
| qdrant            ACTIVE         | CPU: 12%  MEM: 1.1G  VRAM: 3.2G             |
| comfyui           FAILED         | Ports: 8188                                  |
| ...                              | Volumes: comfyui-models, comfyui-output     |
|                                  | Dependencies: nvidia cdi, podman runtime    |
+----------------------------------+---------------------------------------------+
| F1 Dashboard | F2 Logs | F3 Actions | F4 Volumes | F5 Plugins | F6 Audit      |
+--------------------------------------------------------------------------------+
```

## 8.2 Mandatory Views

- Dashboard
- Service Detail
- Logs (stream + filter + parse)
- Actions/Runbook view
- Volume management
- Plugin management
- GPU telemetry
- Audit explorer

## 8.3 Widget Requirements

- Status badges
- Gauges (CPU/MEM/VRAM)
- Sparklines (restart and error frequency)
- Table with sortable columns
- Modal confirm dialogs
- Non-blocking toast notifications

## 8.4 Keybindings (Required)

- `j/k` or arrows: move selection
- `Enter`: open detail
- `s`: start
- `t`: stop
- `r`: restart
- `e`: enable/disable toggle
- `l`: logs view
- `d`: diagnose
- `x`: factory reset action
- `/`: search
- `?`: help
- `q`: back/quit

---

## 9) Service-Specific Function Rundown

## 9.1 ollama

- Functions: model pull/list/delete, warm model, endpoint ping, GPU allocation view.
- Failure focus: model corruption, disk full, GPU unavailable.

## 9.2 ollama-webui

- Functions: backend URL validation, connectivity test to Ollama, session/data backup.
- Failure focus: cannot reach `host.containers.internal:11434`.

## 9.3 localai

- Functions: model preload inspect, OpenAI-compatible endpoint health, context/thread tuning.
- Failure focus: invalid model layout, CUDA failure, overcommitted context size.

## 9.4 qdrant

- Functions: collection list/summary, snapshot trigger, index status checks.
- Failure focus: corrupted storage, write permission issues, port conflicts.

## 9.5 whisper-asr

- Functions: model selection/verification, inference latency probe, queue depth metric.
- Failure focus: missing ASR model cache, GPU memory pressure.

## 9.6 ai-toolbox

- Functions: Jupyter/TensorBoard process checks, workspace quota checks, package task runner.
- Failure focus: notebook token/auth config, dependency drift.

## 9.7 text-generation-webui

- Functions: model and LoRA inventory, API health, extension control.
- Failure focus: extension breakage, incompatible model format.

## 9.8 comfyui

- Functions: custom node install/update/remove, workflow import/export, output cleanup.
- Failure focus: broken custom node graph dependencies.

## 9.9 stable-diffusion

- Functions: extension management, model inventory, output archive and cleanup.
- Failure focus: extension regression, xformers startup issues.

## 9.10 ollama-user (user scope)

- Functions: user-level lifecycle control, model management, user context diagnostics.
- Failure focus: lingering not enabled, missing user systemd session.

## 9.11 acab-inference

- Functions: host-native endpoint health (`:8012`), binary/version checks, log parsing.
- Failure focus: missing model manifests, CUDA/cudnn issues.

---

## 10) Log Parsing and Failure Attribution Rules (MVP)

Rules engine must map known patterns to diagnosis cards.

Example card shape:

```json
{
  "service": "comfyui",
  "signature": "cuda_out_of_memory",
  "confidence": 0.93,
  "likely_cause": "VRAM exhaustion during workflow execution",
  "next_actions": [
    "Reduce batch size",
    "Unload inactive models",
    "Restart service to reclaim VRAM"
  ]
}
```

Minimum signature set:

- `cuda_out_of_memory`
- `nvidia_cdi_missing`
- `port_already_in_use`
- `image_pull_failed`
- `upstream_dependency_unreachable`
- `permission_denied_mount`
- `model_not_found`

---

## 11) Security and Safety Requirements

- No destructive action without explicit operator confirmation.
- Context-safe execution (cannot accidentally run user operations against system scope and vice versa).
- Input validation for all plugin URLs/names.
- Audit events are append-only from the application layer.
- Redact secrets from logs and exported reports.

---

## 12) Non-Functional Requirements

- Cold start in under 2 seconds on target hardware.
- Dashboard refresh interval configurable (default 2s).
- Log streaming must remain responsive under high throughput.
- CLI output supports both human and JSON modes.
- Must operate correctly over SSH terminals.

---

## 13) MVP Acceptance Criteria

MVP is accepted only if all are true:

- Operator can fully manage lifecycle for every listed service in both scopes.
- Dashboard shows real-time status and resource signals per service.
- Log view supports live tail, filter, and automatic failure attribution.
- Factory reset flow works with explicit safeguards and audit logging.
- Plugin tooling operations are available for at least Ollama, ComfyUI, and Stable Diffusion.
- Audit exports are generated and parseable.
- CLI commands are scriptable with stable exit codes.

---

## 14) Build and Delivery Requirements

- Repository includes:
  - Rust workspace
  - integration tests for systemd and Podman adapters
  - fixture-based tests for log signature parser
  - sample config for managed service registry
- Deliverables:
  - release binary
  - man page
  - shell completions
  - operator quickstart markdown

This MVP must feel like a serious operations tool on day one, not a demo shell.
