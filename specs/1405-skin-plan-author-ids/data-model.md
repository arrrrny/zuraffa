# Data Model: 1405 — skin plan author strict W-ids + plan validator

## Entities (new)

### `SkinPlanAuthor` (pure service, `lib/src/plugins/tdd/services/skin_plan_author.dart`)

The skin plan author's format contract (issue #1405): strict W-id emission
plus the plan-time id validator. Pure — no filesystem access, deterministic.

| Member | Signature | Semantics |
| --- | --- | --- |
| `strictWId` | `RegExp` (static final) | `^W\d+$` — the only id shape the skin plan's W rows carry. |
| `sanitizeDeclaredSkinToken` | `static ({String id, String prose})? Function(String)` | Trim the token; if it already matches `^W\d+$` return `(id: token, prose: '')`; else if it starts with `W\d+`, return the leading id plus the prose remainder (surrounding whitespace and orphan parens at the remainder's ends stripped); else return null (not a W-behavior — the validator refuses). |
| `malformedIdReason` | `static String? Function(String)` | Null when the id matches `^W\d+$`; otherwise the AC-named malformation diagnosis in precedence order: no `W\d+` pattern → unmatched paren → spaces → other non-strict shape. |
| `validateSkinPlanWIds` | `static List<String> Function(Iterable<String>)` | One refusal line per non-strict id (token quoted, diagnosis named, fix line appended). Empty list = the table is clean. |

## Entities (touched)

### `PlanCommand._resolveLanes` (`lib/src/plugins/tdd/commands/plan_command.dart`)

The SKIN declaration loop (the classification pass over
`LaneDeclaration.behaviorIds`):

- For a SKIN lane, each declared token goes through
  `sanitizeDeclaredSkinToken`. A null result adds a validator refusal; a
  non-null result classifies the sanitized id (prose remainder rides the
  annotations map, keyed by the sanitized id, only when the parser did not
  already carry an annotation for it).
- CORE/BOTH lanes: byte-identical behavior (their tokens pass through
  unsanitized, exactly as before).
- Hand rows then emit from the sanitized classification — the id column is
  `^W\d+$` by construction; the prose lands in the behavior column.

### `_LaneResult.refusals`

Unchanged shape (List<String>); the validator's lines join the existing
refusal surface → the plan gate prints them and exits 2 before any artifact
write.

## State transitions

```text
SKIN declaration token (from ## Lanes, post parser)
  │
  ├─ matches ^W\d+$ ──────────────► row id = token (unchanged path)
  │
  ├─ starts with W\d+ + prose ────► row id = W\d+ ; prose → behavior column
  │
  └─ no leading W\d+ ─────────────► validator refusal (exit 2, no artifacts)
```

## Invariants

- I1: Every W-behavior id emitted into the skin plan's outer-loop table
  matches `^W\d+$`.
- I2: No prose reaches the id column; sanitizer prose lands only in the
  behavior column.
- I3: A validator refusal leaves the feature directory without new lane
  artifacts (the pre-existing no-artifact-on-refusal gate).
- I4: CORE/BOTH declarations and all derived-behavior ids are untouched.
- I5: The set of behaviors (ids + lanes) a clean spec produces is
  unchanged — only malformed emission is affected.
