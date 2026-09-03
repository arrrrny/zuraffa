# Bug Assessment: widget lane dead-ends at make — no generator surface for widget-kind behaviors + _rowKind misreports widget rows as unit-kind

- **Slug**: tdd-133-widget-make-path
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/939
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

A widget-kind behavior (A1, `## Outer loop: widget behaviors`, feature 002-login) reaches certified RED through the #830 lane and then dead-ends at `zfa tdd make`: the composition fallback disengages claiming `behavior "A1" is unit-kind` (wrong on its face — the test list, the registry record and the gen'd test header all say widget), and the make honest-stops `unexpressible`. Every UI-rich spec therefore stops at `stopped_at=A1:make` on its first widget behavior, forever.

## Symptom

```
composition fallback disengaged: behavior "A1" is unit-kind: compose composes acceptance subjects against the feature's green unit subjects, and a unit subject implements its own logic (spec 052 Out of Scope).
zfa tdd make: cannot plan a generation for behavior "A1". ... unexpressible
make: behavior=A1 outcome=unexpressible feature=002-login
```

## Reproduction (this repo, pre-fix)

Real-CLI fixture (pure-Dart, `dart test` profile, feature 002-login, A1 widget-kind + certified red + the gen-shaped view-builder stub):

```
reader: A1 kind=widget                       # TestListReader — the kind source of truth
--- REAL CLI: zfa tdd make A1 --feature 002-login
   composition fallback disengaged: behavior "A1" is unit-kind: ...
make: behavior=A1 outcome=unexpressible feature=002-login
exit: 1
```

(saved pre-fix in this record's `tdd/red-evidence.md`; the issue's `~/zik_zak_test` repro is the same shape under the flutter profile)

## Suspected Code Paths

- `lib/src/plugins/tdd/services/composition_targets.dart` — the make fallback's kind gate (`discover`, step 2): `if (targetRow.kind != BehaviorKind.acceptance)` refuses EVERY non-acceptance kind, and the failure message HARDCODES the text `is unit-kind` regardless of the row's actual kind. A widget row is therefore (a) refused a lane and (b) mislabeled.
- `lib/src/plugins/tdd/commands/make_command.dart` — `_compositionFallback` consults that gate and returns null for widget rows → the honest `unexpressible` stop. `_rowKind` itself resolves widget correctly (the shared `TestListReader` parses `## Outer loop: widget behaviors` → `BehaviorKind.widget` since bug #830) — the mislabel lives in the gate's message, exactly the issue's second hypothesis ("the resolution path drops the widget kind" — here: the message, not the reader).
- `lib/src/plugins/tdd/services/generation_planner.dart` — zero widget references, BY DESIGN (description-keyed, pure, SC-006); UI prose never maps to `entity create`/`make`/`build`. This is the structural defect: with the fallback gated to acceptance, NO surface takes a widget row past RED.

## Root Cause (confirmed, confidence: high)

Two independent defects compounding:

1. **No widget lane in the fallback.** The planner is description-keyed by design (its purity is pinned SC-006); the composition fallback (#642/spec 052) is the phase-aware lane for prose-keyed behaviors, but its gate (`CompositionTargets.discover`) admits acceptance-kind targets only. Widget rows — the #830 testWidgets pair with a view-builder subject — have no planner mapping and no fallback lane: dead-end at make, always.
2. **The gate's failure message hardcodes the kind.** `'behavior "$behaviorId" is unit-kind: ...'` is emitted for unit-, theme-, ffi-, platform- and widget-kind rows alike. `_rowKind`/`TestListReader` resolve widget correctly (proven above: `reader: A1 kind=widget`); the disengage message is what lies.

## Proposed Remediation (implemented in this fix)

1. **Widget make path** — `make_command._compositionFallback` routes widget-kind targets to a NEW view-builder lane shaped BEFORE anchor discovery (the minimal view is driven by the spec's declared Presentation layer contract + the behavior's scenario literals, not by green unit subjects — no anchor precondition, determinism per VISION §4). The lane's generation step is the new `zfa tdd view <id>` command (registered alongside func/compose, same plugin scoping rationale as #657/#610): a deterministic generator that replaces the gen'd `Widget <name>() => throw UnimplementedError(...)` stub with a compiling minimal `StatelessWidget` skeleton composed of (a) one `Text` per scenario literal of the description (the same literals `behavior_test_writer._scenarioFinders` turns into `find.text` assertions, #912 defect 3) and (b) one deterministic always-compiling core-Flutter stand-in per declared Presentation component token (input/field → TextField, button → ElevatedButton, ...; unknown tokens → labeled placeholders). Scenario-specific behavior inside the view stays the sanctioned handcraft seam; the loop REACHES green through a generated skeleton exactly as func subjects do. Idempotent; refuses unrecognized stub shapes; never touches the paired test (044 ownership).
2. **`_rowKind` / composition gate** — `composition_targets.dart` treats widget like acceptance (both compose against the feature's green unit subjects) and names the row's ACTUAL kind in every refusal (`is ${kind.name}-kind`), so the pre-#939 mislabel is unreachable: a unit-kind refusal still says unit-kind (accurately), a theme-kind refusal says theme-kind, and a widget row is never refused by the gate at all.

The planner itself is untouched (byte-for-byte, SC-006).

## Hard constraints honored

- VISION §4 errors-are-an-API: every new failure path exits non-zero with a named reason (`view: behavior=<id> outcome=runner-error|...`).
- Widget make path is deterministic: same registry record + test list + stub → byte-identical view (pinned by U-V8).
- View composition details remain the sanctioned handcraft seam: the emitted skeleton carries the remedy in its header comment; the loop only certifies compile + finders.
- One PR for this bug only.

## Relationship to sibling issues / PRs

- **#830/#912** — the widget lane's gen pair (view-builder stub + testWidgets test); this fix gives that pair its make surface.
- **#642 / spec 052** — the composition fallback this fix extends; the acceptance path (compose → build, anchors required) is unchanged.
- **#657/#610** — the generator-surface precedent (`tdd func`) and plugin scoping rationale the `tdd view` command mirrors.
- **#737/#694** — the terminal-build tolerance and skip transition the widget lane rides when the fixture's build step is red but the behavior's own test passes.
