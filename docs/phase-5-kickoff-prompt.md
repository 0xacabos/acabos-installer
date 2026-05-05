# Chatouille Kickoff Prompt - Phase 5 (Reset + Volumes + Audit)

Use this exact prompt with Chatouille for Phase 5.

---

Implement **Phase 5: Reset, Volume Management, and Audit Trail** for the ACABOS Service Manager MVP.

Authoritative requirements:

- `docs/mvp-acabos-service-manager.md`
- `docs/mvp-acabos-service-manager-checklist.md`
- `docs/project-intake.md`
- `docs/phase-4-kickoff-prompt.md`

Scope for this phase only:

- Implement recreate and factory reset workflows:
  - recreate (preserve volumes)
  - factory reset (destructive, explicit confirmation)
- Implement volume operations:
  - list
  - size estimate
  - backup/archive
  - restore
  - purge (guarded)
- Implement audit persistence to SQLite for all mutating actions:
  - lifecycle actions
  - reset/recreate actions
  - volume operations
  - archive/purge operations
- Implement audit query and export (JSON/CSV) in CLI.

Out of scope for this phase:

- No new TUI feature families beyond wiring existing actions/views
- No plugin ecosystems (Phase 6)

Deliverables:

- Reset workflow module with safety guards.
- Volume management module.
- Audit DB schema + writer + query/export layer.
- Tests for:
  - confirmation-gated destructive flows
  - backup/restore roundtrip
  - audit row creation for each mutating action category
  - JSON/CSV export validity

Constraints:

- No destructive operation without explicit confirmation.
- Operations must be idempotent where practical.
- Errors must include remediation hints.

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

Expected completion signal for Phase 5:

- Operator can safely perform reset and volume workflows with complete audit traceability.
