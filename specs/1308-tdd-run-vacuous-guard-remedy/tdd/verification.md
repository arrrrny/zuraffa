# Verification: 1308-tdd-run-vacuous-guard-remedy

## Test-first evidence (red → green)

| behavior | red evidence | green evidence |
| -------- | ------------ | -------------- |
| U-1308-1 (FR-005 vocabulary) | RED 1: `dart analyze` — 13 compile errors (`vacuousGuardFallbackRemedy`/`vacuousGuardWarningToken`/`contentCarriesVacuousGuardMarker`/`vacuousGuardHandStepViolation` undefined) | GREEN: `dart test issue_1308_vacuous_guard_remedy_test.dart` — `+1: U-1308-1 ... All tests passed!` |
| U-1308-2 (FR-002 gen warning) | RED 2: assertion failure — `Expected: contains 'zfa:tdd: guard-only' / Actual: ''` (writer printed no warning) | GREEN: warning printed, file still written, content unchanged (`+2: U-1308-2 ... All tests passed!`) |
| U-1308-3a/b/c (AC-4 no-warning guards) | GREEN from RED 2 run (nothing printed) — guarded by construction | GREEN post-implementation: `+5: All tests passed!` |
| U-1308-5 (FR-001 stop remedy) | RED 3: driver run — stop message carried only the generic `resume:` line; remedy string absent | GREEN: exact remedy printed; `stopped_at=U1:make` preserved; `stopped_at=U1:hand` absent |
| U-1308-6 (FR-004 hand seam) | RED 3: driver run — `stopped_at=U1:make` (generic), no hand step, no journal violation | GREEN: `stopped_at=U1:hand` in summary + engine `drive` journal entry; violation names what to write + where |
| U-1308-4 (FR-003 forwarding) | RED 3: driver run — gen child's warning swallowed (`[run] U1 gen -> ok`, no warning line in transcript) | GREEN: token + remedy lines forwarded into the run transcript; run completes |
| U-1308-REG1 (SC-4 regression guard) | — | `run_command_test.dart` 49/49, `bug_1259_vacuous_green_test.dart` 7/7, `behavior_test_writer_test.dart` 7/7, `run_engine_command_test.dart` + `run_skin_command_test.dart` 17/17, fast driver-adjacent suites 41/41 |

## Test runs (cloud-agent scope: changed files only — no full suite)

```text
dart analyze <changed dart files + new test files>   → No issues found!
dart format --set-exit-if-changed lib test           → 0 changed (exit 0 — the CI format gate)
dart test test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart               → 5/5 pass
dart test --preset=all test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart → 3/3 pass
dart test --preset=all test/plugins/tdd/bug_1259_vacuous_green_test.dart           → 7/7 pass
dart test --preset=all test/plugins/tdd/run_command_test.dart                      → 49/49 pass
dart test --preset=all test/plugins/tdd/commands/run_engine_command_test.dart
                        test/plugins/tdd/commands/run_skin_command_test.dart      → 17/17 pass
dart test <fast adjacent: behavior_test_writer, run_command_path_format,
           explain_flag, json_flag>                                              → 41/41 pass
```

Pre-existing, unrelated failures on pristine HEAD (reproduced with the
changes stashed — NOT introduced by this feature):

- `test/plugins/tdd/commands/gen_command_test.dart`: 17 pass / 1 fail —
  the bug #871 "registry composite third segment" test's expected test-name
  rendering (`test('returns 42 ...')` vs the emitted
  `test('B-003 — returns 42 ...')`).
- `test/plugins/tdd/make_command_test.dart`: 33 pass / 5 fail — same
  counts on pristine HEAD (environment-dependent suite).

## End-to-end proof (real CLI, not the fake binary)

`scripts/demo_1308_vacuous_remedy.sh` (run from the repo root against a
throwaway temp project; repro of the issue's spec + the traced variant):

1. `zfa tdd plan 1308-demo` — fallback routing note
   (`route: U1 -> unit lane [fallback: ... trace FR to a declared contract row]`).
2. `zfa tdd gen U1` — the gen-time warning, step still exits 0, test emitted:
   ```text
   zfa tdd gen: WARNING [zfa:tdd: guard-only] behavior "U1" — the generated
   unit test's only assertion is the bare UnimplementedError guard: no
   `traces:` line to a declared contract row derives a real outcome
   assertion, and the prose heuristics did not match. `make` will refuse
   this test vacuous-green (issue #1259) and the run will stop here
   (issue #1308).
      --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan,
      re-run zfa tdd gen, re-run zfa tdd run
   ```
3. `zfa tdd verify-red U1` — `classification=assertion certified=true`
   (honest red preserved).
4. `zfa tdd run 1308-demo` — the stop remedy:
   ```text
   zfa tdd run: step failed — behavior=U1 step=make outcome=vacuous-green
      the generated test is GUARD-ONLY [zfa:tdd: guard-only] — the behavior
      is fallback-routed (no traces: to a declared contract row), so gen
      could not derive a real outcome assertion and make refuses it
      vacuous-green (issue #1259, #1308).
      --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan,
      re-run zfa tdd gen, re-run zfa tdd run
   run: feature=1308-demo result=stopped pending=0 red=1 green=0 done=0
   stopped_at=U1:make
   ```
5. The TRACED entity contract variant (`TodoRepo: add(AddTodo) -> Todo`,
   traces `FR-001, TodoRepo`) — gen emits the guard WITH the marker and NO
   fallback warning; the run stop is the named hand step:
   ```text
   zfa tdd run: step failed — behavior=U1 step=make outcome=vacuous-green
      the traced contract's return is void/an entity — the
      zfa:tdd: vacuous-guard marker IS the designed hand-delta seam
      (issue #1308): ...
      hand step: U1:hand — write an assertion on the observable outcome in
      test/tdd/1308-demo-hand/u1_test.dart (replace the vacuous-guard
      guard, remove the marker), then re-run `zfa tdd run 1308-demo-hand`.
   run: feature=1308-demo-hand result=stopped pending=0 red=1 green=0 done=0
   stopped_at=U1:hand
   ```
   Journal (`tdd/journal.json`, engine `drive` entry):
   `"stopped_at": "U1:hand"` and the violation
   `hand-step=U1:hand — replace the zfa:tdd: vacuous-guard guard at
   test/tdd/1308-demo-hand/u1_test.dart with an assertion on the
   observable outcome, remove the marker, then re-run make (issue #1308)`.

## Mutation evidence (test strength)

The messaging layer is string-output; the driver suite exercises the MUTANTS
that matter:

- marker REMOVED from the traced test file → the stop reverts to the
  fallback remedy + `stopped_at=U1:make` (U-1308-5 asserts
  `isNot(contains('stopped_at=U1:hand'))`; the arm's branch predicate is
  the marker itself).
- marker ADDED to the fallback test file → the stop flips to the hand step
  (U-1308-6 asserts `stopped_at=U1:hand` against a marker-carrying file;
  U-1308-5 asserts the opposite against a marker-free one — the pair kills
  the swapped-branch mutant).
- forward scan token widened/narrowed → U-1308-4 asserts BOTH the token
  line and the remedy line survive the forward, and the fast suite asserts
  the writer emits exactly those two lines.

## Hard-constraint audit

- Engine cycle / verify gate semantics / contract scanner: untouched
  (`git diff` covers only `vacuous_guard.dart`, `behavior_test_writer.dart`,
  `run_driver_core.dart` + tests + spec artifacts).
- Generated test shape: unchanged (U-1308-2 asserts the emitted content is
  byte-identical to the pre-change template; the guard is still emitted).
- `make`'s vacuous-green refusal: unchanged (`bug_1259_vacuous_green_test.dart`
  7/7).
