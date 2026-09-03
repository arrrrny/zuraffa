# Implementation Plan: Inert-Stub Red — Certify Widget Finders as the RED Surface

**Branch**: `071-inert-stub-red` | **Date**: 2026-09-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/071-inert-stub-red/spec.md` (GitHub issue #959)

## Summary

Widget-lane RED is certified on assertion #1 only (`isNot(UnimplementedError)`) because the widget subject stub throws `UnimplementedError`, the generated test aborts there, and authored finder assertions never execute at red time ("born green"). The fix: emit an **inert-but-valid stub** (`Widget subject() => const SizedBox.shrink()`) as the widget-lane red surface. The guard assertion then passes, the pump runs, and every authored finder fails against the empty view — red is certified *on the assertions*. A vacuous-finder (scaffolded) test passes against the inert stub, lands on `unexpected-green`, and is refused — making the #912 scaffold gate mechanical instead of string-only. The throwing-capture path stays as a secondary guard. Red verdicts name the failing finder.

## Technical Context

**Language/Version**: Dart 3.13 (pubspec pins `sdk: ^3.11.0`); pure-Dart root package
**Primary Dependencies**: `args`, `path`, `yaml`, `crypto` (CLI + plugin code); generated widget tests target `flutter_test` in *target projects* (never executed by this repo's own suite)
**Storage**: file-based artifacts (`specs/<feature>/tdd/artifacts.json`, `tdd/cycle-log.md`)
**Testing**: `dart test` (package:test ^1.25.0) per `.specify/memory/tdd-profile.md`; feature scope `dart test test/plugins/tdd/`
**Target Platform**: CLI (`zfa tdd gen` / `zfa tdd verify-red` / `zfa tdd make`) running on host; emits test code for Flutter target projects
**Project Type**: library/cli (zuraffa generator + TDD plugin)
**Performance Goals**: classifier is pure text parsing — negligible; verify-red keeps its existing 2-minute default child-process timeout
**Constraints**: generated widget tests must still compile in Flutter projects without new imports beyond `flutter/material.dart`; existing non-widget lanes must not change behavior
**Scale/Scope**: ~4 source files + ~4 test files under `lib/src/plugins/tdd/`, `test/plugins/tdd/`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unratified Spec Kit template (no project-specific principles). Checked against the repo's de-facto governance, which this plan honors:

- **VISION §2 (referee, not assistant)**: the framework refuses to certify red until authored assertions demonstrably fail — this feature *is* a §2 implementation. PASS.
- **VISION §4 (errors are an API)**: verdicts stay machine-parseable (`verify-red: behavior=… classification=… certified=…`); the new failing-finder detail is added to the verdict surface, never as prose-only. PASS.
- **TDD discipline** (tdd-profile conventions): behaviors land test-first; red evidence in `tdd/cycle-log.md`. PASS.
- **Generated-code contract**: generated widget tests still compile cleanly (FR-011 heritage) — the inert stub adds no import. PASS.

No violations.

## Project Structure

### Documentation (this feature)

```text
specs/071-inert-stub-red/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── cli-verdicts.md  # verify-red summary-line + evidence contract deltas
└── tasks.md             # Phase 2 output (/skill:speckit-tasks)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── services/
│   ├── subject_writer.dart        # MODIFY: widget-kind stub -> inert SizedBox.shrink()
│   ├── behavior_test_writer.dart  # MODIFY: comment/guard wording stays; scenario block unchanged
│   ├── red_classifier.dart        # MODIFY: extract failing-assertion identity from transcript
│   └── widget_scaffold.dart       # MODIFY (docs only): marker stays; mechanical gate documented
├── commands/
│   ├── verify_red_command.dart    # MODIFY: print + log failing-finder detail on assertion reds
│   └── make_command.dart          # NO CODE CHANGE: string gate stays as backstop
└── models/
    └── (red_classification.dart unchanged — same seven classes)

test/plugins/tdd/
├── subject_writer_test.dart            # MODIFY: widget stub expectations (new/updated)
├── bug_830_widget_subject_kind_test.dart  # MODIFY: stub no longer throws
├── bug_912_template_self_hosting_test.dart # MODIFY: scaffold path expectations under inert stub
├── red_classifier_test.dart            # MODIFY/EXTEND: failing-finder extraction fixtures
└── verify_red_command_test.dart (or scenarios/)  # EXTEND: verdict names failing finder
```

**Structure Decision**: Existing plugin layout is kept; no new top-level directories. The change is intentionally narrow: swap the widget-lane red surface (stub), keep the guard, and enrich the verdict with the failing finder's identity.

## Complexity Tracking

> No constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
