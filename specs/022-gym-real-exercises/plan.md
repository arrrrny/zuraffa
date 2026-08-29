# Implementation Plan: Build Real GYM Exercises for zuraffa, zorphy, zikzak_inappwebview, vendure-flutter-sdk

**Branch**: `022-gym-real-exercises` | **Date**: 2026-08-29 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/022-gym-real-exercises/spec.md`

## Summary

Stands up real-world GYM training exercises across the four core
packages we develop daily — zuraffa, zorphy, zikzak_inappwebview, and
vendure-flutter-sdk (issue #397). Each package gets a `.gym/` directory
with mandatory warmup reps (deps + build + one authenticated smoke
call) and at least one graded exercise representing a genuine dev
task (not a re-skinned unit test). Each `gym.yaml` is consumable by
the miki GYM runner without runner modifications; mis-fires emit
structured DROP CARDs (Did / Expected / Happened / Where); grading is
exit-code-based.

zuraffa already has a working `.gym/` (3 warmup reps + 2 graded
exercises); this feature adds **one new graded exercise** to zuraffa
and ships reference `.gym/` artifacts for the other three packages
under `examples/gym-templates/`. The reference templates are
copy-paste-ready: the maintainer of each target package lifts the
`.gym/` directory into their own repo unmodified.

The reference templates live in zuraffa because (a) we can only push
to zuraffa, and (b) the spec calls for a single PR delivering all
four packages' `.gym/` artifacts in one shot. Maintainers of zorphy,
zikzak_inappwebview, and vendure-flutter-sdk consume the templates
by copying the relevant `examples/gym-templates/<pkg>/.gym/` into
their own repo root.

## Technical Context

**Language/Version**: Dart 3.11+ (repo `sdk: ^3.11.0`); toolchain
Dart 3.13.2. Pure Dart under `lib/` — zuraffa itself never imports
Flutter (Constitution VII: Engine Purity). The reference exercises
for zikzak_inappwebview target a Flutter example app (the package's
own `example/`); the exercise code itself stays pure-Dart by spawning
`flutter` as a subprocess.

**Primary Dependencies**: zero new packages. Existing `test`, `path`,
`yaml`. The DROP CARD format is a plain text file written via
`dart:io`.

**Storage**: filesystem only — exercises write sandboxes under
`.gym/.sandbox/`; never mutate the package source tree (FR-005).

**Testing**: `test` (Dart standard); the TDD extension drives
red-green-refactor. Existing `test/plugins/gym/gym_plugin_test.dart`
and `test/commands/gym_command_test.dart` prove the GymPlugin still
emits the canonical gym.yaml shape — no regressions allowed (FR-008).

**Target Platform**: developer workstations; CI runs
`dart analyze && dart test` on Linux. The miki GYM runner is the
intended headless consumer (issue #397).

**Project Type**: library + CLI (existing zuraffa shape) + reference
template directories under `examples/gym-templates/`.

**Performance Goals**: each warmup rep < 60s on a warm cache; each
graded exercise < 5 min. No new performance-critical code.

**Constraints**: exercises MUST run in isolated sandboxes and MUST
NOT mutate source (FR-005); mis-fires MUST emit DROP CARDs with
Did/Expected/Happened/Where (FR-006); grading is exit-code-based
(FR-007); existing zuraffa `.gym/` exercises MUST stay valid (FR-008);
each `gym.yaml` MUST be consumable by miki without runner
modifications (FR-004).

**Scale/Scope**: one new graded exercise for zuraffa, three reference
`.gym/` directories under `examples/gym-templates/`, one shared
`DropCard` helper library, plus the spec-kit artifacts. ~10 new files;
~6 new tests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **VII Engine Purity**: all exercise code is pure-Dart — `lib/`
  imports stay Flutter-free. The zikzak_inappwebview reference
  exercise spawns `flutter` as a subprocess; it does not import
  Flutter.
- **I Single Source of Truth**: the `gym.yaml` artifact format is the
  authority the miki runner consumes; the GymPlugin already emits it
  (per-entity) and the package-level gym.yaml mirrors that shape.
- **IV Explicit Boundaries**: exercises declare their `setup`,
  `verifyCommand`, and `evaluate` explicitly — no implicit behavior.
- **VIII No Magic**: DROP CARDs are plain text with structured fields;
  no opaque IDs or hidden state.
- **No violations**; no complexity-tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/022-gym-real-exercises/
├── spec.md              # input (pre-existing draft)
├── plan.md              # this file
├── tasks.md             # /speckit-tasks output
└── tdd/
    ├── test-list.md     # /speckit-tdd-plan output
    └── verification.md  # /speckit-tdd-verify output
```

### Source Code (repository root)

```text
.gym/
├── gym.yaml                          # EXTENDED: +1 exercise entry
├── warmup/
│   ├── 01-deps.dart                  # existing — no change
│   ├── 02-build.dart                 # existing — no change
│   └── 03-smoke.dart                 # existing — no change
├── exercise-generate-feature.dart    # existing — no change
├── exercise-agent-rewrite-zfa-only.dart  # existing — no change
├── exercise-extend-zfa-cli.dart      # NEW graded exercise
└── lib/
    └── drop_card.dart                # NEW shared DROP CARD helper

examples/
└── gym-templates/                    # NEW: reference .gym/ for other packages
    ├── README.md                     # how to consume the templates
    ├── zorphy/
    │   └── .gym/
    │       ├── gym.yaml
    │       ├── warmup/
    │       │   ├── 01-deps.dart
    │       │   ├── 02-build.dart
    │       │   └── 03-smoke.dart
    │       └── exercise-store-mutation.dart
    ├── zikzak_inappwebview/
    │   └── .gym/
    │       ├── gym.yaml
    │       ├── warmup/
    │       │   ├── 01-deps.dart
    │       │   ├── 02-build.dart
    │       │   └── 03-smoke.dart
    │       └── exercise-js-bridge-roundtrip.dart
    └── vendure-flutter-sdk/
        └── .gym/
            ├── gym.yaml
            ├── warmup/
            │   ├── 01-deps.dart
            │   ├── 02-build.dart
            │   └── 03-smoke.dart
            └── exercise-fetch-product.dart

test/
└── plugins/gym/
    ├── extend_zfa_cli_exercise_test.dart     # NEW
    ├── drop_card_test.dart                   # NEW
    └── gym_templates_test.dart               # NEW
```

**Structure Decision**: zuraffa's own `.gym/` is extended in place
(matches the existing convention). Reference templates for the other
three packages live under `examples/gym-templates/<pkg>/.gym/` —
copy-paste-ready for each package's maintainer. A shared `DropCard`
helper lives under `.gym/lib/` so every exercise (zuraffa's new one
+ the three templates) emits DROP CARDs with the same shape.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations — table is empty by design.

## Key Design Decisions

### D1 — Reference templates under `examples/gym-templates/`

The spec calls for `.gym/` in each of the four packages, but this
PR can only target zuraffa. The resolution: ship the three
non-zuraffa packages' `.gym/` artifacts as **reference templates**
under `examples/gym-templates/`. Each template is a complete,
copy-paste-ready `.gym/` directory the package maintainer lifts into
their own repo root. This satisfies FR-001 (each package gets a
`.gym/`) in the only way possible within a single-repo PR.

### D2 — DROP CARD format

A DROP CARD is a plain-text file written to
`.gym/.sandbox/<exercise>/DROP_CARD.md` (or stdout if filesystem is
read-only). The format is fixed:

```text
# DROP CARD — <exercise-id>

**Did**: <one-line summary of what the exercise attempted>
**Expected**: <the expected outcome>
**Happened**: <the actual outcome>
**Where**: <file:line or stage identifier>

## Detail
<optional multi-line context>
```

The shared `DropCard` helper enforces the four required fields;
omitting any of them throws an `ArgumentError` at emission time
(FR-006).

### D3 — New zuraffa graded exercise: `extend-zfa-cli`

A genuine dev task: scaffold a new `zfa <name>` subcommand that
prints "hello from <name>" when invoked. The exercise:
1. Spawns `zfa` (the running binary) with `--help` to confirm it's
   on PATH.
2. Asserts the operator's submission (a Dart file under
   `.gym/.sandbox/extend-zfa-cli/lib/src/commands/hello_command.dart`)
   subclasses `Command<void>` and registers itself in a synthetic
   `CommandRunner`.
3. Spawns `dart` with the submission file and asserts stdout
   contains "hello from hello" when invoked with `hello` as the
   subcommand.

This is a real dev task — it exercises the same muscle as adding a
new CLI command to zuraffa itself, not a re-skinned unit test.

### D4 — zorphy reference exercise: `store-mutation`

Opens a Zorphy store, dispatches a mutation, asserts subscribers
received it. The exercise uses zorphy's public `Store` API (no
internal symbols). Warmup reps:
- `01-deps.dart`: `dart pub get` (assumes the consumer cloned
  zorphy and added it as a path dep).
- `02-build.dart`: `dart analyze` on the consumer app.
- `03-smoke.dart`: open a `Store<int>`, dispatch `setValue(42)`,
  assert subscriber fired.

### D5 — zikzak_inappwebview reference exercise: `js-bridge-roundtrip`

Boots the example app, evaluates JS in the bridge, asserts the
message round-trips. The exercise spawns
`flutter run -d <platform> --no-pub` against the package's
`example/` directory and pipes a JS expression to stdin. Warmup
reps mirror the pattern: deps, build, smoke (smoke = spawn the
example headlessly and assert it boots without error).

### D6 — vendure-flutter-sdk reference exercise: `fetch-product`

Initializes the client, fetches a product by id, asserts the
returned fields exist and are typed. The exercise hits the public
Vendure demo instance (`https://demo.vendure.io`). Warmup reps:
- `01-deps.dart`: `dart pub get`.
- `02-build.dart`: `dart analyze`.
- `03-smoke.dart`: HTTP GET to `https://demo.vendure.io/shop-api`
  — proves the demo is reachable before graded work begins.

### D7 — No regression to existing zuraffa exercises

The existing `generate-feature` and `agent-rewrite-zfa-only`
exercises are untouched. The new `extend-zfa-cli` exercise is
ADDED to `gym.yaml`'s `exercises:` list; existing entries stay
exactly as they are. The shared `DropCard` helper is a new file
under `.gym/lib/` — existing exercises do not import it (they have
their own inline DROP CARD logic) so they remain backward-
compatible.

## Phase 0 — Research (consolidated, no separate `research.md`)

- Confirmed: zuraffa's existing `.gym/gym.yaml` follows the
  canonical format the miki runner consumes (verified by reading
  the file and the GymPlugin emitter).
- Confirmed: zorphy exposes a public `Store<T>` API (per the
  package's pub.dev description); the exercise uses only public
  symbols.
- Confirmed: zikzak_inappwebview ships an `example/` directory
  that boots a Flutter app with a JS bridge — the exercise spawns
  it via `flutter run`.
- Confirmed: vendure-flutter-sdk exposes a `VendureClient` with a
  `getProduct(id)` method (per the package's pub.dev description);
  the demo instance at `https://demo.vendure.io` is publicly
  reachable.
- Confirmed: the existing `test/plugins/gym/gym_plugin_test.dart`
  pins the canonical gym.yaml shape — adding new entries must not
  break it.

## Phase 1 — Design (consolidated; contracts inlined above)

The DROP CARD format (D2), the new zuraffa exercise contract (D3),
and the three reference exercise contracts (D4, D5, D6) are the
design contracts. The "no regression" rule (D7) is enforced by
running the existing test suite + the existing exercises unchanged.

## Quickstart (validates SC-001 end-to-end)

```bash
# 1. zuraffa's existing exercises still pass (no regression — SC-003)
dart run .gym/warmup/01-deps.dart
dart run .gym/warmup/02-build.dart
dart run .gym/warmup/03-smoke.dart
dart run .gym/exercise-generate-feature.dart
dart run .gym/exercise-agent-rewrite-zfa-only.dart

# 2. zuraffa's NEW graded exercise passes
dart run .gym/exercise-extend-zfa-cli.dart

# 3. Each reference template's gym.yaml parses
for pkg in zorphy zikzak_inappwebview vendure-flutter-sdk; do
  cat examples/gym-templates/$pkg/.gym/gym.yaml | dart run -c 'void main() { /* yaml parse check */ }'
done

# 4. A mis-fire produces a DROP CARD (SC-004)
# (See test/plugins/gym/drop_card_test.dart for the structured assertion.)
```
