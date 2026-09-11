# Contract: 1405 — skin plan author CLI + artifact surface

## CLI contract: `zfa tdd plan <feature>` on a Lanes-declaring spec

### Case A — sanitizable SKIN token (exit 0, prose in the behavior column)

Input (`## Lanes`, SKIN row):
```yaml
- lane: SKIN
  behaviors: [Sign In header and subtitle, W1 (renders the login screen pixel-perfect, W2]
```
is REJECTED (exit 2) because `Sign In header and subtitle` carries no
`W\d+` pattern — the whole malformed declaration is refused, never
partially ingested.

A declaration whose only malformation is a leading-id token:
```yaml
- lane: SKIN
  behaviors: [W1 (renders the login screen pixel-perfect, W2]
```
plans exit 0 and `04-SKIN.md`'s widget outer-loop table carries:

```
| W1 | renders the login screen pixel-perfect | LANE:SKIN | PENDING |
| W2 | skin behavior declared in `## Lanes`  | LANE:SKIN | PENDING |
```

The id column is `^W\d+$`; the prose lives in the behavior column.

### Case B — malformed SKIN token (exit 2, no artifacts, refusal names the class)

Input: any SKIN token with no leading `W\d+` (`Sign In header and
subtitle`, `a full-width guest outline button`, `an or divider`).

Behavior:
- stdout: `zfa tdd plan: lane contract FAILED — N lane violation(s)
  (spec: ...)` followed by one line per offending token:
  `skin plan validator: declared skin behavior "Sign In header and
  subtitle" <diagnosis>. --> fix: write clean W-ids (^W\d+$) in the SKIN
  lane's behaviors: list; move the prose into a parenthetical annotation`
  where `<diagnosis>` is one of:
  - `carries spaces (prose leaked into the id column)`
  - `carries an unmatched paren (truncated mid-sentence)`
  - `carries no W<digits> pattern`
  - `is not a strict W-id (^W\d+$)`
- exit code: 2
- filesystem: **no** `04-SKIN.md`, **no** `04-ENGINE.md`, **no**
  `04-CONTRACT.md`, **no** meta-index rewrite, **no** behavior row
  synthesized from the malformed tokens.

### Case C — clean spec (byte-compatible, exit 0)

Input: the canonical issue-#1000 fixture (`CORE [A1, A2, U1-U6]`, `SKIN
[W1-W4]`, `BOTH [A3 (acceptance: navigates to deal_list)]`).

Behavior: unchanged from the unfixed tree — exit 0, `04-SKIN.md` with the
four W rows, the BOTH annotation in the behavior column, the meta-index
pointers intact.

## Library contract: `SkinPlanAuthor` (pure)

```dart
SkinPlanAuthor.sanitizeDeclaredSkinToken('W2')
// → (id: 'W2', prose: '')
SkinPlanAuthor.sanitizeDeclaredSkinToken('W1 (renders the login screen pixel-perfect')
// → (id: 'W1', prose: 'renders the login screen pixel-perfect')
SkinPlanAuthor.sanitizeDeclaredSkinToken('Sign In header and subtitle')
// → null
SkinPlanAuthor.malformedIdReason('W1 renders')
// → 'carries spaces (prose leaked into the id column)'
SkinPlanAuthor.malformedIdReason('W1 (renders')
// → 'carries an unmatched paren (truncated mid-sentence)'
SkinPlanAuthor.malformedIdReason('Sign In header and subtitle')
// → 'carries no W<digits> pattern'
SkinPlanAuthor.malformedIdReason('W2')
// → null
SkinPlanAuthor.validateSkinPlanWIds(['W1', 'Sign In header and subtitle'])
// → one refusal line for the prose token; [] for ['W1', 'W2']
```

## Non-contract (explicitly unchanged)

`zfa tdd gen`, `zfa tdd make`, `zfa tdd run`, `zfa tdd run-engine`,
`zfa tdd run-skin`, `zfa tdd verify`, `zfa tdd status`, `zfa tdd split`,
the spec parser's tokenizer, and the lane derivation algorithm — zero
behavioral change.
