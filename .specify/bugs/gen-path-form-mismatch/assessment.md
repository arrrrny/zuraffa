# Bug Assessment: tdd gen A5 refuses on registry path-form mismatch

- **Slug**: gen-path-form-mismatch
- **Created**: 2026-09-09T11:17:54Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1397
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

The issue reports a verification misfire in the TDD loop: `zfa tdd gen A5` refuses to regenerate an absence test because the registry contains the same test path in different forms (relative for A5 and machine-specific absolute for A4). The ownership gate compares the strings and reports an ownership conflict, while `zfa tdd doctor` reports no drift because its checks do not normalize path forms. The issue is tracked under missing integration between doctor and the gen ownership gate.

Issue: https://github.com/arrrrny/zuraffa/issues/1397

## Symptom

Regenerating behavior A5 is refused with an ownership conflict, even though the prescribed doctor command reports that the stores agree and provides no remedy.

## Reproduction

1. Use the `004-login-ui` feature and its TDD registry containing mixed relative and absolute test paths.
2. Run `zfa tdd gen A5 --feature 004-login-ui --project example --widget-shell materialapp`.
3. Observe the ownership-conflict refusal for `test/tdd/004-login-ui/a5_test.dart` versus the absolute registry path.
4. Run `zfa tdd doctor 004-login-ui --project example --json` and observe a no-drift verdict with no prescription.

## Suspected Code Paths

- TDD gen ownership/registry conflict handling for behavior A5.
- TDD registry artifact persistence, including `example/specs/004-login-ui/tdd/artifacts.json`.
- TDD doctor drift detection and prescription generation.

## Root Cause Hypothesis

Registry paths are persisted and compared in inconsistent relative/absolute forms. Gen performs a literal path comparison, while doctor does not normalize paths before checking drift, so the recovery command cannot detect or repair the conflict.

## Proposed Remediation

Normalize registry paths when writing and comparing them, resolving relative paths against the project root. Add equivalent path-form normalization to doctor drift checks, and remove machine-specific absolute paths from committed registry artifacts so records remain portable.

## Risks & Considerations

- Path normalization must preserve intended ownership boundaries and avoid treating distinct paths as equivalent after symlink or case-sensitive filesystem differences.
- Changing persisted registry paths may affect existing artifacts and should include compatibility/migration coverage.
- Regression tests should cover mixed relative and absolute paths through both gen ownership checks and doctor verdicts.

## Open Questions

- What is the canonical project-root resolution rule for registry paths across CLI working directories and nested projects?
- Should existing committed absolute paths be migrated automatically, rejected, or normalized only on write/compare?
