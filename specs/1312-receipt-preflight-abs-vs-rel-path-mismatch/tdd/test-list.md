# TDD Test List — Spec 1312 receipt preflight abs-vs-rel path mismatch

One behavior per line, traced to the acceptance criteria (SC-n) in
spec.md. Every behavior is written as a failing test FIRST (RED), then
made to pass (GREEN). Red for this feature is an assertion red: the
preflight fires `missing_receipt` on subjects a receipt already covers,
because the audited absolute path never intersects the receipt's
project-relative path.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | An audited ABSOLUTE path inside projectRoot whose project-relative form is covered by a shipped receipt → preflight passes (ok, gateActive, zero findings) | SC-2 | test/plugins/tdd/services/receipt_preflight_test.dart |
| B2 | An audited path OUTSIDE projectRoot is skipped — no `missing_receipt` finding, report stays ok | SC-3 | test/plugins/tdd/services/receipt_preflight_test.dart |
| B3 | A mixed audited list (absolute-in-root covered + relative covered + absolute-out-of-root) → zero findings; relativization is idempotent on already-relative paths | SC-4, SC-5 | test/plugins/tdd/services/receipt_preflight_test.dart |
| B4 | CLI: `artifacts.json` with ABSOLUTE `subject_path` (as `zfa tdd gen` writes it) + covering receipt → `zfa tdd verify` prints `receipt preflight: ok` and proceeds past the gate (existing registries fixed at compare time, no re-gen) | SC-1 | test/plugins/tdd/services/receipt_preflight_test.dart |
| B5 | Regression: relative `subject_path` + covered receipt still passes (existing CLI test 'green receipt gate lets the audit proceed', unmodified) | SC-5 | test/plugins/tdd/services/receipt_preflight_test.dart |
| B6 | Gate still fails closed: uncovered subject (relative or absolute-in-root) still yields `missing_receipt` naming the project-relative path; audit never starts (existing tests, unmodified) | SC-6 | test/plugins/tdd/services/receipt_preflight_test.dart |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*
dart test test/plugins/tdd/services/receipt_preflight_test.dart
```

Expected RED: B1–B4 fail (`missing_receipt` fired on covered subjects /
gate failure instead of `receipt preflight: ok`); B5–B6 (existing
tests) stay green — they pin today's already-correct relative-path
behavior and the fail-closed contract.

## Green protocol

Same single-file command after the fix lands in
`lib/src/plugins/tdd/services/receipt_preflight.dart`. Then targeted
`dart analyze` on changed files, `dart format .`, kernel-cache cleanup.
