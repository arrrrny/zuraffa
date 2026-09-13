# Bug Assessment — #1486: Key Entities fields silently dropped without backticks

- **Slug**: 1486-entity-fields-backtick-parsing
- **Created**: 2026-09-13
- **Source**: bug report 1486 (task brief; phrased as GitHub issue #1486 on
  arrrrny/zuraffa)
- **Verdict**: valid
- **Severity**: critical (silent data loss at spec-parse time; first signal
  is a vacuous-green ~28 minutes into a run)
- **Related**: #1480 (template gap — spec authoring grammar never reaches a
  spec-kit project), #1429, #1381 (2-col table vanished silently — same
  silence family), #781, #919 (3-col table form), #829 (phase-0 entity
  orchestration)

## Symptom

A `## Key Entities` row that declares fields in perfectly readable prose —

```markdown
| Task | id: String, title: String, isCompleted: bool, createdAt: String | purpose |
```

— parses into a `SpecEntity` with **zero fields**, silently. Phase-0 then
generates a field-less entity (`zfa entity create -n Task` with no `--field`
args); the first signal anywhere in the pipeline is a vacuous-green deep
into the run.

## Root cause (confirmed against the tree)

`lib/src/plugins/tdd/services/spec_parser.dart` — the `_fieldPair` regex
requires backticks around the whole pair:

```dart
static final RegExp _fieldPair = RegExp(
  r'`([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^`]+)`',
);
```

Both call sites consume it verbatim: the table-row branch (fields cell of
the zuraffa-1.0 3-column table and the pre-#919 2-column table) and the
legacy bullet branch (`- **Task**: ...`). A plain `name: Type` pair matches
nothing; `SpecEntity.fields` defaults to `const []`; no anomaly is recorded
anywhere — the parse succeeds "successfully" with empty fields.

## Controlled experiment (reproduced in this session)

| Fields row form | `SpecEntity.fields` | Generated |
|---|---|---|
| `\| Task \| id: String, title: String \|` (plain) | `[]` | `abstract class $Task {}` (field-less) |
| `\| Task \| \`id: String\`, \`title: String\` \|` (backticked) | `[id:String, title:String]` | all fields present |

RED evidence: `test/plugins/tdd/services/bug_1486_entity_fields_backtick_parsing_test.dart`
run on the pre-fix tree — B1/B2/B3/B5/B6 fail with actual `[]` exactly as
the issue predicts; the backticked guards (B4/B8) pass (backwards-compat
baseline intact). Captured in `red-evidence.md`.

## Why the silence is the sharp part

The loss happens at the FRONT of a long pipeline, and every stage after it
is honest: `plan_command` writes `## Key entities` from the parsed fields
(a plain `name: Type` join — so the plan artifact is empty), `TestListReader.
readEntities` reads that empty section back, phase-0 creates (or reuses!)
the entity with no fields, and downstream `make` steps generate against a
hollow subject. Nothing downstream can distinguish "the spec declares no
fields" from "the parser dropped them" — that distinction is only available
at parse time, which is where the fix lives.

The reuse path is the worst case: a pre-fix run persists a field-less
entity on disk; a later, fixed run finds the file and reports
`phase-0 entity Task -> reused` — the plan's now-correctly-parsed fields
are still ignored, again silently.

## Remediation (what this fix does)

1. **Unbackticked fallback for table cells** (both 2-col and 3-col forms):
   the fields cell is the pair-dedicated grammar — backticked, plain, and
   mixed pairs all parse, in source order, with top-level-comma splitting
   that respects nested `<...>`/`(...)` generics (`Map<String, int>`).
   Bullet prose keeps the strict backticked-only covenant: ordinary prose
   colons (`Note: this file is generated`) must not mint fields.
2. **Positive-evidence-empty detection**: a cell that SHOWS pair evidence
   (a backtick span or an `identifier:` shape) but still parses to zero
   fields yields a `SpecEntityFieldAnomaly(entity, cell, line)`.
   `zfa tdd plan` prints a per-row WARNING (the #1381 warning's sibling)
   instead of losing the row silently.
3. **Phase-0 reuse logs field mismatch**: when the loop reuses an existing
   entity file whose `final` members diverge from the plan's declared
   fields, the driver names both sets (print-only; reuse semantics
   unchanged). A pre-fix field-less entity reused by a fixed run is no
   longer invisible.

Constraint adherence: the state machine, gen, and loop semantics are
untouched — the parsing fix lives entirely in `spec_parser.dart`; the two
signal paths are print-only additions (plan warning + phase-0 reuse log).
