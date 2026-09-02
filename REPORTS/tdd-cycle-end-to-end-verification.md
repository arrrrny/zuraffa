# TDD Cycle End-to-End Verification Report

- **Date**: 2026-09-02
- **Verified at commit**: `14651299` (fix(741): tdd run caches full-suite baseline and skips on already-green behaviors, #746)
- **Toolchain**: Dart SDK 3.13.3 (stable), pure-Dart projects (no Flutter SDK), Linux x64
- **Scope**: `zfa setup` → `zfa tdd init` → `zfa tdd plan` → `zfa tdd run <feature>` driven end to end with the REAL pipeline (no fake zfa), twice: once for a bootstrap feature, once for a full todo application.

## Result: PASS

Both features completed the full red-green-refactor loop autonomously:

```
run: feature=001-app-bootstrap result=complete pending=0 red=0 green=0 done=8
run: feature=001-todo-app     result=complete pending=0 red=0 green=0 done=9
```

The todo application is committed as `examples/todo_tdd/` — `dart test`
(11 passing) and `dart run bin/todo_app.dart` both work from a fresh
`dart pub get`.

## Verification steps (as executed)

### 1. Setup and baseline

| Step | Command | Outcome |
| --- | --- | --- |
| Scaffold | `zfa setup todo_tdd --dart --no-git` | app created, `build.yaml` + domain dirs + `.zfa.json` written, zuraffa deps wired |
| TDD baseline | `zfa tdd init` | Dart profile written (`.specify/memory/tdd-profile.md`, `dart_test.yaml`, bootstrap smoke test, mocktail/coverage/mutation_test dev-deps) |
| Green baseline | `dart test` | 2/2 passing on day zero |

### 2. Specification and planning

`specs/001-todo-app/spec.md` was written with the SpecParser contract:
numbered `**Given**/**When**/**Then**` scenarios (one line) → acceptance
behaviors `A1..An`; `- **FR-xxx**: <description>` lines → unit behaviors
`U1..Un`. Notes for spec authors:

- the behavior description is the **Then-clause only**, and only text on
  the **same line** as `**Then**` is captured — multi-line Then-clauses are
  silently truncated;
- `zfa tdd plan` wrote 3 acceptance + 6 unit behaviors (9 total).

### 3. The run

`zfa tdd run 001-todo-app --project . --zfa-bin ~/.local/bin/zfa` drove every
behavior through `gen → verify-red → make → refactor` in list order
(acceptance outer loop, unit inner loop):

- every `verify-red` produced an **assertion-classified** certified red
  (honest red — no compile-error or load-error misfires);
- entity-path behaviors executed `entity create -n <Name>` → `tdd wire <id>
  --entity <Name>` → `build`; function-path behaviors executed
  `tdd func <id>` → `build`; each make finished with the target test green
  and the suite guard certified;
- **the #741 run-baseline cache worked as designed on resumed runs**: the
  baseline was captured once per run and every make reused it instead of
  re-running the full suite (the contract fixed for #750/#752);
- a mid-run kill (external timeout) was recovered by re-running the same
  command — `run-state.json` resume plus the #694 already-green skip
  transition behaved correctly (U6 resumed at `make`, found its target
  already green, took the skip transition, and the run completed);
- `dart test` after the run: **11/11 passing**; `dart analyze`: 0 errors,
  0 warnings (24 info-level style lints inside generated files only —
  subject naming, relative lib imports, nullable `Object?` capture).

## Findings

### F1. CRUD-keyword acceptance behaviors cannot reach green (generation-error)

- **Severity**: high (blocks the loop for a natural spec phrasing)
- **Evidence** (reproduced in a throwaway project, `zfa tdd make` output):
  `make: behavior=A1 outcome=generation-error feature=001-crud-probe`
- **Repro**: spec acceptance scenario with Then-clause *"the Todo repository
  service persists a todo item."* (entity exists), then
  `zfa tdd gen A1 && zfa tdd verify-red A1 && zfa tdd make A1`.
- **Root cause**: `GenerationPlanner.plan()` routes descriptions containing
  `crud` / `use case` / `repository` / `service` to
  `[make <slug> (+ --no-entity), build]`. The pipeline steps succeed, but
  nothing implements the behavior's acceptance subject
  (`lib/tdd/<id>_subject.dart` still throws `UnimplementedError`), so the
  post-generation target run stays red and make honestly stops with
  `generation-error`. The spec-052 composition fallback does not engage
  because the plan IS expressible; and even if it did, acceptance behaviors
  run before any unit behavior is green (list order), so no composable
  anchors exist in a single pass.
- **Suggested direction**: for acceptance-kind rows routed to the CRUD
  branch, append a subject-implementation step (e.g. `tdd wire <id> --entity
  <Name>` when the description names an entity that exists, else engage the
  composition fallback), or document CRUD-keyword acceptance prose as
  unsupported and stop at *plan* time with an actionable message instead of
  after a full build cycle.

### F2. `zfa entity add-field` corrupts empty-body entities

- **Severity**: high (produces invalid Dart from a standard CLI flow)
- **Repro**: create an entity without fields (the cycle's default:
  `zfa entity create -n Todo`), then
  `zfa entity add-field -n Todo --field id:String …`
- **Observed**: the field getters are prepended at byte 0 — ABOVE the file
  header, imports, and class declaration — and `build_runner` fails with
  `A function body must be provided` errors.
- **Root cause** (zorphy 2.3.1, `EntityCreator._insertFields`):
  ```dart
  final classPattern = RegExp(r'abstract class \$+' + className + r'\s*\{');
  final classMatch = classPattern.firstMatch(content);
  ...
  if (allMatches.isEmpty) {
    insertPosition = content.indexOf('{', classMatch.end) + 1;
  }
  ```
  The match already consumes the class's opening `{`, so `indexOf('{', …)`
  searches for a *second* brace. For an empty same-line body (`abstract
  class $Todo {}`) there is none: `indexOf` returns `-1` and
  `insertPosition` becomes `0`. Entities with existing multi-line fields
  take the `allMatches` branch and are unaffected.
- **Workaround**: apply the full schema with
  `zfa entity create -n Todo --field …` (template path — correct), which is
  what `examples/todo_tdd` does.

### F3. Cycle-generated entities are field-less by design

- **Severity**: medium (usability / expectation setting)
- The planner emits `entity create -n <Name>` with no `--field` flags, so
  the entity surfaces as an empty shell even when the behavior description
  reads *"create entity Todo with id, title, …"*. Prose-to-schema type
  inference would be speculative, so this is defensible minimal generation —
  but the driver output never tells the user the schema step is pending.
  A post-run hint (or spec-format support for typed field lists) would close
  the gap.

### F4. Behavior artifact paths are flat across features

- **Severity**: medium (multi-feature projects)
- `gen` writes `test/tdd/<id>_test.dart` / `lib/tdd/<id>_subject.dart`
  keyed on the behavior id only (`A1`, `U1`, … are auto-assigned per
  feature). Two features in one project therefore collide on `A1`, and the
  second `gen` fails with an ownership conflict
  (`test file … exists on disk but the registry has no recorded ownership`).
  Works today with one-feature-per-project or per-project sequencing; a
  feature-namespaced path (or per-feature subdirectory) would make
  multi-feature projects work.

### F5. Multi-line Then-clauses are silently truncated in `tdd plan`

- **Severity**: low
- `SpecParser._extractScenarioText` matches `\*\*Then\*\*\s*(.+)$` with
  `multiLine: true`, capturing only the same-line remainder. Wrapped
  scenario lines (natural in Markdown) produce truncated behavior
  descriptions — e.g. A1 planned as the literal description `create`. The
  plan command should either join the scenario block or warn on truncation.

## Positive observations

- The red classification (`verify-red`) is honest: it rejects compile-error
  and load-error reds and only certifies assertion failures.
- The #694 skip transition + `run-state.json` resume + #741 baseline cache
  compose correctly under an abrupt mid-run kill.
- `zfa setup --dart` + `zfa tdd init` give a genuinely green day-zero
  baseline without any Flutter dependency.
- The full run needs zero manual edits: every green flip came from
  generated code (`tdd func`, `tdd wire`, entity templates).

## Artifacts

- `examples/todo_tdd/` — the verified todo application (specs, cycle-log
  evidence, entities, subjects, tests, runnable `bin/todo_app.dart`).
