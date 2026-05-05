# Chatouille Kickoff Prompt - Phase 2 (Lifecycle CLI Core)

Use this exact prompt with Chatouille for Phase 2.

---

Implement **Phase 2: Lifecycle CLI Core** for the ACABOS Service Manager MVP.

Authoritative requirements:

- `docs/mvp-acabos-service-manager.md`
- `docs/mvp-acabos-service-manager-checklist.md`
- `docs/project-intake.md`
- `docs/phase-1-kickoff-prompt.md`

Scope for this phase only:

- Implement systemd lifecycle operations for CLI:
  - `status`
  - `start`
  - `stop`
  - `restart`
  - `enable`
  - `disable`
- Wire context-aware execution:
  - system scope for system services
  - user scope for `ollama-user`
- Implement stable exit code behavior:
  - `0` success
  - `1` operational failure
  - `2` usage/validation error
  - `4` permission/context mismatch
- Add `--json` output mode for `status`.

Out of scope for this phase:

- No TUI rendering
- No podman image/recreate/reset operations
- No logs/diagnostics parser
- No audit DB

Deliverables:

- systemd adapter module with typed errors.
- CLI command handlers for lifecycle operations.
- JSON and human-readable status output.
- Tests for:
  - one system-scope service action path
  - one user-scope service action path
  - permission/context mismatch behavior
  - exit code correctness

Constraints:

- Reuse Phase 1 registry and scope validation.
- Keep command semantics deterministic.
- Return clear, actionable errors.

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

Expected completion signal for Phase 2:

- Lifecycle CLI commands execute with scope safety and stable exit codes.
