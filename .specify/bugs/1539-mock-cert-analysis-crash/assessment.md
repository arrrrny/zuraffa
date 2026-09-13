# Bug Assessment: mock create --certify — analysis server crash after the persisted (conforms) receipt flips exit to 1

- **Slug**: 1539-mock-cert-analysis-crash
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1539
- **Verdict**: valid (dogfood evidence + code trace)
- **Severity**: high (false generation-error stops the TDD cycle on a step that passed)

## Report

`zfa tdd make U2` on a fresh todo host: `mock create --name Task --certify`
wrote every artifact, persisted the receipt
`mock-cert:task@008d26db (conforms)` to `.zfa/receipts/mock-task.json`,
and THEN exited 1 — the dogfood tail shows the crash lines
(`Bad state: The analysis server crashed unexpectedly` /
`The analysis server shut down unexpectedly.`) riding the output as fix
lines, followed by the `✅ Success!` block and the
`📜 mock-certification: … (conforms) → .zfa/receipts/mock-task.json`
line. `make` saw exit 1 and stopped the cycle with
`outcome=generation-error` on a step whose actual work succeeded.

## Symptom

A transient analysis-server crash inside the scoped `dart analyze`
subprocess poisons an already-successful certification: the gate fails,
the CLI exits 1, and the TDD driver records a false generation-error —
even though the persisted receipt says `conforms`.

## Reproduction

1. Host under memory pressure (concurrent builds) — the child `dart
   analyze`'s analysis server crashes mid-run.
2. `zfa mock create Task --certify` on a conforming mock.
3. Observe: exit 1, crash tail in the output, `Success!` + `(conforms)
   → .zfa/receipts/mock-<entity>.json` also in the output.
4. `zfa tdd make` maps the exit to `outcome=generation-error` and stops.

## Suspected Code Paths

- `lib/src/plugins/mock/services/mock_certification.dart` —
  `MockCertifier.gate()` (scoped analyze; any non-zero exit without
  `error -` lines becomes a fix line carrying the RAW output tail, so
  the crash text rides the fix line) and `MockCertifier._defaultRunner`
  (the `dart analyze` subprocess).
- `lib/src/commands/mock_command.dart` — `_runMockGeneration` (order:
  generate → `MockCertificationService.certify` → `writeReceipt` →
  gate; `!report.passed` → `exitCode = 1`, and the human summary still
  prints `Success!` + `(conforms) → receipt` — exactly the dogfood
  tail).
- `lib/src/commands/mock_verify_command.dart` — `mock verify` consumes
  the SAME gate with the same `passed → exit` mapping (its stated AC:
  same machinery as MockCertify), so the same transient crash produces
  the same false failure there.

## Root Cause Hypothesis

`gate()` classifies ANY non-zero analyze exit as drift. An
analysis-server crash is an INFRA failure of the verification TOOL, not
a property of the mock: the structural half of the gate (AST
missing/invented member checks — the same evidence the receipt
records) passed, the receipt was persisted BEFORE the gate ran, and the
crash text contains no `error -` diagnostics. The exit path then
contradicts the engine's own persisted evidence.

## Proposed Remediation

Issue suggestions 1+2 (surgical); suggestion 3 is a follow-up:

1. **Crash classification + one retry** (`MockCertifier.gate`): when
   the scoped analyze exits non-zero with NO parseable `error -` lines
   and the output carries the analysis-server crash signature, retry
   the analyze pass ONCE.
   - Retry clean → the gate proceeds on the retry result.
   - Retry crashes again AND there is no structural drift (missing and
     invented members empty — the same condition the persisted receipt
     records as `conforms`) → INFRA, not drift: no `--> fix:` line, the
     report exposes `analyzeUnverified` (new field) with a loud
     disclosure, and `passed` stays true — the certification stands on
     its structural proof + persisted receipt.
   - Structural drift present → the gate still fails (the crash does
     not mask real drift); real `error -` diagnostics still fail the
     gate (the safe-failure contract is unchanged).
2. **Callers disclose loudly**: `mock create --certify` and `mock
   verify` print the unverified-compiler-verdict warning when
   `analyzeUnverified` is set, and exit 0 — the warning names the
   re-proof path (`zfa mock verify`) so the disclosure is actionable,
   never a silent pass.

Follow-up (out of scope here, tracked in the issue): short-circuit
"already certified" on re-run when the receipt is present instead of
re-analyzing from scratch.

## Risks & Considerations

- Must not weaken the gate: real analyzer errors and structural drift
  keep failing; only the double-crash + structurally-clean shape
  degrades, and it degrades LOUDLY (the disclosure text is asserted by
  the tests).
- `mock verify` shares the gate; the fix must keep its
  findings/envelope mapping coherent (the crash tail must not appear as
  an `analyze_error` finding anymore).

## Open Questions

- None blocking; the crash signature strings come verbatim from the
  dogfood evidence.
