# Bug Spec: Route Plugin Dual-System Unreconciled

- **Slug**: route-dual-system-unreconciled
- **Source assessment**: ./assessment.md
- **TDD feature**: this directory
- **TDD mode**: ON

## Problem (reproduced)

The CLI Route Plugin (`lib/src/plugins/route/`) and the DDA Route Plugin
(`lib/src/dda/plugins/route/`) generate routes independently:

- CLI side drives `zfa route create|custom|deep-link|shell` and produces
  `*_routes.dart` from entity configs.
- DDA side reads `@ZfaRoute` / `@Route` annotations on View classes and produces
  `zfa_router.g.dart`.

When both run in the same project, no tool reconciles them: the same logical
route can be declared twice, one system can drift from the other, and the CLI
output is emoji-only with no machine-readable format.

## Acceptance Criteria (the fixed behavior)

Each criterion is observable from the public CLI / public artifacts and is the
target a failing test will pin.

- **AC1** — `zfa route verify` is reachable as a top-level subcommand. Given a
  project that has *both* a CLI-generated `*_routes.dart` and a DDA-annotated
  `*_view.dart` with `@ZfaRoute`, `zfa route verify` exits non-zero and prints
  one drift finding per conflicting route, including the source file of each
  side.
- **AC2** — `zfa route verify --json` emits a single `route-table.json` artifact
  on stdout (or to a file via `--out <path>`) containing the union of routes
  from both systems. Each entry has `{path, source: cli|dda, file, line, name}`.
  The JSON parses with `jsonDecode` and is stable across runs.
- **AC3** — `zfa route verify --plain` produces deterministic text output
  (no emojis, no color) suitable for CI logs. The same input yields byte-for-byte
  identical output across runs.
- **AC4** — A drift lint runs as part of `zfa build` (or `zfa route verify`)
  and warns when a `*_routes.dart` exists but no corresponding `@ZfaRoute`
  annotation is found, and vice versa. The warning is non-fatal by default;
  `--strict` upgrades it to non-zero exit.
- **AC5** — A regression test pins the route-table self-test (#842) continues
  to pass — i.e. we do NOT regress the existing probe-on-disk behavior while
  adding verify/json/plain.

## Reproduction (the failing scenario)

1. Create an entity: `zfa entity create -n Product --field id:String --field name:String`
2. Generate CLI routes: `zfa make Product --preset=crud --with=route` → produces `product_routes.dart`
3. Add a DDA annotation by hand on `ProductView`:
   ```dart
   @ZfaRoute(path: '/products')
   class ProductView extends StatelessWidget { ... }
   ```
4. Run `zfa build` → produces `zfa_router.g.dart`.
5. Observe: the same `/products` path is declared twice with no detection.
6. **Expected after fix**: `zfa route verify` reports a drift finding for
   `/products` with both source files.

## Out of Scope (this bug does NOT deprecate the CLI yet)

- The assessment's *Phase 2 / Phase 3* (deprecate `zfa route create|custom|deep-link|shell`,
  remove CLI route generation) is a follow-up. This bug adds `verify`, `--json`,
  `--plain`, and the drift lint — both systems keep working, but their state
  becomes observable.

## Files Likely To Change

- `lib/src/commands/route_command.dart` — add `verify` subcommand and
  `--json` / `--plain` / `--strict` / `--out` flags.
- `lib/src/plugins/route/route_plugin.dart` — surface the route table for
  verify; emit a `RouteTable` DTO that other plugins can consume.
- `lib/src/dda/plugins/route/route_plugin.dart` — expose its built route
  table through the same `RouteTable` DTO.
- `lib/src/cli/standard/output_format.dart` — add plain output mode.
- New: `lib/src/plugins/route/verify/route_verify.dart` — drift detection
  logic; reads CLI-side `*_routes.dart` from disk and DDA-side from
  `RouteTable`.
- New: `test/plugins/route/route_verify_test.dart` — unit tests for verify
  output, JSON shape, and drift detection.
- New: `test/cli/route_command_json_test.dart` — CLI integration test for
  `--json` / `--plain`.

## Risks

- Adding a new subcommand is additive; no existing CLI surface breaks.
- The drift lint default is `warn`, not `fail` — projects that already have
  both systems running will not see a hard failure.
- We must not regress the existing route-table self-test (#842).
