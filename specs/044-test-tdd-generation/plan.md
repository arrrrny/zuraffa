# Implementation Plan: 044 — Behavior-aware test generation and trustworthy mutation evidence

**Branch**: `044-test-tdd-generation` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

## Summary

Extend the `zfa tdd` plugin (landed in `specs/041-tdd-setup-plugin`) with
two production surfaces: a behavior-aware `zfa tdd gen <behavior-id>` that
materializes a planned behavior into exactly one test + one paired
compilable subject with an honest-red assertion failure, and a trustworthy
`zfa tdd verify --feature <feature>` that derives mutation scope from
registered behavior artifacts, runs a green-suite preflight, classifies
killed/survived/timed-out mutants separately, marks
unavailable/empty/incomplete/unparseable results as `NOT_ASSESSED`,
restores every temporarily mutated subject before returning, and writes
`specs/<feature>/tdd/verification.md` from the real run.

## Technical Context

**Language/Version**: Dart 3.13+ (the project's `pubspec.yaml` pins
`sdk: ^3.11.0`; CI uses the latest stable 3.13.x).

**Primary Dependencies**: `args`, `path`, `yaml`, `code_builder`,
`dart_style`, `analyzer`. The mutation audit shells out to
`dart run mutation_test` (already wired as a `dev_dependency` by the
prior `041-tdd-setup-plugin` PR).

**Storage**: Two new on-disk artifacts per feature:

- `specs/<feature>/tdd/artifacts.json` — append-only registry of
  behavior id -> {test_path, subject_path, runnable_test_name,
  ownership, created_at}. Written by `gen`; read by `verify` and (later)
  by `run`.
- `specs/<feature>/tdd/verification.md` — produced FRESH by every
  `zfa tdd verify` run. Append-only across runs is NOT acceptable for
  this spec (see FR-019); the file is overwritten on each invocation to
  reflect the actual current run, never a stale copy.

**Testing**: `dart test` for the zuraffa codebase itself. New tests
live under `test/plugins/tdd/` (commands/services/models) and
`test/cli/writers/tdd/` (writers). Mutation coverage of the new code is
the very thing this feature ships — `mutation-test.xml` is extended to
scope the new `gen`+`verify` files.

**Project Type**: CLI tool + library. This feature extends the existing
`lib/src/plugins/tdd/` plugin and adds two new services
(`artifact_registry`, `subject_writer`, `behavior_test_writer`,
`mutation_scope`, `mutation_auditor`).

## Constitution Check

- **Library-first**: PASS. All new logic lives under `lib/src/plugins/tdd/`.
- **CLI interface**: PASS. The user-facing surface is `zfa tdd gen` and
  `zfa tdd verify`.
- **Test-first**: PASS. This spec is implemented through
  `/speckit.tdd.run` — every behavior in `tdd/test-list.md` is
  written and observed red before its implementation.
- **Integration testing**: PASS. The honesty of `gen` is proved by an
  integration test that invokes `dart test` on the generated test and
  asserts the failure classification.
- **Observability**: PASS. `gen` prints a structured result line;
  `verify` writes a structured `verification.md`.
- **Simplicity/YAGNI**: PASS. `make`/`refactor`/`run` are explicitly
  out of scope; only `gen` and `verify` ship.

## Project Structure

```text
specs/044-test-tdd-generation/
├── spec.md
├── plan.md
├── tasks.md
└── tdd/
    ├── test-list.md
    └── verification.md   ← produced FRESH by /speckit.tdd.verify

lib/src/plugins/tdd/
├── tdd_plugin.dart              (unchanged)
├── commands/
│   ├── gen_command.dart         (rewritten — was a misfire-stop stub)
│   └── verify_command.dart      (extended — adds scope derivation, preflight, NOT_ASSESSED, restoration)
├── services/
│   ├── artifact_registry.dart   (NEW — FR-007)
│   ├── behavior_test_writer.dart (NEW — FR-001, 010)
│   ├── subject_writer.dart       (NEW — FR-001, 004, 011)
│   ├── mutation_scope.dart       (NEW — FR-012)
│   ├── mutation_auditor.dart     (NEW — FR-013..021; wraps MutationVerifier)
│   ├── source_restorer.dart      (NEW — FR-021)
│   ├── spec_parser.dart         (extended — already exists)
│   └── mutation_verifier.dart   (extended — adds NOT_ASSESSED classification)
└── models/
    ├── behavior.dart             (unchanged)
    ├── artifact_record.dart       (NEW — FR-005, 007)
    ├── ownership.dart             (NEW — FR-005, 006, 008)
    └── mutation_outcome.dart      (NEW — FR-014..019)

test/plugins/tdd/
├── commands/
│   ├── gen_command_test.dart      (NEW — covers FR-001..011)
│   └── verify_command_test.dart   (NEW — covers FR-012..023)
├── services/
│   ├── artifact_registry_test.dart  (NEW — FR-006..008)
│   ├── behavior_test_writer_test.dart (NEW)
│   ├── subject_writer_test.dart      (NEW)
│   ├── mutation_scope_test.dart      (NEW — FR-012)
│   ├── mutation_auditor_test.dart    (NEW — FR-013..021)
│   └── source_restorer_test.dart    (NEW — FR-021)
└── models/
    ├── artifact_record_test.dart     (NEW)
    ├── ownership_test.dart           (NEW)
    └── mutation_outcome_test.dart    (NEW)
```

## Complexity Tracking

No violations. `gen` is a single command, `verify` extends an existing
command, the artifact registry is one append-only JSON file per feature,
and the mutation auditor wraps the existing `MutationVerifier` rather
than re-implementing subprocess execution.
