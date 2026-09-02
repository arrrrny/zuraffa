feature: tdd-widget-test-subject-kind (bugfix #830, branch mode)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: b6afda42
behaviors: 6
proven: 6
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 6
criteria_covered: 6
mutation_score: 100 # scope: changed branch, 3 deliberate mutants, all caught, all restored
mutants_survived: 0
suite: bug #830 17/17; tdd plugin dir 438; chunked fast suite 67 chunks, no new failures
---

# TDD Verification: #830 widget-test subject kind — UI specs cannot be built by pure-function subjects

**Verdict: PASS.** The decisive reason: the generated widget pair, executed
for real under `flutter test` on a temp Flutter project with the rebuilt
binary, failed first as an **assertion-shaped honest red** (`Expected: not
<Instance of 'UnimplementedError'>` caught by the pre-pump expect) and turned
**green** once the view-builder subject was implemented — green that measures
the UI, which the pre-fix plain-function/scenario-runner subjects could never
provide — with the whole fast suite showing zero new failures and three
deliberate mutants all caught.

Record source note: the on-repo records for this bug were not present at
`b6afda42` (no `.specify/bugs/tdd-widget-test-subject-kind/` exists on any
branch); the authoritative input was the GitHub issue body of
[arrrrny/zuraffa#830]("[TDD-120] Widget-test subject kind") — the quoted
requirements below are from that body.

## Root cause (from issue, confirmed in source)

`zfa tdd gen` could only emit two subject shapes. `BehaviorKind` was
`{acceptance, unit}` (`lib/src/plugins/tdd/models/behavior.dart:4`), and
`SubjectWriter._renderSubject` dispatched exactly those two: a unit stub
(`int $target() => throw UnimplementedError(...)`) or an acceptance
"scenario runner" (`void $target() => throw UnimplementedError(...)`) — both
plain-function subjects that assert nothing about any widget tree. The paired
`BehaviorTestWriter` test was a smoke-shaped `test()` lambda. For an
acceptance scenario like "the dashboard renders the brand theme", green on
that pair proved nothing about the UI: theme.of colors, presence of expected
widgets, and navigation outcomes were unmeasurable. The test-list reader
recognized only acceptance/unit kinds (section-header inference plus the
gen-legacy 6-column kind cell), so no spec-driven path could mark a behavior
UI-observable either.

## Remediation (issue points 1–5, mapped)

1. **New subject kind** — `BehaviorKind.widget`
   (`lib/src/plugins/tdd/models/behavior.dart`). `zfa tdd gen <id> --kind
   widget` overrides the test-list row's kind (args-level `allowed` list;
   unknown values are a usage error pre-write). Spec-driven marking:
   `SpecParser.isUiAcceptance` matches the issue's named acceptance prose
   ("renders brand theme", "sidebar on macOS", "bottom nav on iOS" —
   renders/sidebar/bottom nav/tab bar/app bar/app shell/theme/widget/
   navigate, word-bounded, case-insensitive) and marks such acceptance
   scenarios `widget`; `plan` renders them into a new `## Outer loop: widget
   behaviors` section; `TestListReader` maps that header AND a 6-column
   `widget` kind cell to the kind.
2. **Widget test emission** — `BehaviorTestWriter._renderWidgetTest` emits
   `testWidgets(...)` importing `flutter_test`, calls the subject's
   view-builder OUTSIDE the pump, and captures `UnimplementedError` into
   `expect(built, isNot(isA<UnimplementedError>()))` — so the stub-stage red
   is assertion-shaped, never an exception escaping the pump (which the
   classifier routes to runner-error). When green, the view is pumped inside
   `MaterialApp(home: Scaffold(body: view))` (Theme.of / Navigator /
   MediaQuery resolve) and asserted present via `find.byWidget(view)`.
3. **View-builder subject stub** — `SubjectWriter`'s widget branch emits a
   `Widget $target() => throw UnimplementedError(...)` page contract with
   `import 'package:flutter/material.dart'` and `// kind: widget` in the
   provenance header. Composition with the entity pipeline (`zfa make
   --with=vpc` view generation + wire) is issue #829's surface and is
   deliberately NOT touched here (minimal-change constraint; `make` keeps its
   existing honest-stop routing for acceptance prose).
4. **verify-red widget taxonomy** — `RedClassifier.classify` red side checks
   the assertion signature FIRST (honest red), then widget pump/build
   signatures (`EXCEPTION CAUGHT BY WIDGETS|RENDERING|FLUTTER TEST FRAMEWORK
   LIBRARY`, `The following <not-TestFailure> ... was thrown`,
   `pumpAndSettle timed out`) → runner-error. Pure-dart transcripts never
   carry the flutter-framework phrasing, so existing classifications are
   unchanged (all 30 pre-existing classifier tests pass untouched).
5. **Golden-file support** — `zfa tdd gen <id> --kind widget --golden`
   appends `expectLater(find.byWidget(view), matchesGoldenFile('goldens/
   <snake-id>.png'))` with the per-platform refresh command documented in the
   emitted header. `--golden` without widget kind is rejected pre-write
   (FR-002 pattern). Baselines are committed by the app project per platform
   via `flutter test --update-goldens` — proven working in the e2e below.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| B-830a: the reader accepts widget-kind rows (widget section header AND a 6-column `widget` kind cell) | PROVEN | reader tests written FIRST; run on base → failed: header inferred `acceptance`, 6-column row rejected `expected 4 columns … found 6`. Green after fix |
| B-830b: SpecParser marks UI-intent acceptance scenarios `widget`; non-UI scenarios stay `acceptance`; unit behaviors untouched | PROVEN | parser tests written FIRST; run on base → failed: `Expected: 'widget' / Actual: 'acceptance'` (both prose fixtures). Green after fix |
| B-830c: plan writes the widget section and lands UI rows in it; non-UI rows stay in the acceptance section | PROVEN | plan e2e tests written FIRST; run on base → failed: `does not contain '## Outer loop: widget behaviors'`. Green after fix |
| B-830d: `gen --kind widget` emits a widget pair (testWidgets + pre-pump honest-red capture + view-builder subject with material import and `// kind: widget` header); verdict JSON carries the kind | PROVEN | gen e2e test written FIRST; run on base → failed: `Could not find an option named "--kind"`. Green after fix; verdict `{"verdict":"created","kind":"widget"}` |
| B-830e: a spec-driven widget row emits the same pair without any flag; `--golden` appends the matchesGoldenFile hook; `--golden`/`--kind` misuse is rejected pre-write | PROVEN | gen e2e tests written FIRST; run on base → failed: `malformed test list — line 3 … found 6` (row rejected). Green after fix |
| B-830f: widget failure taxonomy — assertion mismatch stays honest red (real flutter_test shape), pump/build crash and pumpAndSettle timeout without an assertion signature are runner-error | PROVEN | classifier tests written FIRST (one idealized pin corrected by the e2e discovery, see Honest-red discovery); the real captured transcript is now a pinned fixture |

RED commands (before fix, recorded output):

```
dart test test/plugins/tdd/bug_830_widget_subject_kind_test.dart
00:00 +1 -12: Some tests failed.          # 12 defect failures, 4 pins green
Failing tests (exact shapes):
  reader: Expected: 'widget' / Actual: 'acceptance'
  reader: test-list.md line 7: expected 4 columns (id/behavior/traces/state), found 6
  parser: Expected: 'widget' / Actual: 'acceptance'
  plan:   Expected: contains '## Outer loop: widget behaviors' / does not contain
  gen:    Could not find an option named "--kind"
  gen:    malformed test list — line 3: expected 4 columns … found 6
  classifier: Expected: 'runner-error' / Actual: 'assertion'   (idealized pin, later corrected)
  (+2 more gen content failures, +2 parser layout failures)
```

GREEN (after fix):

```
dart test test/plugins/tdd/bug_830_widget_subject_kind_test.dart
00:00 +17: All tests passed!

dart test test/plugins/tdd
01:59 +438: All tests passed!
```

## Honest-red discovery (e2e against the REAL rebuilt binary)

`scripts/rebuild.sh` rebuilt `zfa` from the branch; on a temp Flutter project
(`flutter` + `flutter_test` sdk deps, `flutter pub get`):

1. `zfa tdd plan 080-ui-dashboard` on a spec whose AC-1 is "**Then** the
   dashboard renders the brand theme." → `wrote … with 0 acceptance + 1
   widget + 1 unit behaviors (2 total)`; A1 lands in the widget section.
2. `zfa tdd gen A1` → pair emitted (`test/tdd/a1_test.dart` +
   `lib/tdd/a1_subject.dart`), verdict JSON
   `{"command":"gen","behavior":"A1","verdict":"created","kind":"widget"}`.
3. `flutter test test/tdd/a1_test.dart` → **honest red, assertion-shaped**:
   `The following TestFailure was thrown running a test: Expected: not
   <Instance of 'UnimplementedError'> / Actual: UnimplementedError:
   <UnimplementedError: subject_a1 not implemented>` — "This was caught by
   the test expectation on … line 37" (the expect BEFORE the pump, exactly
   as designed).
4. This REAL transcript exposed an idealization in the RED-phase classifier
   pin: flutter_test wraps EVERY test failure — assertion mismatches
   included — in the `EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK` banner and
   rethrows it as "The following TestFailure was thrown". The original
   precedence (pump signature before assertion) would have misrouted every
   real widget assertion failure to runner-error. Precedence corrected to
   assertion-first (honest-red-preserving); the idealized pin was replaced
   by the captured real-transcript fixture, which now pins the corrected
   contract. Execution evidence corrected an idealized fixture — the loop
   working as intended. Signature detail: the thrown-dump signature excludes
   `TestFailure` (`The following (?!TestFailure)\S+ was thrown`) so the
   banner never masks a genuine crash dump either.
5. Implemented the subject (`Widget subject_a1() => Builder(builder:
   (context) => ColoredBox(color: Theme.of(context).colorScheme.primary,
   …));`) → `flutter test` → `00:00 +1: All tests passed!` Green now
   measures the UI.
6. Golden workflow (fresh project copy): `zfa tdd gen A1 --golden` → verdict
   JSON carries `"golden":true`, emitted test carries
   `matchesGoldenFile('goldens/a1.png')` with the refresh command in the
   header; `flutter test --update-goldens test/tdd/a1_test.dart` → committed
   baseline `test/tdd/goldens/a1.png`; `flutter test` → `All tests passed!`

Two test-side corrections during RED, kept here for honesty: (a) the plan
test initially asserted the count line on the captured output, but `plan`
prints through `stdout.writeln` (outside the capturing zone) — the test now
asserts the file, which is the contract; (b) the UI signature initially
included `screen`, which broke the pre-existing pinned multiline-scenario
test ("they see the home screen", spec 041) — a false positive; the
signature was tightened before GREEN completed and that test passes
unchanged.

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | LOW | The UI-intent signature is prose-heuristic by design: a UI scenario phrased with none of the pinned words is NOT auto-marked widget. The explicit `zfa tdd gen <id> --kind widget` override is the sanctioned escape hatch, and the signature deliberately rejects generic display verbs ("shows", "displays", "screen") that CLI specs carry (breaking the spec-041 pin proved the point) | spec_parser.dart `uiAcceptanceIntent` + e2e golden/`--kind` runs |
| 2 | LOW | `make` on a widget-kind acceptance behavior keeps its pre-existing honest-stop routing (unexpressible reason or composition fallback); the entity-pipeline composition that would flip it green is issue #829's surface, out of scope under the minimal-change constraint | generation_planner.dart untouched; issue #830 point 3 |

No `HIGH` smells in the new tests: content-level assertions on emitted files
with the exact generated shapes, deterministic temp fixtures created in
`setUp` and removed in `tearDown`, existing `CliRunner(exitOnCompletion:
false)` conventions reused (no bypassed test utilities), classifier fixtures
anchored to a REAL captured transcript rather than a paraphrase, and the
widget-e2e evidence comes from executed `flutter test` runs, not simulated
output.

## Mutation results (deliberate mutants — no mutation tool in profile)

| Mutant | Change | Result | Judgment |
| --- | --- | --- | --- |
| A | `_kindFromCell`: drop the `widget` kind-cell branch | bug suite fails (spec-driven widget row rejected again) | CAUGHT; restored → 17/17 |
| B | `classify`: re-flip precedence (pump signature before assertion) | bug suite fails at the real-shape honest-red fixture | CAUGHT; restored → classifier suite 30/30 |
| C (weak) | remove only `widgets?\|navigat…` from the alternation | SURVIVED — fixtures still matched via `renders?`/`sidebar` | documented; motivated keeping the explicit `--kind widget` override |
| C (strong) | `isUiAcceptance => false` | 3 failures (2 parser tests + plan e2e) | CAUGHT; restored → 17/17 |

## Traceability (issue criteria → tests)

| Issue requirement | Change | Evidence |
| --- | --- | --- |
| New subject kind `widget`; `zfa tdd gen <id> --kind widget` | `BehaviorKind.widget`; gen `--kind` (args `allowed`) + `--golden` flags; effective-kind override plumbing (records, writers, staleness re-render, verdict JSON `kind`/`golden`) | B-830d/e; e2e verdict JSON; negative pins rejected pre-write |
| Spec-driven: plan marks A-behaviors of UI specs as widget kind | `SpecParser.isUiAcceptance` + widget branch; plan widget section + count message; reader header + 6-column cell | B-830a/b/c; e2e plan output |
| Widget test boots app shell/feature view via testWidgets, pumps, asserts scenario | `_renderWidgetTest`: capture → expect → pump in MaterialApp shell → `find.byWidget` | B-830d; e2e honest red → implement → green |
| Subject stub = view-builder / page contract | `SubjectWriter` widget branch (`Widget $target()` + material import + `// kind: widget` header) | B-830d content pins; e2e subject implemented in one step |
| verify-red classification extended for widget failures | `RedClassifier`: assertion-first, then `_widgetPumpException` → runner-error | B-830f incl. real captured transcript; 30/30 pre-existing classifier tests unchanged |
| Golden-file support with committed baselines per platform | gen `--golden` → `matchesGoldenFile` hook + documented refresh workflow | B-830e; e2e: verdict `golden:true`, baseline PNG generated, suite green |

## What was not audited

- **Slow/flutter tier execution of the generated pair inside zuraffa's own
  test suite**: the 17 bug tests are content-level by design; the executed
  evidence comes from the one-off e2e above, not from a committed flutter-tier
  test (the repo's fast suite excludes flutter-tagged tests and there is no
  Flutter fixture harness in test/).
- **Golden drift across platforms**: only one baseline PNG was generated
  (linux host). Per-platform baseline commitment (macOS/Windows font/AA
  differences) is the app project's workflow contract; gen emits the hook and
  documents the refresh command but nothing can verify cross-platform goldens
  from here.
- **`make` end-to-end for widget behaviors** (issue #829 composition) and
  **artifact namespacing** (issue #827): explicitly out of scope for this
  PR's minimal-change constraint.
- **The issue's 24-spec affected list**: its numbering does not resolve
  against this repo (specs/ has 66 dirs; e.g. `002-add-toggle-method` carries
  no UI prose), so no per-spec audit was possible; detection coverage was
  validated against the issue's named prose examples instead.
- **Mutation tooling**: deliberate hand mutants only (3), scoped to the
  changed branch logic; no automated mutant generation.

## Shared verify (branch-level)

```
dart analyze
# 47 issues: 46 pre-existing in examples/todo_tdd (master baseline) + 1
# pre-existing unused import in test/commands/entity_help_test.dart (file
# untouched by this branch). Zero new.

tools/run_tests_chunked.sh   # 67 chunks, run in foreground batches with
                             # identical semantics (stdin </dev/null, "No
                             # tests ran" = SKIP, kernel caches cleaned
                             # between chunks)
BATCH 1-14:   ran=14 fail=0
BATCH 15-30:  ran=16 fail=0
BATCH 31-44:  ran=14 fail=0
BATCH 45-56:  ran=12 fail=0
BATCH 57-68:  ran=11 fail=0
test/plugins/tdd root-level files (incl. bug #830, gen/plan/runner/verify/
wire suites, --exclude-tags flutter): 00:11 +91: All tests passed!

dart format --set-exit-if-changed lib/src/plugins/tdd test/plugins/tdd/bug_830_widget_subject_kind_test.dart
Formatted 63 files (0 changed) in 0.17 seconds.   # exit 0
```
