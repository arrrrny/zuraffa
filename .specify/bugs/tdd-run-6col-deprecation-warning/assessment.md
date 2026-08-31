# Bug Assessment: zfa tdd run: deprecation warning on 6-column test-list is verbose and gives incorrect migration advice

- **Slug**: tdd-run-6col-deprecation-warning
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/649
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

When `zfa tdd run` encounters a 6-column test-list, it prints a deprecation warning to stderr before proceeding. The warning has two problems:

1. It is verbose and alarming for users who have a valid 6-column list they did not create. Per spec 050, the 6-column dialect is accepted for one release — the loop should proceed transparently without a warning when the user did nothing wrong.
2. The migration advice is incorrect. The warning says "re-run `zfa tdd plan <feature>` to migrate" but `zfa tdd plan` writes `spec.md`, not `test-list.md`. The correct migration is a manual format conversion of the test-list itself.

Issue URL: https://github.com/arrrrny/zuraffa/issues/649

## Symptom

The loop proceeds correctly for valid 6-column lists, but emits a noisy, misleading deprecation warning that (a) alarms users who did nothing wrong and (b) gives incorrect migration advice pointing at `zfa tdd plan` — which writes `spec.md`, not `test-list.md`.

## Reproduction

1. Have a feature using the 6-column test-list format (e.g. `specs/044-049` in the zuraffa repo itself).
2. Run `zfa tdd run <feature>`.
3. Observe the deprecation warning before the run proceeds.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/test_list_reader.dart:135-143` — the warning is printed unconditionally (once per file, gated by `deprecatedDialectWarned`) whenever 6-column rows are encountered. Verified: the flag prevents duplicate warnings within a single file, but does not suppress the warning for legitimately-6-column files.
- `lib/src/plugins/tdd/services/test_list_reader.dart:16-37` — the doc comment confirms the 6-column dialect is an explicit "one release" compatibility shim covering two private dialects: gen's old dialect and the spec-kit tdd extension's hand-written shape used by `specs/044–049` (spec 050, FR-007). These are first-party, spec-sanctioned shapes — not user error.
- `lib/src/plugins/tdd/commands/plan_command.dart` — `zfa tdd plan` writes `spec.md` (and derives `test-list.md` from it), so the warning's "re-run plan to migrate" advice is wrong: plan does not rewrite an existing test-list in the 4-column format.

## Root Cause Hypothesis

The reader treats *any* 6-column row as a deprecated dialect and warns, but the doc comment itself records that the 6-column shape is a spec-sanctioned format (spec 050 FR-007) used by the repo's own `specs/044–049`. The warning has no way to distinguish "user wrote this by hand in the old dialect" from "this is a first-party spec-kit tdd extension artifact". Separately, the migration text references `zfa tdd plan` as the migration path, but plan writes `spec.md` — it does not convert an existing `test-list.md`. High confidence: code path and warning text verified directly in source.

## Proposed Remediation

**Preferred**: Split the warning into two behaviors:
1. For first-party / spec-sanctioned 6-column files (the spec-kit tdd extension shape used by `specs/044–049`), suppress the warning entirely — these are valid per spec 050 and the user did nothing wrong.
2. For genuine legacy 6-column files (gen's old dialect), keep a one-time warning but correct the migration advice to describe a manual format conversion of `test-list.md` to the 4-column shape — not "re-run `zfa tdd plan`".

Alternatively, gate the warning behind a version or marker (e.g. only warn when the file predates the 4-column canonical format), and fix the migration text in all cases.

**Files likely to change**:
- `lib/src/plugins/tdd/services/test_list_reader.dart` (lines 135-143)
- `test/plugins/tdd/test_list_reader_test.dart`

**Tests to add or update**:
- A spec-kit-style 6-column list runs with zero stderr output (transparent path).
- A legacy 6-column list emits a warning whose text does NOT mention `zfa tdd plan` as the migration for test-list format.
- The warning is emitted at most once per file (regression for the existing `deprecatedDialectWarned` gate).

## Risks & Considerations

- Suppressing the warning for spec-kit-style files may hide genuine migration needs after the one-release grace period ends; track the cutoff version explicitly.
- Changing warning text must not break any tests asserting on the old message string.
- Distinguishing the two 6-column dialects must not introduce false positives/negatives in row parsing — the parser already handles both shapes correctly.

## Open Questions

- [NEEDS CLARIFICATION: When does the 6-column grace period end? Is there a version gate for the warning?]
- [NEEDS CLARIFICATION: Should the spec-kit tdd extension shape be treated as canonical going forward, or migrated to 4-column?]