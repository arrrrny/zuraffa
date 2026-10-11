# Spec 1322 — fix: phase-0 preflight ensures the builder package is in the dependency graph; the #276 safety net names the missing package instead of blaming globs

GitHub issue: arrrrny/zuraffa#1322 (severity high — one missing dev
dependency dead-ends the whole feature under three different outcome
labels, none naming the dependency)

## Problem

In a clean Dart package where `zorphy_annotation` is a direct dependency
but the `zorphy` builder package is NOT in the dependency graph (not even
transitively), `zfa tdd run <feature>` phase-0:

1. `zfa entity create StreamEvent` scaffolds a `@Zorphy(generateJson:
   true, …)` entity with part statements.
2. Scaffolds a `build.yaml` registering `zorphy:zorphy`.
3. Runs the build — build_runner warns `Ignoring options for unknown
   builder zorphy:zorphy`, silently generates nothing.
4. The zuraffa#276 safety net (`verifyOutputsOrFail`) FAILS: "build_runner
   wrote 0 outputs although @Zorphy sources exist" — with a remedy that
   says to fix `generate_for` globs.

The glob is ALREADY correct (`lib/src/**` + `test/**`). The real cause —
`zorphy` not resolvable in `.dart_tool/package_config.json` — is never
named. In projects like todo_planner the same setup works only because
`zorphy` arrives transitively, hiding the gap.

Downstream damage: every subsequent `make` re-runs `zfa build` for
certification, so the misdiagnosed failure keeps resurfacing under three
different outcome labels — `runner-error`, `green-with-failed-build`,
`generation-error` — none naming the dependency.

Workaround (verified): `dart pub add --dev zorphy`, then re-run the
driver; the build generates part files and the safety net passes.

Root cause: `zfa entity create` validates `zorphy_annotation` (the
annotation import) but never checks that the BUILDER package the
build.yaml registers is resolvable; the #276 safety net then blames the
only misconfiguration it knows (globs).

## Deliverables

1. **Phase-0 preflight in `zfa entity create` (AC-1).** Before writing
   the entity (and before the build.yaml the phase-0 build would
   scaffold), the create path MUST determine the effective builder set —
   the builders registered in the project's `build.yaml` UNION the
   canonical builder set `DependencyWirer.buildYamlContent` scaffolds
   when the file is missing — and check that each builder's PACKAGE is
   resolvable in `.dart_tool/package_config.json`. For every missing
   package it MUST run `dart pub add --dev <pkg>` automatically
   (Flutter projects: `flutter pub add --dev <pkg>`); when the add
   fails (offline, resolution conflict) it MUST refuse as a BLOCKING
   step — name the package, print the exact command, and exit non-zero
   without writing the entity. The auto-add is hermetic: process
   spawning injectable (the `PubspecProcessRunner` convention), and the
   `--dry-run` mode reports the would-add without spawning or writing.
2. **The #276 safety net distinguishes missing dependency from glob
   mismatch (AC-2).** `BuildCommand.verifyOutputsOrFail` — when
   `@Zorphy` sources exist but 0 outputs were written — MUST first
   diagnose the missing-builder-dependency class (effective builder set
   vs `.dart_tool/package_config.json`, corroborated by build_runner's
   `Ignoring options for unknown builder <key>` signal in the captured
   build output). When that class fires, the message MUST name the
   missing package, quote the build_runner signal, and prescribe the
   exact fix (`dart pub add --dev <pkg>`) — NOT the glob remedy. When
   the class does not fire, the current glob-remedy message is printed
   UNCHANGED.
3. **Build outcomes name the dependency (AC-3).** When a build fails
   because the builder package is missing, the outcome label and stop
   message MUST name the missing package and prescribe the exact fix —
   not the generic `runner-error` / `generation-error`. Because a
   NON-ZERO build exit can have many causes, the failure is attributed
   to the missing dependency only when the captured output LINKS the
   failure to the builder — build_runner's `Ignoring options for
   unknown builder <key>` signal, or the #276 safety-net marker the
   child `zfa build` prints when it fails through the new message —
   AND the static check names missing packages (the typo class can
   never be diagnosed as a missing dependency):
   - phase-0 (`RunDriverCore._runEntityPhaseZero`): a failed `zfa
     build` whose output classifies as missing-builder-dependency stops
     with the distinct result label `missing-builder-dependency`
     (verdict still `error` via `verdictForDriverResult` — the
     green|red|error vocabulary is unchanged), `stopped_at=phase-0:build`,
     and a message naming the package + the exact fix.
   - make (`zfa tdd make`): a failed plan `build` step whose output
     classifies as missing-builder-dependency is graded
     `MakeOutcome.missingBuilderDependency` (`outcome=missing-builder-
     dependency` in the machine summary line — NOT `generation-error`),
     with the message naming the package + the exact fix. Exit 1, no
     green entry (same honesty class as `generation-error`).
4. **Generic, not hardcoded zorphy (AC-4a).** The check works for ANY
   builder registered in build.yaml: the missing set is computed per
   builder key (`<package>:<builder>` → `<package>`; a bare key is its
   own package) and every missing package is named with its own
   `dart pub add --dev <pkg>` remedy. `zorphy` is never special-cased
   in the check logic.
5. **Backward compatibility (AC-4b).** Projects where every builder
   package is already resolvable — directly or transitively — continue
   to work unchanged: the preflight is a no-op (no spawn, no pubspec
   mutation), the safety-net message is byte-identical to today's, and
   every existing outcome label is preserved for every other failure
   class. An ABSENT `.dart_tool/package_config.json` is an UNVERIFIABLE
   state: the diagnosis never fires (no false positives on projects
   that simply have not run `pub get` yet — build_runner's own "run pub
   get" error is accurate there).
6. **Scope fence.** Fix ONLY entity scaffolding (the phase-0 preflight),
   the #276 safety-net message, and the build outcome labeling. The
   core engine cycle, the build_runner invocation (`_runBuild`), the
   zorphy code generation, and the verify gate are untouched.

## Success criteria (measurable)

- **SC-1** — Unit: the preflight service, given a resolved fixture
  project (package_config.json present, `zorphy` absent) whose effective
  builder set includes `zorphy:zorphy`, returns the missing package and
  — with an injected runner — spawns exactly
  `dart pub add --dev zorphy` in the project root and reports it added.
- **SC-2** — Unit: the preflight refuses as a blocking step when the
  add fails: `failed` names the package, the printed lines contain the
  exact `dart pub add --dev <pkg>` command and the pub error tail.
- **SC-3** — Unit: no-op when every builder package is resolvable (no
  spawn) and in dry-run (no spawn, would-add reported, pubspec
  byte-identical).
- **SC-4** — Unit: `verifyOutputsOrFail` with `@Zorphy` sources, 0
  outputs, and the missing-builder diagnosis fires → returns false and
  the printed message names `zorphy`, contains
  `dart pub add --dev zorphy`, contains the build_runner
  unknown-builder signal, and does NOT contain the `generate_for` glob
  remedy.
- **SC-5** — Unit: same fixture but every builder package resolvable
  (or package_config absent) → the CURRENT glob-remedy message
  (contains `generate_for` / `lib/src/**`), no `pub add` — the #276
  message is preserved for every other class (existing tests stay
  green, unmodified).
- **SC-6** — CLI tier: `zfa entity create` in a resolved project where
  `zorphy` is absent + failing injected add → non-zero exit, the entity
  file is NOT written, the blocking prescription names the package; and
  in a project where `zorphy` IS resolvable → entity created normally,
  pubspec byte-identical (no-op proof).
- **SC-7** — Driver tier: a scripted phase-0 build failure carrying the
  missing-builder signal stops the run with
  `result=missing-builder-dependency` (not `runner-error`),
  `stopped_at=phase-0:build`, and a stop message naming the package and
  prescribing `dart pub add --dev <pkg>`. A scripted GENERIC build
  failure (no signal, no marker) over the same missing-package state
  keeps `result=runner-error` (the existing U-991b contract, unmodified)
  — the static state alone never attributes an unrelated failure.
- **SC-8** — Unit: `MakeCommand`'s build-step failure classifier grades
  a failed `build` step carrying the signal (or the safety-net marker)
  as `missing-builder-dependency` (not `generation-error`); every other
  failed step, every unlinked build failure, and every other
  build-failure class keeps the existing outcome.
- **SC-9** — Generic proof: a fixture registering a non-zorphy builder
  (e.g. `some_other_pkg:its_builder`) with that package absent → the
  diagnosis names `some_other_pkg` and prescribes `dart pub add --dev
  some_other_pkg`.
- **SC-10** — `dart analyze` clean on every changed file; `dart format
  .` produces zero diffs; targeted suites green.

## Constraints

- Fix lives ONLY in: the new
  `lib/src/core/dependencies/builder_dependency_preflight.dart`
  (phase-0 preflight + shared classifier), `entity_command.dart`
  (preflight call site), `build_command.dart` (safety-net message +
  buildOutput pass-through), `run_driver_core.dart` (phase-0 build
  failure classification), `generation_plan.dart` (+1 enum value),
  `make_command.dart` (build-step failure classification). No engine,
  build_runner invocation, zorphy codegen, or verify-gate changes.
- `.specify/` templates/scripts untouched; spec number 1322 taken as
  the next free issue-derived number under `specs/`.
- One PR per issue; commits follow Conventional Commits (`fix(1322):`).
