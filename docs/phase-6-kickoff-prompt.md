# Chatouille Kickoff Prompt - Phase 6 (Plugin Task Runners + MVP Closeout)

Use this exact prompt with Chatouille for Phase 6.

---

Implement **Phase 6: Plugin Task Runners and MVP Closeout** for the ACABOS Service Manager MVP.

Authoritative requirements:

- `docs/mvp-acabos-service-manager.md`
- `docs/mvp-acabos-service-manager-checklist.md`
- `docs/project-intake.md`
- `docs/phase-5-kickoff-prompt.md`

Scope for this phase only:

- Implement plugin/adjacent tooling task runners for MVP-required services:
  - Ollama model tasks (`list`, `install/pull`, `remove`)
  - ComfyUI custom node tasks (`list`, `install`, `remove`, `update`)
  - Stable Diffusion extension tasks (`list`, `install`, `remove`, `update`)
- Include provenance tracking for plugin/model sources.
- Ensure plugin operations are auditable.
- Finalize CLI/TUI wiring for plugin operations.
- Perform MVP acceptance pass against checklist and close gaps.

Out of scope for this phase:

- No new post-MVP feature families
- No web interface or multi-node orchestration

Deliverables:

- Plugin abstraction and per-service adapters.
- CLI commands and TUI controls for plugin tasks.
- Audit integration for all plugin mutations.
- Acceptance checklist report with pass/fail evidence.
- Tests for:
  - install/remove cycle for one plugin/model per required service class
  - invalid source rejection
  - provenance capture

Constraints:

- Keep plugin operations explicit and reversible when possible.
- Never execute unvalidated source inputs.
- Preserve deterministic naming and command surfaces.

Return:

- code changes
- tests
- short verification steps
- explicit MVP acceptance summary

Verification commands:

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo check --workspace --all-targets
cargo test -p chatouille
```

---

Expected completion signal for Phase 6:

- MVP acceptance gate is fully satisfied with evidence, and required plugin workflows are operational.
