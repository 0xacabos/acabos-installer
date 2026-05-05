# Project Intake: ACABOS Service Manager (for Chatouille)

## Purpose

Use Chatouille to generate an MVP-grade Rust + Ratatui service-management toolkit (`acabos-services`) for ACABOS AI container operations.

This intake file defines the generation strategy, phase boundaries, and acceptance checkpoints to keep output deterministic and testable.

## Primary Inputs

- `docs/mvp-acabos-service-manager.md`
- `docs/mvp-acabos-service-manager-checklist.md`

Treat these as the source of truth for product scope, functional requirements, and definition-of-done.

## Target Output

Generate a Rust project implementing:

- TUI-first operational interface (Ratatui)
- CLI command surface for automation
- Dual context support (system + user systemd scopes)
- Full lifecycle management for ACABOS services
- Logging, diagnostics, audit, and guarded reset workflows

## Non-Negotiable Constraints

- Systemd state is canonical service truth.
- Destructive actions require explicit confirmation.
- Every mutating action is auditable.
- GPU services must expose GPU runtime signals.
- MVP scope only (no post-MVP feature creep).

## Recommended Generation Strategy

Run Chatouille in phased prompts rather than one-shot generation.

### Phase 1: Domain and Registry

Generate:

- service catalog and typed domain models
- context/scope model (`system` vs `user`)
- command routing skeleton

Exit gate:

- service lookup and scope validation tests pass

### Phase 2: Lifecycle CLI Core

Generate:

- CLI commands for `status`, `start`, `stop`, `restart`, `enable`, `disable`
- systemd adapter integration
- stable exit codes

Exit gate:

- lifecycle smoke tests pass for at least one system service and one user service

### Phase 3: TUI Baseline

Generate:

- dashboard + service detail panes
- status badges and core metrics placeholders
- keybindings and help modal

Exit gate:

- keyboard-only navigation works
- state updates render without panics

### Phase 4: Logs + Diagnostics

Generate:

- log tail and historical filters
- signature-based diagnostics parser
- diagnosis cards with cause/remediation

Exit gate:

- fixture logs trigger expected signatures

### Phase 5: Reset, Volumes, and Audit

Generate:

- recreate/factory reset flows
- guarded volume operations
- SQLite audit writer + export

Exit gate:

- destructive actions are confirmation-gated
- audit rows emitted for all mutating operations

### Phase 6: Plugin Tasks (MVP subset)

Generate:

- Ollama model task runner
- ComfyUI custom node task runner
- Stable Diffusion extension task runner

Exit gate:

- install/remove cycle works for one artifact per service class

## Prompting Guidance for Chatouille

- Keep each phase prompt narrow and explicit.
- Include exact files to create/modify in each phase prompt.
- Require tests with each phase.
- Reject any response that skips error handling for operations touching data.
- Require deterministic command and module naming across phases.

## Suggested Prompt Template (per phase)

```text
Implement Phase <N> for the ACABOS Service Manager MVP.

Authoritative requirements:
- docs/mvp-acabos-service-manager.md
- docs/mvp-acabos-service-manager-checklist.md

Scope for this phase only:
- <bullet list>

Deliverables:
- <files/modules>
- tests for <specific behaviors>

Constraints:
- No out-of-scope features
- Strong error handling
- Deterministic naming

Return:
- code changes
- tests
- short verification steps
```

## Validation Commands (Local)

From Chatouille workspace root:

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo check --workspace --all-targets
cargo test -p chatouille
```

For generated project artifacts, require at minimum:

```bash
cargo check
cargo test
```

## Handoff Bundle

Provide these three docs to Chatouille together:

- `docs/mvp-acabos-service-manager.md`
- `docs/mvp-acabos-service-manager-checklist.md`
- `docs/project-intake.md`

This bundle is sufficient to drive a deterministic, phased MVP build with auditable progress.
