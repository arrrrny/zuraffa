# Tasks: 0965-i18n-keyed-widget-contracts (issue #965)

## Outer loop: widget behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-001 | the spec contract parses `key:` declarations with EN anchors from Presentation rows | FR-001 | DONE |
| A-002 | `zfa tdd view` emits `t.<key>` for anchored literals and scaffolds missing keys into lib/i18n | FR-002, FR-003 | DONE |
| A-003 | the generated widget test boots the slang test shell and asserts resolved keys; EN copy edits survive | FR-004 | DONE |
| A-004 | the ledger traces `t.<key>` per row and reports hardcoded strings as untraced-surface violations | FR-005 | DONE |
| A-005 | the optional expansion tier pumps base + de and scaffolds the expansion file | FR-006 | DONE |

## Layer contracts

### Presentation

- `I18nKeyContract`: `key` declared surface, `anchor` EN literal, `parseToken` grammar
- `I18nKeyTable`: `anchorOf`, `keyOf`, `toDeclaredSurfaces`

### Domain

- `FinderTaxonomy`: `LiteralKind.key` emission (resolved accessor, never quoted)
- `UiLedgerBuilder`: `untracedHardcodedStrings` detector

## Implementation checklist

- [x] T001 (RED first) `services/i18n_key_contract.dart` — contract model + parser + table; tests prove keys parse from spec-shaped LayerContracts (US1)
- [x] T002 `commands/view_command.dart` — key-mapped rendering + accessor import + `lib/i18n` scaffolding (US2)
- [x] T003 `services/behavior_test_writer.dart` + `commands/gen_command.dart` — slang test shell, resolved-key assertions, copy-edit survival (US3)
- [x] T004 `services/ui_ledger_builder.dart` — key rows + untraced-surface violations (US4)
- [x] T005 expansion tier — `--i18n-expansion` / `tdd.i18nExpansion`, expansion testWidgets + `strings_<loc>.i18n.json` scaffold (US5)
- [x] T006 refactor + verify — dart format, dart analyze, chunked suite, no new failures; `/speckit.tdd.verify` (fallback audit) writes tdd/verification.md from the real run
