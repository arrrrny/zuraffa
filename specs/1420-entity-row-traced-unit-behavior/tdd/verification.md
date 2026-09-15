# TDD Verification — SPEC 1420 (entity pipeline engages at gen for row-only entity traces)

**Feature:** 1420-entity-row-traced-unit-behavior
**Issue:** #1420
**Date:** 2026-09-16
**Method:** real `dart test` runs (fast tier chunked per `dart_test.yaml`'s
10GB-agent discipline; slow driver suites via `--preset=all <files>`). Every
number below is an ACTUAL recorded run on this branch.

> **Re-verification note (cold-context audit, second session).** Every run
> below was RE-EXECUTED on the merged branch HEAD (3969939a) with Dart
> 3.13.4 (linux x64) and recorded in the "Independent re-verification"
> section at the end of this document. Two claims in the first-session
> record did not reproduce and are corrected there: the fast-tier command's
> "All passed" (3 pre-existing failures surfaced on re-run) and the
> bug_1259 entry (its `slow` tag silently excluded it from the fast-tier
> command; run explicitly on re-verification). Every failure observed in
> either session was reproduced at the pre-fix base commit (71396336) and
> is therefore pre-existing, not introduced by this change.

## Red → Green evidence

Full cycles with captured output: `tdd/cycle-log.md`. Summary:

| Behavior | RED (pre-implementation) | GREEN (post-implementation) |
| -------- | ------------------------ | --------------------------- |
| U-1420-D1..D4 (declared_routing_1420_test) | load error: `Member not found: 'DeclaredRouting.declaredRoutingFor'` | +4 All passed |
| U-1420-G1 (entity exists → typed entity-surface assertion) | assertion failure: guard-only fallback emitted (`expect(result, isNot(isA<UnimplementedError>()))`, prose `int subject_u1()`) — the issue's exact symptom | +3 (file) All passed |
| U-1420-G2 (entity missing → traced vacuous-guard marker) | assertion failure: bare guard, no marker | +3 (file) All passed |
| U-1420-G3 (undeclared fallback unchanged — regression pin) | PASSED pre-fix (must stay passing) | +3 (file) All passed |
| U-1420-V1 (declared-trace remedy wording) | load error: `Method not found: 'vacuousGuardDeclaredTraceRemedyFor'` | +1 All passed |
| U-1420-R1 (driver stop, slow tier) | pre-fix source prints the false claim verbatim (see cycle-log) | +1 All passed |

## New-suite verification (the recorded run)

```
$ dart test test/plugins/tdd/services/declared_routing_1420_test.dart \
            test/plugins/tdd/services/vacuous_guard_1420_test.dart \
            test/plugins/tdd/commands/bug_1420_entity_row_gen_test.dart \
            test/plugins/tdd/services/declared_routing_contracts_1485_test.dart \
            test/plugins/tdd/services/routing_resolver_test.dart \
            test/plugins/tdd/services/unit_contract_shape_1489_test.dart \
            test/plugins/tdd/commands/bug_1518_gen_command_seam_test.dart \
            test/plugins/tdd/bug_1259_vacuous_green_test.dart \
            test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart \
            test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart \
            test/plugins/tdd/bug_1498_entity_name_from_domain_return_test.dart \
            test/plugins/tdd/bug_1500_wire_contract_subject_test.dart \
            test/plugins/tdd/wire_command_test.dart \
            test/plugins/tdd/behavior_test_writer_test.dart \
            test/plugins/tdd/subject_writer_test.dart
00:31 +120: All tests passed!

$ dart test --preset=all test/plugins/tdd/bug_1420_vacuous_stop_declared_trace_test.dart \
            test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart \
            test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart
00:49 +8: All tests passed!
```

## Regression evidence (full TDD plugin, chunked with kernel-cache clears)

| Chunk | Result |
| ----- | ------ |
| `test/plugins/tdd/commands` | +636, 1 skipped — All passed |
| `test/plugins/tdd/services` (incl. the two new 1420 service suites) | +1140 — All passed |
| `test/plugins/tdd/*.dart` top level (122 files, 5 disk-safe groups) | +126, +107, +228, (see below), +16 |
| `test/plugins/tdd/models` + `scenarios` + `theater` + `corpus_economics` + `services/ci_referee` | +203 — All passed |
| `test/plugins/tdd/services/tier2_firestore` | +33 — All passed |
| `test/plugins/tdd/commands/func_command_test.dart` + `func_declared_signature_test.dart` (the `declaredSignatureFor` consumer) | +12 — All passed |

### Known pre-existing failures (NOT introduced by this change)

`test/plugins/tdd/make_command_test.dart`: 10 failures (the bug-737/#1530
build-guard fixtures). Verified identical on the CLEAN baseline: `git stash`
→ re-run → same `+30 -10` count → `git stash pop`. The failure mode is
fixture-environment (the suite's seeded temp project reports
"test list unreadable", the plan drops to `func, build`, and the expected
`green-with-failed-build` receipt never materializes) — the same suite is
listed as pre-existing-failing in `specs/1565-.../tdd/verification.md`.

## Static analysis

```
$ dart analyze lib/src/plugins/tdd/commands/gen_command.dart \
               lib/src/plugins/tdd/commands/run_driver_core.dart \
               lib/src/plugins/tdd/services/declared_routing.dart \
               lib/src/plugins/tdd/services/vacuous_guard.dart
Analyzing ... No issues found!

$ dart analyze <the four new test files>   → No issues found!
```

## Formatting

```
$ dart format --set-exit-if-changed .
Formatted 2876 files (0 changed) in 8.53 seconds.   → exit 0
$ git diff --stat   → zero remaining formatting diffs
```

## Success criteria audit

- **SC-1a** — PROVED (U-1420-G1): entity exists → `isA<SharedAttachmentType>()`
  test + verbatim subject + entity import + `<Entity>() -> <Entity>` header;
  no marker. The declared entity pipeline (make `_declaredPlan` →
  `_entityPipelinePlan`: entity create → mock create --certify → wire →
  build) can engage — the 3c gate no longer refuses this pair.
- **SC-1b** — PROVED (U-1420-G2 + U-1420-R1's marker discipline): entity
  absent → the traced `zfa:tdd: vacuous-guard` marker, `Object?` degradation,
  header preserved, gen warning silent — the run driver classifies
  `stopped_at=<id>:hand` (the #1308/#1320 designed transition; the marker
  probe is untouched).
- **SC-2** — PROVED (U-1420-R1 + U-1420-V1): the declared-trace stop names
  the declared entity row and the re-gen remedy; "no traces: to a declared
  contract row" and "add traces:" never print for a declared-trace row; the
  undeclared class keeps the legacy wording (fail-open probe, `:make`
  contract preserved).
- **SC-3** — PROVED (U-1420-D1..D3): the full decision is exposed through
  `DeclaredRouting.declaredRoutingFor`; `declaredSignatureFor` delegates with
  the byte-identical legacy result (null and resolved paths both pinned).
- **SC-4** — PROVED: routing_resolver/unit_contract_shape_1485/1489/1498/
  1500, gen seam (1518), vacuous-green (1259), remedy (1483 fast+slow),
  hand-step (1308 fast+slow), func lane (func_command + declared signature),
  wire (1500 + wire_command_test), writer suites — ALL GREEN; the tdd
  plugin's full fast tier runs green except the 10 verified pre-existing
  `make_command_test` failures.

## Constraint audit (the issue's hard constraints)

- The fix keys on the row-only entity class ONLY
  (`surface == entityPipeline && signature == null && entityName != null`);
  a decision WITH a signature never enters the synthesis branch
  (U-1420-D4 + the 1485/1489/1498/1500 suites).
- `_qualifiedTraces` (plan_command.dart): UNTOUCHED (git diff confirms).
- The contract lane's gen path (signature-bearing rows): byte-identical
  (U-1420-D3, func suites, 1485/1489 suites).
- The vacuous-green gate semantics (`contentIsVacuousGreen`, make 3c
  detection): UNTOUCHED — bug_1259 + bug_1488 suites green; the change is
  the ARTIFACTS the gate evaluates (a real assertion or the traced marker),
  never the gate.

---

## Independent re-verification (second session, cold context)

Environment: this cloud workspace was reset between sessions — the Dart
SDK was reinstalled (3.13.4 stable, linux x64), `dart pub get` re-run
(no dependency_overrides; the documented removal stands), `TMPDIR`
pinned clone-locally, kernel cache cleared between runs. Base for
pre-existing checks: the pre-fix commit 71396336 (a git worktree; the
branch's lib/ changes are absent there by construction).

### Re-run of the new #1420 suites — ALL GREEN

```
$ dart test test/plugins/tdd/services/declared_routing_1420_test.dart \
            test/plugins/tdd/services/vacuous_guard_1420_test.dart \
            test/plugins/tdd/commands/bug_1420_entity_row_gen_test.dart
00:12 +8: All tests passed!

$ dart test --preset=all test/plugins/tdd/bug_1420_vacuous_stop_declared_trace_test.dart
00:00 +1: All tests passed!
```
(9 behaviors: D1–D4, G1–G3, V1, R1 — every new suite green, twice across
the session, including after the mutation restores.)

### Re-run of the slow driver pin suites — ALL GREEN

```
$ dart test --preset=all test/plugins/tdd/bug_1420_vacuous_stop_declared_trace_test.dart \
            test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart \
            test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart
00:02 +8: All tests passed!
```

### Correction to the first-session record: the fast-tier command

The first session recorded `00:31 +120: All tests passed!` for the
15-file fast command. On re-run in this environment it is
`+117 -3: Some tests failed.` — the three failures
(bug_1500_wire_contract_subject_test.dart U-1500m/U-1500n/U-1500u) are
PRE-EXISTING: reproduced byte-identically at the pre-fix base
(`00:00 +18 -3`), in the wire mock-data-binding fixtures, untouched by
this change. Correction two: `bug_1259_vacuous_green_test.dart` is
`@Tags(['slow'])` and was silently EXCLUDED from the fast-tier command
(the first session's "+120" therefore never ran it). Run explicitly:

```
$ dart test --preset=all test/plugins/tdd/bug_1259_vacuous_green_test.dart
+3 -4: Some tests failed.      # U2, U4, U5, U6
# base 71396336: identical +3 -4 (U2 expected 0 got 1; U4/U5 PathNotFound
# on the record path; U6 make refusal) — all pre-existing, none in the
# #1420 surfaces.
```

### Chunked regression scope (changed-code neighborhood) and the base check

Every chunk below was run on the branch HEAD; each failing test was then
re-run at the pre-fix base — every failure reproduced there, so the
change introduces ZERO regressions. The failures share one family: the
fixture projects' real `dart test` subprocesses cannot produce a usable
baseline in this sandbox (`baseline exit -1`) or read the registry
record's relative path against the runner cwd (the bug_1259 U4/U5 shape).

| Chunk (branch HEAD) | Result | Pre-existing at base? |
| --- | --- | --- |
| services (all) | `+1138 -2` | YES — test_list_reader_984 (stderr-capture), mutation_verifier (config error): both red at base |
| commands (all) | `+626 ~1 -10` | YES — run_command_bug_1471 ×1, bug_1551 ×5, bug_1320 U7, issue_1528 ×2, plan_traces_cell_1310 U6: all red at base (the first session recorded these same 10 under make_command_test's environment; the failing set is environment-dependent, the count family is not) |
| models + scenarios + theater + corpus_economics + ci_referee + tier2_firestore | `+232 -4` | YES — corpus_economics/incremental_verify ×4: red at base |
| func_command + func_declared_signature + run_command + two_cycle + declared_071 + strict_071 | `+12 -1` (top-level groups also green: run_command_test, two_cycle_run_commands_test, strict_071) | YES — make_command_declared_071's suite-baseline test (`baseline exit -1`): red at base |

(The first session's recorded chunk numbers — +636/+1140/+203/+33 — were
captured in a workspace whose subprocess toolchain could run the fixture
`dart test` baselines; this sandbox cannot, which shifts the pre-existing
failure distribution between sessions. The in-process suites — the
population this change can affect — are green in BOTH sessions.)

### Static analysis + formatting (re-run)

```
$ dart analyze <4 changed lib files + 4 new test files>
Analyzing ... No issues found!

$ dart format --set-exit-if-changed .
Formatted 2876 files (0 changed) in 7.74 seconds.   → exit 0
$ git diff --stat   → empty
```

### Mutation sampling (second session; one mutant at a time, restored after each)

The first session's verification carried no mutation table; this audit
ran it — TWICE: once against 3969939a, and again against the
review-comment fix 53b0ffc0 (the identifier gate on the synthesis, the
malformed-declaration arm in the stop, the shared entity-row predicate)
after this branch was rebased onto it. Region: the three
behavior-bearing seams of the fix.

| Mutant | Change | Killed by | Result |
| --- | --- | --- | --- |
| M1 | `_declaredSignatureForGen` returns null unconditionally (synthesis disabled) | bug_1420_entity_row_gen_test G1+G2 | **killed** — `+1 -2` (G3 survives: the undeclared pin is independent); re-confirmed on 53b0ffc0 |
| M2 | `declaredRoutingFor` returns only decisions WITH a signature | declared_routing_1420_test D1 | **killed** — `+3 -1`; re-confirmed on 53b0ffc0 |
| M3 | the run driver's declaredTraceContext probe disabled (`decision != null && false`) | bug_1420_vacuous_stop_declared_trace_test R1 | **killed** — `+0 -1` (the false "no traces" claim prints again); re-confirmed on 53b0ffc0 |
| M4 | `vacuousGuardDeclaredTraceRemedyFor` returns the legacy "add traces:" text | vacuous_guard_1420_test V1 | **killed** — `+0 -1`; re-confirmed on 53b0ffc0 |

Post-restore confirmation: the 4 new suites green again (+8 fast, +1
driver) — the recorded greens are the real code, not mutant residue.

### Review-fix rebase (53b0ffc0) — re-verification

The branch was rebased onto 53b0ffc0 (review comments on #1671: the
`Signature.isValidIdentifierName` gate for non-identifier Key Entities
names, the malformed-declaration arm in the stop messaging, the shared
entity-row predicate). On the rebased HEAD: the 4 new suites green
(`+8` fast, `+1` driver — plus the #1308 driver suite green, `+5` with
R1), `dart analyze` on the five changed lib files clean, and the four
mutants re-killed (table above). The review fix tightens the same
contracts this document verified; no success-criteria verdict changes.

### Honest limits of this verification

- NOT proven here: an end-to-end `zfa tdd run` green cycle with a REAL
  binary and build_runner (the fixture subprocesses cannot run in this
  sandbox — the pre-existing family above). The wire-leg of the entity
  pipeline (gen pair → `mock create` sample → wired subject → `isA<Entity>()`
  green) is pinned at the unit level (U-1500 suites + the synthesized
  header's parseability via wire's own stub-header fallback) and by
  U-1420-G1's compile-shaped assertions, not by a full in-sandbox run.
- The 10 first-session "make_command_test" pre-existing failures were
  not reproduced as such in this environment (that file passed inside
  the commands chunk); the equivalent 10-failure set surfaced in
  neighboring fixture-subprocess suites instead. Both sets verified
  pre-existing; the distribution is environment-dependent, recorded as
  such.
