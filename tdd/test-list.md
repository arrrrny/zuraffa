# TDD test list — SPEC 1693: mock cert digest is format-canonical (no re-cert after phase-2 format)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| G1 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | `dart format`-only drift after certification (bytes change, mtime moves, declaration does not) → the gate reads `certified` — a second sandbox certification is NOT demanded (the #1693 bug; pre-fix this read `stale`) | issue #1693 constraint 1, SC-1 | RED → GREEN |
| G2 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | a real entity edit after certification (new field, different AST) → `stale` with the exact fix command and the canonical reason prefix | issue #1693 constraint 2, SC-2 | RED → GREEN |
| G3 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | an unparseable entity source with a recorded digest → `stale` (what cannot be canonicalized cannot be what was certified) | constraint 2 (soundness) | GREEN (mtime-equivalent pre-fix) |
| G4 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | pre-1693 receipts (no `entity_digest`) keep the mtime freshness semantics — entity touched after the receipt → `stale`, same reason contract | SC-3 | GREEN (guard, passes pre- and post-fix) |
| G4b | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | pre-1693 receipts keep mtime freshness — receipt newer than the entity → `certified` | SC-3 | GREEN (guard, passes pre- and post-fix) |
| G5 | test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart | unit | the digest overrides a lying-fresh mtime — a receipt re-touched after a real edit still refuses (semantic drift is never waived even when mtimes lie) | constraint 2 (strongest form) | RED → GREEN |
| G6 | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | `entity_digest` roundtrips through toJson/fromJson; a receipt without one omits the JSON key (pre-1693 byte stability) | SC-4 | RED (compile) → GREEN |
| G7 | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | `fromRun` records the digest when given, omits when null | SC-4 | RED (compile) → GREEN |
| G8 | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | `MockCertifier.certify` records the format-canonical digest of the entity source via the lib-side helper; the written receipt carries `entity_digest` | SC-4, constraint 4 | RED (compile) → GREEN |
| G8b | test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart | unit | `certify` without an entity file records NO digest (honest absence — the gate falls back to mtime for that receipt) | SC-4 (honest absence) | RED (compile) → GREEN |
| W1 | test/plugins/tdd/commands/spec_1693_run_gate_format_drift_test.dart | unit | the `zfa tdd run` preflight (`RunEngineCommand.checkFeature`, the task's `UserSession` repro) certifies after phase-2 format-only drift | issue repro, SC-1 | GREEN (post-fix wiring pin) |
| W2 | test/plugins/tdd/commands/spec_1693_run_gate_format_drift_test.dart | unit | the preflight still refuses after a real entity edit — `blockedEntity: UserSession`, stale reason, exact fix | issue repro, SC-2 | GREEN (post-fix wiring pin) |

## Red evidence (pre-fix, this session, base a9329746)

- Behavioral red — the gate file compiles against the pre-fix tree
  (hand-written receipt JSON with `entity_digest`; the pre-fix loader
  ignores the unknown key):
  `dart test test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart`
  → `00:00 +4 -2: Some tests failed.`
  - G1 FAILED for exactly the issue's reason: format-only drift read as
    `stale` (mtime, digest ignored).
  - G5 FAILED for exactly the digest-first claim: a lying-fresh mtime
    was accepted.
  - G2/G3/G4/G4b passed — the guards that must survive the fix.
- New-seam red — the receipt/certifier file fails to LOAD pre-fix:
  `Error: The getter 'entityDigest' isn't defined for the type
  'MockCertReceipt'` (+ `format_canonical_digest.dart` unresolved) —
  the honest first red for a NEW seam (spec 1001/1664 convention).

## Green evidence (post-fix, this session)

- Both spec suites: `dart test
  test/plugins/mock/certification/spec_1693_gate_format_drift_test.dart
  test/plugins/mock/certification/spec_1693_receipt_and_certifier_test.dart`
  → `00:00 +11: All tests passed!`
- Wiring pins: `dart test
  test/plugins/tdd/commands/spec_1693_run_gate_format_drift_test.dart`
  → `00:00 +2: All tests passed!`
- Mutation audit (`mutation-test-1693.xml`, scoped to the spec-1693
  freshness lines of `cert_registry.dart` + `format_canonical_digest.dart`,
  command `bash tools/run-1693-mutation-tests.sh`):
  → `Total tests: 16, Undetected Mutations: 0 (0.00%), Success: true`.
  The first pass left 2 survivors — both character-level mutations of the
  stale-reason string literal (`mock-cert` → `mock+cert`); G2/G4 were
  strengthened to pin the reason prefix and the audit re-ran clean.

## Guard pins (pre-existing, unchanged and green against the fix)

| id | suite | description |
| -- | ----- | ----------- |
| 1110 | test/plugins/mock/cert_registry_test.dart | the spec-1110 existence/freshness/reference vocabulary (legacy mtime receipts) |
| 1001 | test/plugins/mock/certification/mock_cert_receipt_test.dart | the receipt document contract |
| 1110-fixture | test/plugins/mock/certification/mock_cert_registry_test.dart | the registry fixture behaviors |
| 1002 | test/engine/mock_certifier_test.dart | the engine-side live certification (shares the gate read side) |
| preflight | test/plugins/tdd/commands/run_engine_command_test.dart | the spec-1001 run preflight wiring |
