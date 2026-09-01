# Bug Assessment: zfa tdd refactor calls dart run bin/zfa.dart build which does not exist

- **Slug**: tdd-refactor-missing-bin-zfa-dart
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/689
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd refactor` hardcodes the path `dart run bin/zfa.dart build` as the build pass, but this file does not exist in a project bootstrapped by `zfa setup`. The refactor step always fails with exit 255.

## Symptom

`zfa tdd refactor` exits 255 with "Could not resolve the package: Missing bin/zfa.dart in the package."

## Reproduction

1. `zfa setup` → creates system `zfa` at `~/.local/bin/zfa`, no `bin/zfa.dart` in project.
2. `zfa tdd init` → TDD baseline.
3. `zfa tdd gen` + `make` → works.
4. `zfa tdd refactor` → exit 255.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/refactor_command.dart` — hardcodes `dart run bin/zfa.dart build`.

## Root Cause Hypothesis

`zfa setup` installs the system-level `zfa` CLI at `~/.local/bin/zfa` but does NOT create a `bin/zfa.dart` in the project. The refactor command hardcodes `dart run bin/zfa.dart build`, which fails because the file doesn't exist. Confidence: **high** — the file is absent and the path is hardcoded.

## Proposed Remediation

**Preferred:** Use the system-installed `zfa build` command instead of `dart run bin/zfa.dart build`. The system `zfa` is already on PATH (or resolvable via the same entrypoint resolution used by other TDD commands).

**Alternatives:**
- Create a `bin/zfa.dart` passthrough stub during `zfa setup` / `zfa tdd init`.
- Resolve the zfa entrypoint the same way `make`/`gen`/`verify` do (via `PipelineRunner`).

**Files likely to change**:
- `lib/src/plugins/tdd/commands/refactor_command.dart`

**Tests to add or update**:
- `zfa tdd refactor` on a fresh `zfa setup` project → exits 0 (build pass succeeds).
- Regression: refactor still works when `bin/zfa.dart` does exist.

## Risks & Considerations

- Using the system `zfa build` requires the entrypoint resolution to work reliably (it already does for other TDD commands).
- Creating a `bin/zfa.dart` stub is a fallback if entrypoint resolution is unreliable.

## Open Questions

- None blocking.