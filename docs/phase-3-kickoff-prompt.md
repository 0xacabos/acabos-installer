# Chatouille Kickoff Prompt - Phase 3 (TUI Baseline)

Use this exact prompt with Chatouille for Phase 3.

---

Implement **Phase 3: TUI Baseline** for the ACABOS Service Manager MVP.

Authoritative requirements:

- `docs/mvp-acabos-service-manager.md`
- `docs/mvp-acabos-service-manager-checklist.md`
- `docs/project-intake.md`
- `docs/phase-2-kickoff-prompt.md`

Scope for this phase only:

- Build a minimal but functional Ratatui interface with:
  - dashboard view
  - service list
  - service detail pane
  - context indicator in header
- Render state from existing backend lifecycle/status layer.
- Implement required baseline keybindings:
  - navigation (`j/k` or arrows)
  - select (`Enter`)
  - help (`?`)
  - quit/back (`q`)
- Add placeholder metrics fields where full telemetry is not yet implemented.

Out of scope for this phase:

- No log streaming view
- No diagnostics signatures
- No volume management
- No plugin operations
- No factory reset flow

Deliverables:

- TUI app state and event loop.
- Dashboard and service detail rendering.
- Help modal with key map.
- Tests for:
  - core render state transitions
  - keyboard navigation behavior
  - no-panic guarantees on empty/error states

Constraints:

- Keyboard-only operation.
- Keep layout stable and deterministic.
- Prioritize operational clarity over visual novelty.

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

Expected completion signal for Phase 3:

- Operator can launch TUI, navigate services, and inspect baseline status without mouse usage.
