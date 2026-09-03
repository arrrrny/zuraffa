# Tasks: 892-tdd-realize-mock-swap (spec 913 — zfa tdd realize)

Derived from the SPEC 913 protocol's TDD cycle table. Every behavioral task has
a failing test before its implementation (TDD extension contract).

- [ ] T001. RED: write the failing acceptance/unit tests for the command
      skeleton + DI rebind + state transition MOCKED → REAL (A1, A2, A6, U1-U7).
      Evidence: red runs recorded in `tdd/cycle-log.md`.
- [ ] T001. GREEN: implement `realize_command.dart` skeleton, `realize_state.dart`,
      `di_rebind.dart`; register the subcommand. Evidence: green runs.
- [ ] T002. Contract gate (A3, U8-U10): `contract_gate.dart` — MOCK-era suite
      against the real binding stays green; verdict attributes red to the real
      impl or the mock; red blocks the swap and rolls the rebind back.
- [ ] T003. Differential gate (A4, U11-U13): `differential_gate.dart` — real vs
      mock on the same committed fixtures (extends #832), drift report with
      per-field comparison, threshold from `.zfa.json`, reuses #805 machinery.
- [ ] T004. Nuance receipts (A5, U14-U16): `nuance_receipts.dart` — hand-deltas
      recorded (file, reason, diff-hash) in the feature's provenance ledger
      (#807 proof-carrying); ungated hand-deltas block.
- [ ] T005. Era-tagged cycle-log (U17-U18): `era_tagged_log.dart` — entries
      carry era tags; state transitions visible in history; era preserved.
- [ ] T006. REFACTOR + VERIFY: `dart format .`, `dart analyze`,
      `tools/run_tests_chunked.sh` — no new failures. Then
      `/speckit.tdd.verify` writes `tdd/verification.md` from the real run.
- [ ] T007. Docs: `.specify/extensions/tdd/templates/realize.md` command docs
      (the driver protocol for the differential gate and the ledger contract).
