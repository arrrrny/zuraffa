# Tasks: 1009-realize-mock-firestore-differential

- **Spec ID**: 1009-realize-mock-firestore-differential
- **Created**: 2026-09-05

## T001: Firestore-shaped fake store (RED → GREEN)
- `FakeFirebaseFirestore` + typed-value codec at
  `lib/src/plugins/tdd/services/tier2_firestore/fake_firebase_firestore.dart`
- REST wire-shape round-trip: `integerValue` / `doubleValue` /
  `stringValue` / `booleanValue` / `mapValue` / `arrayValue` / `nullValue`
- `collection().doc()` get/set/delete; collection listing in document-id
  order; per-collection isolation; idempotent delete; auto-id allocation
- Fail-closed on unencodable types
- Tests: `test/plugins/tdd/services/tier2_firestore/fake_firebase_firestore_test.dart`

## T002: Tier2MockProvider (RED → GREEN)
- Firestore-shaped adapter behind the Tier-1 driver invocation surface at
  `lib/src/plugins/tdd/services/tier2_firestore/tier2_mock_provider.dart`
- CRUD routing incl. entity-qualified spellings; deterministic `seed`;
  `Tier2MockMethodError` naming any method outside the surface
- Tests: `test/plugins/tdd/services/tier2_firestore/tier2_mock_provider_test.dart`

## T003: differential receipt (RED → GREEN)
- `realize.<Entity>.firestore.receipt.json` writer at
  `lib/src/plugins/tdd/services/realize_mock_receipt.dart`
- Per-method `{method, tier1_result, tier2_result, diff: none|mismatch}`
  records inside a `proof.v1` envelope (parseable by `zfa proof check`,
  zero findings)
- Tests: covered through T004's command acceptance tests + the SC-3
  proof-check integration test

## T004: the realize-mock command (RED → GREEN)
- `zfa tdd realize-mock <Entity> --against=firestore` at
  `lib/src/plugins/tdd/commands/realize_mock_command.dart`, registered in
  `TddCommand` after `RealizeCommand` (additive; realize untouched)
- Tier-1 contract-test run gate (fail-closed `tier1-red`), fixture-case
  loading (fail-closed `blocked`), per-case Tier-1 oracle (recorded
  `mockOutput`, else the tier-1 driver protocol), fresh seeded
  Tier2MockProvider per case, JSON-equality diff, receipt write,
  era-tagged cycle-log entry (era MOCKED, kind realize-mock)
- Per-entity gate: exit 0 iff every method's `diff == none`; mismatched
  methods named with both tiers' values; `--json` verdict envelope
- Tests: `test/plugins/tdd/commands/realize_mock_command_test.dart`
  (SC-1, SC-2, SC-2b, SC-3, A–H)

## T005: end-to-end verification (REAL)
- Production proof on a scratch project: real CLI, real `dart test`
  subprocess for the Tier-1 contract run, real receipt, `zfa proof check`
  parse (counted, zero findings), deliberate wrong-type divergence →
  exit 1 with the method named
- `/speckit.tdd.verify` → `tdd/verification.md` with the session's real
  evidence: red reproduction, 44/44 new tests, 75/75 chunked fast-tier
  chunks (71 PASS / 4 by-design SKIP / 0 FAIL), 4/4 deliberate mutants
  killed + restoration re-verified, `dart analyze` 0 errors, `dart format`
  zero diffs
- Commit and open PR (Closes #1009)
