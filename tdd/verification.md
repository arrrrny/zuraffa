# Verification — 1693-mock-cert-format-canonical-digest

- **Date**: 2026-09-18 (this session, from the actual runs below — no
  content copied from an earlier spec's file)
- **Branch**: `fix/1693-mock-cert-format-canonical-digest` (working tree,
  pre-push; base `a9329746`)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart
  3.13+" floor; the repo pins `sdk: ^3.11.0`)
- **Scope audited**: `spec.md` (SC-1..SC-5), `plan.md`,
  `tdd/test-list.md`, the changed code
  (`lib/src/plugins/mock/certification/cert_registry.dart`,
  `mock_cert_receipt.dart`, `mock_certifier.dart`, and the new
  `format_canonical_digest.dart`), the new test files, and the
  `mutation-test-1693.xml` audit config.
- **Verify path**: `/speckit.tdd.verify` Step 0 detected `ZFA_MISSING`
  (this repo is the zuraffa framework itself — no `.zfa.json` consumer
  wiring), so the command's documented FALLBACK PATH ran: the LLM-guided
  audit with real in-session red/green/mutation evidence. `zfa tdd
  verify`'s mutation phase was covered equivalently by the repo's own
  `mutation_test` tool driven through a spec-scoped config
  (`mutation-test-1693.xml`) — the same tool `zfa tdd verify` dispatches.

## Verdict: PASS

| id | criterion | verdict | evidence |
|----|-----------|---------|----------|
| SC-1 | format-only drift after certification → `certified`, no second certification | PASS | G1 (red→green) + W1; the pre-fix tree refused both (behavioral red captured) |
| SC-2 | a real entity edit after certification still refuses as `stale` | PASS | G2 + W2 (blocked entity, stale reason, exact fix command); G5 additionally proves the digest overrides a lying-fresh mtime |
| SC-3 | pre-1693 receipts keep the mtime freshness semantics | PASS | G4/G4b (both directions) + the untouched spec-1110 suite `cert_registry_test.dart` 9/9 |
| SC-4 | the certifier records the format-canonical digest for both entry points; JSON omits the field when absent | PASS | G6/G7/G8/G8b — both CLI entry points (`mock create --certify`, `mock certify`) flow through the single changed `certify()` choke point; legacy receipts stay byte-stable |
| SC-5 | existing suites stay green; analyze clean; format clean | PASS | guard suites below; `dart analyze` on all 7 touched files: `No issues found!`; `dart format --set-exit-if-changed .` exit 0 |

## 1. Red → green (this session, base a9329746)

- **Red (behavioral, the issue's bug)** — the gate test file was written
  to compile against the PRE-FIX tree (receipt JSON hand-written with
  `entity_digest`; the pre-fix loader ignores the unknown key):
  `dart test test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart`
  → `00:00 +4 -2: Some tests failed.`
  G1 failed with format-only drift read as `stale` (the #1693
  repro at the gate decision point); G5 failed with a lying-fresh mtime
  accepted. The four guards (G2/G3/G4/G4b) passed, so the red set is
  exactly the two claims the fix changes.
- **Red (new seam)** — `dart test
  test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart`
  → load error: `The getter 'entityDigest' isn't defined for the type
  'MockCertReceipt'` (+ unresolved `format_canonical_digest.dart`) — the
  honest first red for a new seam.
- **Green** — after the fix: the two spec files → `00:00 +11: All tests
  passed!`; the run-preflight pins → `00:00 +2: All tests passed!`.

## 2. Semantic-drift case re-run explicitly (spec §4 step 5)

G2 (unit) and W2 (`tdd run` preflight wiring): a real entity edit after
certification refuses with `CertRegistryStatus.stale`, reason prefix
`mock-cert.UserSession.json is stale:`, fix
`zfa mock create UserSession --certify`. G5 adds the strongest form: a
receipt re-touched AFTER a real edit (mtime says fresh, digest says
stale) still refuses. All three ran green in this session.

## 3. Mutation audit (the `tdd verify` mutation phase, equivalent path)

`dart run mutation_test mutation-test-1693.xml -f md -o
mutation-test-1693-report` — scoped by line whitelist to the spec-1693
freshness block of `cert_registry.dart` (lines 193–242) and the digest
seam `format_canonical_digest.dart` (lines 38–58); test command
`bash tools/run-1693-mutation-tests.sh` (the three gate suites, `-j 1`,
kernel-cache hygiene per the repo convention).

```
Total tests: 16
Undetected Mutations: 0 (0.00%)
Timeouts: 0
Not covered by tests: 0
Success: true
```

First pass: `FAILED: 2/16 (12.50%) mutations were not detected!` — both
survivors were character-level mutations of the stale-reason string
literal (`mock-cert` → `mock+cert`), which no test pinned. G2/G4 were
strengthened to assert the reason prefix
(`startsWith('mock-cert.Login.json is stale:')`) — a legitimate contract
pin (the refusal receipt and `zfa tdd status` render this string
verbatim) — and the audit re-ran clean.

## 4. Gates

- `dart analyze` on the 3 changed lib files, the new helper, and the 3
  new test files → `No issues found!`
- `dart format .` → re-check `--set-exit-if-changed` exit 0 (zero
  remaining diffs across 2947 files).
- Mapped-scope test run (fresh kernel-cache cleanup per §5):
  `dart test test/plugins/mock/certification/
  test/plugins/mock/cert_registry_test.dart
  test/plugins/tdd/commands/spec_1693_run_gate_format_drift_test.dart
  test/engine/mock_certifier_test.dart` → `00:14 +55: All tests passed!`
- Adjacent sweep: `run_engine_command_test.dart` + `test/engine/` +
  `test/plugins/slice/` → `00:19 +217: All tests passed!`

## 5. Pre-existing failures flagged (not introduced, not fixed here)

`test/integration/mock_certification_e2e_test.dart` (tagged `slow`,
excluded from the default lane) — 2 of 3 tests fail in THIS environment
with the sandbox unable to resolve `package:zuraffa/zuraffa.dart` /
`package:zuraffa/mock.dart` inside the throwaway sandbox project.
Verified pre-existing by `git stash -u` → re-run on base `a9329746` →
the same `[E]` at the same assertion. The failure is environmental
(sandbox framework-root resolution against this machine's pub layout),
not related to the digest change; it was NOT "fixed" to keep the PR
minimal and honest.

## 6. Constraints audit

1. **Format-only drift is not staleness** — G1/W1 (and the digest-first
   branch replaced the mtime read for receipts that carry
   `entity_digest`).
2. **Real entity source changes still detected** — G2/G3/G5/W2; the
   mutation audit killed all 16 mutants in the changed logic, including
   the "ignore digest mismatch" and "digest raw bytes" classes.
3. **No second certification per entity** — the gate returns
   `certified` on format-only drift; nothing in the fix path re-runs the
   sandbox.
4. **Works under Flutter sandbox certification** — the digest is
   computed in-process by the driving zfa (`dart_style`, a direct
   dependency); no toolchain subprocess was added to cert or gate, so
   the Flutter-host path (spec 1600's `flutterTest` sandbox) is
   untouched and the recorded digest is toolchain-independent.
