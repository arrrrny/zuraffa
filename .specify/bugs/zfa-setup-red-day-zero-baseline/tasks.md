# Tasks: zfa-setup-red-day-zero-baseline (issue #626)

Bug-triage task file. The fix itself landed in commit `af1e3b0`; the tasks
below are the audit findings worth acting on from
`tdd/verification.md` (verdict PASS_WITH_GAPS). The bug is not blocked by
these: no HIGH findings, no untested criteria.

## Phase 1: TDD remediation

- [ ] T1 (finding 1, MED): split the eager day-zero gate test into two — one
      asserting the emitted app surface (lib/app.dart + symbol + zfa
      attribution + smoke content), one asserting `flutter test` exit 0 — so
      each has a single reason to fail. Prove it done by confirming Gate 1
      contains exactly those two tests, with one failure reason per test, then
      run:
      `dart test test/integration/day_zero_smoke_gate_test.dart --preset=integration`.
- [ ] T2 (finding 4, LOW): promote `_runFlutterTest` from
      `test/integration/day_zero_smoke_gate_test.dart` to
      `test/helpers/` (e.g. `run_flutter_test.dart`) so future Flutter-app
      e2e tests reuse it instead of hand-rolling a third subprocess runner.
      Prove it done by confirming `_runFlutterTest` is defined under
      `test/helpers/` and imported and reused by
      `day_zero_smoke_gate_test.dart`, then run:
      `dart analyze test/helpers/ && dart test test/integration/day_zero_smoke_gate_test.dart --preset=integration`.
- [ ] T3 (follow-up, from "What was not audited"): file an issue for
      `zfa tdd init` on pure-Dart projects — the smoke test asserts an app
      module nothing generates (pre-existing red, out of #626's blast
      radius). Prove it done with: `gh issue create ...` referencing this
      verification report.
