# Implementation Plan: Skin plan author emits strict W-ids; plan validator rejects malformed ids

**Branch**: `feat/1405-skin-plan-author-ids` | **Date**: 2026-09-10 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/1405-skin-plan-author-ids/spec.md`

## Summary

The skin plan author — the plan-time step that turns a spec's `## Lanes`
SKIN declarations into `04-SKIN.md`'s outer-loop behavior table — ingests
declaration tokens verbatim as row ids. When the authoring LLM splits a
behavior sentence mid-fragment (at a comma), the leaked prose lands in the
id column (`| Sign In header and subtitle | skin behavior declared in
## Lanes |`, `| W1 (renders the login screen pixel-perfect | ... |`),
leaving 8 of 9 skin behaviors machine-unreachable and the skin lane stuck at
0/1 — only the one cleanly-parsed id (`W2`) ever gets a generated test. The
fix (issue #1405) makes the author emit ids strictly matching `^W\d+$`: a
token that starts with a `W\d+` id is sanitized (prose remainder moved to
the behavior column), and a token with no `W\d+` pattern is refused by a new
plan-time validator — before any artifact is written — instead of being
ingested into a malformed table. Clean `W1..Wn` specs keep planning
byte-compatibly.

## Technical Context

**Language/Version**: Dart 3.x (repo SDK constraint `^3.11.0`; toolchain
Dart 3.13+)

**Primary Dependencies**: repo-local TDD plugin (`plan_command.dart` —
`_resolveLanes` hand-row emission; new pure service `skin_plan_author.dart`);
`package:test`. No new external dependencies.

**Storage**: N/A (the planner emits markdown lane artifacts under
`specs/<feature>/tdd/`; the validator runs in-memory at plan time)

**Testing**: `dart test` (single-file targeted runs per the verify protocol).
New tests: `test/plugins/tdd/services/skin_plan_author_test.dart` (pure
service unit rows) + `test/plugins/tdd/commands/issue_1405_skin_plan_author_ids_test.dart`
(CLI surface, hermetic temp project — the `plan_lanes_1000_test.dart` shape).

**Target Platform**: CLI (macOS/Linux/Windows dev machines; CI on POSIX)

**Project Type**: library/cli

**Performance Goals**: plan latency unchanged (same parse + resolve pass,
plus one linear id-shape scan)

**Constraints**: fix ONLY the skin plan author (id emission) and the plan
validator (id validation); no changes to the core engine cycle, the gen
pipeline, the make pipeline, the verify gate, or the skin lane derivation
algorithm (which behaviors exist and their lane assignment); no artifacts on
refusal ("an incomplete split never leaves a half-written lane plan")

**Scale/Scope**: one new pure service (sanitizer + validator), one wiring
edit in `_resolveLanes`' skin declaration loop, refusal lines through the
existing `_LaneResult` gate (exit 2 before artifacts), tests; the
`zfa tdd split` ingestion path and non-skin lanes are deliberately
untouched

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Test-first (non-negotiable): RED rows recorded against the unfixed tree
  before the fix lands, same commit series. ✓
- Errors-are-an-API: a non-sanitizable token becomes a refusal naming the
  token and the malformation class (spaces / unmatched paren / no `W\d+`
  pattern); never a silent drop (the issue #1432 bug class). ✓
- Declarations win, gaps refuse: the validator extends the existing lane
  refusal gate (`_LaneResult.refusals` → exit 2, no artifacts), the same
  fail-fast surface the noFlutter guard and the golden-drift guard use. ✓
- Plan-time honesty: validation happens at plan time — a malformed table
  never reaches gen/run, so `zfa tdd status`'s denominator is the plan's
  real W-id count. ✓

## Project Structure

### Documentation (this feature)

```text
specs/1405-skin-plan-author-ids/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (CLI + artifact contract)
└── tasks.md             # Phase 2 output (/speckit-tasks command)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── commands/
│   └── plan_command.dart        # _resolveLanes: skin token sanitization +
│                                #   validator wiring (the ONLY lib edit)
└── services/
    └── skin_plan_author.dart    # NEW: strict W-id emission + plan-time
                                 #   validator (pure, no I/O)
test/plugins/tdd/
├── commands/
│   └── issue_1405_skin_plan_author_ids_test.dart  # NEW: CLI surface
└── services/
    └── skin_plan_author_test.dart                 # NEW: unit rows
```

**Structure Decision**: the sanitizer + validator live in one new pure
service beside the other skin-plan services (`skin_authoring.dart`,
`skin_hand_edit.dart`, `lane_split.dart`) so both the plan command and any
future authoring surface share one format contract; the CLI-level behavior
(exit 2, no artifacts, refusal text) is pinned by the command test.

## Phase 0 — Research (resolves all NEEDS CLARIFICATION)

See [research.md](./research.md). Conclusions:

- R1: The malformed table is produced by `PlanCommand._resolveLanes`' hand
  rows: `SpecParser.parseLanes` → `_expandBehaviorTokens` strips only
  *closed* trailing parens, so a sentence split at a comma leaks
  `W1 (renders ...` (unmatched paren) and bare prose fragments verbatim into
  `LaneDeclaration.behaviorIds`; the hand-row loop emits them as ids.
- R2: The rescue rule is anchored: only a token *starting* with `W\d+` is
  sanitized (the issue's observed truncation shape); prose mid-token
  (`the W1 button`) is refused — the author must not guess ids out of
  mid-sentence prose.
- R3: The refusal surface already exists: `_LaneResult.refusals` → the plan
  gate prints the lines and exits 2 before any artifact write.
- R4: `zfa tdd status`'s skin denominator derives from run receipts, whose
  totals derive from the rows the lane plan resolves — strict emission plus
  validator rejection fixes the count transitively; the status command, run
  driver, gen and make are untouched.

## Phase 1 — Design

See [data-model.md](./data-model.md), [contracts/](./contracts/),
[quickstart.md](./quickstart.md).

- The author's API: `SkinPlanAuthor.sanitizeDeclaredSkinToken(token)` →
  `({String id, String prose})?` (null = not a W-behavior); the validator's
  API: `SkinPlanAuthor.malformedIdReason(id)` → `String?` and
  `SkinPlanAuthor.validateSkinPlanWIds(ids)` → refusal lines.
- Emission contract: `| W1 | renders the login screen pixel-perfect | ...`
  — prose in the behavior column only; the id cell is always `^W\d+$`.
- Validator contract: the three AC-named malformation classes each get a
  distinct diagnosis in the refusal line; a rejected plan writes nothing.

**Constitution re-check after Phase 1**: unchanged verdict — all four
gates hold with the design above.

## Progress

- [x] Phase 0 research complete (no NEEDS CLARIFICATION left)
- [x] Phase 1 design complete (data-model, contracts, quickstart)
- [x] Constitution check passes (initial + post-design)
- [x] Phase 2 tasks (/speckit-tasks)
