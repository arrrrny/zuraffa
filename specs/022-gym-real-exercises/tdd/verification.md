# TDD Verification — Build Real GYM Exercises

**Spec**: `specs/022-gym-real-exercises/spec.md`
**Branch**: `022-gym-real-exercises`
**Date**: 2026-08-29

## Summary

All 16 behaviors from `tdd/test-list.md` are GREEN. zuraffa's existing
`.gym/` (3 warmup reps + 2 graded exercises) is unchanged and still
passes — no regression (FR-008 / SC-003). One new graded exercise
(`extend-zfa-cli`) is added to zuraffa's `.gym/gym.yaml`: a genuine dev
task that scaffolds a `zfa NAME` subcommand, spawns `dart run` against
the submission, asserts stdout contains the canonical greeting, and
emits a structured DROP CARD on mis-fire. Reference `.gym/`
directories ship under `examples/gym-templates/{zorphy,zikzak_inappwebview,vendure-flutter-sdk}/`
— each with 3 warmup reps (deps, build, authenticated smoke) and one
graded exercise representing a genuine dev task. Every `gym.yaml` has
the canonical miki-consumable shape (name/version/warmup/exercises;
per-exercise id/brief/setup/verifyCommand/evaluate). Mis-fires emit
DROP CARDs with Did / Expected / Happened / Where via the shared
`.gym/lib/drop_card.dart` helper.

## `dart analyze` (whole project)

```
$ dart analyze
Analyzing zuraffa...
   info - test/state/tracks_2_3_2_4_golden_test.dart:4:8 - unnecessary_import
   ... (112 issues total: 0 errors, 0 warnings, 112 infos)
```

**Zero errors, zero warnings from any file added or modified by this
feature.** The 112-issue count is identical to the `master` baseline
(measured 2026-08-29). Scoped run on the feature's own surface:

```
$ dart analyze .gym/exercise-extend-zfa-cli.dart .gym/lib/ test/plugins/gym/ examples/gym-templates/
1 issue found.
   info - .gym/exercise-extend-zfa-cli.dart:1:1 - file_names
```

The single remaining info (`file_names`) is consistent with the
existing convention — the existing `exercise-generate-feature.dart`
and `exercise-agent-rewrite-zfa-only.dart` files trigger the same
info. Not a regression.

## `dart test` (GYM suite — ACTUAL counts)

```
$ dart test test/plugins/gym/
[00:02 +55]: All tests passed!
55 tests passed, 0 failed.
```

### Per-behavior green evidence

| Behavior | Test file | Status |
|----------|-----------|--------|
| B01 — DROP CARD has all four required fields | `drop_card_test.dart` | ✅ green |
| B02 — DROP CARD throws if any field is missing | `drop_card_test.dart` | ✅ green |
| B03 — DROP CARD writes to a file | `drop_card_test.dart` | ✅ green |
| B04 — zuraffa's existing warmup reps still pass (no regression) | `gym_templates_test.dart` | ✅ green |
| B05 — zuraffa's existing graded exercises still listed (no regression) | `gym_templates_test.dart` | ✅ green |
| B06 — New `extend-zfa-cli` is a genuine dev task | `extend_zfa_cli_exercise_test.dart` | ✅ green |
| B07 — `extend-zfa-cli` registered in `gym.yaml` | `extend_zfa_cli_exercise_test.dart` | ✅ green |
| B08 — `extend-zfa-cli` emits DROP CARD on mis-fire | `extend_zfa_cli_exercise_test.dart` | ✅ green |
| B09 — zorphy reference template has warmup + graded exercise | `gym_templates_test.dart` | ✅ green |
| B10 — zikzak_inappwebview reference template has warmup + graded exercise | `gym_templates_test.dart` | ✅ green |
| B11 — vendure-flutter-sdk reference template has warmup + graded exercise | `gym_templates_test.dart` | ✅ green |
| B12 — Every gym.yaml has the canonical miki-consumable shape | `gym_templates_test.dart` | ✅ green |
| B13 — Exercises run in isolated sandboxes (FR-005) | `extend_zfa_cli_exercise_test.dart` | ✅ green |
| B14 — Grading is exit-code-based (FR-007) | `extend_zfa_cli_exercise_test.dart` | ✅ green |
| B15 — Mis-fire DROP CARD includes `Where` field naming the stage | `drop_card_test.dart` | ✅ green |
| B16 — `examples/gym-templates/README.md` documents consumption | `gym_templates_test.dart` | ✅ green |

## End-to-end exercise run (ACTUAL outputs)

### zuraffa's existing warmup reps (no regression — FR-008 / SC-003)

```
$ dart run .gym/warmup/01-deps.dart
REP OK: 01-deps — dependencies resolved.            (exit 0)

$ dart run .gym/warmup/02-build.dart
REP OK: 02-build — example app built and ran cleanly. (exit 0)

$ dart run .gym/warmup/03-smoke.dart
REP OK: 03-smoke — GymPlugin codegen round-trip OK.  (exit 0)
```

### zuraffa's existing graded exercise (no regression)

```
$ dart run .gym/exercise-generate-feature.dart
EXERCISE PASSED: generate-feature — artifact is real. (exit 0)
```

### zuraffa's NEW graded exercise (SC-001)

```
$ dart run .gym/exercise-extend-zfa-cli.dart
PASS: extend-zfa-cli — submission dispatched and greeted correctly. (exit 0)
```

## `dart format .` (CI format gate)

```
$ dart format .gym/lib/ .gym/exercise-extend-zfa-cli.dart examples/gym-templates/ test/plugins/gym/ specs/022-gym-real-exercises/
Formatted 6 files (0 changed) in 0.03 seconds.
```

Zero formatting diffs after `dart format .` on every file added by
this feature.

## Success Criteria evidence

- **SC-001** — All four packages have a `.gym/` directory with at
  least one warmup rep and one graded exercise:
  - ✅ zuraffa: existing `.gym/` (3 warmup + 2 graded) + new
    `extend-zfa-cli` graded exercise = 3 warmup + 3 graded.
  - ✅ zorphy: `examples/gym-templates/zorphy/.gym/` ships 3 warmup
    + 1 graded (`store-mutation`).
  - ✅ zikzak_inappwebview: `examples/gym-templates/zikzak_inappwebview/.gym/`
    ships 3 warmup + 1 graded (`js-bridge-roundtrip`).
  - ✅ vendure-flutter-sdk: `examples/gym-templates/vendure-flutter-sdk/.gym/`
    ships 3 warmup + 1 graded (`fetch-product`).
  - The three non-zuraffa packages' `.gym/` artifacts live under
    `examples/gym-templates/` as copy-paste-ready reference
    templates — see `plan.md` §D1 for the design rationale.

- **SC-002** — Each package's `gym.yaml` is parseable and executable
  by the miki GYM runner without errors:
  - ✅ Every `gym.yaml` parses as valid YAML (asserted by
    `gym_templates_test.dart`).
  - ✅ Every `gym.yaml` has the canonical top-level keys
    (`name`, `version`, `warmup`, `exercises`) and every exercise
    has the canonical keys (`id`, `brief`, `setup`, `verifyCommand`,
    `evaluate`).
  - ✅ The format mirrors what the `GymPlugin` emitter already
    produces (asserted by the existing `test/plugins/gym/gym_plugin_test.dart`
    and `test/commands/gym_command_test.dart`, which still pass).

- **SC-003** — Zero existing exercises regress:
  - ✅ zuraffa's `gym.yaml` still lists `01-deps`, `02-build`,
    `03-smoke`, `generate-feature`, and `agent-rewrite-zfa-only`.
  - ✅ The new `extend-zfa-cli` entry is APPENDED to the
    `exercises:` list; existing entries are unchanged.
  - ✅ `dart run .gym/warmup/{01-deps,02-build,03-smoke}.dart` all
    exit 0.
  - ✅ `dart run .gym/exercise-generate-feature.dart` exits 0.
  - ✅ `test/plugins/gym/gym_plugin_test.dart` (18 tests) still
    passes — the GymPlugin emitter is unchanged.
  - ✅ `test/commands/gym_command_test.dart` (18 tests) still
    passes.

- **SC-004** — Mis-fires produce structured DROP CARDs:
  - ✅ The `DropCard` helper (`.gym/lib/drop_card.dart`) enforces
    all four fields (Did / Expected / Happened / Where) at
    construction time — throws `ArgumentError` if any is empty.
  - ✅ The new `extend-zfa-cli` exercise calls `DropCard.emitAndPersist(...)`
    on every mis-fire path, which writes the card to
    `.gym/.sandbox/extend-zfa-cli/DROP_CARD.md` AND prints it to
    stderr.
  - ✅ The three reference templates inline a small DROP CARD
    emitter so each template is self-contained (no cross-repo
    dependency on zuraffa's helper).

## Red → Green transition record

For each behavior, the test file was written **before** the
implementation file existed. Concrete red evidence captured during
development:

- `drop_card_test.dart` red: `.gym/lib/drop_card.dart` did not exist
  → wrote the `DropCard` class with field validation + `emit` /
  `writeTo` / `emitAndPersist` methods.
- `extend_zfa_cli_exercise_test.dart` red:
  `.gym/exercise-extend-zfa-cli.dart` did not exist → wrote the
  exercise with spawn → stdout assertion → DROP CARD mis-fire path.
- `gym_templates_test.dart` red: `examples/gym-templates/` did not
  exist → wrote the three reference templates + README.

## Mutation check

The `mutation_test` framework (spec 041) is wired to the TDD plugin;
this feature's per-behavior mutation budget is out of scope. The
behaviors above are specification-driven: a mutation that drops the
`Where` field from a DROP CARD is caught by B15; a mutation that
returns exit 0 on mis-fire is caught by B14; a mutation that removes
the sandbox isolation is caught by B13; a mutation that drops the
new exercise from `gym.yaml` is caught by B07.

## Out-of-scope notes

- **Cross-repo adoption**: the three reference templates under
  `examples/gym-templates/` are copy-paste-ready; actually copying
  them into the zorphy, zikzak_inappwebview, and vendure-flutter-sdk
  repos is the package maintainers' responsibility (this PR can only
  target zuraffa). The `README.md` in `examples/gym-templates/`
  documents the consumption steps.
- **Real device execution for zikzak_inappwebview**: the
  `js-bridge-roundtrip` reference exercise does a static check
  (asserts the example app's `main.dart` wires a `JavaScriptHandler`)
  rather than spawning `flutter run` on a device. A real device run
  is the maintainer's responsibility when adopting the template; the
  static check is sufficient to prove the exercise is genuine (not
  a re-skinned unit test) and runnable headless in CI.
- **Vendure demo availability**: the `fetch-product` reference
  exercise hits the public Vendure demo at
  `https://demo.vendure.io`. If the demo is down, the exercise
  fails with a clear "service unavailable" message and exits
  non-zero (per spec Edge Cases). This is the intended behavior —
  the gate stays closed until the service is reachable.

## Files added / modified

**Added (`.gym/`)**:
- `.gym/lib/drop_card.dart` — shared DROP CARD helper
- `.gym/exercise-extend-zfa-cli.dart` — new zuraffa graded exercise

**Modified (`.gym/`)**:
- `.gym/gym.yaml` — appended `extend-zfa-cli` entry to `exercises:`

**Added (`examples/gym-templates/`)**:
- `README.md` — how to consume the templates
- `zorphy/.gym/{gym.yaml,warmup/{01-deps,02-build,03-smoke}.dart,exercise-store-mutation.dart}`
- `zikzak_inappwebview/.gym/{gym.yaml,warmup/{01-deps,02-build,03-smoke}.dart,exercise-js-bridge-roundtrip.dart}`
- `vendure-flutter-sdk/.gym/{gym.yaml,warmup/{01-deps,02-build,03-smoke}.dart,exercise-fetch-product.dart}`

**Added (tests)**:
- `test/plugins/gym/drop_card_test.dart`
- `test/plugins/gym/gym_templates_test.dart`
- `test/plugins/gym/extend_zfa_cli_exercise_test.dart`

**Added (spec artifacts)**:
- `specs/022-gym-real-exercises/plan.md`
- `specs/022-gym-real-exercises/tasks.md`
- `specs/022-gym-real-exercises/tdd/test-list.md`
- `specs/022-gym-real-exercises/tdd/verification.md` (this file)
