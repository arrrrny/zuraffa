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
| `test/plugins/mock/mock_datasource_builder_1570_test.dart` (A1–A4, U2–U5) | 12 passed |
| `test/plugins/mock/mock_certify_gate_test.dart` (A6/A7/U5/U6 incl. updated U5) | 4 passed |
| `test/plugins/mock/` (full mock plugin suite) | 169 passed |
| `test/plugins/datasource/` + `test/plugins/method_append/` + `test/plugins/repository/` (untouched writers) | 132 passed |
| `test/commands/` (CLI surfaces incl. mock_command, make_command) | 401 passed |

`dart analyze` over `lib/src/plugins/mock/` + the two changed test
files: **No issues found!** · `dart format` (changed files): **0
changed**.

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

## Mutation evidence

| mutant | change | result |
| --- | --- | --- |
| M1 | detector returns `const []` (shape check disabled) | KILLED — 5 tests fail (A1×2, A4×2, U3): `+6 -5` |
| M2 | arm the check under `force` (drop `!options.force` conjunct) | KILLED — U4 force test fails: `+10 -1` |
| M3 | repair notice removed (`if (false && shapeDrift)`) | KILLED — A4 notice test fails: `+10 -1` |
| M4 | interface `isEmpty` early-return removed | EQUIVALENT — drift set is provably empty either way (empty interface members ⇒ empty missing set); guard retained as defensive clarity |
| M5 | mock-side fail-open dropped (`classNode == null` guard removed) | KILLED — new "mock class absent from its file" test fails (written after M4 exposed the coverage gap) |

M4 exposed a real gap during the audit: no test pinned the mock-side
fail-open. The mock-unparseable test was added (A3 family), turning
the load-bearing guard into a killed mutant (M5). Final suite count
includes it (12 behavior tests).

## Acceptance criteria coverage

| criterion (issue #1570) | verdict | proof |
| --- | --- | --- |
| 1. `make --methods=` propagates appended methods to the mock datasource | **PROVED** | A1 ×2 (builder lane + `MockPlugin.generate` entry, the `mock create` config shape); E2E step 2 |
| 2. The mock datasource compiles (no `non_abstract_class_inherits_abstract_member`) | **PROVED** | E2E steps 1→3: the verbatim error before, `No issues found!` after |
| 3. `zfa build` gate passes after `make --methods=` append | **PROVED** | E2E step 4: `✅ Build completed successfully` |
| 4. Shape-check staleness detection matches the tdd lane's stale-mirror comparison | **PROVED** | FR-003: detector uses the certification's own AST primitives (`MethodExtractor.extractMethodsFromInterface` + `AstHelper.findMethods`) — member-set comparison, no package resolution; U1 pins exact member-set semantics |

## Scope guard (hard constraint)

`git diff` touches ONLY the mock lane and its tests/specs:
`lib/src/plugins/mock/builders/mock_datasource_builder.dart`,
`lib/src/plugins/mock/services/mock_staleness_detector.dart` (new),
`test/plugins/mock/*`, `specs/1570-*/**`, `tool/` (none left), plus
the `.gitignore`-independent scratch-free tree. The interface writer,
the real datasource writers, the repository writers, and the
analyze/build gate are untouched — their 132 + 401 suites stay green.

## Unrelated pre-existing failures

None observed in the executed suites. (Repo-wide `dart analyze`
carries 112 pre-existing `info` lints — unchanged by this branch.)

## Verdict

**PASS** — test-first evidence (5 recorded reds), mutation evidence
(4 killed, 1 equivalent), acceptance criteria 1–4 PROVED, no scope
drift.
