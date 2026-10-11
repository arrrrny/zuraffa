# Spec 1131 — [A+ UPGRADE] datasource: verify, receipts, --explain, error handling

**Issue:** #1131 · **Plugin:** `datasource` · **Grade path:** C → A+
**Branch:** `spec/1131-datasource-verify-receipts-explain`

## Mission

The datasource plugin is the data layer's foundation — every other plugin
depends on it — yet it shipped with no verify gate, no receipts on the
capability path, no `--explain`, and a generate() path that could escape as
an uncaught exception. A malformed datasource output goes undetected today.
This spec closes all four gaps without changing generation semantics.

## Orders

1. **`zfa datasource verify <Entity>`** (`DataSourceVerifyCommand`): verify
   that the generated datasource interface matches the entity's field
   signatures. Exit 0 on clean, exit 1 with `--> fix:` if any method
   signature drifts from the entity definition. `--json` emits the single
   canonical `verdict.v1` envelope (issue #1105).
2. **Receipts in `CreateDataSourceCapability.execute()`**: persist a
   `proof.v1` receipt at `.zfa/receipts/datasource-<entity>.json` carrying
   the datasource interface's sha256 (`interface_sha256`) and the entity
   source hash (`entity_source.sha256`) — on BOTH invocation paths (the
   `zfa datasource create` subcommand and the standalone positional path).
3. **`--explain`** on the datasource create path: describe which datasource
   types are generated (remote/local/mock/sqlite), which entity fields map
   to which methods (id-field → UpdateParams/DeleteParams/ToggleParams,
   query-field → get/watch, the rest flow through the entity type), and
   the interface shape (the signatures generation would emit). Read-only.
4. **Error handling**: wrap the FULL generate() path (config build →
   generation → receipt) in try/catch in both `plan()` and `execute()`;
   every exception becomes `ExecutionResult(success: false, ...)` with a
   reason and a `--> fix:` hint. A malformed entity never crashes.
5. **Provenance headers** on all generated datasource files (interface,
   remote, local), mirroring the provider convention (spec #979).

## Constraints

- Use the canonical envelope (issue #1105) for `--json` on verify.
- Do not change the generation semantics.
- One PR for this spec.

## Acceptance

- `zfa datasource verify <Entity>` reports conformance or drift.
- `.zfa/receipts/datasource-<entity>.json` exists after create.
- All generated datasource files contain the provenance header.
- A malformed entity does not crash with uncaught exception.
