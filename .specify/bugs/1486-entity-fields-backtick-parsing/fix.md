# Fix — #1486: entity fields — accept unbackticked pairs; warn on
# positive-evidence-empty

- **Slug**: 1486-entity-fields-backtick-parsing
- **Branch**: `fix/1486-entity-fields-backtick-parsing`
- **Constraint adherence**: parsing semantics live entirely in
  `spec_parser.dart`; the state machine, gen, and loop semantics are
  untouched. The two new signals are print-only.

## 1. `spec_parser.dart` — the parsing fix

### The pair shape

`_fieldPairShape` — `^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+)$` — is the single
`name: Type` shape, applied two ways by `_parseFieldCell(cell)`:

- **Backticked spans** (backwards compatible by construction): the cell is
  walked as alternating in/out-backtick segments. Each span's RAW content
  must match the pair shape with the identifier opening the span and the
  type running to the closing backtick — exactly the old `_fieldPair`
  semantics (commas inside a span stay part of the type; an untrimmed
  trailing type such as `` `a: ` `` still yields the same whitespace type
  the old regex produced, which the caller then trims).
- **Unbackticked text** between spans (and any trailing tail): split on
  top-level commas only — a comma nested in `<...>` / `(...)` belongs to
  its type (`Map<String, int>`, `List<List<int>>`) — then each fragment
  must match the pair shape. Shapeless fragments are skipped, never minted.

An unterminated backtick span degrades to plain-pair parsing rather than
vanishing (the exact silence #1486 forbids).

Scope: **table cells only** (both the zuraffa-1.0 3-column form and the
pre-#919 2-column form). Bullet prose keeps `_fieldPair` verbatim — free
prose may carry ordinary colons, so only the explicit backtick covenant may
mint fields there (false-positive guard, pinned by guard B8).

### Positive-evidence-empty detection

`_fieldCellEvidence` — `` `|[A-Za-z_][A-Za-z0-9_]*\s*: `` — marks a cell as
DECLARING intent. Evidence + zero parsed fields ⇒ the row yields a
`SpecEntityFieldAnomaly(entity, cell, line)` (new public record; the cell
is kept verbatim, the line is the 1-based spec line). `parseKeyEntities`
gains an optional `anomalies` out-param — additive, every existing caller
is source-compatible.

### Phase-0's comparison helper

`SpecParser.entityFieldNamesFromDartSource(source)` extracts the field
names an on-disk entity declares (`final`/`late final` members;
assignment-initialised locals are excluded by the `=`; constructor params
carry no `final`). Best-effort by design — it feeds a warning, never a
gate.

## 2. `plan_command.dart` — warn at plan time (print-only)

The #1381 zero-entity warning keeps its behavior; its per-row sibling now
names every anomaly:

```
zfa tdd plan: WARNING — Key Entities row `Task` (spec line N) declares
field pairs that parsed to zero fields (cell: `1id: String`) — fix the
field grammar or the entity will be created field-less (issue #1486).
```

The author learns in seconds, not 28 minutes into a run.

## 3. `run_driver_core.dart` — phase-0 reuse logs field mismatch
(print-only)

The reuse branch (`locateEntityFile != null`) now compares the plan's
declared field names against `entityFieldNamesFromDartSource` of the file
on disk; on divergence it prints:

```
[run] phase-0 entity Task -> field mismatch: plan declares [id, title,
isCompleted, createdAt], entity file declares [id] — reuse keeps the
on-disk shape (issue #1486)
```

Reuse semantics are byte-for-byte unchanged: the comparison never gates,
never mutates, and a read failure stays quiet. The pre-fix field-less
entity that a later run silently reuses is now named.

## Files touched

| File | Change |
|---|---|
| `lib/src/plugins/tdd/services/spec_parser.dart` | pair-shape/cell-evidence regexes, `_parseFieldCell`, `SpecEntityFieldAnomaly`, `parseKeyEntities(anomalies:)`, `entityFieldNamesFromDartSource`, docs |
| `lib/src/plugins/tdd/commands/plan_command.dart` | consume anomalies → per-row WARNING (print-only) |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | reuse branch logs declared-vs-on-disk field mismatch (print-only) |
| `test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart` | B1–B9 (new suite) |

## Known behavior notes (deliberate, documented)

- In a table cell, unbackticked `identifier: text` pairs now parse — a
  fields cell is the pair-dedicated grammar. A stray prose colon inside a
  fields cell can therefore mint a field; that is the grammar the issue
  asks for (the cell exists to carry pairs). The evidence-empty warning
  catches the malformed remainder.
- An unbalanced backtick in a table cell now degrades to plain-pair
  parsing instead of silently yielding `[]`.
