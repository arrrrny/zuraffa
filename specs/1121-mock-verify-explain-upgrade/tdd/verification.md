# TDD verification — SPEC 1121 (mock verify + explain)

## Test-first evidence (red → green)

The behavior tests were written BEFORE the implementation and run RED on
the pre-implementation tree, then GREEN after.

- **RED evidence** (implementation absent, tests present):
  `dart test test/plugins/mock/mock_verify_test.dart` →
  `00:01 +2 -8: Some tests failed.` — 8 failing (A1, A2, A3, A4, A4b, A5,
  A5b, A6: `mock verify` / `mock explain` not recognized grammar), 2
  passing (A4c/A5c usage refusals — the runner-level UsageException path
  already produced exit 2 + fix lines; the contract held pre-wiring).
- **GREEN evidence** (same tests, implementation landed):
  `00:01 +10: All tests passed!` — 10/10.

## Commands run (ACTUAL results)

| Command | Result |
|---|---|
| `dart analyze <5 changed .dart files>` | `No issues found!` |
| `dart test test/plugins/mock/mock_verify_test.dart` | **10 passed, 0 failed** |
| `dart test test/commands/mock_command_help_test.dart test/plugins/mock/mock_command_exit_test.dart` | **5 passed, 0 failed** |
| `dart test test/plugins/mock/mock_certify_gate_test.dart` (shared-gate regression) | **4 passed, 0 failed** |
| `dart test test/commands/manifest_verify_gate_test.dart` (schema ≡ grammar after capability registration) | **9 passed, 0 failed** |
| `dart test test/commands/exit_protocol_golden_test.dart` (exit-code golden table) | **14 passed, 0 failed** |
| `dart format` over the 5 changed files | 0 changed (format-clean) |

Scope note (cloud-disk constraint): only suites touching the modified
surfaces were run — never the full suite. `dart format --output=none
--set-exit-if-changed .` reports 3 pre-existing unformatted evidence files
under `specs/1142-adaptive-layout-contract/tdd/evidence/` — pre-existing on
master, unrelated to this spec, deliberately left untouched to keep the PR
scoped.

## Mutation-strength spot checks

The suite kills the obvious mutants of the new surface:

- **Exit-code mutants** (`return 0` → `return 1` on conform): A1 asserts
  exit 0 + no fix lines; A4 asserts envelope `verdict: pass` /
  `exit_class: 0`. The inverse (`return 1` → `return 0` on drift) is killed
  by A2/A4b (exit 1 + findings non-empty).
- **Gate-bypass mutant** (skip the scoped analyze): A2's structural drift
  still exits 1; the U6-style analyze-only failure is covered by the
  sibling gate suite (`mock_certify_gate_test.dart U6` re-run green) and by
  the shared `MockCertifier` (no new gate code).
- **Read-only mutant** (verify writes a receipt/registry entry): A1 asserts
  a before/after tree snapshot equality.
- **Explain stub mutant** (report `covered` for every method): A5b drifts
  `update` and asserts the `missing` status appears; A6 asserts the
  structured `methods`/`selector` payload (declared `forMethod` selector,
  discriminator `String`, the on-disk `params.status` binding).

## Acceptance-criteria coverage

| AC | Evidence |
|---|---|
| AC-1 pass exit 0 + interface/registry named | A1 |
| AC-2 drift exit 1 + `--> fix:` naming member + interface | A2 |
| AC-3 missing artifacts → exit 1 + `missing_file` + create fix | A3 |
| AC-4 `--json` canonical `zuraffa.verdict.v1` envelope | A4, A4b |
| AC-5 read-only (no writes) | A1 tree snapshot |
| AC-6 explain coverage/status/skipped/selector | A5, A5b, A6 |
| AC-7 explain `--json` report under `details.explain` | A6 |
| AC-8 `mock_verify_test.dart` covers pass/drift/--json (+refusals, explain) | 10/10 green |
| AC-9 same conformance shape as MockCertify | shared `MockCertificationService.certify` + `MockCertifier.gate` call path; gate regression suite green |

## Not proved here

- The real (non-overridden) `dart analyze` subprocess path inside the gate —
  exercised by the slow-tier integration suites (excluded from the fast
  tier by `dart_test.yaml`), not re-run here; the fast tier pins the
  contract through the `MockCertifier.analyzeRunnerOverride` seam, the same
  split `mock_certify_gate_test.dart` uses.
- Service-mode provider conformance — out of scope per spec.md.
