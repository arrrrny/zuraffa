# Fix: escape pipe characters in plan table cells; plan and run agree on table format (#1401)

- **Slug**: 1401-plan-pipe-escape-table-cells
- **Fixed in**: `lib/src/plugins/tdd/commands/plan_command.dart`
  (commit `fix(1401): escape pipe characters in plan table cells; plan
  and run agree on table format` on `fix/1401-plan-pipe-escape-table-cells`)
- **Strategy**: writer escape + plan-side reader unescape (fail-fast
  rejected: it would refuse legitimate FR prose the format can carry —
  GFM `\|` — and silently dropping pipes would corrupt requirement text)

## Writer: `_escapeCell`

New private static helper escapes `|` as `\|` inside every free-text
table cell plan writes, across all five row dialects:

| Row dialect      | Cells escaped                                  |
| ---------------- | ---------------------------------------------- |
| acceptance (A)   | behavior (via `_marked`), traces cell          |
| widget (5-col)   | behavior, traces cell (kind cell is taxonomy)  |
| unit (U)         | behavior (via `_marked`), traces cell          |
| contract         | description (criterion is a grammar token)     |
| native/ffi       | description, traces (preserved free text)      |
| key entities     | `purpose` prose                                |
| ext dependencies | `contract` prose                               |

Backslashes are deliberately NOT re-escaped: the readers' contract
treats `\|` as the only cell-level escape, and a lone `\` followed by
any non-pipe character survives both directions unchanged. A literal
`\|` in the original prose also round-trips (writer emits `\\\|`-shaped
text; the reader's first unescaped split point stays the real one).
Escaping is a no-op for pipe-free text, so every existing artifact is
byte-stable on re-plan.

## Reader: `_splitRowUnescapingPipes`

Plan's meta-index reconcile reader (the `#1310` positional cell parse)
replaced its naive `split('|')` with the same escaped-pipe-aware
character scan the run-side `TestListReader._splitRow` applies: split
only on UNESCAPED pipes, unescape `\|` back to a literal pipe. The
`#1310` keying contract (criterion = second-to-last cell) is preserved
exactly — criterion tokens are grammar-constrained and cannot contain
pipes, so the key extraction is insensitive to escaped pipes in
description cells.

## Not changed (hard constraints)

- core engine cycle, run driver, verify gate — untouched;
- spec-parser grammar — untouched (pipes remain legal FR prose);
- `test_list_reader.dart` — untouched; its `_splitRow` was already the
  contract the writer now satisfies.

## Verification

See `tdd/verification.md` — RED (2 failing tests, exact runner refusal
reproduced) → GREEN (2/2 pass) → 109/109 across the plan/reader
regression surfaces → `dart analyze` clean on changed files →
`dart format` clean repo-wide (2501 files, 0 changed).
