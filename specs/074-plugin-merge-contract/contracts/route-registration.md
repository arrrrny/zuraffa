# Contract: Route Registration (merge-time)

## Regeneration

Merge triggers the route plugin's existing routing-index regeneration
over the landed feature's route modules — the same seam
`create_route`/`shell_route`/`deep_link` capabilities use. The host
router file is never hand-edited: `getAllRoutes()` is regenerated to
include the feature's modules additively.

## Resolution proof

After regeneration, each manifest `RouteDecl.path` resolves through the
generated table to the declared page. The resolution check is pure
(table traversal) and reports per-route:

```text
/login -> LoginPage ✓
```

## Conflicts

An incoming route whose name or path collides with an existing host
route refuses BEFORE any landing: exit non-zero naming both modules and
the colliding path with

```text
--> fix: rename the incoming route module or remove the stale host route.
```

## Idempotence

Regeneration is additive and deterministic: re-merging a merged feature
regenerates an identical barrel (byte no-op).
