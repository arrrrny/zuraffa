# ZFA TDD Cycle — External Agent Guideline

This guide takes an external agent from **zero** to a **completed zfa TDD cycle**
(red → green → receipts) on a real project — pure-Dart engine and Flutter skin —
using only `zfa` commands plus the project's normal test runner.

Verified against zfa build `d23bde35` (2026-09-08); full Flutter engine+skin
cycle additionally verified on `583d711d` (2026-09-09, §5a evidence). Check
your binary first (Step 1): older builds hit the bugs catalogued under
"Known sharp edges".

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

## 5a. Expected hand steps (designed stops, not misfires)

A full cycle on a real Flutter app stops a few times by design. Each stop
names the file to edit. Edit only that file, then re-run `zfa tdd run
<feature>` — done behaviors are skipped.

1. **Unit hand step — vacuous-guard** (`U<n>:hand`, issue #1259/#1308).
   The func scaffold only auto-greens **primitive** contracts
   (`String`/`int`/`bool`/`double`/`void`). An entity-returning contract
   (`todos() -> List<Todo>`) scaffolds to an honest `UnimplementedError`
   throw, and `make` refuses a green earned by the guard-only assertion set.
   The run stops with:
   ```
   hand step: U4:hand — write an assertion on the observable outcome in
   test/tdd/<feature>/u4_test.dart (replace the vacuous-guard guard, remove
   the marker), then re-run `zfa tdd run <feature>`.
   ```
   **Do**: in the named test, keep the `UnimplementedError` capture block,
   add `expect(result, isA<List>());` (pin the declared return shape), and
   delete the marker comment — the detector keys on the literal
   `zfa:tdd: vacuous-guard` string, so the text must not survive even inside
   a replacement comment. Hand-implement the subject (a real domain model +
   a delegating `subject_u4()`), then re-run. `make` sees the target test
   already passing → records green via the drift-skip transition
   (issue #694/#1162).
2. **Widget hand step — scaffolded skin test** (`W<n>`, issues #912/#1258).
   A hand-declared `W` row whose description has no scenario prose
   (`description: skin behavior declared in ## Lanes`) generates a
   **scaffolded** widget test: placeholder finder
   `expect(find.byWidget(view), findsOneWidget);` with the
   `zfa:tdd: scaffolded` marker. The placeholder passes against the inert
   `SizedBox.shrink()` subject, so the run stops with `not-certified-red`
   (the run driver UX gap is issue #1373 — the message does not mention the
   author path; you are reading the author path here). **Do**, per behavior:
   ```bash
   # 1. author concrete finders (a plain .txt of Dart statements)
   zfa tdd make W1 --feature <f> --author --finders-file finders/w1.txt
   # 2. generation fails (expected — lane-only descriptions carry no
   #    scenario tokens); the subject restores to its inert shape
   # 3. hand-write the real view in the skin seam (a StatefulWidget next to
   #    the subjects) and point the subject at it:
   #    Widget subject_w1() => const MyFeatureView();
   # 4. record green through the pipeline (drift skip):
   zfa tdd make W1 --feature <f>
   ```
   Finder rules (hard gates, refusal restores the test byte-identical):
   - **Lead with `expect` presence assertions** (`find.text` /
     `find.byType` / `find.widgetWithText`). Interaction-first finders
     (`await tester.tap(...)` on a finder with no match) throw
     `StateError: Bad state: No element` → classified **runner-error** →
     authoring refused. The authored test must certify red via an
     *assertion* against the inert stub.
   - The finders file must contain ≥1 `expect(`/`expectLater(` and must not
     contain the scaffold marker string.
   - Interaction statements (`enterText`/`tap`/`pumpAndSettle`) are allowed
     after the leading expects — the block replaces the placeholder in place,
     inside the `testWidgets` body.
   - Authoring W2/W3: the test does not exist until the run generates it.
     Resume `zfa tdd run` first (it gens W2 and stops at `not-certified-red`),
     then run the `--author` make.
   - **Prevention**: annotate `W` rows with real scenario prose
     (`W1 (the empty list shows the input row and an empty-state message)`)
     so `gen` derives concrete finders and the author step is skipped.
3. **Skin lane dependency gate**: the first `W` gen refuses until
   `zuraffa_ui` is a direct dependency (the widget test boots a
   `ZuraffaApp` shell, issue #938). `flutter pub add zuraffa_ui`, re-run.
4. **`zfa tdd status` trailing counts** (`| 40 violations |`) are ui-ledger
   audit surfaces, not gates — `engine ✅ skin ✅` with exit 0 is the
   machine verdict.

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
| `zfa tdd gen` emitted `package:test` test imports on Flutter hosts, where the package cannot resolve (compile-error at verify-red) | #1351 | **fixed on branch `fix/1351-gen-flutter-test-import`** (binary build `510c4aa4`) — gen now detects Flutter hosts and emits `package:flutter_test` imports |
| `zfa tdd make`/`compose` refused not-certified-red when an older error section for the same behavior preceded the certified-red section in cycle-log.md — a resumed run with any earlier honest error was permanently blocked | #1353 | **fixed on branch `fix/1351-gen-flutter-test-import`** (binary build `583d711d`) — the check now scans all sections for any `kind: red` |
| `zfa tdd run` stops at a scaffolded widget behavior with a cryptic `not-certified-red` instead of handing off to the `--author --finders-file` flow | #1373 | **open** — workaround: the §5a step-2 author flow |
| `zfa tdd gen` on a fallback-routed SKIN FR (no `traces:` to a contract row) emits a guard-only unit test; `make` refuses it vacuous-green (issue #1259) and the run stops | #1402 family | **open** — workaround: hand-edit the generated `uN_test.dart` to add scenario assertions (see §8 gotcha 1), `verify-red`, hand-implement the subject, `make` |
| `zfa tdd gen` for SKIN widget behaviors (W ids) emits placeholder finders (`expect(find.byWidget(view), findsOneWidget)`) marked `zfa:tdd: scaffolded`; verify-red goes unexpected-green and make blocks | #1373 family | **open** — workaround: replace the placeholder assertions with concrete finders/registry assertions, `verify-red`, hand-implement the subject, `make` |
| FR body containing `|` (e.g. `<all|active|completed>`) breaks the pipe-table parser in test-list.md | [#1401](https://github.com/arrrrny/zuraffa/issues/1401) | **open** — workaround: write FR alternatives comma-separated in spec.md |
| `--plain-name` lookup in `make` silently exits 79 ("No tests ran") when a hand-edited test name doesn't embed the behavior description verbatim | [#1402](https://github.com/arrrrny/zuraffa/issues/1402) | **open** — workaround: embed the exact behavior description as the outer test name |

Cross-check evidence: `fix_verification_probe` spec runs 8/8 green in one
uninterrupted run on `d23bde35` (8 behaviors: A1–A4, U1–U4, CORE lane).
Full-cycle evidence: a Flutter macOS todo app (15 behaviors: 6 acceptance +
6 unit CORE lane, 3 widget SKIN lane) completed end-to-end from scratch on
binary build `583d711d` — every §5a hand step exercised, both receipts
green, `flutter test` 16/16, and the built `.app` live-tested on macOS
(2026-09-09).
Second full-cycle evidence (2026-09-09): the `xray-cli` spec (29 behaviors:
22 CORE + 7 SKIN) completed end-to-end from scratch — a pure-Dart engine
driving a live macOS Flutter app through an X-Ray bridge (GET /xray/tree +
POST /xray/action), all CRUD+search+filter commands exercised against the
running app via `bin/todo.dart`, visual state confirmed by screenshot. This
validated every workaround in this guide under §8.

## Authoring gotchas (spec-parser grammar, hit 2026-09-09)

These are not code bugs — the parser fails fast with a remedy, but the
grammar rules are stricter than the template suggests. All discovered
while authoring the `xray-cli` spec (CLI CRUD over the X-Ray bridge):

1. **Layer Contracts labels must be exactly `Domain`, `Data`,
   `Presentation`, or `Function`.** A label like
   `**Domain (engine, pure Dart)**:`
   parses for contract-behavior derivation but is dropped from the ROUTING
   table (spec_parser.dart `parseContractRows`), so every FR tracing to a
   row under that label refuses with `danglingReference`. Same for
   `**Skin**:`, which is not a known layer — Flutter-facing rows belong
   under `**Presentation**:`.
2. **Contract bullets are ` - `Name`: `sig` `` — a parenthetical between
   the name and the colon silently drops the row** (`TodoList` (extended):
   never routes). Method tokens in `traces:` are validated against the
   declared signatures, so a trace to `Foo.bar` requires `bar` to be a
   declared method of `Foo`.
3. **Lane `behaviors:` annotations cannot contain commas.**
   `W1 (mount view, sync state)` splits on the comma into two bogus hand
   rows (`W1 (mount view` + `sync state)`). Write annotations
   comma-free: `W1 (mount view and sync state)`.
4. **`Key Entities` rows route, `Key Entities` prose bullets do not** —
  entities must live in the pipe table (`| Entity | Fields |`).
5. **Anything external the FRs trace (e.g. `XRayBridgeServer.start`) must
   be declared in an `## External Dependencies & Contracts` table** with a
   `service` type — otherwise the trace dangles even though the symbol
   exists in a pub dependency.

## Reference specs (in this repo)

- `specs/041-tdd-setup-plugin/spec.md` — the full TDD cycle contract
- `specs/1000-spec-template-core-skin-lanes/spec.md` — lane grammar, noFlutter guard
- `specs/1008-two-cycle-driver/spec.md` — run-engine/run-skin/run/status contracts
- `specs/1005-skin-hand-written-seam/spec.md` — the skin hand-edit seam
- `specs/1113-unified-tdd-journal/spec.md` — journal, prove, status
- `.specify/templates/spec-template.md` — the authoritative authoring template

## 8. Skin-lane gotchas (hit 2026-09-09, `xray-cli` full cycle)

These were hit while completing a 29-behavior full cycle (22 CORE + 7 SKIN)
that ended in a live-tested macOS app driven by an external CLI through the
X-Ray bridge. None are blockers; each has a working workaround.

1. **Fallback-routed unit behaviors (U9–U11 in that spec) gen guard-only
   tests.** When an FR has no `traces:` the generator cannot derive an
   outcome assertion and emits only the `UnimplementedError` guard; `make`
   refuses it vacuous-green and the run stops. Fix by hand: rewrite
   `uN_test.dart` so the scenario description becomes real assertions over
   the subject's return value (e.g. assert the registry tree JSON), keep the
   behavior description string as the test name verbatim (the `--plain-name`
   matcher depends on it), then `verify-red` (expect `classification:
   assertion`), hand-implement the subject, `make`.
2. **Widget behaviors (W ids) gen placeholder finders.** The generated test
   ends with `expect(find.byWidget(view), findsOneWidget)` under a
   `zfa:tdd: scaffolded` marker — a bare stub passes it, so verify-red goes
   `unexpected-green` and `make` blocks with `not-certified-red`. Replace the
   placeholder with scenario-derived assertions (finders or registry
   checks), then run `verify-red Wn` explicitly (an already-green target
   skips red certification and make refuses), hand-implement the subject to
   return the real view, `make`.
3. **Subjects of every hand step return the subject value, not widgets
   only.** Unit subjects may return plain Dart values (`Map`, `List`,
   `Future<int?>`); the test just needs to assert on them. Widget subjects
   return the view builder.
4. **Registry state must merge, not overwrite.** If a global registry stores
   per-node state and a widget's build path re-registers the node with
   `state: null`, it will wipe dynamically-synced state. Merge with the
   existing entry: keep `existing?['state']` when the incoming state is
   null.
5. **Hot restart, not hot reload.** Changes in `main()` (e.g. starting a
   bridge server) need `R` in the `flutter run` pane; `r` re-runs only
   `build()`. Verify the server is up with `curl` before driving it.
6. **Drive the live app, then prove it visually.** The CLI mutates app state
   through the bridge; confirm the window actually renders the new state
   (`osascript` frontmost + `screencapture -x`, then read the image) —
   state JSON equality alone does not prove the UI.
