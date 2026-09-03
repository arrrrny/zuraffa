# Chore Issue: make default → mock path: MOCKED tier, contract-conforming green (func-stub becomes --stub)

- **Slug**: make-default-mock-path
- **Fetched**: 2026-09-03
- **Issue**: 909
- **URL**: https://github.com/arrrrny/zuraffa/issues/909
- **State**: open
- **Author**: arrrrny
- **Labels**: none

## Body

"Part of #908 (Mock-First Realization).

## Why

Current make default (func-stub) produces shallow green: 'subject_u1() => 0' proves nothing. The legacy zik_zak already validated the architecture: 165 mock files, mock datasources behind interfaces, DI-swapped. zfa mock create already emits the full trio (mock data + datasource interface + mock datasource) — verified live. The TDD loop must route through it.

## Required

1. 'zfa tdd make' default path: 'zfa mock create' for the behavior's entity/contract → wire mock datasource via DI → target test green against the MOCK. State: MOCKED.
2. run-state gains the MOCKED tier between green-real and done; suite-green at MOCKED = contract conformance (real evidence, not stub-pass).
3. func-stub path demoted to explicit '--stub' escape hatch; cycle-log marks stub-era evidence distinctly so verify can reject stub-only green from counting as contract-proven.
4. Fixture provenance: mock-data hashes bound into cycle-log evidence.

## Absorbs

- The default-path discussion from #829/#830 workflows
- Fixture provenance line from old #848 DoD"

## Comments

None.
