# Bug Assessment: Route Plugin Dual-System Unreconciled

- **Slug**: route-dual-system-unreconciled
- **Created**: 2026-09-04
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Fix the bad route — Good: self-proving via generated route-table tests (#842); genuinely idempotent, probes on-disk reality instead of trusting flags. Bad: two route systems (CLI vs DDA annotation) unreconciled; emoji-only output. Add: --json route-table artifact + zfa route verify + drift lint between the two generators.

## Symptom

Zuraffa has two independent route generation systems that do not reconcile with each other:

1. **CLI Route Plugin** (`lib/src/plugins/route/`) — Driven by `zfa route create|shell|deep-link|custom` commands. Generates `*_routes.dart` files from entity definitions via `RouteBuilder`.
2. **DDA Route Plugin** (`lib/src/dda/plugins/route/`) — Driven by `@ZfaRoute`/`@Route` annotations on View classes. Generates `zfa_router.g.dart` via `RouteDDAPlugin`.

When both systems are used in the same project, they produce conflicting or duplicate routes with no drift detection. Output is emoji-only (⚠️, ℹ️, ⏭) with no machine-readable `--json` option.

## Reproduction

1. Create entity with `zfa entity create -n Product --field id:String --field name:String`
2. Run `zfa make Product --preset=crud --with=route` (CLI generates `product_routes.dart`)
3. Add `@ZfaRoute(path: '/products')` to `ProductView` class manually
4. Run `zfa build` (DDA generates `zfa_router.g.dart`)
5. Observe: two route definitions exist with no conflict detection or merge

## Suspected Code Paths

- `lib/src/plugins/route/route_plugin.dart` — CLI route plugin entry point
- `lib/src/plugins/route/builders/route_builder.dart` — CLI route generation logic
- `lib/src/dda/plugins/route/route_plugin.dart` — DDA annotation processor
- `lib/src/dda/plugins/route/route_annotation.dart` — `@ZfaRoute`/`@Route` annotation definitions
- `lib/src/commands/route_command.dart` — `zfa route` CLI command
- `lib/src/cli/standard/output_format.dart` — output formatting (emoji-only)

## Root Cause Hypothesis

**High confidence**: The CLI and DDA route systems were built independently and never integrated. The CLI system derives routes from entity config and `--methods` flags. The DDA system derives routes from annotations on View classes. There is no:
- Single source of truth for routes
- Drift detection between CLI-generated and DDA-generated routes
- Unified output format (CLI uses emojis, DDA outputs nothing visible)
- `--json` flag to emit machine-readable route table

## Proposed Remediation

**Preferred**: Unify the two systems by deprecating the CLI-driven route generation in favor of the annotation-driven DDA system, which is more flexible and developer-controlled. Provide:
1. **`zfa route verify`** — compares CLI-generated routes against DDA annotations, reports drift
2. **`--json`** — emits `route-table.json` artifact with all declared routes
3. **Drift lint** — warns when `*_routes.dart` exists but corresponding `@ZfaRoute` annotation is missing (and vice versa)
4. **Emoji-free `--plain`** flag — text-only output for CI/scripts

**Migration path**:
- Phase 1: Add `zfa route verify --json` to surface both systems' output
- Phase 2: Deprecate `zfa route create|shell|deep-link|custom` (emit warning)
- Phase 3: Remove CLI route generation, keep only DDA annotations

**Alternatives**:
- Keep both systems but add a `routeMode: 'cli' | 'dda'` config option in `.zfa.json` to select which system runs
- Hybrid: CLI generates initial routes, DDA annotations override/explain CLI output

**Files likely to change**:
- `lib/src/commands/route_command.dart` — add `--json`, `--verify` flags
- `lib/src/plugins/route/route_plugin.dart` — add verify/drift detection
- `lib/src/cli/standard/output_format.dart` — add plain output mode
- `lib/src/dda/plugins/route/route_plugin.dart` — add route table JSON export
- New: `lib/src/commands/route_verify_command.dart` or integrate into existing

**Tests to add or update**:
- `test/plugins/route/route_verify_test.dart` — drift detection between systems
- `test/cli/route_command_json_test.dart` — `--json` output format
- `test/regression/route_dual_system_test.dart` — both systems coexisting

## Risks & Considerations

- **Breaking change**: Projects using `zfa route create` will need annotation migration
- **Backwards compatibility**: Must support existing CLI route generation during transition
- **Migration cost**: All existing `*_routes.dart` files need conversion to `@ZfaRoute` annotations
- **Adoption**: DDA requires developers to add annotations manually; CLI is fully automated

## Open Questions

- [NEEDS CLARIFICATION: Should existing CLI-generated routes be auto-converted to annotations, or manual migration?]
- [NEEDS CLARIFICATION: What is the timeline for deprecating CLI route commands?]
- [NEEDS CLARIFICATION: Should `zfa_router.g.dart` replace `app_routes.dart` or coexist?]
