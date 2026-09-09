# Plan — Spec 1369 example TDD baseline dev_dependencies

**Branch**: `1369-tdd-baseline-dev-deps` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

Add `test: ^1.0.0` + `coverage: ^1.15.1` to `example/pubspec.yaml`
dev_dependencies with the issue-reference comment (mutation_test already
present; flutter_test kept). Pin the baseline with a YAML-parse test
(`test/package_sdk/bug_1369_example_tdd_baseline_test.dart`) asserting
presence (B1) and the writer-canonical constraints (B2) — the same set
`PubspecDevDependenciesPatcher.flutterDevDependencies` writes, so `zfa
tdd init` on the repaired tree is a no-op.

## Test strategy

Hermetic YAML assertions (no network, no Flutter SDK needed locally);
Flutter resolution is CI's flutter-smoke-gate. Scoped pin: package_sdk
suite + analyze.
