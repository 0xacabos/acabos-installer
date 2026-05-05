# RECOMPOSITION PLAN

## Clean Architecture Model

Proposed bounded layers based on current structure:

1. `orchestration` layer
- stage scheduler, resume policy, operator interaction.

2. `platform_primitives` layer
- state I/O, logging, chroot mount lifecycle, timeout wrappers, disk helpers.

3. `domain_stages` layer
- pure stage contracts with explicit inputs/outputs and deterministic probes.

4. `validation_policy` layer
- doctor checks, dependency graph, severity model, machine-readable reports.

5. `configuration_data` layer
- immutable templates, version pins, package sets, unit/quadlet configs.

## Component Boundary Actions

- KEEP
  - `lib/topology.sh` as declarative topology authority.
  - `config/*` data files as externalized policy/config surface.
  - stage-per-file decomposition in `lib/stage_*.sh`.

- REFACTOR
  - `acabos-install`: move top-level resume logic into functions; remove illegal `local` usage.
  - `doctor/acabos-doctor`: move top-level execution loop into `main()`; remove illegal `local` usage.
  - stage modules: replace ad-hoc inline heredocs with reusable template deployment helpers where repeated.

- EXTRACT
  - extract a shared "command execution policy" helper for consistent chroot mount/unmount around commands.
  - extract machine-readable doctor result emitter (JSON) for deterministic downstream consumption.
  - extract explicit stage contract schema (inputs, outputs, side-effects, rollback semantics) from comments into versioned data.

- DISCARD
  - no immediate file discard mandated by evidence.
  - evaluate removal or activation path for currently unreferenced/dead toggles (`ACABOS_DEV_MODE`) and unused artifacts if confirmed by full runtime tests.

## Refactor Strategy (ordered)

1. Correct hard runtime issues (`local` at top level) in orchestrator and doctor.
2. Synchronize docs and stage contract references with implemented 13-stage flow.
3. Add deterministic output mode for doctor and stage probes (structured JSON outputs).
4. Introduce strict config schema checks pre-run (required files, expected fields, hash manifests).
5. Separate destructive host actions from idempotent target configuration actions via explicit execution adapters.

## Overall Recomposition Classification

- Repository decision: `REFACTOR` (core architecture is coherent but has correctness and drift defects that block deterministic reliability claims).
