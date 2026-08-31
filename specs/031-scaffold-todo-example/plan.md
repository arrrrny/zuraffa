# Implementation Plan: Scaffold Todo Example via CLI with Full Test Suite

**Branch**: `031-scaffold-todo-example` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/031-scaffold-todo-example/spec.md`
(seed: GitHub issue #225; structure reference: issue #219)

## Summary

Recreate the repository's `example/` todo app entirely through `zfa` CLI
commands, proving the CLI can produce a complete, compiling, fully tested
Clean Architecture app with zero hand-written domain or data layer code.
The workflow is: create the Flutter shell (`flutter create`, pubspec with
the path-dependent `zuraffa` package, Hive/zorphy codegen wiring), then
`zfa entity enum -n TodoPriority` and `zfa entity create -n Todo` with all
eight fields (`id:int`, `title:String`, `description:String`,
`isCompleted:bool`, `priority:TodoPriority`, `tags:List<String>`,
`createdAt:DateTime`, `completedAt:DateTime`), then
`zfa make Todo --preset=crud --methods=create,get,getList,update,delete,watch,watchList --test`
to generate the seven use cases plus repository, datasource, DI wiring, and
a test file per use case, then `zfa build` (build_runner) to emit zorphy
comparisons, Hive type adapters, and field indices. Only the presentation
layer (`main.dart`, `setup.dart`, `presentation/*`) is hand-written, per
spec User Story 4. The generated app must pass `flutter test` (all
generated use case tests) and report 0 errors / 0 warnings from
`flutter analyze`, with a flat layout under `example/lib/src/` matching the
hand-written reference from issue #219.

## Technical Context

**Language/Version**: Dart 3.13+ (installed toolchain: Dart 3.13.2 stable)
and Flutter 3.47+ (installed toolchain: Flutter 3.47.2 stable). The root
`zuraffa` package stays pure Dart; the example app is a Flutter package
that depends on it via `path: ../`.

**Primary Dependencies**: the `zfa` CLI from this repo (`dart run
bin/zfa.dart`, executables `zfa`/`zuraffa`); `zorphy`/`zorphy_annotation`
(published, resolved by `dart pub get` — no path overrides per repo policy);
`hive_ce` + `hive_ce_generator` for Hive type adapters;
`build_runner` for codegen; `mocktail` for generated test doubles;
`flutter_lints` for the example's analysis options.

**Storage**: `example/lib/src/data/cache/hive_setup.dart` +
`hive_setup.g.yaml` (Hive field indices emitted by the zuraffa build
pipeline, verified 1:1 against the Todo entity definition per US3).

**Testing**: generated use case tests run under `flutter test` inside
`example/` (the example is a Flutter package — the root repo's
`tools/run_tests_chunked.sh` fast-suite still runs untouched at the root to
prove no root regression, per repo policy of never running a single whole
`dart test`). Static analysis: `flutter analyze` inside `example/` (SC-003:
0 errors / 0 warnings) plus `dart analyze` at the repo root.

**Target Platform**: Flutter (iOS/Android shells for the example app; tests
and analysis run on the Linux host VM).

**Project Type**: example application scaffolded end-to-end by generator
commands; no changes to the root package's `lib/` are planned — any CLI gap
discovered during the scaffold (unclear error, missing file, bad import) is
reported per AGENTS.md STOP-ON-ROADBLOCK and fixed only if it blocks
SC-001..SC-005.

**Performance Goals**: the whole scaffold is a one-shot developer flow
(`flutter create` + ~4 `zfa` commands + 1 build); the only meaningful
budgets are the spec's: build_runner succeeds, suite passes, analyze clean.

**Constraints**: AGENTS.md hard rules — entities only via `zfa entity
create` (no hand-written entities), builds via the CLI's build pipeline,
fixed v5 generation paths (`lib/src/domain/entities`), no
`dependency_overrides` with `path:` entries in the root pubspec (already
removed upstream; the example's pubspec uses the published zorphy versions
resolved from pub.dev). Duplicate scaffolding must not corrupt state (spec
edge case: second run skips or warns, never silently corrupts).

**Scale/Scope**: one new top-level `example/` Flutter package
(~25 generated architecture files, ~7 generated test files, 5-6 hand-written
presentation files), spec-kit artifacts under
`specs/031-scaffold-todo-example/`, and no root-package source edits unless
a scaffold-blocking CLI bug forces one.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unfilled template — no ratified
gates to enforce. AGENTS.md constraints respected: no hand-created entities
(entity creation goes through `zfa entity create`/`zfa entity enum`), no
direct `build_runner` invocation outside `zfa build` in the agent flow, no
invented folder structures (v5 fixed layout matches the #219 reference), no
new root dependencies. The STOP-ON-ROADBLOCK rule is acknowledged: the
first unexpected CLI failure stops the work and is reported rather than
worked around silently.

## Post-Design Constitution Check

Re-checked after design: unchanged — the design adds a dependent example
package and runs the canonical v5 workflow (`entity create` → `make` →
`build`) exactly as AGENTS.md prescribes; no gate is violated.

## Project Structure

### Documentation (this feature)

```text
specs/031-scaffold-todo-example/
├── spec.md              # Draft spec (input — already present)
├── plan.md              # This file
├── tasks.md             # Dependency-ordered task list (MVP-first)
└── tdd/
    ├── test-list.md     # One behavior per line, traced to spec criteria
    ├── cycle-log.md     # Baseline + red/green evidence, append-only
    └── verification.md  # Test-first + mutation evidence (from tdd.verify)
```

### Source Code (repository root)

```text
example/                          # Flutter app, scaffolded by this feature
├── pubspec.yaml                  # zuraffa path dep + hive/zorphy codegen deps
├── analysis_options.yaml         # flutter_lints
├── build.yaml                    # codegen config for hive_ce/zorphy
├── .zfa.json                     # zfa project config for the example
├── lib/
│   ├── main.dart                 # hand-written (presentation boundary)
│   ├── setup.dart                # hand-written DI bootstrap over generated DI
│   └── src/
│       ├── domain/               # CLI-GENERATED (zero hand-written code)
│       │   ├── entities/
│       │   │   ├── enums/todo_priority.dart      # zfa entity enum
│       │   │   └── todo.dart + todo.zorphy.dart  # zfa entity create + build
│       │   ├── repositories/                     # zfa make --preset=crud
│       │   └── usecases/                         # 7 use cases + tests
│       ├── data/                 # CLI-GENERATED
│       │   ├── datasources/      # datasource + local/mock impl
│       │   ├── repositories/     # repository impl
│       │   └── cache/            # hive_setup.dart + hive_setup.g.yaml
│       └── presentation/         # hand-written (US4: page/controller/
│                                 # presenter/state over generated use cases)
└── test/
    └── src/domain/usecases/      # CLI-GENERATED: one test file per use case
                                  # (create/get/getList/update/delete/watch/
                                  # watchList — 2 tests each)
```

The layout above is the flat reference structure from issue #219
(`domain/`, `data/`, `presentation/` directly under `example/lib/src/`, no
deeper nesting than the layer/entity directories the generators emit).

## Technical Approach

### Phase A — Example shell (hand-written, mechanical)

1. `flutter create --platforms=ios,android --project-name example example`
   (org left default; the #219 reference shipped the same two platforms).
2. Trim to the reference shape: pubspec gets `zuraffa: path: ../`,
   `hive_ce`, dev deps `build_runner`, `hive_ce_generator`, `mocktail`,
   `flutter_lints`; `analysis_options.yaml` from the reference;
   `build.yaml` for codegen.
3. `flutter pub get` resolves everything from pub.dev (no path overrides
   beyond the intentional `../` zuraffa dependency).

### Phase B — Entity via CLI (US1.AC1, FR-001, FR-006, FR-007)

```bash
cd example
dart run ../bin/zfa.dart entity enum -n TodoPriority --value low,medium,high
dart run ../bin/zfa.dart entity create -n Todo \
  --field id:int --field title:String --field description:String \
  --field isCompleted:bool --field priority:TodoPriority \
  --field tags:List<String> --field createdAt:DateTime \
  --field completedAt:DateTime
```

Rationale: the type validator requires the enum to exist before the entity
references it (issue #296 guard), so `TodoPriority` is created first — the
CLI's documented remediation. `DateTime` and `List<String>` are resolved
primitives for the validator; Hive/zorphy handle their adapters and
comparisons (FR-007). All fields are non-nullable, matching the #219
reference entity; nullable-awareness is exercised by `completedAt`'s
semantic optionality at the use case layer rather than `?` syntax (the
reference entity declares it non-nullable too).

### Phase C — Use cases + data layer + tests via CLI (US1.AC2, FR-002..004)

```bash
dart run ../bin/zfa.dart make Todo \
  --preset=crud \
  --methods=create,get,getList,update,delete,watch,watchList \
  --id-field=id --id-field-type=int \
  --test
```

`--preset=crud` expands to `usecase,repository,datasource,di`; `--test`
adds the test plugin (one test file per use case, 2 tests each: success
delegation + failure propagation). If the datasource plugin emits only an
abstract surface, `--mock` supplies the mock datasource/data the #219
reference carried; any gap here is a STOP-ON-ROADBLOCK candidate.

### Phase D — Codegen (US1.AC3, FR-008, US3)

```bash
dart run ../bin/zfa.dart build
```

`zfa build` drives build_runner (`zorphy` comparisons/patch/field
descriptors, `hive_ce_generator` adapters) and the zuraffa build pipeline
emits `hive_setup.g.yaml` field indices. Verified 1:1 against the entity
definition (US3 acceptance scenarios).

### Phase E — Hand-written presentation (US4)

`main.dart`, `setup.dart` (registers generated use cases via get_it), and
`lib/src/presentation/{todo_controller,todo_page,todo_presenter,todo_state}.dart`
— importing ONLY generated architecture files, no domain/data logic.

### Phase F — Verification (SC-002..004)

- `flutter test` in `example/` → all generated tests pass (SC-002).
- `flutter analyze` in `example/` → 0 errors, 0 warnings (SC-003).
- Directory-tree comparison against the #219 reference → flat layout
  (SC-004).
- Root regression: `dart analyze` + `tools/run_tests_chunked.sh` at the
  repo root (the example is additive; the root suite must stay green).

## TDD Adaptation (how the loop applies to a scaffolding feature)

This feature's "unit under test" is the CLI scaffold itself; the tests the
loop maintains are the generated use case tests plus the layout/artifact
assertions. The test list (`tdd/test-list.md`) binds each acceptance
scenario to its concrete verification (a `flutter test` file, an analyzer
run, or a structural assertion script). Red evidence = the state before the
scaffold step it demands (missing files / failing test run), recorded in
`cycle-log.md`; green = the post-scaffold run with real counts. Mutation
evidence for `tdd.verify` uses deliberate-mutant sampling (per
`.specify/memory/tdd-profile.md`: no mutation tool wired — e.g. temporarily
corrupting a generated use case delegation must turn its test red).

## Risks & Mitigations

- **CLI gaps while scaffolding** (the whole point of the issue): STOP at
  the first unexpected failure per AGENTS.md; fix only what blocks
  SC-001..SC-005, reporting each fix as `fix(031):` in the same PR.
- **Disk pressure on the disposable VM** (9.9 GB, ~6.7 GB free after the
  Flutter SDK): follow the standing housekeeping obligation — clean
  `build/`, `.dart_tool/` test kernels, and scratch fixtures after every
  phase; never a single whole-repo `dart test`.
- **zorphy/hive codegen drift vs the #219 reference**: the reference dates
  to zorphy v2.1; the published resolution may emit different file names.
  Parity is judged on the flat layout and 1:1 field indices, not byte-level
  equality.
- **Analyzer noise from generated code**: `flutter analyze` must end 0/0;
  generated-code suppressions (ignore comments) come from the CLI writers,
  not hand edits to generated files.
