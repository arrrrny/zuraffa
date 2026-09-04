# Test List: 0965-i18n-keyed-widget-contracts

## Outer loop: acceptance behaviors

One per user story in `spec.md` (issue #965). The Presentation contract below
dogfoods the spec's own contract: `key:` tokens declare i18n surfaces with the
EN literal as the anchor.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the spec contract parses `key:` declarations with EN anchors from Presentation rows and refuses malformed keys | FR-001 | PENDING |
| A-002 | `zfa tdd view` emits `t.<key>` for anchored literals and scaffolds missing keys into lib/i18n | FR-002, FR-003 | PENDING |
| A-003 | the generated widget test boots the slang test shell and asserts resolved keys; EN copy edits survive | FR-004 | PENDING |
| A-004 | the ledger traces `t.<key>` per row and reports hardcoded strings as untraced-surface violations | FR-005 | PENDING |
| A-005 | the optional expansion tier pumps base + de and scaffolds the expansion file | FR-006 | PENDING |

## Layer contracts

### Presentation

- `I18nKeyContract`: `key` dotted surface id, `anchor` EN literal, `parseToken` grammar with typed refusals
- `I18nKeyTable`: `anchorOf` anchor-to-key resolution, `toDeclaredSurfaces` ledger projection

### Domain

- `FinderTaxonomy`: `LiteralKind.key` emission through the resolved accessor (never quoted display text)
- `UiLedgerBuilder`: `untracedHardcodedStrings` untraced-surface violation detector
