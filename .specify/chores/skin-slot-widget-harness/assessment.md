# Chore Assessment: slot-aware widget test harness

- **Slug**: skin-slot-widget-harness
- **Created**: 2026-10-19
- **Source**: https://github.com/arrrrny/zuraffa/issues/1920
- **Verdict**: in scope
- **Size**: medium

## Report (verbatim or summarized)

`zfa tdd run-skin` conformance mode (spec 1005, SKIN lanes declaring
`adaptive_slots`) accepts a behavior only when the GREEN transcript carries
one `skin-event: behavior=W<n> slot=<slot>` line per declared slot
(`run_skin_command.dart` gate (a)). No generator-supported route exists to
produce that line from a widget-lane test:

- `BehaviorTestWriter._renderWidgetTest` imports exactly
  `package:flutter/material.dart`, `package:flutter_test/flutter_test.dart`
  (and optionally the widget shell / i18n accessor).
- `debugDefaultTargetPlatformOverride` lives in
  `package:flutter/foundation.dart`, which `material.dart` does not
  re-export, so a hand-added import is the only route today — the same gap
  issue #1878 closed for `tdd make`'s finder-authoring path.
- Releasing the override through `addTearDown` is too late: the framework
  verifies foundation debug variables at the end of `_runTestBody`, before
  tear-down callbacks run, so the release must be the body's last statement
  (a `finally` inside the body).

The issue asks for one of three remedies; the preferred one is a slot-aware
widget harness: when the feature's SKIN lane declares `adaptive_slots`, the
generated widget test loops the declared slots, pins the environment per
slot, prints the `skin-event` line, and releases the pin in a `finally`.

## Summary

Teach `zfa tdd gen` to emit a slot-aware widget test whenever the behavior
belongs to a SKIN lane declaring `adaptive_slots`, and document the
body-release rule. This is a chore: it closes a generator gap in the TDD
tooling, not a user-facing feature.

## Constitution Check

- Constitution VII (`lib/` never imports Flutter): the change lives in the
  TDD plugin's string-emitting writer and stays pure Dart; it emits Flutter
  imports into generated target-project tests, never into `lib/`.
- No-JIT rule: no CLI spawning changes.
- Generated-code integrity: `behavior_test_writer.dart` is hand-written
  source, not generated output; no `.zorphy.dart` file is touched.

## Affected Paths

- `lib/src/plugins/tdd/services/behavior_test_writer.dart` — the widget
  template; needs an `adaptiveSlots` input, the foundation import, the slot
  loop, per-slot pin/release helpers, and the `skin-event` print.
- `lib/src/plugins/tdd/commands/gen_command.dart` — resolves the feature's
  SKIN lane slots from `spec.md` and threads them through `_writersFor` to
  both the real write and the staleness mirror.
- `docs/tdd-run-skin.md` (or the nearest run-skin reference) — the
  "release the pin as the body's last statement" rule and the slot-loop
  harness description.

## Proposed Approach

**Preferred**:

1. Add `List<String> adaptiveSlots` to `BehaviorTestWriter` (default empty,
   preserving the legacy byte-identical template for every non-slot lane).
2. In `gen_command`, parse `<featureDir>/spec.md` with `SpecParser`, take
   the SKIN lane(s) whose `behaviors` include the target id, and collect
   their `adaptiveSlots`; pass the list to `_writersFor` for both the real
   write and the staleness mirror. Parse failures fail open to no slots.
3. The widget template, when slots are present, emits
   `import 'package:flutter/foundation.dart';`, wraps the existing body in
   `for (final slot in const <String>[...])`, calls `_pinSkinSlot(tester,
   slot)` (platform override for ios/android/macos/windows/linux/fuchsia,
   surface size for mobile/tablet/desktop), prints
   `skin-event: behavior=<id> slot=$slot` after `pumpAndSettle()`, and
   releases in a `finally` with `_releaseSkinSlot(tester)`.
4. Document the release rule and the harness in the run-skin docs.

**Alternatives**:

- A subject-side `setTargetPlatform` helper — loses the per-slot render and
  still leaves every feature reinventing it.
- Refusal-only (option 3) — removes the guesswork but leaves the lane
  unable to conform.

**Paths likely to change**:

- `lib/src/plugins/tdd/services/behavior_test_writer.dart`
- `lib/src/plugins/tdd/commands/gen_command.dart`
- `test/plugins/tdd/services/behavior_test_writer_adaptive_slots_1920_test.dart`
- `test/plugins/tdd/commands/gen_command_adaptive_slots_1920_test.dart`
- the run-skin documentation file

**Verification to run**:

- `dart test test/plugins/tdd/services/behavior_test_writer_adaptive_slots_1920_test.dart`
- `dart test test/plugins/tdd/commands/gen_command_adaptive_slots_1920_test.dart`
- `dart analyze lib/src/plugins/tdd`
- `dart format lib test`

## Risks & Considerations

- The legacy template is asserted byte-for-byte by existing tests; the new
  branch must be inert when no slots are declared.
- The staleness mirror renders the expected pair again — it must pass the
  same slots or every slot-aware pair reports false staleness.
- Slot pinning must release before the test body returns; `addTearDown` is
  the trap the issue documents.
- Width-defined slots (`mobile`, `tablet`, `desktop`) resolve before the
  platform switch in the generated adaptive view, so the harness pins the
  surface as well as the platform.

## Open Questions

None.
