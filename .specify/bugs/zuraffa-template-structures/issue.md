# Bug Issue: zfa parses the zuraffa template's declared structures: Key Entities table, Dependencies & Contracts, Layer Contracts, Template Version pin

- **Slug**: zuraffa-template-structures
- **Fetched**: 2026-09-03
- **Issue**: 919
- **URL**: https://github.com/arrrrny/zuraffa/issues/919
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

"Part of #908 (Mock-First Realization). Blocks the zuraffa template from dictating the flow — the template declares structures zfa must consume.

## Context

The zuraffa spec template (`zuraffa-1.0`, shipped in speckit-extensions/zuraffa) is now the owned contract. Verified live in a test project: `zfa tdd plan` parses the core sections cleanly (Given/When/Then ACs → acceptance behaviors, FR-xxx → unit behaviors, persistence-kind tagging works). But the template's NEW declarative sections — the ones that make it more than core spec-kit — are invisible to zfa.

Repro project: `~/zik_zak_test/specs/001-shoe-size-tracker/spec.md` (spec authored from the zuraffa template).

## Work item 1: parse Key Entities table → phase-0 entity create

The template declares entities as a markdown table:

```markdown
| Entity | Fields | Purpose |
|--------|--------|---------|
| ShoeSizePreference | `id: String`, `brand: String`, `sizeEu: double`, `savedAt: DateTime` | One saved shoe size for one brand |
```

zfa's entity extractor expects the legacy bullet format (`- **Name**: description`) and ignores the table. Consequence: `zfa tdd run` on the test project starts driving behaviors with **no phase-0 entity creation** — ShoeSizePreference never exists, unit behaviors route to func-stubs.

Required:
- `zfa tdd plan` extracts entities from the table: name from column 1, fields from column 2 (backtick-enclosed `name: Type` pairs), purpose from column 3.
- Phase-0 runs `zfa entity create -n <Name> --field <n>:<T> ...` for each row, exactly as the bullet-format path does today.
- Both formats supported (bullet = legacy specs, table = zuraffa-1.0).

## Work item 2: parse External Dependencies & Contracts table → mock-first input

```markdown
| Dependency | Type | Contract | Mock Priority |
|-----------|------|----------|---------------|
| Hive | storage | `read(key) -> ShoeSizePreference?`, `write(key, value) -> void` | P1 |
```

This table is THE input for the mock-first make path (#909): each row declares what `zfa mock create` must generate a contract-conforming mock for. Today it is parsed by nothing.

Required:
- `zfa tdd plan` extracts the dependencies table into the plan artifact (feature's tdd/ or the registry).
- `zfa tdd make` (mock-default path, #909) reads declared dependencies and routes each to `zfa mock create` with the contract shape.
- "No undeclared dependencies" becomes a lint: a behavior referencing an external not in the table = exit 2 with the fix.

## Work item 3: parse Layer Contracts → interface generation targets

```markdown
**Domain**:
- `ShoeSizePreferenceRepository`: `save(ShoeSizePreference) -> Future<Result<void, AppFailure>>`, ...
```

The spec declares the exact repository/datasource signatures. Generated interfaces should MATCH these declarations (or the spec is wrong and planning should say so).

Required:
- `zfa tdd plan` extracts declared layer contracts into the plan artifact.
- `zfa make <Entity>` generates repository/datasource interfaces consistent with the declared signatures; a declared method the generator cannot express = exit 2 naming the method (the #829 lineage's honesty rule).

## Work item 4: verify Template Version → treaty pin

The template header carries:

```markdown
**Template Version**: `zuraffa-1.0`
```

Required:
- `zfa tdd plan` reads the marker; unknown or missing version = **exit 3** (contract drift) with `--> fix:` pointing at the zuraffa extension install.
- Known versions pin the parser grammar expected for items 1-3 (a zuraffa-2.0 template with breaking section changes fails loudly, not confusingly).

## Acceptance

On the test project (`~/zik_zak_test`, spec 001-shoe-size-tracker):
1. `zfa tdd plan` announces `phase-0 entity ShoeSizePreference -> created` with fields from the table
2. Dependencies table present in the plan artifact; make's mock path consumes it
3. Generated `ShoeSizePreferenceRepository` matches the declared Layer Contract signatures
4. Removing the Template Version line → exit 3 with fix line
"

## Comments

None.
