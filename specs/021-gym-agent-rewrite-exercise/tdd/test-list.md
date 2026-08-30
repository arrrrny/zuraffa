---
feature: 021-gym-agent-rewrite-exercise
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4 # SC-001..SC-004 in spec.md; 12 story-level acceptance scenarios traced through the inner loop
planned_at: b2af3cb4
updated_at: post-implementation (all behaviors DONE)
suite_baseline: green # feature scope. Baselines at b2af3cb4: existing exercise `generate-feature` -> exit 0; `dart analyze` -> 111 issues, 23 pre-existing errors confined to the standalone `zikzak_session` package (now published on pub.dev) + examples/mcp_demo/; repo test suite untouched by this feature (no lib/ or test/ changes).
---

# Test List: GYM Exercise — Agent Rewrite of a Dart Package Using Only zfa

## Test surface note

The deliverable IS a graded test: `.gym/exercise-agent-rewrite-zfa-only.dart` runs
the trained protocol and grades itself by exit code (FR-007), consumed headless by
the miki GYM runner via `verifyCommand`. The TDD loop therefore drives the exercise
script outside-in: each behavior below is an assertion phase in the script, taken
red (assertion written and failing for the right reason — protocol step not yet
implemented) before the step that makes it green. The "test" column names the
script phase plus the observable it asserts.

## Outer loop: acceptance behaviors

One per success criterion in `spec.md`. Each stays red until the exercise works
end to end through its real entry point — `dart run .gym/exercise-agent-rewrite-zfa-only.dart`
(or the miki runner invoking its verifyCommand).

| id  | behavior                                                                                                                            | traces  | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------------------------------- | ------- | ------- | ------- | ---- |
| A1  | On a compatible sample package the exercise completes a zfa-only rewrite whose output compiles and matches the canonical v5 layout for every manifest entity | SC-001, US1-S1..S3 | example | DONE | `.gym/exercise-agent-rewrite-zfa-only.dart` leg A: doctor markers → entity create → make → build → v5 layout + compilation assertions |
| A2  | On a non-compatible package the exercise stops before any rewrite command and produces a structured report, and the run still grades pass (exit 0) | SC-002, US2-S1..S3 | example | DONE | `.gym/exercise-agent-rewrite-zfa-only.dart` leg B: not-compatible markers → STOP → `NOT-ZURAFFA-COMPATIBLE.md` sections + pristine lib/ + exit 0 |
| A3  | The exercise runs end-to-end headless (no manual intervention) and produces a deterministic grade and output structure across clean-sandbox runs | SC-003, US3-S1, US4-S2 | example | DONE | two consecutive clean-sandbox invocations → exit 0 both, identical file set |
| A4  | The exercise is discoverable in the GYM registry and listed with a clear brief describing what it trains | SC-004, US3-S2 | example | DONE | `.gym/gym.yaml` entry `agent-rewrite-zfa-only` has id/brief/setup/verifyCommand/evaluate; `generate-feature` entry unchanged |

## Inner loop: unit behaviors

Grouped by the exercise-script component from `plan.md` that owns them.

### Setup phase — sandbox + fixtures (`.gym/exercise-agent-rewrite-zfa-only.dart`)

| id  | behavior                                                                                                        | traces             | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------------- | ------------------ | ------- | ------- | ---- |
| U1  | Repo-root resolver walks up from cwd and finds `bin/zfa.dart` (the zfa entry the protocol drives)                 | FR-008, edge: zfa missing | example | DONE | script setup: `_zfaRoot` resolves; zfa bin path exists |
| U2  | Sandbox is created fresh under `.gym/.sandbox/exercise-agent-rewrite-zfa-only/` and the package source tree is never mutated | FR-006, US3-S1 | example | DONE | script setup: prior sandbox wiped; clean tree asserted by run on a clean checkout |
| U3  | Fixtures are copied in with the `__ZURAFFA_ROOT__` placeholder normalized, and `dart pub get` resolves in the compatible target | FR-003, edge: sandbox cannot access deps | example | DONE | script setup: pub get exit 0; on failure a clear setup error (not a grade) is reported |

### Compatibility detection (FR-002)

| id  | behavior                                                                                  | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U4  | `zfa doctor` on the compatible fixture surfaces `Zuraffa package found` + `zorphy_annotation found` | FR-002, US1-S1 | example | DONE | leg A step 1: marker assertions |
| U5  | `zfa doctor` on the plain fixture surfaces `Zuraffa package not found` + `zorphy_annotation not found` | FR-002, US2-S1 | example | DONE | leg B step 1: marker assertions |

### Rewrite leg — zfa-only protocol (FR-001, FR-004, FR-008)

| id  | behavior                                                                                                                     | traces             | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------------------------------------------------ | ------------------ | ------- | ------- | ---- |
| U6  | `zfa entity create -n <Name> --field ...` per manifest entity lands `lib/src/domain/entities/<snake>/<snake>.dart` with the declared fields | FR-001, FR-004, US1-S3 | example | DONE | leg A step 2: file + field assertions per entity |
| U7  | `zfa make <Name> datasource repository usecase` per entity lands repository, datasources, and usecases at the v5 paths          | FR-001, FR-004, US1-S3 | example | DONE | leg A step 3: canonical file set per entity |
| U8  | `zfa build` completes codegen (`.zorphy.dart` + `.g.dart` parts) and its embedded `dart analyze` reports no errors               | FR-004, US1-S2     | example | DONE | leg A step 4: parts exist + analyze-clean output |
| U9  | A missing canonical file fails the exercise with a named assertion message (no silent partial pass)                             | FR-004, edge: partial output | example | DONE | `_fail` path: message names the missing artifact |

### Stop-and-report leg (FR-005)

| id  | behavior                                                                                                                              | traces          | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------------------------------------- | --------------- | ------- | ------- | ---- |
| U10 | The structured report `NOT-ZURAFFA-COMPATIBLE.md` is written beside the target with package, verdict, why/evidence, and what-would-make-it-compatible sections | FR-005, US2-S2 | example | DONE | leg B step 2: report exists; all four sections present |
| U11 | No rewrite command fires on the non-compatible target: `lib/` stays pristine and no `lib/src/domain/entities/` tree appears              | FR-005, US2-S1 | example | DONE | leg B step 3: pristine-tree assertions |
| U12 | Grading is exit-code based: exit 0 when both legs behave correctly; exit 1 with `EXERCISE FAILED` when any assertion breaks             | FR-007, US3-S1 | example | DONE | full run exit codes for pass and forced-fail cases |

### Registry integration (FR-001)

| id  | behavior                                                                                                        | traces       | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------------------------- | ------------ | ------- | ------- | ---- |
| U13 | `.gym/gym.yaml` registers `agent-rewrite-zfa-only` with unique id, brief, setup, verifyCommand, evaluate keys      | FR-001, SC-004 | example | DONE | registry entry present, shape mirrors existing entry |
| U14 | The existing `generate-feature` exercise entry and warmup reps are untouched (no registry regression)              | FR-001, US3  | example | DONE | baseline run of `generate-feature` still exit 0 after registration |

## Invariants and edge cases still to place

- Setup failure (pub get fails, deps unreachable) must surface as a clear setup error, never a misleading FAIL grade — covered by U3's error path.
- Empty/blank target package (no entities yet) — the manifest-driven protocol defines entities before architecture generation (U6 before U7); a manifest with no entities would fail U6 with a named message.
- Non-zfa tool use during the rewrite (hand-writing Dart files) — the exercise's protocol invokes only zfa commands (U6–U8); hand-written output is graded against the zfa-generated structure (U6–U9 assert the canonical artifacts, which hand-writing would have to reproduce exactly).

## Out of scope

- Actually rewriting `zikzak_inappwebview` (issue #477) — explicitly excluded by spec assumptions; the exercise is scoped to completable package types.
- A `zfa` compatibility *fixer* (making non-compatible packages compatible) — spec assumption: stop-and-report is the fallback, no fixing.
- `test/` suite additions — the task boundary for this feature is `.gym/` + `specs/` only; the exercise script is the graded test surface.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time, adapted to this feature's surface (the exercise script):

- Exercise under test: `dart run .gym/exercise-agent-rewrite-zfa-only.dart`
- Existing-exercise regression: `dart run .gym/exercise-generate-feature.dart`
- Static analysis (repo, unchanged by feature): `dart analyze` — baseline 111 issues / 23 pre-existing errors (standalone `zikzak_session` package + examples/mcp_demo/), exit 3 at b2af3cb4
- Repo suite (no lib/test changes in this feature): `dart test` (slow; scoped sub-runs acceptable per profile)
