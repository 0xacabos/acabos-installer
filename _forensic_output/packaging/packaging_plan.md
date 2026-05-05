# PACKAGING PLAN

## Archive Objective

Create `./_forensic_output.tar.gz` containing:

- Entire `./_forensic_output/` directory.
- All project `source_code` files identified in `docs/FILE_INDEX.md`.
- Existing repository documentation files.

## Explicit Exclusions

- `node_modules/`
- `build/`
- `dist/`
- `target/`
- caches
- binaries

## Planned Archive Layout

- `_forensic_output/docs/*`
- `_forensic_output/manifest/project_manifest.json`
- `_forensic_output/inventory/file_tree.txt`
- `_forensic_output/packaging/packaging_plan.md`
- `acabos-install`
- `doctor/acabos-doctor`
- `lib/*.sh`
- script-like files under `config/` classified as source code
- repository documentation (`README.md`, `CONTRIBUTING.md`, `docs/*.md`)

## Notes

- Runtime directories under `state/` are not included as source-code payload.
- No build/runtime artifact directories matching the exclusion list were present in observed tree.
