# TDD Verification — SPEC 1420 (entity pipeline engages at gen for row-only entity traces)

**Feature:** 1420-entity-row-traced-unit-behavior
**Issue:** #1420
**Date:** 2026-09-16
**Method:** real `dart test` runs (fast tier chunked per `dart_test.yaml`'s
10GB-agent discipline; slow driver suites via `--preset=all <files>`). Every
number below is an ACTUAL recorded run on this branch.

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
