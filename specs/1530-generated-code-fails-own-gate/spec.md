**Template Version**: `zuraffa-1.0`

# Spec: 1530-generated-code-fails-own-gate

**Feature Branch**: `feat/1530-generated-code-fails-own-gate`

**Created**: 2026-09-13

**Status**: Draft

**Input**: `zfa build` on the dogfood todo app fails its own analyze gate on
zfa-generated code: generated datasource files emit `hide Task, TaskPatch` —
names not present in the import target (`undefined_hidden_name` x4) — and
import `package:zuraffa/...` while the target pubspec declares only
`zuraffa_flutter` / `zuraffa_ui` (`depend_on_referenced_packages`). The core
`zuraffa` package is never ensured. Every unit behavior's `make` recorded
`green-with-failed-build`: the suite certifies green while the build gate
stays red, and the receipt never shows the warnings that caused it.
Related: #942 (the hide mechanism's origin), #942 tolerance class, #1176
(seed-time filtering), #1407 (errors-only gate).

## Overview

The generator writes the `#942` barrel `hide` clause unconditionally when
the target project's zuraffa barrel cannot be resolved at seed time
(`ZuraffaBarrelExports.filter` falls back to keeping every name). A target
whose pubspec does not declare core `zuraffa` (a Flutter app declaring only
`zuraffa_flutter` / `zuraffa_ui`) has no resolvable barrel, so every
generated datasource/mock/provider file bakes in `hide <Entity>,
<Entity>Patch` for names the imported library never exports — each one an
`undefined_hidden_name` warning, and `zfa build`'s analyze gate fails on
warnings. The same missing declaration makes the generated
`package:zuraffa/...` imports fire `depend_on_referenced_packages`. The
only safety net for the declaration is the #1265 auto-add, which spawns a
network `pub add` and silently degrades to a printed warning when it
cannot run — so the declaration is never ENSURED. The TDD loop then
tolerates the failed terminal build step per #737/#942 and records
`green-with-failed-build` without surfacing the analyzer warnings, so the
drift is invisible per step.

This spec fixes the generator's own honesty: (1) the `hide` combinator is
emitted only with names verified present in the imported library, or
dropped entirely; (2) when generated files import `package:zuraffa/...`,
the `zuraffa` dependency is ensured in the target pubspec with the same
offline-safe textual discipline `zfa tdd init --skin` uses for
`zuraffa_ui`; (3) a `green-with-failed-build` make receipt prints the
analyze warnings verbatim so drift is visible per step.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Generated `hide` clauses only name real exports (Priority: P1)

A developer generates datasources/mocks/providers into a target project.
Every emitted `import 'package:zuraffa/...' hide ...;` clause names only
symbols the imported library verifiably exports; when nothing can be
verified (or nothing needs hiding) the combinator is dropped entirely, so
the generated tree stops failing `zfa build`'s analyze gate with
`undefined_hidden_name` warnings.

**Why this priority**: this is the direct producer of the 4x
`undefined_hidden_name` gate failures in the issue; without it the gate
stays red on zfa-generated code.

**Independent Test**: run `zfa make <Entity> datasource --with mock`
against a fixture target whose package config lacks a resolvable `zuraffa`
barrel, then grep the generated files: no `hide` clause may name a symbol
absent from the import target.

**Acceptance Scenarios**:

1. **Given** a fixture target project whose `.dart_tool/package_config.json` has no `zuraffa` entry (the dogfood state — the barrel cannot be resolved at seed time), **When** the user runs `zfa make Task datasource --with mock`, **Then** the generated files import `package:zuraffa/zuraffa.dart` and `package:zuraffa/mock.dart` with NO `hide` combinator at all — the unverified legacy hide is gone.
   **Type**: acceptance
2. **Given** a fixture target whose resolved zuraffa barrel exports `QueryParams` (and not `Product`/`ProductPatch`), **When** the user generates a `QueryParams`-shaped artifact, **Then** the emitted hide clause contains `QueryParams` (the #942 collision protection) and no other name.
   **Type**: acceptance
3. **Given** a resolved barrel whose export lines carry combinators (`export 'x.dart' show FailureReportQueue;` / `export 'y.dart' hide StateMigrator;`), **When** the barrel surface is collected, **Then** only shown names count as exported and hidden names count as absent — verification is against the library's real surface, not the target files' full declaration list.
   **Type**: acceptance
4. **Given** a generated artifact whose hide candidates are all verified exports (existing compiling output, e.g. an entity named `Credentials` colliding with the framework `Credentials`), **When** the same generation re-runs on the fixed generator, **Then** the hide clause is still emitted with the verified name — existing compiling generated code is not broken.
   **Type**: acceptance

---

### User Story 2 — `package:zuraffa` is ensured in the target pubspec (Priority: P2)

When a generation run writes files that import `package:zuraffa/...`, the
run ensures `zuraffa` is declared under the target pubspec's
`dependencies:` — offline-safe, idempotent, comment/formatting-preserving
(the `zfa tdd init --skin` textual patcher discipline for `zuraffa_ui`) —
so `depend_on_referenced_packages` cannot fire on zfa-generated imports,
network or no network.

**Why this priority**: the missing declaration is the second gate-red
class and the reason the seed keeps failing; the textual ensure removes
the network dependency the #1265 auto-add has.

**Independent Test**: run `zfa make Task datasource --with mock` in a
fixture target whose pubspec lacks `zuraffa`, offline (pub add cannot
run): the pubspec afterwards declares `zuraffa` under `dependencies:`,
hand-edits and comments preserved, and a re-run makes no further change.

**Acceptance Scenarios**:

1. **Given** a fixture target whose pubspec does not declare `zuraffa`, **When** a generation run writes files importing `package:zuraffa/zuraffa.dart`, **Then** the run adds `zuraffa: <constraint>` under the pubspec's `dependencies:` block (never `dev_dependencies:`) and reports the declaration on the completion receipt.
   **Type**: acceptance
2. **Given** the same target re-run (or a target already declaring `zuraffa`), **When** generation writes files importing `package:zuraffa/...`, **Then** the pubspec is left byte-identical (idempotent) and no duplicate entry appears.
   **Type**: acceptance
3. **Given** a pubspec with comments and hand formatting around the `dependencies:` block, **When** the ensure writes the declaration, **Then** every existing comment, blank line, and entry order is preserved (textual patch, not a YAML rewrite).
   **Type**: acceptance
4. **Given** a pubspec with an inline `dependencies: {...}` mapping (unsupported shape), **When** the ensure runs, **Then** it refuses loudly (no silent pubspec mangling) and the generation run surfaces the refusal while its own artifacts stay correct.
   **Type**: acceptance
5. **Given** files written by a run that import no `package:zuraffa/...` URI at all, **When** the run completes, **Then** the ensure does not touch the pubspec (no drive-by declarations).
   **Type**: acceptance

---

### User Story 3 — `green-with-failed-build` receipts surface the warnings (Priority: P3)

When a make tolerates a failed terminal build step (#737/#942) and records
`green-with-failed-build`, the receipt prints the analyzer warnings from
the failed build output verbatim — the tolerated class is never a quiet
default, so drift is visible per step in the transcript.

**Why this priority**: it makes the residual failure class observable;
it does not un-red the gate by itself, so it ships after the two fixes
that shrink the class.

**Independent Test**: drive `zfa tdd make` with a fake `zfa` bin whose
build step fails with analyzer `warning -` lines in its output while the
behavior's own test passes: the receipt contains each warning line
verbatim before the `make: behavior=... outcome=green-with-failed-build`
summary.

**Acceptance Scenarios**:

1. **Given** a tolerated terminal build failure whose output carries analyzer `warning -` lines, **When** make records `green-with-failed-build`, **Then** the receipt prints each warning line verbatim (a capped sample plus a remainder count when voluminous, mirroring the #1407 refusal logger).
   **Type**: acceptance
2. **Given** a tolerated terminal build failure whose output carries analyzer `error -` lines, **When** make grades it, **Then** the #942 refusal stands unchanged (errors are never tolerated into green) — this story changes receipt verbosity only, never the grading.
   **Type**: acceptance
3. **Given** a tolerated build failure with no `warning -` lines in its output, **When** make records `green-with-failed-build`, **Then** the receipt states that no analyzer warnings were reported (the build failed for another reason) — the step transcript stays self-explaining.
   **Type**: acceptance

---

### Edge Cases

- What happens when the barrel resolves but the seed walks a barrel whose nested `index.dart` uses directory-relative exports (`export 'query_params.dart';`)? The collector resolves relative targets against the exporting barrel's own directory (not lib-root), so names one level down are verified instead of silently dropped.
- What happens when the target pubspec declares `zuraffa` only under `dependency_overrides:`? An override is not a declaration (the #1190 contract) — the ensure still adds the `dependencies:` entry.
- What happens when the pubspec is unparseable YAML at ensure time? The ensure refuses loudly and the run keeps its existing gap-warning behavior — no silent pubspec rewrite.
- What happens when an entity is named like an SDK-provided package or the host package itself? Existing exclusion rules (`KnownTypes`, host-package exclusion in the scanner) apply before any hide emission; unchanged by this spec.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The barrel-export filter MUST return an EMPTY hide list when the zuraffa barrel surface is unresolved (no seed / no resolvable barrel), so generators emit the import with no `hide` combinator at all — the legacy unconditional hide fallback is removed.
            traces: BarrelExports
- **FR-002**: The barrel surface collector MUST honor export-line combinators when collecting exported names: a `show`-restricted export line contributes only the shown names, and a `hide`-carrying export line excludes the hidden names. Non-`show`-restricted, non-`hide`-carrying export lines keep contributing every top-level type declared in the target file.
            traces: BarrelExports
- **FR-003**: The barrel surface collector MUST resolve nested barrel export targets relative to the exporting barrel file's own directory (a directory-relative `export 'query_params.dart';` inside `src/core/params/index.dart` resolves inside `src/core/params/`), so one-level-down barrel names verify instead of silently dropping.
            traces: BarrelExports
- **FR-004**: All generator emission sites that attach a `hide` combinator to a framework-barrel import (datasource local/remote/interface, mock datasource, failing mock provider, provider, sqlite datasource, repository interface, usecase) MUST route their hide candidates through the (FR-001..FR-003) filter; a filtered-empty list emits the import without a combinator.
            traces: HideEmission
- **FR-005**: When a generation run writes files whose content imports any `package:zuraffa/...` URI, the run MUST ensure `zuraffa` is declared under the target pubspec's `dependencies:` with the standard constraint (`^6.0.0`, mirroring `DependencyWirer.standardSet`), using the offline-safe textual patch discipline (parse YAML for detection only; patch textually; refuse inline-mapping shapes loudly).
            traces: ZuraffaEnsure
- **FR-006**: The ensure MUST be idempotent (a pubspec already declaring `zuraffa` under `dependencies:` is left byte-identical) and MUST preserve comments, blank lines, and entry order; it MUST NOT require network (no spawned `pub add` for the declaration itself).
            traces: ZuraffaEnsure
- **FR-007**: The existing #1265 auto-add and #1190 gap-warning flows remain for every OTHER package the generated files import; the `zuraffa` declaration rides the same post-pass hook and its receipt line names what was declared.
            traces: ZuraffaEnsure
- **FR-008**: When make tolerates a failed terminal build step and records `green-with-failed-build`, the receipt MUST print the analyzer `warning -` lines from the failed step's output verbatim (capped sample + remainder count when voluminous, mirroring the #1407 `_logWarningsOnlyGateRefusal` style), or an explicit "no analyzer warnings reported" line when the output carries none.
            traces: MakeReceipt
- **FR-009**: The build gate itself, the analysis server, and the state machine MUST remain untouched: the #942 errors-never-tolerated refusal, the #737 per-behavior guard, the #1407 errors-only policy, and every existing outcome label (`green`, `skipped`, `green-with-failed-build`, `adopted`, `born-green`, `generation-error`, ...) keep their current semantics. This spec changes WHAT the generator emits and WHAT the receipt prints — never how the gate grades.
- **FR-010**: Generated code that compiled before this change MUST still compile: for a resolved barrel, verified hide names are emitted exactly as before (the #942 collision protection is preserved — `Credentials`-style entities still hide the framework export).

## Layer Contracts

**Function**:
- `BarrelExports`: `filter(hides) -> List<String>` — the seeded barrel-surface filter; unresolved seed → empty list (FR-001).
- `BarrelExports`: `seed(projectRoot) -> void` — collects the surface with combinator-aware, directory-relative resolution (FR-002, FR-003).
- `ZuraffaEnsure`: `ensure(projectRoot) -> EnsureResult` — textual, offline-safe `zuraffa` declaration ensure returning what was added (FR-005, FR-006).
- `MakeReceipt`: `printToleratedBuildWarnings(output) -> void` — verbatim analyzer-warning block for the tolerated-build receipt (FR-008).

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| TargetProject | `pubspec.yaml`, `.dart_tool/package_config.json` | The generation target whose declarations and resolution state drive both the seed and the ensure |
| GeneratedFile | `path`, `content`, `action` | Files a run wrote; their `package:zuraffa/` imports trigger the ensure (FR-005) |

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1-A12, U1-U4]
    flutter_allowed: false
```

Behavior-id derivation: A1-A4 are US1's scenarios (hide verification),
A5-A9 US2's (dependency ensure), A10-A12 US3's (receipt warnings); U1
routes FR-001..FR-004 (hide emission), U2 routes FR-005..FR-007
(dependency ensure), U3 routes FR-008 (receipt warnings), U4 routes
FR-010 (compiling-output preservation). FR-009 is a constraint, not a
behavior. This feature is pure-Dart generator/CLI behavior (the dogfood
app's gate is driven by the pure-Dart CLI); no widget surface is
exercised.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `zfa make Task datasource --with mock` against a fixture target with NO resolvable zuraffa barrel emits ZERO `hide` combinators naming symbols absent from the import target (grep-verifiable: no `hide Task, TaskPatch`) (AC US1-1).
- **SC-002**: With a resolved fixture barrel, the emitted hide list contains only names the barrel surface verifiably exports — including `show`/`hide` combinator handling and nested directory-relative barrels (AC US1-2, US1-3).
- **SC-003**: After a generation run whose files import `package:zuraffa/...`, the target pubspec declares `zuraffa` under `dependencies:` without any network call (the ensure is textual); a second run leaves the pubspec byte-identical (AC US2-1, US2-2).
- **SC-004**: A `green-with-failed-build` receipt contains the analyzer warning lines verbatim from the failed build output (or the explicit no-warnings line) (AC US3-1, US3-3).
- **SC-005**: The full existing test suite passes with no new `dart analyze` warnings on changed files, and every previously-compiling generated shape (verified hide emission, #942 collision case) is byte-preserved in the seeded path (AC US1-4, FR-010).

## Assumptions

- The dogfood todo app's exact pubspec shape (only `zuraffa_flutter` / `zuraffa_ui` declared) is behaviorally equivalent to a fixture target with no resolvable `zuraffa` barrel for the hide path; the fixture reproduces the emitted `hide Task, TaskPatch` byte-for-byte (verified during exploration).
- The standard constraint for the ensured declaration is `^6.0.0` — the same range `DependencyWirer.standardSet` wires for pure-Dart targets; no new version negotiation is introduced.
- Flutter SDK-dependent dogfood targets are out of scope for this repo's test matrix; the fix is host-agnostic (the hide emission and the pubspec patcher are pure Dart and exercised via fixtures).
- The generator keeps running when the target pubspec is absent/exotic (existing "not a target project" conventions); the ensure participates in those same degradations rather than introducing a new failure mode.
