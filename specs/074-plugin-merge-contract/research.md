# Research: Plug-In Merge Contract (074)

## R1 — Route registration seam

The route plugin's capabilities (create/shell/deep-link) regenerate the
routing index so `getAllRoutes()` (returning `List<RouteBase>`) includes
new modules. **Decision**: merge triggers the same regeneration for the
landed feature's route modules and then proves registration by
resolving each manifest route path through the generated table. A route
name collision refuses naming the existing and incoming modules.

## R2 — DI graph check

The di plugin generates flavor-switched registrations (#893/#934); the
tdd smoke-test writer already emits a bootstrap smoke pattern.
**Decision**: merge generates a conformance test that constructs the
host graph and resolves every manifest token per flavor; the gate runs
it as a real test (evidence, not grep). A missing binding fails with
the token named.

## R3 — View convention check

071's proven view shapes + the app shell plugin define the host shell
convention (page composes the adaptive shell entry, not a bare
MaterialApp/Scaffold root). **Decision**: a structural (AST-lite)
check: each merged view artifact's root composition references the host
shell; violations refuse naming the file. Deliberately syntactic — no
widget-tree runtime needed.

## R4 — Rollback without git

Hosts may be dirty or not even git repos. **Decision**: before landing,
snapshot every file merge will touch (content-addressed copies under a
temp dir) + a fingerprint; on gate failure restore exactly those bytes
and verify the restore by re-hashing (byte-identical proof, FR-006/SC-002).

## R5 — Baseline-aware suite gate

#741/#953 established the run-baseline pattern. **Decision**: capture
pre-merge suite results; post-merge, new failures = failing NOW that
were green (or absent) at baseline. Pre-existing reds are reported and
never gate. The feature-suite check uses the same comparison scoped to
the feature's files.

## R6 — Idempotence

Landing copies are content-addressed; a re-merge with unchanged
artifacts writes identical bytes (no-op) and re-runs gates (cheap after
warm caches). Manifest records the last verdict.

## R7 — Alternatives rejected

- **git-based rollback**: rejected — hosts may not be repos; snapshot
  is self-contained.
- **Route registration by host file edit**: rejected — hand-editing is
  the defect; regeneration is the seam.
- **Running the whole host app for gates**: rejected — suite + graph
  construction are sufficient proofs and CI-safe.
