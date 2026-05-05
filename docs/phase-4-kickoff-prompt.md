# Chatouille Kickoff Prompt - Phase 4 (Logs + Diagnostics)

Use this exact prompt with Chatouille for Phase 4.

---

Implement **Phase 4: Logs and Diagnostics** for the ACABOS Service Manager MVP.

Authoritative requirements:

- `docs/mvp-acabos-service-manager.md`
- `docs/mvp-acabos-service-manager-checklist.md`
- `docs/project-intake.md`
- `docs/phase-3-kickoff-prompt.md`

Scope for this phase only:

- Implement service-scoped log access:
  - follow/live tail
  - historical range (`since`)
  - filters (`level`, `regex`, keyword)
- Add TUI log view with streaming and filtering controls.
- Implement diagnostics signature parser with this minimum set:
  - `cuda_out_of_memory`
  - `nvidia_cdi_missing`
  - `port_already_in_use`
  - `image_pull_failed`
  - `upstream_dependency_unreachable`
  - `permission_denied_mount`
  - `model_not_found`
- Add diagnosis cards containing confidence, likely cause, and next actions.

Out of scope for this phase:

- No factory reset
- No volume backup/restore
- No plugin install/remove tasks
- No audit DB exports (write path can remain for Phase 5)

Deliverables:

- Journal adapter for scoped log reads.
- TUI log pane and CLI log command integration.
- Diagnostics parser module + fixtures.
- Tests for:
  - signature matching correctness
  - filter behavior
  - streaming stability under high log volume

Constraints:

- Unknown patterns must fail gracefully.
- Diagnostics must never block log streaming.
- Keep parsing deterministic and test-driven.

Return:

- code changes
- tests
- short verification steps

Verification commands:

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo check --workspace --all-targets
cargo test -p chatouille
```

---

Expected completion signal for Phase 4:

- Operator can stream logs and receive immediate, structured failure attribution for known patterns.
