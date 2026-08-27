# Data Model: make --test regenerates tests for id-less entities

**Feature**: 016-fix-make-test-no-id | **Date**: 2026-08-27

No persisted data changes — this feature only changes a runtime validation gate and a config-key resolution inside one command. This file documents the in-memory model the change introduces or touches.

## Entities (in-memory)

### Id-dependent plugin set (NEW)

- **Representation**: `static const Set<String>` on `MakeCommand` (named, greppable — FR-003).
- **Members** (justification in research.md R2):
  `repository, datasource, usecase, controller, presenter, service, provider, route, view, gql, graphql, sqlite, api, sync`
- **Lifecycle**: compile-time constant; never mutated.
- **Relationships**: deliberately disjoint from `_valueObjectRootPlugins` (a different concern: which plugins are dropped for value objects). `test`, `mock`, `gym`, `di`, `cache` etc. are intentionally absent → id-neutral.

### Representative query field (NEW resolution result)

- **Representation**: `EntityFieldInfo?` (existing class: `name`, `type`, `nonNullableType`) returned by a new `EntityFieldResolver.resolveRepresentativeField(...)`.
- **Selection rule** (research.md R4): first non-nullable `String` → first non-nullable `int` → first nullable `String`/`int` → first other non-enum scalar (`double`, `num`, `bool`, `DateTime`). Never a custom/enum type; never a synthetic `id`; `null` when the entity has no usable field.
- **Consumption**: written into `PluginContext.data['query-field']` / `data['query-field-type']` by `MakeCommand` — exactly the keys the existing `hasId` branch already populates for id-bearing entities, so downstream consumers (test/mock/gym plugins) need zero changes.

### EntityIdResolution (UNCHANGED)

- Existing resolver output (`kind`, `autoId`, `idField`, `isValueObject`, `hasId`). The no-id shape (`idField == null && !autoId`) now has two outcomes instead of one:

| Active plugins | Outcome for id-less entity |
|---|---|
| ∩ id-dependent ≠ ∅ | #307 loud failure (unchanged message + hints, exit 1, no files) |
| ∩ id-dependent = ∅ | proceed; query-field ← representative real field (if resolvable and not user-overridden) |

## Data flows

```text
resolvePlan → activePlugins ──┐
                              ├─► entity resolution (resolveIdField)
entity source file ───────────┘        │
                                  hasId? ── yes → populate id-field/query-field (unchanged)
                                   │
                                   no ──► id-dependent plugin active? ── yes → #307 throw (unchanged)
                                   │                                        (incl. mixed --test+usecase)
                                   └── no → resolveRepresentativeField →
                                            query-field/query-field-type (unless user-parsed)
                                            → manager.run → test plugin regenerates files
```

## Invariants

1. The #307 diagnostic (message + three remediation hints) is byte-identical whenever it fires.
2. `--query-field` / `--query-field-type` passed by the user are never overwritten.
3. No plugin under `lib/src/plugins/` changes behaviour for id-bearing entities or value objects.
