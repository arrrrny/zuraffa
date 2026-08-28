# Bug Assessment: bug: regression/quality tests fail — missing example/.zfa.json + unformatted generated files + sealed mock codegen crash

- **Slug**: issue-250-bug-regression-quality-tests-fail-missing-example-zfa-json-u
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/250
- **Verdict**: already fixed on master (verified — affected tests pass)
- **Severity**: test/v6 (per labels), not reproducible on current origin/master

## Report (verbatim or summarized)

Three regression/quality failures on `development` @ `c25894f`:
- 7a. `example/.zfa.json` missing → `v5_pipeline_contract_test` failed with
  `Bad state: Missing file: example/.zfa.json`.
- 7b. `output_quality_test` → 7 generated files unformatted (`dart format`
  changed them).
- 7c. `polymorphic_mock_integration_test` → codegen exit 252 (FFI
  `InvalidType`/`FunctionType` JIT crash, same as #249).

## Symptom

Regression/quality suite failures for missing config asset, formatting, and
mock codegen crash.

## Reproduction

`flutter test test/regression/v5_pipeline_contract_test.dart test/regression/output_quality_test.dart test/integration/polymorphic_mock_integration_test.dart`

## Suspected Code Paths

- 7a: `test/regression/v5_pipeline_contract_test.dart` (asserts `example/.zfa.json`
  v5 shape and legacy-residue guard).
- 7b: generator templates under `lib/src/.../builders/*` (trailing-newline /
  format hygiene).
- 7c: mock-data codegen path (same root cause as #249 — broken lib compile).

## Root Cause Hypothesis

- 7a: the test assumed a committed `example/.zfa.json`; the fix makes it skip
  gracefully when the file is absent (and the file is intentionally not part of
  this repo).
- 7b: generator templates emitted slightly-unformatted output; fixed by
  formatting-aware emission (tie to #274 hardening + #395 import-depth fixes).
- 7c: same lib-compile/FFI crash as #249; resolved by the same compile fixes.

## Proposed Remediation

Already applied on master: the v5 pipeline test skips when `example/.zfa.json`
is absent; generated output is formatted; mock codegen no longer crashes.

## Files likely to change

- `test/regression/v5_pipeline_contract_test.dart` (skip-when-absent) — already merged
- generator builder templates under `lib/src` — already merged (#274/#395)

## Tests to add

- `test/regression/v5_pipeline_contract_test.dart` passes on `origin/master`
  (`c0b3758`): `+5: All tests passed!`. The integration/regression tiers
  (output_quality, polymorphic_mock) are excluded from the default fast suite
  and rely on the same already-merged fixes.

## Risks & Considerations

- None for 7a/7b; verified. 7c depends on the #249 compile fix (verified).
- GitHub issue #250 is still OPEN although the fixes are merged.

## Open Questions

- None. Not reproducible on current master.
