# Bug Issue: [TDD-120] Entity orchestration inside the TDD loop: spec Key Entities → entity create → make → wire

- **Slug**: tdd-entity-orchestration-loop
- **Fetched**: 2026-09-02
- **Issue**: 829
- **URL**: https://github.com/arrrrny/zuraffa/issues/829
- **State**: closed
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: Most of the 120 specs declare Key Entities (ZikZakConfig, Listing, Spark, ScrapeTask, PriceCheckRun, RebateClaim...). The pure-function generator path (fix #728) made unit behaviors pass, but that produces empty subjects — it sidesteps the architecture. The REAL pipeline must generate the domain layer.

The TDD loop never reads the spec's Key Entities. The agent had to run `zfa entity create` manually; `zfa tdd wire` then refused subjects it did not generate via `func`.

Required (system fix):
1. `zfa tdd plan` extracts Key Entities from spec.md into the test-list/plan artifact (entity → fields where the spec carries them).
2. `zfa tdd run` phase 0: idempotent `zfa entity create` for each declared entity + `zfa build`, BEFORE behaviors are driven.
3. Unit behaviors traced to an entity's FR route to the ENTITY pipeline: gen → verify-red → `zfa make <Entity>` (usecases/repos/di) → `zfa tdd wire <behavior> --entity <Entity>` → green.
4. `zfa tdd wire` shape detection fixed to accept the current gen'd stub shape.
5. If an entity already exists, reuse; never regenerate over hand-tuned fields without `--force` + diff report.

## Comments

None.
