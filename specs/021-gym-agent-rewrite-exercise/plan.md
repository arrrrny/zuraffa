# Implementation Plan: GYM Exercise — Agent Rewrite of a Dart Package Using Only zfa

**Branch**: `021-gym-agent-rewrite-exercise` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

## Summary

Add one graded GYM exercise (`agent-rewrite-zfa-only`) to the package-level `.gym/gym.yaml` that trains an agent to rewrite a Zuraffa-compatible Dart package using **only `zfa` CLI commands**, and to **stop-and-report** (structured report, no rewrite attempt) when the target package is not Zuraffa-compatible. The exercise stages two embedded fixture packages into an isolated sandbox (`.gym/.sandbox/`), drives the canonical protocol on both legs — compatible rewrite via `zfa doctor` → `zfa entity create` → `zfa make` → `zfa build`, and non-compatible detection via `zfa doctor` → STOP → structured report — and grades on exit code (0 = pass, per FR-007).

## Technical Context

**Language/Version**: Dart 3.13 (SDK `^3.11.0`). Pure-Dart root package; the exercise and fixtures are pure Dart, no Flutter.

**Primary Dependencies**: existing `zfa` CLI (`bin/zfa.dart` — `doctor`, `entity create`, `make`, `build` subcommands), `zorphy_annotation`, `build_runner` (dev, inside the fixture), `package:path` (already a direct dep) for sandbox path handling. No new package dependencies.

**Storage**: N/A. The exercise's only state is its sandbox under `.gym/.sandbox/exercise-agent-rewrite-zfa-only/` (gitignored, wiped per run).

**Testing**: The exercise script is itself the graded test (exit-code based, FR-007). The TDD loop drives it red→green at the behavior level (see `tdd/test-list.md`); the repo suite (`dart test`) must stay unregressed since no `lib/` or `test/` files change.

**Target Platform**: Linux/macOS/Windows headless CI; the miki GYM runner (`gym.mjs`) consumes `.gym/gym.yaml`.

**Project Type**: GYM training artifacts inside a Dart CLI package. This feature modifies **only `.gym/` and `specs/`** — no `lib/` changes (spec assumption, FR boundary).

**Performance Goals**: Full exercise run (two legs: pub get + 2× entity create + 2× make + 1× build + 1× doctor + assertions) completes in < 5 minutes on CI hardware.

**Constraints**: FR-006 isolation (sandbox only, source tree never mutated); FR-008 zfa-only rewrite (setup may copy fixtures and run `dart pub get`); deterministic, repeatable output structure (US4-S2); `.gym/**` is excluded from the repo's `dart analyze` (analysis_options.yaml) and exercise sandboxes are gitignored.

**Scale/Scope**: One exercise registration, one graded exercise script (~450 lines), two fixture packages, one manifest.

## Constitution Check

PASS — `.specify/memory/constitution.md` is the unfilled template in this repo (no project-specific principles registered), so no gates apply. The feature aligns with the repo's established GYM conventions (issue #397 / #478 lineage): exercises are standalone `dart run` scripts graded by exit code, registered in `.gym/gym.yaml`, sandboxed under `.gym/.sandbox/`.

## Project Structure

### Documentation (this feature)

```text
specs/021-gym-agent-rewrite-exercise/
├── spec.md              # input (pre-existing draft)
├── plan.md              # this file
├── tasks.md             # /speckit.tasks output
└── tdd/
    ├── test-list.md     # graded behaviors + red/green evidence map
    ├── cycle-log.md     # per-cycle red-green-refactor record
    └── verification.md  # /speckit.tdd.verify audit
```

### GYM artifacts (repository root)

```text
.gym/
├── gym.yaml                                   # + exercise `agent-rewrite-zfa-only` entry
├── exercise-agent-rewrite-zfa-only.dart       # graded exercise (new)
├── fixtures/                                  # NEW — embedded, fixed sample targets (FR-003)
│   ├── sample-crud-package/                   # Zuraffa-COMPATIBLE target (rewrite leg)
│   │   ├── pubspec.yaml                       # zuraffa (path placeholder), zorphy, zorphy_annotation, dev:build_runner
│   │   ├── rewrite-manifest.json              # deterministic entity/field/plugin plan
│   │   └── lib/
│   │       ├── legacy_note.dart               # hand-written pre-v5 model (no imports)
│   │       └── legacy_tag.dart                # hand-written pre-v5 model (no imports)
│   └── plain-dart-package/                    # NON-compatible target (stop-and-report leg)
│       ├── pubspec.yaml                       # plain Dart deps, NO zuraffa/zorphy
│       └── lib/main.dart                      # trivial placeholder
└── .sandbox/                                  # gitignored, wiped per run (FR-006)
```

**Structure Decision**: Follows the existing package-level `.gym/` layout from #397 exactly (mirrors `exercise-generate-feature.dart` + `gym.yaml` shape consumed by the miki runner). New `fixtures/` subtree keeps the sample targets explicit, versioned, and deterministic — satisfying FR-003/US4-S1 without network downloads.

## Compatibility-Detection Contract (FR-002)

Detection relies on existing Zuraffa markers surfaced by `zfa doctor` (spec assumption — no new markers invented):

| Target state | `zfa doctor` stdout markers (verified against master `b2af3cb4`) | Route |
|---|---|---|
| Compatible | `Zuraffa package found` AND `zorphy_annotation found` | rewrite leg (zfa-only) |
| Not compatible | `Zuraffa package not found` AND `zorphy_annotation not found` | stop-and-report leg |

Marker precedence is pubspec-driven (deps), consistent with the spec's marker list (`zorphy_annotation` / `.zfa.json` / `zuraffa` dependency). Doctor's exit code is 0 in both states — the signal is parsed from output, which the exercise asserts explicitly.

## Canonical zfa-Only Rewrite Protocol (FR-001, FR-004, FR-008)

For each entity declared in `rewrite-manifest.json` (fields lifted from the legacy model files):

1. `zfa entity create -n <Name> --field <name:type> ...` → `lib/src/domain/entities/<snake>/<snake>.dart`
2. `zfa make <Name> datasource repository usecase` → datasources, domain+data repositories, usecases in v5 layout
3. `zfa build` → build_runner codegen + embedded `dart analyze` on `lib/` (compilation proof, FR-004)

Verified end-to-end in a scratch sandbox on master: entity + make + build produce `No issues found!` from `dart analyze`. Only `zfa` commands touch the target; fixture copy and `dart pub get` run in the setup phase (permitted by FR-008).

## Stop-and-Report Protocol (FR-005, SC-002)

On a non-compatible target the protocol is: run `zfa doctor` → read markers → **stop before any rewrite command** → write `NOT-ZURAFFA-COMPATIBLE.md` next to the target with structured sections (package, verdict, why/evidence, what-would-make-it-compatible) → report to caller with exit 0 (correct behavior, FR-007). The exercise enforces the "no misfire" half by asserting the target's `lib/` tree stays pristine and no `lib/src/domain/entities/` tree appears.

## Complexity Tracking

No violations. No new dependencies, no `lib/` changes, one new exercise + fixtures reusing the established registry shape.
