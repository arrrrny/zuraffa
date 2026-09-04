# Tasks: 071-inert-stub-red — Certify Widget Finders as the RED Surface

**Input**: Design documents from `/specs/071-inert-stub-red/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli-verdicts.md, quickstart.md, tdd/test-list.md

**Tests**: Included — the user requested the full TDD cycle. Behavior tests are written FIRST and must FAIL before their implementation task runs.

**Organization**: Grouped by user story (spec.md US1–US4). Behavior ids (`[behavior: …]`) trace to `tdd/test-list.md` (A1–A9 acceptance, U1–U8 unit). Behavior tasks are **MANDATORY** — the loop (`zfa tdd run`) drives each one red→green; they are never skippable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Exact file paths included in every description

## Path Conventions

Plugin code: `lib/src/plugins/tdd/` · Plugin tests: `test/plugins/tdd/`

---

## Phase 1: Setup

**Purpose**: Establish the baseline the loop audits against

- [x] T001 Run the plugin suite baseline (`dart test test/plugins/tdd/`) and record the green baseline + `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/` state in the cycle log notes

---

## Phase 2: User Story 1 — Red certified on the authored assertions (P1) 🎯 MVP

**Goal**: The widget-lane red surface is an inert-but-valid stub; authored finders execute and fail at red time.

**Independent Test**: Render a widget behavior's subject + test with the current writers; the subject returns an inert widget, and a red transcript against it classifies `assertion` with the finder as evidence.

### Tests for User Story 1 (write FIRST, prove RED — MANDATORY behaviors)

- [x] T002 [P] [US1] MANDATORY behavior task [behavior: U1] — In `test/plugins/tdd/subject_writer_test.dart`: widget-kind `SubjectWriter.render` emits `Widget <target>() => const SizedBox.shrink();` — no `UnimplementedError` in the body, only `package:flutter/material.dart` imported, header keeps behavior_id/source_criterion, doc comment names it the inert red surface
- [x] T003 [P] [US1] MANDATORY behavior task [behavior: U2, A3, A6, U6] — In `test/plugins/tdd/red_classifier_test.dart` (finder-level red pin, issue #959 acceptance 4): a transcript whose failure comes from an authored finder (`Expected: one matching candidate` / `Actual: <0>` after a clean pump) classifies `assertion` (stand-in lacks the label → A3; real finders certify red and the workflow proceeds → A6); plus the writer-level pin that the emitted template runs the finders after the pump and that only the subject file differs between red and green (zero assertion edits → U2, U6)

### Implementation for User Story 1

- [x] T004 [US1] In `lib/src/plugins/tdd/services/subject_writer.dart` (widget branch of `_renderSubject`): emit the inert stub `Widget <target>() => const SizedBox.shrink();` with an "inert red surface — replace this body with the real view builder" doc comment; keep traceability header (implements U1; depends on T002, T003)
- [x] T005 [US1] Update tests that pin the throwing widget stub to the inert contract: `test/plugins/tdd/bug_830_widget_subject_kind_test.dart`, `test/plugins/tdd/bug_912_template_self_hosting_test.dart`, `test/plugins/tdd/make_command_widget_939_test.dart` (depends on T004)

**Checkpoint**: `dart test test/plugins/tdd/` green; widget stub is inert; finder-level red proven at the classifier seam.

---

## Phase 3: User Story 2 — Scaffolded, vacuous tests can never be certified red (P2)

**Goal**: Vacuous-finder (scaffolded) widget tests are green at red time and refused mechanically via `unexpected-green`; the marker string gate stays as backstop.

**Independent Test**: A transcript where all view assertions pass against the inert stub classifies `unexpected-green` (not red); `make`'s marker refusal is unchanged.

### Tests for User Story 2 (write FIRST, prove RED — MANDATORY behaviors)

- [x] T006 [P] [US2] MANDATORY behavior task [behavior: U4, U8, A4, A5] — In `test/plugins/tdd/red_classifier_test.dart`: a green transcript from a vacuous-only widget test against the inert stub classifies `unexpected-green`, not red (vacuous passes → A4; workflow refuses → A5); and in `test/plugins/tdd/bug_912_template_self_hosting_test.dart` the pin that the scaffold marker is still emitted and `contentIsScaffolded` still matches it (marker forces not-red until replaced → U8)

### Implementation for User Story 2

- [x] T007 [US2] Confirm no classifier change is required (unexpected-green path already exists); update the doc comments in `lib/src/plugins/tdd/services/widget_scaffold.dart` so the marker is documented as the backstop while the mechanical refusal comes from the verdict (implements U4, U8; depends on T006)

**Checkpoint**: Vacuous-only red attempt → `unexpected-green` refusal; backstop documented.

---

## Phase 4: User Story 3 — Red verdicts are self-explanatory (P3)

**Goal**: Certified reds name the failing authored assertion in the CLI verdict surface and the cycle-log entry.

**Independent Test**: Feed a finder-failure transcript to the extraction helper → identity string; run verify-red on a red fixture → `red-evidence:` line, `evidence=` summary token, `- evidence:` cycle-log line.

### Tests for User Story 3 (write FIRST, prove RED — MANDATORY behaviors)

- [x] T008 [P] [US3] MANDATORY behavior task [behavior: U3] — In `test/plugins/tdd/red_classifier_test.dart`: extraction of the failing-assertion identity from the reporter grammar — returns the test description / `Expected:`-anchored identity for finder failures, and `null` for transcripts without a parseable identity (runner crash, guard-only failure)
- [x] T009 [P] [US3] MANDATORY behavior task [behavior: A1, A7] — In the verify-red command test/scenario file: a certified red prints `   red-evidence: <identity>`, ends the summary line with `evidence=<identity>` (token omitted for non-assertion classes), and the appended cycle-log red entry carries `- evidence: <identity>` (verdict identifies the authored assertion as the red evidence → A1, A7)

### Implementation for User Story 3

- [x] T010 [US3] In `lib/src/plugins/tdd/services/red_classifier.dart`: add pure `failingAssertionOf(String output) → String?` over the same reporter grammar (test description line + `Expected:`/`Actual:` anchor); no enum change (implements U3; depends on T008)
- [x] T011 [US3] In `lib/src/plugins/tdd/commands/verify_red_command.dart` + `lib/src/plugins/tdd/models/cycle_entry.dart`: thread the identity into the printed `red-evidence:` line, the `evidence=` summary token, and the optional `- evidence:` cycle-log field (bump `evidenceSchemaVersion` only if the bug-828 integrity contract requires it; update `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` fixtures accordingly) (implements A1, A7; depends on T009, T010)

**Checkpoint**: Every certified red names its failing assertion; summary line stays machine-parseable and byte-identical for non-assertion classes.

---

## Phase 5: User Story 4 — Existing error-capture protection remains in force (P4)

**Goal**: The throwing-capture guard still certifies red when a subject throws; template comments re-anchor it as the secondary guard.

**Independent Test**: A transcript where the guard assertion fires (subject still throws) classifies `assertion` — guard-level red — with evidence naming the guard, not a finder.

### Tests for User Story 4 (write FIRST, prove RED — MANDATORY behaviors)

- [x] T012 [P] [US4] MANDATORY behavior task [behavior: U5, U7, A2, A8, A9] — In `test/plugins/tdd/behavior_test_writer_test.dart` (or the existing writer test home): the emitted widget template still contains the capture guard + `expect(built, isNot(isA<UnimplementedError>()))` unchanged, with comments describing the guard as secondary; classifier pins that a guard-only transcript still certifies `assertion` (guard preserved → U5, A9; guard-level distinguished from finder-level and harness failure → U7, A8); plus the green-side pin that a real view passes the unchanged assertions (green with zero edits → A2)

### Implementation for User Story 4

- [x] T013 [US4] In `lib/src/plugins/tdd/services/behavior_test_writer.dart` (`_renderWidgetTest`): update only the explanatory comments (guard = secondary; finders = primary red surface); emitted code shape unchanged (implements U5, U7; depends on T012)

**Checkpoint**: Backward compatibility proven; template docs match the new semantics.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T014 [P] Sweep user-facing docs that describe the widget stub as throwing (`openwiki/`, `docs/`, plugin README sections — grep for the old stub phrasing) and update to the inert-red contract
- [x] T015 Run the full quickstart.md validation: `dart test test/plugins/tdd/` + `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`; record results

---

## Dependencies & Execution Order

### Phase Dependencies

- Setup (T001) → all stories
- US1 (T002–T005) is the MVP and the mechanical foundation: US2's verdict-driven refusal and US4's guard pin both read the inert stub
- US2 (T006–T007), US3 (T008–T011), US4 (T012–T013) are independent of each other once US1 lands
- Polish (T014–T015) last

### Within Each Story

- Test tasks before their implementation task (TDD; behavior ids enforced by `tdd/test-list.md`)
- T004 depends on T002+T003; T005 on T004; T007 on T006; T010 on T008; T011 on T009+T010; T013 on T012

### Parallel Opportunities

- T002, T003 (US1 tests) in parallel; T006, T008, T009, T012 across stories in parallel; T014 during any phase

---

## Implementation Strategy

### MVP First (US1 only)

1. T001 baseline → T002/T003 red → T004/T005 green
2. Validate: finder-level red proven at the seam; suite green
3. US2–US4 can proceed independently afterward

### Notes

- Each behavior lands red-evidence in the cycle log via the loop (`zfa tdd run`), one failing test at a time
- Commit after each story checkpoint
- Avoid: changing the seven-way classification contract; touching non-widget lanes; new imports in generated stubs
