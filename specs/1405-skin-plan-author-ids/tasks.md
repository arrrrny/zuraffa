# Tasks: 1405 — skin plan author strict W-ids + plan validator

**Input**: Design documents from `/specs/1405-skin-plan-author-ids/`
**Prerequisite**: tdd/test-list.md (tdd extension) orders the behavioral work — every behavior has a failing test before its implementation.

## Phase 1 — MVP: the validator + the author (behaviors B1–B5)

- [x] T001 (P1) Create `lib/src/plugins/tdd/services/skin_plan_author.dart`:
      the pure `SkinPlanAuthor` format contract — `strictWId` (`^W\d+$`),
      `sanitizeDeclaredSkinToken` (anchored leading-`W\d+` rescue, prose
      remainder returned, null when no W-behavior), `malformedIdReason`
      (spaces → unmatched paren → no `W\d+` pattern → other, precedence
      order), `validateSkinPlanWIds` (one refusal line per non-strict id,
      fix line appended). [implements B1, B2, B3 unit surface; US1, US2]
- [x] T002 (P1) RED→GREEN: `test/plugins/tdd/services/skin_plan_author_test.dart`
      — unit rows for the sanitizer (strict pass-through, leading-id +
      unmatched-paren prose, leading-id + bare prose, mid-token prose →
      null, prose-only → null, empty → null), the diagnosis precedence
      order, and the validator's refusal lines. Written and failing BEFORE
      T001's implementation compiles green. [B1, B2, B3]
- [x] T003 (P1) Wire the author into `PlanCommand._resolveLanes`' SKIN
      declaration loop: sanitize each SKIN token (null → validator refusal;
      non-null → classify the sanitized id, prose remainder onto the
      annotations map when the parser carried none), leaving CORE/BOTH
      lanes byte-identical. [implements US1 emission + US2 plan-time gate]
- [x] T004 (P1) RED→GREEN: `test/plugins/tdd/commands/issue_1405_skin_plan_author_ids_test.dart`
      — CLI surface, hermetic temp project (`plan_lanes_1000_test.dart`
      shape): the issue's malformed declaration exits 2 with a refusal
      naming the prose token and writes no `04-SKIN.md`; the sanitizable
      declaration emits `| W1 | renders the login screen pixel-perfect |`;
      clean `W1-W9` yields nine strict W rows and the reader resolves nine
      skin behaviors; the canonical #1000 fixture still exits 0 unchanged.
      [B1–B5]

## Phase 2 — Hardening (after the MVP rows are green)

- [x] T005 (P2) Prove the no-artifact-on-refusal invariant explicitly
      (feature directory carries no new lane artifacts after a rejected
      plan) and the diagnosis-class coverage for spaces / unmatched paren /
      no-pattern refusals. [B4]
- [x] T006 (P2) `dart format .` + `dart analyze` on the touched files —
      zero new issues, zero formatting diffs (CI format gate). [B6]
- [x] T007 (P2) Record red evidence (pre-fix run) and green evidence
      (post-fix) under `specs/1405-skin-plan-author-ids/tdd/`; write
      `tdd/verification.md` (test-first + mutation evidence:
      strengthen-check that mutating the strict-`W\d+` check re-reddens
      the suite). [B7]

## Dependencies

- T002 → T001 (the failing tests define the surface before the
  implementation)
- T004 → T003 (the CLI rows need the wiring)
- T005 → T004 (hardening rides the green MVP)
- T006, T007 → all above

## Parallelizable

- T002 and T004's RED drafts can be written together before any
  implementation lands.

## Notes

- The gen pipeline, make pipeline, verify gate, run driver, status command,
  split command, and the spec parser's tokenizer are OUT OF SCOPE — the
  task list must not grow edits there (hard constraint).
- Validation happens at plan time only; nothing new runs at gen/run time.
