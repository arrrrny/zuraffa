# ZFA TDD Cycle — External Agent Guideline

This guide takes an external agent from **zero** to a **completed zfa TDD cycle**
(red → green → receipts) on a real project — pure-Dart engine and Flutter skin —
using only `zfa` commands plus the project's normal test runner.

Verified against zfa build `d23bde35` (2026-09-08). Check your binary first
(Step 1): older builds hit the bugs catalogued under "Known sharp edges".

---

## 0. The contract you are working under

- **The TDD cycle is spec-driven**: you author `specs/<feature>/spec.md`, then
  `zfa tdd plan` derives one behavior per criterion, then `zfa tdd run` drives
  each behavior through gen → verify-red → make → refactor with evidence in
  `specs/<feature>/tdd/cycle-log.md`.
- **The engine/skin split is declared in the spec** (`## Lanes`, issue #1000):
  CORE = pure Dart, SKIN = Flutter, BOTH = shared seam. `zfa tdd run` runs the
  engine lane first, then gates the skin lane on a green engine receipt
  (spec 1008).
- **STOP-ON-MISFIRE RULE** (hard, from the zuraffa AGENTS.md contract): the
  FIRST time a `zfa` command errors or produces output other than expected,
  **stop immediately**. Report it as a zuraffa gap first — file an issue on
  `arrrrny/zuraffa` with command / expected / actual / root cause — then apply
  the **minimum workaround** needed to complete the spec cycle, and record the
  workaround in the report. Never silently route around a gap; a filed issue +
  documented workaround is the designed path. Never hand-write generated
  architecture code; the only sanctioned hand surface is the skin's declared
  hand-edit seam (spec 1005, `_XRaySkinHandEdit`).

---

## 1. Verify the zfa binary

```bash
which zfa && zfa --version
cat "$(which zfa).build_commit" 2>/dev/null || echo "no build stamp"
```

- Binary is normally at `~/.local/bin/zfa`. If it is stale, rebuild from the
  zuraffa repo:

```bash
cd ~/Developer/zuraffa && dart pub get --offline && dart compile exe bin/zfa.dart -o ~/.local/bin/zfa
git rev-parse HEAD > ~/.local/bin/zfa.build_commit
```

- Every `zfa tdd` subcommand accepts `--json` and emits a versioned verdict
  envelope (`zfa tdd verdicts` prints the schema). Script against the exit code
  and envelope, not stdout prose.

## 2. Project setup (scratch or existing)

### 2a. Fresh project

Pure Dart:
```bash
mkdir my_project && cd my_project
dart create --template=package .        # or: dart create --template=console .
```

Flutter (required for a SKIN lane):
```bash
flutter create --platforms=macos my_app && cd my_app
```

### 2b. Dependencies the cycle needs

Add to `pubspec.yaml` (phase-0 self-heals some of these, but declare them —
belt and braces):

```yaml
dependencies:
  zorphy_annotation: ^2.2.0
  json_annotation: ^4.12.0

dev_dependencies:
  test: ^1.25.0            # pure Dart; Flutter projects already have flutter_test
  mocktail: ^1.0.5
  build_runner: ^2.4.0
  json_serializable: ^6.7.0
  coverage: ^1.15.1
  mutation_test: ^1.8.0
  zorphy: ^2.3.1
```

Then `dart pub get --offline` (or `flutter pub get`).

### 2c. TDD baseline

```bash
zfa tdd init
```

Idempotent. Ensures `test/`, `dart_test.yaml` (slow-tier tags + integration
preset), and `.specify/memory/tdd-profile.md`. **Verify the profile picked the
right runner**: a Flutter project must have `runner: flutter_test` /
`suite: flutter test` in the Keys block; a Dart project `runner: dart` /
`dart test`. If it chose wrong, edit the Keys block — every driven step shells
out through these commands.

> **Flutter projects, until issue #1349 is fixed**: init generates
> `lib/app.dart` importing `zuraffa_flutter`/`get_it` without declaring them,
> and self-heals a plain `test` dev_dependency that conflicts with
> `flutter_test`. After init, add `zuraffa_flutter` + `get_it` to
> `dependencies`, delete the `test:` line init added under
> `dev_dependencies`, re-run `flutter pub get`, then confirm
> `flutter test` is green before planning.

## 3. Author the spec

Path: `specs/<feature>/spec.md` (lowercase directory; `<feature>` is the plain
directory name). Copy the shape below — every structural element is load-bearing.

```markdown
# Feature Specification: todo-app

**Template Version**: `zuraffa-1.0`
**Feature Branch**: `todo-app`
**Created**: 2026-09-08
**Status**: Draft
**Input**: "One-line plain-English description of the feature."

## Overview / Mission
What it is, one paragraph.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - <verb-led title> (Priority: P1)

<prose: actor, action, observable result. UI prose like "shows"/"displays"
is fine anywhere — the planner classifies by scenario structure, not buzzwords.>

**Why this priority**: ...
**Independent Test**: <how a skeptic proves this story alone>

**Acceptance Scenarios**:

1. **Given** <state>, **When** <action>, **Then** `<DomainClass.method>` <result>.
   **Type**: acceptance
2. ...

---

### Edge Cases
- <each edge case, phrased like a Then-clause>

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST <behavior> via `TodoList.addTodo` returning the id.
  traces: TodoList.addTodo
- **FR-002**: ... one FR per behavior, single logical line
  traces: TodoList.todos

### Key Entities *(include if feature involves data)*

| Entity | Fields |
| --- | --- |
| Todo | id: String, title: String, done: bool |

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1-A3, U1-U4]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1-W3]
    flutter_allowed: true
    adaptive_slots: [macos]
  - lane: BOTH
    behaviors: []
    flutter_allowed: conditionally
```

## Layer Contracts

**Domain**:
- `TodoList`: `addTodo(String title) -> String`, `toggle(String id) -> bool`, `todos() -> List<Todo>`
- `TodoSummary`: `render(List<Todo>) -> String`
```

### Spec rules that are enforced (not stylistic)

1. **`## Lanes` is required** on current builds — a spec without it is rejected.
   Omitting a spec-derived behavior from every lane refuses the plan (exit 2,
   naming the behavior and the declaration to add). **Edge cases count**: the
   `### Edge Cases` section derives acceptance behaviors just like scenarios,
   so size your ranges to cover them (author the spec, run plan once, and let
   the refusal name any behavior you missed — then widen the range).
2. **Acceptance scenarios derive behavior ids** (`A1`, `A2`, … in story order;
   `U1`, `U2`, … from FRs). Put `**Type**: acceptance` on every acceptance
   scenario line (the planner auto-migrates missing markers once, issue #1186 —
   but author them explicitly).
3. **`traces:` binds an FR to a code subject** — the line immediately after the
   FR. Use method-qualified traces (`TodoList.addTodo`) when one class carries
   several FRs; a bare-class trace over a multi-method row is refused (exit 2
   with the remedy — the planner will not guess).
4. **CORE lane purity is plan-enforced**: any CORE behavior whose row mentions
   `package:flutter` or whose kind is Flutter-only (widget/theme) refuses the
   plan (exit 2, `--> fix:` line, no artifacts written). Keep UI prose in
   scenarios; keep FR subjects pure-Dart classes.
5. **Contract params: prefer scalars** (`String`, `int`, `bool`, `double`,
   `List<...>`). `Object` now parses (`_scalarLiteral` covers it) but scalars
   keep the make path fully automatic.
6. **Entities table** needs exactly `| Entity | Fields |` headers; fields are
   `name: Type` comma-separated.
7. **FR bodies: one logical line.** Hard-wrap the markdown at the continuation
   indent (two spaces after the `- **FR-00N**:` bullet) — multi-line FR prose
   parses, but one-line FRs are the format every tool downstream is tested
   against.
8. **SKIN-only behaviors** that have no deriving scenario (e.g. `W1-W3` widget
   rows) are hand-declared lane rows — annotate them
   (`W1 (renders the todo list view)`) so the plan row carries a description.
9. Optional `## Skin Contract` block — required whenever you declare
   `adaptive_slots`. It must declare all four keys: `adaptive_slots`
   (must match the SKIN lane's), `platform_overrides`, `states`, `routes`.
   Unknown keys, duplicates, and slot/override drift refuse the plan naming the
   offending key. (Spec 1005; the skin conformance cycle rides this contract.)

## 4. Plan

```bash
zfa tdd plan todo-app
```

- Emits `specs/todo-app/tdd/04-ENGINE.md` (CORE + BOTH), `04-SKIN.md`
  (SKIN + BOTH + AdaptiveViewSlots), `04-CONTRACT.md` (the seam), and turns
  `tdd/test-list.md` into the lane meta-index.
- Sanity-check the split before running: `04-ENGINE.md` must contain **zero**
  `package:flutter` references; `04-SKIN.md` must list your `adaptive_slots`;
  every behavior id appears exactly once across the lane files.
- A plan refusal (exit 2) is a **spec-authoring error**, not a zfa bug: read the
  `--> fix:` line, fix the spec, re-plan. Nothing was written.

## 5. Run the cycle

```bash
zfa tdd run todo-app
```

- One command, two lanes: `run-engine` (gen → verify-red → make → refactor per
  behavior, writes `tdd/04-engine-receipt.json`) then `run-skin`, **gated on a
  green engine receipt** (a missing/red engine receipt makes run-skin exit 2
  naming `zfa tdd run-engine` as the remedy — this gate is by design).
- Resumable: state lives in `tdd/run-state.json`. If the run stops (honest red,
  timeout, crash), fix nothing by hand — re-run the same command; done
  behaviors are skipped.
- **Run at most one `zfa tdd run` at a time per machine.** Concurrent runs
  amplify a Dart kernel-cache race under `.dart_tool/test/` and can corrupt
  each other.
- You can also run the lanes deliberately:
  `zfa tdd run-engine todo-app` then `zfa tdd run-skin todo-app`.
- SKIN lanes with `adaptive_slots` run the hand-written conformance cycle
  (spec 1005): contract slots, red-before-green witness, and hand edits land
  under a `_XRaySkinHandEdit(behavior: "W1", file: ..., logged_at: ...)`
  annotation so the receipt can capture them. Hand-edit **only** inside that
  seam — never generated engine code.

## 6. Verify green

```bash
zfa tdd status todo-app        # one line: engine ✅ d/t | skin ✅ d/t | … ; exit 0 iff both green
zfa tdd prove todo-app         # zero ungated behaviors → exit 0 (runs nothing)
dart test                      # or: flutter test — the whole suite green
```

- `status` reads the two receipts; `prove` computes the re-prove delta from the
  unified journal (spec 1113). Both are the machine gates; the suite run is the
  human gate.
- Receipts: `tdd/04-engine-receipt.json`, `tdd/04-skin-receipt.json`
  (schema 1, `verdict: green|red|error`, behavior ids, counts, `stopped_at`).

## 7. When something misfires (the protocol)

1. **Stop.** Do not retry with different flags, `--force`, or hand patches.
2. **Capture**: the exact command, expected output, actual output, and — if you
   can trace it — the root cause in zuraffa source (`lib/src/plugins/tdd/…`).
3. **File** an issue on `arrrrny/zuraffa` with that detail.
4. **Work around minimally** to complete the current spec cycle (e.g. resume
   the run, re-plan after fixing your spec, restart the stopped lane) and
   record the workaround in your report/handoff.
5. The known-fixed sharp edges below are the usual suspects — check the binary
   build commit before suspecting your spec.

## Known sharp edges (fixed as of `d23bde35`)

| Symptom | Issue | Status |
| --- | --- | --- |
| Spec rejected for missing `## Lanes` | #1318 family | fixed |
| Multi-line FR bodies mis-parse | #1319 | fixed |
| Contract-row traces over multi-method rows accepted silently | #1320 | fixed — now exit 2 with remedy |
| `Object` contract param broke the make path | #1321 | fixed |
| Missing `zorphy` dev_dependency crashed phase 0 | #1322 | fixed — phase 0 self-heals; still declare it |
| Non-scalar param diagnosis | #1323 | fixed |
| Engine receipt written before journal entry → false red on resume | #1329 | fixed — on honest stop, resume with the same command |
| Skin receipt written before journal entry → same flake | #1333 | fixed |
| Planner fails to auto-migrate missing `**Type**: acceptance` | #1186 | fixed — one-time migration |
| `zfa tdd init` on a Flutter project generates `lib/app.dart` importing `zuraffa_flutter`/`get_it` without adding the deps, and self-heals a conflicting plain `test` dev_dependency — baseline is red out of the box | #1349 | **open** — workaround: add `zuraffa_flutter` + `get_it` to `dependencies`, remove the `test` dev_dependency init added, `flutter pub get` |

Cross-check evidence: `fix_verification_probe` spec runs 8/8 green in one
uninterrupted run on `d23bde35` (8 behaviors: A1–A4, U1–U4, CORE lane).

## Reference specs (in this repo)

- `specs/041-tdd-setup-plugin/spec.md` — the full TDD cycle contract
- `specs/1000-spec-template-core-skin-lanes/spec.md` — lane grammar, noFlutter guard
- `specs/1008-two-cycle-driver/spec.md` — run-engine/run-skin/run/status contracts
- `specs/1005-skin-hand-written-seam/spec.md` — the skin hand-edit seam
- `specs/1113-unified-tdd-journal/spec.md` — journal, prove, status
- `.specify/templates/spec-template.md` — the authoritative authoring template
