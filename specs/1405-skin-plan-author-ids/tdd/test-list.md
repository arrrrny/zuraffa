# Test List: 1405-skin-plan-author-ids

Derived from spec.md + plan.md (speckit.tdd.plan — LLM-guided derivation;
the repo has no `.zfa.json`). Every behavior gets a failing test BEFORE its
implementation lands (red-green-refactor). Test files:
`test/plugins/tdd/services/skin_plan_author_test.dart` (unit rows),
`test/plugins/tdd/commands/issue_1405_skin_plan_author_ids_test.dart`
(CLI rows).

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-1405-1 | planning a SKIN declaration whose token starts with a W-id followed by leaked prose/an unmatched paren (`W1 (renders the login screen pixel-perfect`) exits 0 and emits `| W1 | renders the login screen pixel-perfect |` — prose in the behavior column, strict id | FR-001, FR-002 | GREEN |
| A-1405-2 | planning the issue's malformed SKIN declaration (`Sign In header and subtitle, W1 (renders ..., W2, a full-width guest outline button, an or divider`) exits 2 with a refusal naming the no-pattern token and writes NO `04-SKIN.md` — the malformed table is never ingested | FR-003, FR-004 | GREEN |
| A-1405-3 | a spec declaring SKIN `W1-W9` with clean ids plans nine strict W rows and the test-list reader resolves nine skin behaviors from the lane plan (the W-id count, not 1) | FR-005 | GREEN |
| A-1405-4 | the canonical issue-#1000 lane fixture (CORE `[A1, A2, U1-U6]`, SKIN `[W1-W4]`, BOTH `[A3 (acceptance: navigates to deal_list)]`) still plans exit 0 with the unchanged `04-SKIN.md` shape | FR-005, FR-006 | GREEN |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1405-1 | `sanitizeDeclaredSkinToken` passes an already-strict token through (`W2` → `(W2, '')`) | FR-001 | GREEN |
| U-1405-2 | `sanitizeDeclaredSkinToken` rescues a leading-id token with an unmatched paren (`W1 (renders the login screen pixel-perfect` → `(W1, 'renders the login screen pixel-perfect')`) and bare prose (`W1 renders the login screen` → `(W1, 'renders the login screen')`) | FR-002 | GREEN |
| U-1405-3 | `sanitizeDeclaredSkinToken` returns null for mid-token prose (`the W1 button`) and prose-only fragments (`Sign In header and subtitle`) — never guesses ids out of mid-sentence prose | FR-002, FR-003 | GREEN |
| U-1405-4 | `malformedIdReason` diagnoses the AC classes in precedence order: spaces → unmatched paren → no `W\d+` pattern → non-strict shape; null for `^W\d+$` ids | FR-003 | GREEN |
| U-1405-5 | `validateSkinPlanWIds` returns one refusal line per non-strict id (token quoted, diagnosis named, `--> fix:` remedy appended) and `[]` for clean id lists | FR-003 | GREEN |
| U-1405-6 | regression guard: the wiring leaves CORE/BOTH declarations byte-identical — a CORE token with an annotation and the BOTH `A3 (acceptance: ...)` form still plan exit 0 with the documented rows | FR-005, FR-006 | GREEN |

## Layer contracts

```yaml
# fr: FR-001, FR-002, FR-003
skin_plan_author.dart: sanitizeDeclaredSkinToken, malformedIdReason, validateSkinPlanWIds
# fr: FR-001, FR-002, FR-003, FR-004
plan_command.dart: _resolveLanes SKIN declaration loop (sanitize + refuse; refusals ride the existing no-artifact gate)
```

## Key entities

```yaml
SkinPlanAuthor: the skin plan author's format contract (strict ^W\d+$ ids)
LaneRow: the emitted plan row (id column + behavior column)
LaneDeclaration: the parsed ## Lanes declaration (behaviorIds + annotations)
```
