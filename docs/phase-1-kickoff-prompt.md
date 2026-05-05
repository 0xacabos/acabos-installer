# Chatouille Kickoff Prompt - Phase 1 (Domain + Registry)

Use this exact prompt with Chatouille to begin implementation.

---

Implement **Phase 1: Domain and Registry** for the ACABOS Service Manager MVP.

Authoritative requirements:

- `docs/mvp-acabos-service-manager.md`
- `docs/mvp-acabos-service-manager-checklist.md`
- `docs/project-intake.md`

Scope for this phase only:

- Create typed domain models for managed services, runtime state, health state, action result, and context scope.
- Create canonical service registry entries for:
  - `ollama`
  - `ollama-webui`
  - `localai`
  - `qdrant`
  - `whisper-asr`
  - `ai-toolbox`
  - `text-generation-webui`
  - `comfyui`
  - `stable-diffusion`
  - `ollama-user` (user scope)
  - `acab-inference`
- Include per-service metadata: unit name, scope, default ports, GPU requirement, key volumes, and optional health endpoint.
- Implement context model and validation logic that prevents user/system scope mixups.
- Implement CLI skeleton routes (no actual systemd actions yet), enough to parse and validate service and scope inputs.

Out of scope for this phase:

- No real systemd operations
- No podman operations
- No TUI rendering
- No log parsing
- No audit persistence

Deliverables:

- New modules/files for domain + registry + context validation.
- Minimal CLI plumbing using existing conventions.
- Tests for:
  - registry lookup success for all required services
  - unknown service failure path
  - scope validation (system vs user)
  - input parsing correctness for planned lifecycle commands

Constraints:

- Keep naming deterministic and stable.
- Keep APIs small and composable.
- Add clear error types/messages for invalid service/scope combos.
- Do not add features from later phases.

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

Expected completion signal for Phase 1:

- Service registry and scope validation are implemented and tested.
- CLI accepts planned service identifiers and rejects invalid scope/service combinations deterministically.
