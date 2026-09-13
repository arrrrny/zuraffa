# Bug Assessment: bug_828 doctor tests invoke `tdd doctor --feature`, but the command takes the feature positionally

- **Slug**: tdd-doctor-feature-positional
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1585
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

4 of the 13 tests in `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
fail with the `tdd doctor` usage text instead of a doctor verdict. The suite's
`doctor()` helper invokes `zfa tdd doctor --feature <name> --project <root>`, but
`tdd doctor` takes the feature positionally (`zfa tdd doctor <feature> [--project <path>]`)
and declares only `--json` / `--project`, so the arg parser rejects `--feature` and the
command exits on a usage error. See https://github.com/arrrrny/zuraffa/issues/1585.

## Symptom

Running `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
yields `+9 -4`: four doctor tests fail because the captured output is usage text and the
exit code is the usage-error exit, not the expected doctor verdict (e.g. the assertion
at `bug_828_cycle_log_evidence_integrity_test.dart:429`, `expect(exitCode, 1, reason: out)`).

## Reproduction

```bash
dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart
```

Expected `13/13` green; actual `+9 -4`.

## Suspected Code Paths

- `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart:42-52` — the `doctor()` helper:
  `['tdd', 'doctor', '--feature', feature, '--project', fx.root.path]`.
- `lib/src/plugins/tdd/commands/doctor_command.dart:76,83` — registers only `--json` and
  `--project`; reads the feature from `argResults.rest` (`rest.first`).

## Root Cause Hypothesis

Flag-vs-positional drift between the test helper and the command contract:
`tdd doctor` declares `zfa tdd doctor <feature> [--project <path>]`, but the helper passes
`--feature`, which the arg parser rejects before the drift logic runs.

## Proposed Remediation

[NEEDS CLARIFICATION — decide between fixing the helper to pass the feature positionally
(issue's suggested fix) and widening the command to accept `--feature`; check sibling-command
precedent (e.g. the #1573 family) before choosing.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- The issue notes the failure is pre-existing (reproduces with and without PR #1566), so the
  fix should not be conflated with any in-flight PR.

## Open Questions

- Which side is the contract: the helper (positional) or the command (accept `--feature`)?
