**Template Version**: `zuraffa-1.0`

# Tasks: 1530-generated-code-fails-own-gate

Dependency-ordered, MVP-first. Every behavior task carries a
`[behavior: <id>]` marker and is MANDATORY (never skippable) — the test
must be written and certified red BEFORE its implementation task.

## Phase 1 — Foundational (barrel-surface verification vocabulary)

- [ ] T001 Update `lib/src/utils/zuraffa_barrel_exports.dart` —
      `filter()`: unresolved seed returns `const []` (FR-001, drops the
      combinator; removes the legacy keep-all fallback). Doc comment
      names #1530 (gate red on unverified hides) and preserves the
      #942/#1176 rationale for the seeded path.
- [ ] T002 Update `_collectFromBarrel` — combinator-aware collection
      (FR-002): parse `show`/`hide` on each export line; `show` lines
      contribute only shown names, `hide` lines subtract hidden names;
      unqualified lines keep the full top-level `class`/`mixin`/`enum`/
      `typedef` collection. `package:` targets stay skipped.
- [ ] T003 Update `_collectFromBarrel` recursion — resolve directory-
      relative export targets against the exporting barrel file's own
      directory (FR-003), keeping the depth guard (`depth > 3` cutoff,
      recursion below `depth < 2`).

## Phase 2 — Behavior: no unverified hides in generated output (US1)

- [ ] T004 [behavior: A-1530-1] RED first: in
      `test/utils/zuraffa_barrel_exports_test.dart`, replace the
      `unresolved → legacy unconditional hide` expectation with
      `unresolved → the hide combinator is dropped entirely`
      (`barrelHideNames('Product')` isEmpty with no seed). Certify RED
      (current keep-all fails it), then make GREEN via T001. This is the
      MVP slice: the dogfood `hide Task, TaskPatch` emission dies here.
- [ ] T005 [behavior: A-1530-2] RED first: fixture barrel exporting
      `QueryParams` only — `barrelHideNames('QueryParams')` keeps
      exactly `['QueryParams']` (already green; guards FR-010/the #942
      collision path against T001 regressions).
- [ ] T006 [behavior: A-1530-3] RED first: fixture barrel with
      `export 'a.dart' show Alpha;` + `export 'b.dart' hide Beta;` where
      `a.dart` declares `Alpha` AND `Extra`, `b.dart` declares `Beta` —
      assert `Alpha` verifies, `Extra` and `Beta` do not (FR-002).
- [ ] T007 [behavior: A-1530-4] RED first: nested barrel
      `src/core/params/index.dart` with directory-relative
      `export 'query_params.dart';` — `QueryParams` verifies (FR-003).
- [ ] T008 [behavior: U-1530-1] RED first: generated-output probe —
      hermetic target fixture with NO resolvable zuraffa entry, drive
      the datasource builder emission path (`EntityUtils.barrelHideNames`
      consumers via the datasource plugin generator) and assert the
      emitted `import 'package:zuraffa/zuraffa.dart';` carries NO
      `hide` combinator and the mock emission carries none on
      `package:zuraffa/mock.dart` (FR-004 end-to-end on the exact
      files from the issue).

## Phase 3 — Behavior: `package:zuraffa` dependency ensure (US2)

- [ ] T009 [behavior: A-1530-5] RED first: create
      `test/core/dependencies/pubspec_zuraffa_ensure_test.dart` —
      pubspec WITHOUT `zuraffa`: `ensure` adds `zuraffa: ^6.0.0` at the
      end of the `dependencies:` block (FR-005).
- [ ] T010 [behavior: A-1530-6] Idempotence: pubspec already declaring
      `zuraffa` under `dependencies:` → file byte-identical after
      `ensure` (FR-006).
- [ ] T011 [behavior: A-1530-7] Comment/format preservation: fixture
      pubspec with comments, blank lines, and entries after
      `dependencies:` → all preserved, insertion before the next
      top-level key (FR-006).
- [ ] T012 [behavior: A-1530-8] Refusals: inline `dependencies: {...}`
      → `UnsupportedError`; unparseable YAML → `FormatException`;
      `zuraffa` under `dependency_overrides:` only → still added under
      `dependencies:` (FR-005 edge contract).
- [ ] T013 [behavior: A-1530-9] No-foreign-imports no-op: run whose
      files import no `package:zuraffa/` URI → pubspec untouched
      (US2-5).
- [ ] T014 Implement `lib/src/core/dependencies/pubspec_zuraffa_ensure.dart`
      (T009-T012 green): `PubspecZuraffaEnsure.ensure(projectRoot)` —
      YAML-parse detection (read-only), textual patch, typed refusals,
      result naming what was added.
- [ ] T015 Wire the ensure into `lib/src/commands/make_command.dart`'s
      pubsync post-pass (FR-007): when the run's files import
      `package:zuraffa/` and `dependencies:` lacks it → ensure +
      completion receipt line; refusals degrade to the existing gap
      warning. Unit-test the wiring seam (ensure invoked iff a written
      file imports `package:zuraffa/`; existing `PubspecAutoAdd` arm
      untouched for other packages).
- [ ] T016 [behavior: A-1530-10] RED first: end-to-end make receipt —
      fake-zfa make run on a fixture whose files import
      `package:zuraffa/` with an offline-failing pub add: completion
      output names the ensured declaration (FR-007 receipt).

## Phase 4 — Behavior: green-with-failed-build receipt warnings (US3)

- [ ] T017 [behavior: A-1530-11] RED first: in
      `test/plugins/tdd/make_command_test.dart`'s bug-737 group, extend
      the tolerated-build fixture: the failing build step's output
      carries `warning -` lines → the receipt prints each line verbatim
      before `make: behavior=... outcome=green-with-failed-build`
      (FR-008; the existing gwfb assertion stays).
- [ ] T018 [behavior: A-1530-12] RED first: same fixture with NO
      `warning -` lines in the build output → receipt prints the
      explicit "no analyzer warnings reported" line (FR-008).
- [ ] T019 [behavior: A-1530-13] Guard: build output WITH `error -`
      lines keeps the #942 refusal (`generation-error`, no green
      evidence) — the receipt change never re-grades (FR-009; the
      existing bug-737 errors-not-tolerated test stays green, extend
      its assertions if needed).
- [ ] T020 Implement the warnings block in the tolerated path of
      `lib/src/plugins/tdd/commands/make_command.dart`: extract
      `warning -` lines from `failed.output` (#1407 regex shape), print
      verbatim capped at 10 + remainder, or the no-warnings line
      (T017/T018 green).

## Phase 5 — Non-behavioural (implement after behaviors certify)

- [ ] T021 Regression sweep: run the full
      `test/utils/zuraffa_barrel_exports_test.dart`,
      `test/utils/entity_utils_test.dart`,
      `test/core/dependencies/`, `test/plugins/tdd/make_command_test.dart`,
      `test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart` lanes;
      fix any expectation still encoding the legacy keep-all fallback.
- [ ] T022 Probe re-run: regenerate against the exploration fixture
      shape (target without resolvable zuraffa) — grep: no
      `hide Task, TaskPatch` anywhere; offline make run declares
      `zuraffa` textually; record evidence in
      `tdd/verification.md`.
- [ ] T023 `dart analyze` zero new warnings on all touched files;
      `dart format` clean; update `CHANGELOG.md` under the unreleased
      section naming #1530.
