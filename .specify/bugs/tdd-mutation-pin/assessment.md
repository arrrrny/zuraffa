# Bug Assessment: zfa tdd init pins mutation_test ^1.0.0 while the toolchain's MutationVerifier parses the v1.8.0+ report format

- **Slug**: tdd-mutation-pin
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/755
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

`zfa tdd init` writes `mutation_test: ^1.0.0` into generated projects' `dev_dependencies`, but the toolchain's own `MutationVerifier` parses the **mutation_test v1.8.0+** report format. Every initialized project is internally inconsistent out of the box — the pin predates the format the verifier expects. https://github.com/arrrrny/zuraffa/issues/755

## Symptom

Newly initialized TDD projects get `mutation_test: ^1.0.0`, but the mutation verifier only understands v1.8.0+ reports. The pin must be manually raised after init.

## Reproduction

1. Run `zfa tdd init` on any project (Dart or Flutter mode).
2. Inspect generated `pubspec.yaml` — `dev_dependencies` contains `mutation_test: ^1.0.0`.
3. Compare with `lib/src/plugins/tdd/services/mutation_verifier.dart:235,255` which documents and parses v1.8.0+ format only.

## Suspected Code Paths

- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:26` — `flutterDevDependencies` map
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart:35` — `dartDevDependencies` map

## Root Cause Hypothesis

The version pin in `pubspec_dev_dependencies_patcher.dart` was never updated to match the `MutationVerifier`'s v1.8.0+ requirement. The verifier presumably upgraded its parser but the init writer kept the old pin.

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

Likely fix: bump both maps from `mutation_test: '^1.0.0'` to `mutation_test: '^1.8.0'`. Also update `coverage` to latest (suggested ^1.15.1) and remove unused `mocktail` dev dependency per issue.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Need to confirm which `coverage` version is latest at merge time.
- Removing `mocktail` may break projects that rely on it — verify it's truly unused before dropping.

## Open Questions

- [NEEDS CLARIFICATION: is mocktail used anywhere in the generated test scaffold?]
- [NEEDS CLARIFICATION: what is the actual latest `coverage` version — verify before pinning]
