**Template Version**: `zuraffa-1.0`

# Spec: 1381-entity-table-2col

GitHub issue: arrrrny/zuraffa#1381 (verify-misfire / spec-drift, EPIC
#1014 exit criterion 3 / #1001 deliverable 3)

## Summary

`SpecParser.parseKeyEntities` matched ONLY the zuraffa-1.0 3-column
header, so a pre-#919 2-column `| Entity | Fields |` table extracted ZERO
entities silently. `zfa tdd plan` then wrote a test list without the
`## Key entities` section (no warning), and `RunEngineGate.checkFeature`
derived zero CORE entities — the certification refusal branch was
unreachable: the gate passed trivially with the certification receipt
deleted.

## Locked decisions

1. Remedy (a): `_entityTableHeader2Col` + `_entityTableRow2Col` — the
   parser accepts the pre-#919 2-column grammar (bug #919 kept pre-919
   artifacts readable everywhere else); purpose is empty for 2-column
   rows.
2. Remedy (b): `plan_command` prints a warning naming the section when
   the spec declares `## Key Entities` but zero entities were extracted
   — the silent loss becomes visible for shapes beyond the 2-column
   grammar.
3. Remedy (c) (the gate surfacing `core-entities=0`) is recorded as
   follow-up hardening, not taken here — with (a)+(b) the gate's input
   is correct at the source.
4. The 3-column grammar, bullet-declared entities, and every other
   parser behavior are unchanged.

## Functional requirements

- **FR-1**: a 2-column Key Entities table extracts entities with their
  fields (purpose empty).
- **FR-2**: the 3-column grammar is unchanged (guard).
- **FR-3**: a declared-but-unparseable Key Entities section makes plan
  print the #1381 warning.

## Acceptance scenarios

1. 2-column table → one entity `Login` with id/username/token fields (B1).
2. 3-column table → unchanged extraction incl. purpose (B2 guard).
3. Zero-extraction section → plan prints the warning naming
   `## Key Entities` and the extraction failure (B3).

## Success criteria

- **SC-001**: The run-engine cert gate can no longer pass trivially on a
  pre-#919 spec — the entities extract, so the gate enforces
  certification as designed.
- **SC-002**: The spec parser and plan suites stay green.

## Assumptions

- The parser's field-pair extraction (`_fieldPair`) works identically on
  the 2-column Fields cell.
