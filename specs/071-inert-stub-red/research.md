# Research: 071-inert-stub-red

Date: 2026-09-03. Sources: issue #959, `VISION.md` §2/§4, plugin sources listed below.

## Decision 1 — the inert stub replaces the throwing stub as the widget-lane RED surface

**Decision**: `SubjectWriter._renderSubject`'s widget branch (`lib/src/plugins/tdd/services/subject_writer.dart:88-113`) emits `Widget <target>() => const SizedBox.shrink();` (documented as the deliberate inert red surface) instead of `Widget <target>() => throw UnimplementedError('<target> not implemented');`.

**Rationale**: With a throwing stub, `BehaviorTestWriter._renderWidgetTest` (`behavior_test_writer.dart:316-343`) fails at the guard (`expect(built, isNot(isA<UnimplementedError>()))`, line 328) and aborts — authored finders never execute at red. With the inert stub the guard passes, the pump renders a real (empty) view, and every content-inspecting finder fails — red is certified on the authored assertions. This is exactly the issue's proposed fix; it also turns vacuous finders (`find.byWidget(view)`) green at red time, so scaffolded tests classify `unexpected-green` and are refused mechanically.

**Alternatives considered**:
- *Keep throwing stub, add a `--finders` verify-red mode that re-runs with an injected stub*: rejected — two red surfaces for one behavior invites drift; the gen-time stub is the single surface every downstream gate already reads.
- *Emit the inert body only when finders exist, throwing stub otherwise*: rejected — the vacuous case must land on `unexpected-green` (un-greenable), which only the inert stub produces; a throwing stub would certify guard-level red for a scaffold and launder it into the loop.

## Decision 2 — the throwing-capture path stays as a secondary guard

**Decision**: No change to the generated test's guard (`behavior_test_writer.dart:321-328`); update only its explanatory comments.

**Rationale**: Issue acceptance 3 requires it. It also keeps red honest for hand-written subjects that still throw, and it is the classification source for guard-level vs assertion-level reds (FR-007).

## Decision 3 — failing-finder identity is extracted from the transcript by the classifier module

**Decision**: Add a pure helper in `red_classifier.dart` (e.g. `failingAssertionOf(String output) → String?`) that extracts the failing assertion's identity from a red transcript (the failing test's description line and/or the `Expected:`/`Actual:` block header — the same package:test reporter grammar the classifier already parses). `VerifyRedCommand` prints it (`red-evidence: <finder>`) and includes it in the cycle-log entry on `assertion` reds. `RedClassification` (the seven-way enum) is unchanged.

**Rationale**: Keeps all transcript grammar in one module (the classifier file's own stated lesson); verdicts stay machine-parseable (VISION §4); issue acceptance 1 ("classification names the failing finder") is satisfied without a breaking enum change. `models/cycle_entry.dart` gains the detail via the existing append-only log format.

**Alternatives considered**:
- *New eighth classification enum value*: rejected — seven classes are a published contract (spec 046, issue #831); "which finder" is evidence detail, not a class.
- *Regex extraction scattered in the command*: rejected — violates the module's documented rule ("never scatter output-grammar regexes across call sites").

## Decision 4 — scaffold gate enforcement becomes verdict-driven; the string gate stays as backstop

**Decision**: Keep `make_command.dart:300-327` (marker check) unchanged. The primary refusal for scaffolded tests now comes from the loop itself: inert stub + vacuous finders → test is green at red time → `classify` returns `unexpected-green` → verify-red refuses non-zero, no evidence.

**Rationale**: Issue acceptance 2 makes scaffolded-red impossible mechanically; the string check remains as an early, cheap backstop with a clearer message (issue #912 heritage, `widget_scaffold.dart`).

## Decision 5 — existing widget-kind tests are updated, not preserved as-is

**Decision**: Tests asserting the throwing widget stub (`test/plugins/tdd/bug_830_widget_subject_kind_test.dart`, `bug_912_template_self_hosting_test.dart`, `make_command_widget_939_test.dart`, subject-writer tests) are updated to the inert-stub contract; new tests pin the issue's acceptance matrix (inert stub → finder-level red; vacuous finders → unexpected-green; throwing subject → guard-level assertion red; `find.text('X')` present/absent → green/red).

**Rationale**: The stub shape is the feature under change; behavior-level honesty of the loop is preserved via the acceptance matrix tests. Non-widget lanes (unit/acceptance/ffi/persistence) are untouched.
