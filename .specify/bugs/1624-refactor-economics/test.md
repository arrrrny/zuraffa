# Test — BUG 1624 (refactor economics: batch phase 1, gate the build, inherit the re-proof)

## Test surface

New / updated assertions:

- `test/plugins/tdd/services/build_relevance_test.dart` — new group
  `refactorBuildSkipNote (issue #1624)`: marker missing → run; newer
  annotated `.dart` → run; newer plain `.dart` → skip; newer non-Dart →
  run; newer build-config → run; unchanged tree → skip.
- `test/plugins/tdd/services/refactor_passes_test.dart` — a spec whose
  `skipGate` returns a note is recorded as a skipped action
  (`skipped: true`, `filesChanged: []`, exit 0) and the fake executor
  never sees it; the default pass set attaches a gate to `build` only.
- `test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart`
  — the ledger test's first-invocation spawn count is now 1 (preflight
  only; the re-proof is inherited), plus two new command-level tests:
  * `bug 1624: no pass changed a file — the re-proof child is NOT spawned
    and the preflight verdict is inherited` (suite spawns == 1, output and
    cycle log name the inheritance and cite #1624);
  * `bug 1624: --full-reproof still spawns the re-proof even when no pass
    changed a file` (suite spawns == 2);
  plus a driver-level test `bug 1624: a phase-1 refactor spawn carries
  --pass-batch`.
- `test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart` — the
  phase-1 refactor-argv test also pins `--pass-batch`.
- Adjusted for the new contract (slow/regression tiers, outside this
  ticket's verification list):
  `bug_1507_kernel_cache_cycle_start_test.dart` (healthy-cycle counter is
  now 1 — preflight only) and `bug_1333_refactor_reproof_retry_test.dart`
  (B3/B4/B5 seed a malformed lib so a pass DOES change a file and the
  re-proof is exercised; B6 asserts the inherited verdict line instead of
  a fabricated green).

## Commands + results

| Command | Result |
|---------|--------|
| `dart test test/plugins/tdd/services/build_relevance_test.dart` | 21 passed |
| `dart test test/plugins/tdd/services/refactor_passes_test.dart` | 13 passed |
| `dart test test/plugins/tdd/services/pipeline_runner_test.dart` | 15 passed, 1 skipped |
| `dart test test/plugins/tdd/services/step_runner_test.dart` | 20 passed |
| `dart test --preset=all test/plugins/tdd/commands/bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart` | 16 passed |
| `dart test test/plugins/tdd/models/refactor_action_test.dart test/plugins/tdd/theater/theater_data_test.dart` | 50 passed, 1 skipped |
| `dart test --preset=all test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart` | 9 passed (see note) |
| `dart analyze` on every touched lib/test file | No issues found |
| `dart format --output=none --set-exit-if-changed` on every touched file | exit 0, 0 changed |

`--preset=all` is required for the `@Tags(['slow'])` files: the repo's
default `dart_test.yaml` sets `exclude_tags: slow`, and naming the file
does not clear that exclusion (a bare `dart test <file>` reported "No
tests ran").

## bug_922 — the e2e test is load-sensitive (not a regression)

`bug_922_refactor_preflight_baseline_test.dart` holds 9 tests; the last is
the heavyweight `run driver end-to-end` test (it provisions a real
build_runner/pub-get fixture and spawns real `dart test` suites through an
exec forwarder).

- First full-file run: **8 passed, 1 failed** — the e2e test ended
  `result=runner-error … stopped_at=B-001:refactor` after the refactor
  child stalled inside its real `dart test` preflight.
- Second full-file run of the SAME command: **9 passed** (e2e at 3m29s
  into the file).
- The e2e test run alone with this change: **passed** (5m03s); run alone
  on the stashed (pre-change) tree: **passed** (4m22s).

So the single earlier failure was machine-load flakiness in the real-suite
child, not a regression of this change — the same test is documented as an
environment-dependent pre-existing failure in
`.specify/bugs/1588-phase2-refactor-batch-and-parked-exempt/test.md`. This
change only removes work from that path (the re-proof is inherited when
nothing changed), so it cannot have made the child slower.

## The other edited test files (run after the primary list)

| Command | Result |
|---------|--------|
| `dart test --preset=all test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart` | 6 passed |
| `dart test --preset=all test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart` | 4 passed |

Both were adjusted for the new contract (bug_1507: the healthy-cycle
counter is 1 — preflight only, since the re-proof is inherited; bug_1333:
B3/B4/B5 seed a malformed lib so a pass DOES change a file and the
re-proof is exercised, B6 asserts the inherited verdict line), and both
pass.
