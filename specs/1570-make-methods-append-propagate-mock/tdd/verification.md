# Verification: 1570-make-methods-append-propagate-mock

Date: 2026-09-14 · Branch: `feat/1570-make-methods-append-propagate-mock`

## Method

Every number below is from a real `dart test` / `dart analyze` run in
this checkout against the real mock lane (and, for the E2E proof,
against the real CLI via `dart run zuraffa:zfa` in a scratch consumer
project). Nothing is asserted from reading code alone. The red→green
discipline: the five behavior tests were run and observed FAILING on
the pre-fix tree (cycle 1 RED evidence in `tdd/cycle-log.md`), the
implementation landed, and every suite below was re-run and observed
passing. Kernel cache cleaned before runs (`rm -rf .dart_tool/test/`).

This file was updated for the PR #1614 review round (pool task
`5bd7be01-2162-4fca-9176-ab22929c63e5`, cycle 3 of the cycle log): the
review found two shapes the repair emitted uncompilably, a
clobbering repair path, a dead contract, a duplicated primitive, a
typo, and U1/U2 coverage claimed but not in the PR. All eight were
resolved; the sections below mark what was (re)run in this round.

## Red evidence (pre-fix tree)

`dart test test/plugins/mock/mock_datasource_builder_1570_test.dart`
→ `+6 -5` — five behavior tests FAILED exactly as the issue predicts:

- A1 repair: `Expected: 'updated' Actual: 'skipped'` (the
  existence-based skip = the #1570 bug).
- A1 plugin entry: ledger empty (`the drifted mock must appear as
  repaired in the ledger`).
- A4 notice: no repair notice on stdout.
- A4 dry-run: `Expected: not 'skipped' Actual: 'skipped'`.
- U3 invented surface: mock stayed `Set:['get']` — `getList` never
  landed (`Missing concrete implementation` state).

The six unchanged-behavior guards (A2 in-sync skip, A3 fail-open ×3,
U4 revert/append/force ×3) passed pre-fix — they pin contracts the fix
must not move.

## Green evidence (post-fix)

| suite | result |
| --- | --- |
| `test/plugins/mock/mock_datasource_builder_1570_test.dart` (A1–A5, U1–U4, U6) | 16 passed |
| `test/plugins/mock/mock_datasource_builder_1570_compile_test.dart` (U2 compile bar, review round) | 2 passed |
| `test/plugins/mock/mock_certify_gate_test.dart` (A6/A7/U5/U6 incl. re-based A6) | 4 passed |
| `test/plugins/mock/` (full mock plugin suite) | 175 passed |
| `test/plugins/datasource/` + `test/plugins/method_append/` + `test/plugins/repository/` (untouched writers) | 132 passed |
| `test/commands/` (CLI surfaces incl. mock_command, make_command) | 401 passed at `30eefff9`; NOT re-run end-to-end in the review round (the run was killed by the runner timeout under machine load). The mock/make CLI path is covered by the certify-gate file, which drives the real `CliRunner` (A6/U5). |

`dart analyze` over `lib/src/plugins/mock/` + the changed test files:
**No issues found!** · `dart format --set-exit-if-changed lib test`:
**0 changed**.

## E2E proof (real CLI, scratch consumer project)

Reproduced the dogfood post-state exactly (older-project config: no
`method_append` plugin default; interface declaring `get, getList`;
certified mock implementing only `get`):

1. BEFORE: `error - scan_session_mock_datasource.dart:12:7 - Missing
   concrete implementation of 'ScanSessionDataSource.getList' -
   non_abstract_class_inherits_abstract_member` (the issue's verbatim
   error, same line/column).
2. `zfa mock create ScanSession --methods=get,getList` → `🔧 Shape
   drift detected: ScanSessionMockDataSource is missing getList
   declared by ScanSessionDataSource — repairing ... (issue #1570)`,
   ledger `📝` (updated).
3. AFTER: scoped analyze over the interface + mock pair → `No issues
   found!`
4. `zfa build` → `✅ Build completed successfully` (gate green).

## Review round (PR #1614 findings → fixes)

The review (24h earlier, commit `30eefff9`) verified the design working
for `get`/`getList` and found the repair emitting uncompilable code for
three other shapes the interface writer really emits. Fix map:

| finding | verdict |
| --- | --- |
| 🔴 stream bodies typed `Future<void>` → `Stream<void>` (`argument_type_not_assignable`) — drift synthesis AND custom-usecase branch | **fixed** — `Future<$returns>.delayed(...)` at both sites; U2 + the custom-usecase unit test |
| 🟠 always-required `params` → `invalid_override` for `dispose()`, `conflicting_method_and_field` for `Stream<bool> get isInitialized` | **fixed** — `parameterCount` + `isGetter` carried on `ParsedUseCaseInfo` from `MethodExtractor`; the repair mirrors the declaration |
| 🟡 verification docs claimed U1/U2 coverage not in the PR | **fixed** — U1 (detector exactness) + U2 (real-analyze compile bar) + A5 added; this file corrected |
| 🟡 certify-gate A6 vacuous (unconditional analyzer stub) | **fixed** — A6 re-based on signature-level drift + a state-conditional stub |
| 🔵 drift path re-emitted config members (clobbered customized bodies) | **fixed** — repair is strictly additive; A5 pins it |
| 🔵 dead `config` parameter + unreachable null contract in `_mockMethodImplForMissingMember` | **fixed** — parameter dropped; the null fallback is now real (non-`Stream<bool>` getters → certification gate's report) |
| 🔵 `_implementedMemberNames` scanned every class (scoped weaker than the detector) | **fixed** — one shared primitive `MockStalenessDetector.implementedMemberNamesIn`, used by both |
| 🔵 `pre-#1571` typo | **fixed** — `pre-#1570` |

### Review-round RED/GREEN (real scoped `dart analyze`)

RED (new compile test, pre-fix code): `dart analyze` over the repaired
pair reported 5 issues — `invalid_override` on
`dispose(NoParams params)`, `argument_type_not_assignable` ×3
(`Future<void>` stream bodies), `conflicting_method_and_field` on the
getter-as-method `isInitialized`. GREEN (same test, fixed code): the
analyze exits 0. The fixture is an engine-tier consumer package (path
dependency on this repo, real `dart pub get`); the test runs in the
default fast tier.

## Mutation evidence

Original cycle (cycle log 1):

| mutant | change | result |
| --- | --- | --- |
| M1 | detector returns `const []` (shape check disabled) | KILLED — 5 tests fail (A1×2, A4×2, U3): `+6 -5` |
| M2 | arm the check under `force` (drop `!options.force` conjunct) | KILLED — U4 force test fails: `+10 -1` |
| M3 | repair notice removed (`if (false && shapeDrift)`) | KILLED — A4 notice test fails: `+10 -1` |
| M4 | interface `isEmpty` early-return removed | EQUIVALENT — drift set is provably empty either way (empty interface members ⇒ empty missing set); guard retained as defensive clarity |
| M5 | mock-side fail-open dropped (`classNode == null` guard removed) | KILLED — new "mock class absent from its file" test fails (written after M4 exposed the coverage gap) |

Review round (cycle 3):

| mutant | change | result |
| --- | --- | --- |
| MR1 | revert the stream body to `Future<void>.delayed` | KILLED — U2 compile test `-2` (`argument_type_not_assignable` ×2) |
| MR2 | drop the additive-repair guard (re-emit existing members) | KILLED — A5 fails: `+15 -1` |
| MR3 | getter branch removed (getters synthesized as methods) | KILLED — U2 compile test `-2` (`conflicting_method_and_field`) |
| MR4 | `parameterCount == 0` branch removed (always emit `params`) | KILLED — U2 compile test `-2` (`invalid_override` on `dispose`) |

## Acceptance criteria coverage

| criterion (issue #1570) | verdict | proof |
| --- | --- | --- |
| 1. `make --methods=` propagates appended methods to the mock datasource | **PROVED** | A1 ×2 (builder lane + `MockPlugin.generate` entry, the `mock create` config shape); E2E step 2 |
| 2. The mock datasource compiles (no `non_abstract_class_inherits_abstract_member`) | **PROVED** | E2E steps 1→3; U2 compile test (real `dart analyze`, every writer shape) |
| 3. `zfa build` gate passes after `make --methods=` append | **PROVED** | E2E step 4: `✅ Build completed successfully` |
| 4. Shape-check staleness detection matches the tdd lane's stale-mirror comparison | **PROVED** | FR-003: detector uses the certification's own AST primitives (`MethodExtractor.extractMethodsFromInterface` + `AstHelper.findMethods`) — member-set comparison, no package resolution; U1 pins exact member-set semantics (in-sync + helpers → empty; missing → exactly one) |

## Scope guard (hard constraint)

`git diff` touches the mock lane, the shared member-shape carriers it
reads, and the feature's tests/specs:
`lib/src/plugins/mock/builders/mock_datasource_builder.dart`,
`lib/src/plugins/mock/services/mock_staleness_detector.dart`,
`lib/src/utils/method_extractor.dart` + `lib/src/models/parsed_usecase_info.dart`
(additive fields only — `parameterCount`/`isGetter`, defaults keep every
existing construction site behavior-identical; review-round finding 2
required carrying the declaration shape out of the extraction),
`test/plugins/mock/*`, `specs/1570-*/**`. The interface writer, the
real datasource writers, the repository writers, and the analyze/build
gate are untouched — their 132 suite stays green.

## Unrelated pre-existing failures

None observed in the executed suites. (Repo-wide `dart analyze`
carries 112 pre-existing `info` lints — unchanged by this branch.)

## Verdict

**PASS** — test-first evidence (5 recorded reds cycle 1, U2 RED with 5
real-analyzer errors cycle 3), mutation evidence (5 killed cycle 1 + 4
killed review round, 1 equivalent), acceptance criteria 1–4 PROVED, no
scope drift beyond the review-sanctioned extractor/model fields.
