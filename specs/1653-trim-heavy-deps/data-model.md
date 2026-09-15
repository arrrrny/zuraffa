# Data Model: 1653-trim-heavy-deps

## Entities

### OptionalPlugin (core, CLI-internal model)

One optional capability, its backing package, and its project-local
enablement state.

| Field | Type | Constraints | Purpose |
| -- | -- | -- | -- |
| `name` | String | one of the catalog ids: `graphql`, `storage`, `observability` | the capability id used on the CLI and in `.zfa.json` |
| `package` | String | pub package name: `zuraffa_graphql`, `zuraffa_storage`, `zuraffa_observability` | the companion package the developer adds |
| `enabled` | bool | persisted per project in `.zfa.json` `plugins:` | explicit opt-in state (FR-006) |
| `resolvable` | bool (derived, never persisted) | read from the target project's `package_config.json` at command time | whether the backing package is actually usable right now (FR-007/FR-008) |

Validation rules:

- `name` must be a catalog id — an unknown id refuses with the catalog
  list (never silently ignored).
- `enabled` is written only by the enable action (idempotent: enabling an
  enabled plugin rewrites the same value and reports no-op).

### PluginCatalog (core, static)

The ordered set of `OptionalPlugin` definitions compiled into core. It is
the single source of truth for `zfa plugin list`, for the gated commands'
guidance text, and for the enable action's package name. Heavy capability
implementations never live here — only their names, packages, and gate
logic.

### TraceObserver (core, NEW light seam)

Replaces the concrete `OtelTracer.instance` reads in the HookContext
assembly path.

| Member | Signature (conceptual) | Notes |
| -- | -- | -- |
| `currentTraceId` | `String?` | no-op default returns null |
| `currentSpanId` | `String?` | no-op default returns null |

The observability companion ships the otel-backed implementation and
registers it; core's default keeps core-only behavior identical to
"tracing absent" (null ids), matching today's behavior when no span is
active.

## State transitions

```text
OptionalPlugin lifecycle (per project):
  absent (default) --enable--> enabled
  enabled --enable (again)--> enabled (no-op success)
  enabled, package missing --> refusal with "add <package>" guidance
  absent, command touched --> refusal with "enable + add" guidance
```

`.zfa.json` shape (additive; existing keys untouched):

```json
{
  "plugins": {
    "graphql": true,
    "storage": false,
    "observability": true
  }
}
```

## Relationships

- `PluginCatalog 1..* OptionalPlugin` — static definitions.
- `OptionalPlugin 1..1` backing package in `packages/` — the companion
  carries the heavy implementation; core carries only the catalog entry
  and the gate.
- `TraceObserver` implemented-by the observability companion; consumed-by
  `Hook`/`UseCase`/`StreamUseCase` in core.
