# TDD Verification — 1529 make timeout (receipt, scaled budget, trimmed re-certification)

**Feature**: 1529-make-timeout-diagnosable-scaled-budget
**Verified**: 2026-09-13 (this session; every command below was executed
here — nothing is claimed from prior output)

## 1. Test-first evidence

- Red evidence: `tdd/red-evidence.md` — the M1/M2 behaviours re-derived
  against `master` in an isolated worktree (compile + assertion reds
  naming every missing symbol: the receipt library, `scaledStepBudget`,
  `elapsed`/`descendantArgvs`, `timeoutReceipt`, the driver's missing
  receipt line, missing warning, missing `--timeout 25.0000` hand-down);
  the M3 behaviours red live this session (missing `RecertScope`
  library; wiring assertions failing with `suite invocations: []`).
- Green: the same tests against this branch — all pass (counts below).

## 2. Executed verification (fast tier, per dart_test.yaml)

| Suite | Behaviours | Result |
|---|---|---|
| `dart test test/plugins/tdd/services/recert_scope_test.dart` | U9, U10, U11 | +13 All tests passed |
| `dart test test/plugins/tdd/spec_1529_recert_wiring_test.dart` | U12a–d | +4 All tests passed |
| `dart test test/plugins/tdd/services/step_timeout_receipt_test.dart` | U1, U2, U5, U6 | passed (16 tests) |
| `dart test test/plugins/tdd/services/subprocess_timeout_test.dart` | U3, U4 | passed (incl. the #742 regression set) |
| `dart test test/plugins/tdd/services/step_runner_test.dart` | U7 | passed (60 tests incl. #690 tiers) |
| `dart test test/plugins/tdd/commands/run_driver_timeout_receipt_test.dart` | U8, U13, hand-down | +3 All tests passed |
| `dart test test/plugins/tdd/run_baseline_cache_test.dart` | #741 contracts | +10 All tests passed |
| `dart test test/plugins/tdd/services/` (whole chunk) | regression | +968 All tests passed |
| `dart test test/plugins/tdd/*.dart` (root chunk) | regression | +523 All tests passed |
| `dart test test/plugins/tdd/commands/` (chunk) | regression | +536 All tests passed |
| `dart test test/plugins/tdd/{models,helpers,scenarios,theater,corpus_economics}` | regression | +149 All tests passed |

The `slow`-tagged make fixture suite (`make_command_test.dart` et al.)
is excluded from cloud-agent runs by the repo's own `dart_test.yaml`
(it spins `pub get` + `build_runner` fixtures); the make contract on
this branch is covered by the fast-tier wiring tests above plus the
existing fast-tier make suites (declared/strict 071, widget 939/950,
1036, 1330 — all in the green chunks).

## 3. dart analyze

```
dart analyze <every changed .dart file>  →  No issues found!
```

(2 infos found mid-session — `use_null_aware_elements`,
`no_leading_underscores_for_local_identifiers` in the wiring test —
fixed before the final analyze.)

## 4. dart format

`dart format` applied over all 14 touched files; `git diff` after
format shows only the intended sources/tests.

## 5. Test-smell rubric

- **Assertion strength**: every behaviour asserts the OBSERVABLE
  contract — receipt file existence + field values (U8), the child's
  forwarded `--timeout 25.0000` read back from the fake entrypoint's
  argv log (hand-down), the suite spy's logged argv (U12a: one scoped
  invocation naming BOTH test files; U12b/c: the bare full-suite
  template), cycle-log suite numbers (`baseline=1 guard=0`), exit codes,
  and outcome tokens.
- **No tautologies**: the fail-closed tests assert the NEGATIVE space —
  `isNot(contains('trimmed re-certification set'))`, the bare suite
  argv, the empty spy log — so the trim cannot silently weaken the
  certification.
- **No test-only production branches**: the production code carries no
  `if (testing)` paths; the fast tier drives real spawn paths through
  spy scripts and injected spawners (the repo's established pattern).
- **Timing sensitivity**: the U8 kill test asserts `elapsed_ms` within
  generous bounds (>=1000, <25000 against a 30s sleeper and a 1.2s
  deadline); no sub-100ms timing assertions anywhere.
- **Fixtures isolated**: temp-dir fixtures disposed in `tearDown`;
  `exitCode` reset; no `Directory.current` mutation (the `--project`
  flag contract).

## 6. Acceptance-criteria coverage (spec.md scenarios)

| Scenario | Covered by |
|---|---|
| US1.1 (receipt on kill, resumable runner-error) | U8 driver test — receipt at `specs/<feature>/tdd/make.<id>.timeout.json` with argv/elapsed/phase/tail; `result=runner-error`; `stopped_at=B-001:make` |
| US1.2 (phase running/compiling/unknown + evidence) | U3 pure tests (tree outranks output markers; honest `unknown`) |
| US1.3 (receipt write fails — never a gate) | U6 (writer outcome reports the error, runner-error stands) + driver note line |
| US2.1 (default = max(25, 4B), handed down) | U1 + the hand-down driver test (`--timeout 25.0000` in the child argv) |
| US2.2 (explicit wins + LOUD warning before first step) | U2 + U13 (warning precedes `step failed` in the captured output) |
| US2.3 (cached duration substitutes; floor without one) | U9 (durationMs round-trip; old files → null → floor) + the `run_driver_core` derivation |
| US3.1 (scope = {own, importer}, never full suite) | U10 + U12a |
| US3.2 (whole-tree scope → full suite unchanged) | U10 full-tree case + U11 whole-tree decision |
| US3.3 (no fingerprint / shared write / unparseable → existing paths) | U11 fail-closed table + U12b + U12c + the trimmed-transcript-unusable fallthrough |

## 7. Residual risks / notes

- The phase inference's process-tree snapshot is POSIX-only (`ps`);
  Windows degrades to output markers, then `unknown` — by design
  (FR-3), tested at the inference level.
- The trimmed guard cannot see dynamic (`string-interpolated`) imports;
  the mtime proof bounds that risk: the trim only fires when make wrote
  NOTHING outside the declared set, so untouched files cannot have been
  affected by the writes.
- The `slow` make fixture tier was not executed on this constrained
  agent (repo policy for cloud agents; disk/RAM ceiling documented in
  `dart_test.yaml`). The fast-tier wiring tests exercise the same
  command surface through spy runners.
