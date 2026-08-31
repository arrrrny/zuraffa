# Verification: Scaffold Todo Example via CLI with Full Test Suite

**Feature**: `031-scaffold-todo-example` | **Audited**: 2026-09-01 | **Auditor**: the implementing session (cold-context audit per `/speckit.tdd.verify`)

**Verdict: VERIFIED (with 2 reported CLI gaps + 1 dropped edge behavior)** —
test-first evidence is real, all behaviors trace to the spec, the loop closed
green (example: 30/30; root: 2385/2385 with byte-identical baseline counts),
and both sampled mutants were killed.

## 1. Test-first audit

- The ENTIRE scaffold was asserted by `example/test/scaffold_contract_test.dart`
  BEFORE any `zfa` scaffold command ran. Cycle 1 records the observed red:
  `flutter test` → **1 passed / 15 failed** with the canonical
  missing-module failure messages (entity file, use case files, DI wiring,
  codegen artifacts, presentation files — none existed).
- Incremental reds were re-observed after each scaffold step advanced the
  frontier (3/13 → 7/9 → 13/3), every step's green is dated by its cycle
  entry, and the final green is **30 passed / 0 failed**.
- The generated use case tests (U4-U7) are the CLI's own TestBuilder output;
  their red state is the absence recorded in Cycle 1's inventory assertions
  plus the compile-blocked runs before `zfa build` emitted the part files.

## 2. Traceability audit

- 11 acceptance behaviors (A1-A11) — one per acceptance scenario in
  `spec.md` (US1: A1-A5, US2: A6-A7, US3: A8-A9, US4: A10-A11). All DONE,
  all traced.
- 10 unit behaviors (U1-U10): U1-U3 (entity/make/build contracts), U4-U7
  (the seven generated use case test files, 14 test cases), U8 (duplicate
  scaffold safety), U9 (codegen artifacts) — DONE. U2/U8 evidence comes from
  observed CLI runs recorded in `tdd/cycle-log.md`; U10 is **DROPPED** with
  the observed CLI behavior recorded (see §5).
- Every `traces` value resolves to a US.AC, FR, or Edge id in `spec.md`.

## 3. Success criteria

| Criterion | Verdict | Evidence |
| --- | --- | --- |
| SC-001 — complete app scaffolded via `zfa` CLI only, zero hand-written domain/data code | **PROVED** | The only hand-written Dart is `lib/main.dart`, `lib/setup.dart`, `lib/src/presentation/*` (US4 boundary, asserted by the A7 contract test: every `domain/`+`data/`+`cache/` file carries a generator marker). All architecture files are `zfa entity enum`, `zfa entity create`, `zfa make --preset=crud --test --mock`, `zfa cache adapter`, `zfa build` outputs. |
| SC-002 — `flutter test` exits 0 on a clean scaffold | **PROVED** | `flutter test` → **30 passed, 0 failed** (recorded in Cycle 5/6). |
| SC-003 — `flutter analyze` 0 errors, 0 warnings | **PROVED** | `flutter analyze` → "No issues found!" (0 errors, 0 warnings, 0 infos; 6.7s). `dart analyze` at root also clean. |
| SC-004 — directory structure matches the #219 reference (flat layout under `example/lib/src/`) | **PROVED, with one documented nuance** | Layering is flat: `domain/`, `data/`, `cache/`, `di/` (generated) and `presentation/` (hand-written) sit directly under `lib/src/`; the A6 contract test enforces a max nesting depth. Nuance: entity files live at `entities/<snake>/<snake>.dart` (one conventional level deeper than #219's flat `entities/todo.dart`) because zorphy 2.3.1 + zuraffa v5/v6 fixed layout + AGENTS.md all mandate it — flagged below, not hand-moved (that would violate the zfa-only contract). |
| SC-005 — generated app is a working example of the zfa workflow | **PROVED** | `zfa build` exits 0 with zorphy comparisons/patch (`todo.zorphy.dart`), json part (`todo.g.dart`), Hive adapter (`hive_registrar.g.dart`), and field-index yaml (`hive_registrar.g.yaml`) whose indices match the entity 1:1 (A8/A9). |

## 4. Mutation audit

No mutation tool is wired (per `.specify/memory/tdd-profile.md`), so
deliberate-mutant sampling was applied per the TDD rubric:

- Mutant 1 (`CreateTodoUseCase.execute` → `throw Exception("MUTANT")`):
  killed — its test failed (`1 passed / 1 failed`), suite restored to green
  after revert.
- Mutant 2 (`WatchTodoUseCase.execute` → `throw Exception("MUTANT")`):
  killed — its test failed; full suite restored to **30/0** after revert.

Both mutations targeted the delegation contract the generated tests exist to
pin; no surviving mutant was observed.

## 5. Found gaps (reported, NOT worked around)

1. **`zfa make --test` placeholder emits non-compiling code** — the test
   plugin's `_ensureNativeMockInfra` writes
   `class TodoMockDataSource implements TodoDataSource {}` with no import
   (`implements_non_class`) and `sampleTodo = null`
   (`avoid_init_to_null`). Additionally the mock generator skips existing
   files, so the placeholder cannot be repaired without `--force`.
   Root cause: `lib/src/plugins/test/test_plugin.dart`. The scaffold uses the
   documented `--mock` path + `--force`; a follow-up should make placeholders
   compile or stop emitting them when the real generators can run.
2. **`zfa build` on an empty project exits 0** — spec Edge-3 expects a clear
   failure naming missing artifacts; the CLI prints "wrote 0 outputs" and
   succeeds. U10 recorded this and is marked DROPPED. Suggested follow-up
   issue: fail-fast guard in the build pipeline.
3. **Zorphy-published writer emits `library enums;`** (unnecessary_library_name)
   in the enum barrel — external package (zorphy 2.3.1), suppressed in the
   example's analysis_options with a comment (the #219 reference used the
   same pattern for zorphy-generated issues).

All fixes this feature DID make to the root package are generator-template
fixes required to satisfy SC-002/SC-003 (test/mock/cache writers + the
pinned `emitsError` expectation in `test_builder_test.dart`); each is
covered by the existing plugin suites, which pass unchanged.

## 6. Root package impact

- `dart analyze` (root): "No issues found!"
- Chunked fast-suite protocol, post-feature: **2385 passed / 0 failed**
  across 60 chunk dirs — identical counts to the pre-feature baseline at
  `d4cf1d06`. The 5 tag-selector-empty chunk dirs (`test/benchmark`,
  `test/core/dependencies`, `test/integration`, `test/plugins/tdd/scenarios`,
  `test/property`) exhibit the same pre-existing "No tests match the
  requested tag selectors" quirk as at baseline; zero actual failures.
- Root source changes: `lib/src/plugins/mock/builders/mock_entity_helper.dart`,
  `lib/src/plugins/mock/builders/mock_value_builder.dart`,
  `lib/src/plugins/test/builders/test_builder_entity.dart`,
  `lib/src/plugins/cache/builders/cache_builder_registrar.dart`,
  `test/plugins/test_builder_test.dart` (expectation updated to the
  framework contract), `analysis_options.yaml` (exclude `example/**`,
  per the standalone-package precedent).

## 7. Deliverables

- `example/` — CLI-scaffolded Flutter todo app (entity + enum + 7 use cases
  + repository/datasource/DI + Hive registrar + field indices + 14 generated
  tests), hand-written presentation only.
- `specs/031-scaffold-todo-example/` — spec.md (draft input), plan.md,
  tasks.md, tdd/test-list.md, tdd/cycle-log.md, tdd/verification.md.
- Closes #225.
