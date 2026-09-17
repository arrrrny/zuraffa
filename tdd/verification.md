# tdd.verify — SPEC 1689: scenario × zero-scaffold fast stop (skip the guaranteed-failing make attempt)

- **Verified**: 2026-09-18, this session, on `fix/1689-scenario-zero-scaffold-fast-stop`
  (working tree, pre-push; base `a9329746` = master's #1694 merge)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`). `specify 1.0.9.dev0`, TDD Extension
  v1.1.2 (installed, `specify extension list` → ✓ TDD Extension).
- **Scope**: `lib/src/plugins/tdd/services/scaffold_attempt_forecast.dart`
  (new, the single-sourced #1689 forecast + remedy),
  `lib/src/plugins/tdd/models/generation_plan.dart` (the
  `wouldNeverPass('would-never-pass')` outcome entry),
  `lib/src/plugins/tdd/commands/make_command.dart` (the 6b pre-flight gate
  + the best-effort `_wouldNeverPassForecast` probe), the new
  `test/plugins/tdd/services/scaffold_attempt_forecast_test.dart`, the new
  `test/plugins/tdd/commands/bug_1689_scenario_zero_scaffold_fast_stop_e2e_test.dart`,
  and the spec artifacts under `.specify/specs/1689-scenario-zero-scaffold-fast-stop/`.

## Verdict: PASS

The `zfa tdd verify` engine lane was not drivable in this session (the
verification targets a cloud-agent sandbox without a `.zfa.json` project at
the repo root — the speckit.tdd.verify command's step 0 falls back to the
LLM-guided audit path, which this file IS the product of). Every piece of
evidence below is from a real run executed in this session against the
named commits; nothing is copied, stubbed, or back-dated. The red runs were
taken with the fix stashed (`git stash push -u -- <the three lib files>`)
and restored afterward (`rg -c wouldNeverPass lib/…/make_command.dart` → 4
confirmed after each restore).

## 1. TDD discipline (red → green)

### Red (pre-fix, base `a9329746`)

`dart test test/plugins/tdd/commands/bug_1689_scenario_zero_scaffold_fast_stop_e2e_test.dart`

- **E-1689-e1 FAILED** — the honest compile-and-run red: the scenaried
  make (gen's provenance-marked `int` stub + the #1679 scenario assertion
  `equals(5)`) went down the full doomed attempt:

  ```
  plan: 2 step(s): func, build
  → func
     terminal build step skipped: … (issue #1587)
     target test exit: 1
  zfa tdd make: target test still fails after generation (exit 1).
     subject restored to its certified-red shape — the make stopped with a
     generation-error, and a failed make leaves no subject mutation (issue #1036)
  make: behavior=B-1689 outcome=generation-error feature=zcalc3
  ```

  That is the issue's zcalc3 transcript shape verbatim (`→ func`, target
  test exit 1, generation-error). The unit suite's first run failed to
  LOAD (`Error: … 'scaffold_attempt_forecast.dart' not found`) — the
  honest first red for a NEW seam.

- The unchanged-behavior pins (e2/e3/e4/e5) passed pre-fix, proving the
  red is specific to the new stop and not a broken harness.

### Green (post-fix, this branch)

- `dart test test/plugins/tdd/services/scaffold_attempt_forecast_test.dart`
  → `00:00 +11: All tests passed!`
- `dart test test/plugins/tdd/commands/bug_1689_scenario_zero_scaffold_fast_stop_e2e_test.dart`
  → `00:31 +5: All tests passed!` (pre-fix: +4 -1), then with the e6 probe
  added: `00:38 +17: All tests passed!` across both new files, and the
  final confirmation run `01:09 +22: All tests passed!` (both new files +
  the #1651/#1565/#1587 guard suites).

The fast-stop transcript, e1 post-fix:

```
zfa tdd make: behavior "B-1689" make attempt would never pass (issue #1689):
the func pass scaffolds the #1517 zero-value dummy (`return 0;`) for the
declared `int` return, but the paired test asserts a different concrete
outcome (equals(5)) — a zero-value scaffold can never satisfy a value
assertion naming another literal, so the attempt is guaranteed-failing work.
   --> fix: hand-implement the subject at lib/b_1689_subject.dart — the func
   pass has no smarter body for this behavior class (its #1517 scaffold is
   the declared type's zero value, and the paired test test/b_1689_test.dart
   asserts the scenario's concrete outcome) — then re-run `zfa tdd make
   B-1689`; the re-run's drift check certifies the implemented subject
   (issue #1689).
make: behavior=B-1689 outcome=would-never-pass feature=zcalc3
```

Zero entries in the fake-zfa argv log (`readFakeZfaLog()` → `[]`): no
`tdd func`, no `build`, no post-generation target test. The subject file
survives byte-identical; no green evidence is appended; exit 1.

## 2. Measured wall times (SC-002)

| scenario | pre-fix | post-fix | saved subprocess work |
| --- | --- | --- | --- |
| e1 — live drift (hashless red; the zcalc3-mirror make) | 7.89s | 7.38–7.54s | `tdd func` spawn + the post-generation target `dart test` + the subject restore |
| e6 — no-drift (hash-certified red, #1587 dedup; the common path) | 7.44s | 6.06–6.95s | the same attempt with the drift re-run already deduped |

Both pre-fix runs ended `outcome=generation-error` with `→ func` and
`target test exit: 1`; both post-fix runs ended `outcome=would-never-pass`
with ZERO subprocesses (the argv log is the observer — the #1587 SC
pattern). The fixture's absolute wall time is dominated by the make's
pre-existing suite-baseline `dart test` (~6s, cold temp project) and the
fixture's target test compiles in well under a second — so the fixture
delta is small BY CONSTRUCTION. The issue's probe measured the same saved
work at ~30s per attempt (37.5s cycle-log span) on a project whose
target-compile dominates; the saving scales with target-compile time,
which is exactly the claim. The mechanism (no func spawn, no doomed target
test, same honest hand-step stop) is pinned by the argv-log and transcript
assertions, which are timing-independent.

## 3. Non-scenaried regression pins (constraint 3)

- E-1689-e2 (guard-only): `outcome=vacuous-green` at the #1259/#1488 3c
  preflight — unchanged, no func spawn.
- E-1689-e3 (type-only + marker over a dummy): `outcome=vacuous-green` at
  the #1651 9b gate — unchanged shape.
- E-1689-e4 (zero-matching `equals(0)`): the gate stays silent —
  `tdd func` SPAWNS (the attempt runs exactly as before the gate existed).
- E-1689-e5 (real implementation + `equals(5)`): the unchanged #694 skip
  transition, `outcome=skipped`, green evidence appended.
- Guard suites re-run against the fix:
  `dart test test/plugins/tdd/commands/bug_1651_vacuous_green_e2e_test.dart
  test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart
  test/plugins/tdd/make_command_1565_test.dart
  test/plugins/tdd/make_command_1587_build_skip_test.dart`
  → `00:29 +5: All tests passed!` (repeated inside the final +22 run).
- Fast-tier sweep: `dart test test/plugins/tdd/services` →
  `01:59 +1168: All tests passed!`; `test/plugins/tdd/models` +
  `test/plugins/tdd/helpers` → `00:02 +86: All tests passed!`;
  `test/plugins/tdd/commands` → +553 with the only failures being the two
  template-grammar files below (environment, see §4), re-run green after
  the fix: `00:01 +27: All tests passed!`.

## 4. Pre-existing failures (flagged, NOT caused by this fix)

Proven pre-existing by identical pass/fail totals on the unfixed base
(the fix stashed, same command, same tree):

1. `test/plugins/tdd/make_command_test.dart` (heavy, real-subprocess lane,
   via `--preset=regression <file>`): **+30 -10** with and without the
   fix. The failing tests' fake-zfa spawn logs come back EMPTY
   (`WhereIterable<String>:[]`) — the entity-pipeline children never
   spawn in this sandbox; unrelated to the gate (the gate never touches
   entity pipelines).
2. `test/plugins/tdd/run_command_test.dart` (heavy driver lane, via
   `--preset=all <file>`): **+37 -19** with and without the fix — the
   same sandbox spawn environment class.
3. `test/plugins/tdd/bug_1651_driver_remedy_test.dart` (+ three driver
   remedy suites run together): **+8 -1** with and without the fix; the 1
   is a LOADING error of that file in this environment (identical on
   base).

A fourth, self-inflicted and REPAIRED class: `specify init` (the spec's
own tooling step) rewrote `.specify/templates/spec-template.md` and broke
the #1186/#1004 template-grammar pins (5 failures). Restoring the
scaffold-touched tracked files (`git checkout -- .specify .agents`) turned
them green — those modifications were environment churn, deliberately
excluded from this PR (one PR per spec; the committed `.specify/` stays
byte-for-byte except the new spec directory).

## 5. Static gates

- `dart analyze` on the five changed/new files → `No issues found!`
- `dart format --output=none --set-exit-if-changed .` (repo-wide) →
  `Formatted 2946 files (0 changed)` — zero formatting drift.
- The `example/` Flutter subpackage does not resolve in this sandbox (no
  Flutter SDK) — the same Flutter-less-sandbox note the #1664
  verification recorded; it is a separate package, untouched by this fix.

## 6. Spec-contract checks (the issue's four constraints)

1. **Detect before the attempt** — the gate sits after the plan
   finalizes and before the #1036 snapshot / `SourceWriteProbe` /
   `runPlan`; e1/e6 prove no subprocess runs past it (argv log empty).
2. **Same honest hand-step remedy** — the stop prints the single-sourced
   `--> fix:` (hand-implement the subject, re-run make; the drift check
   certifies the implemented subject) — the recovery the pre-fix
   `generation-error` stop always ended at, minus the attempt.
3. **Non-scenaried behaviors unaffected** — e2/e3/e4/e5 + the #1651/
   #1565/#1587 guard suites + the predicate's silent rows (guard-only,
   type-only, zero-matching literals, non-stub subjects, legacy no-arg,
   marker-less hand subjects, unparseable matchers) prove no attempt is
   skipped outside the scenario-assertion × zero-scaffold intersection.
4. **Self-removal when func grows real generation** — the forecast keys
   on `funcRewritableStubPattern` + the provenance marker + the #1517
   literal vocabulary (`_declaredStubBody` mirrored verbatim); when func
   stops emitting zero-value literals the prediction is null and the
   gate goes silent with no change in the gate.

The #1679 scenario derivation, the #1517 zero-scaffold semantics, and the
`zfa tdd func` command are untouched; the run driver is untouched (the
generic make-failure arm owns the loop semantics, per spec FR-002).
