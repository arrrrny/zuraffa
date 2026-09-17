Fixes #1661 (feature spec: `specs/1653-trim-heavy-deps`)

## Summary

Adding zuraffa 6.3.0 grew dart_curl's lockfile by **+439 lines**, dragging
the GraphQL, S3/minio, and OpenTelemetry stacks into every consumer of a
"lean" package. This PR trims `graphql`, `gql`, `minio`, and
`opentelemetry` out of the core manifest and barrel while keeping every
capability reachable through zfa — per the maintainer directive: **zfa can
still add these as opt-in plugins, and when enabled they seamlessly run as
zfa commands.**

## What changed

**Core stays lean**
- Root pubspec drops all four heavy packages; a fresh core-only consumer
  now resolves a graph with **zero** of them (no protobuf/xml baggage).
- `lib/zuraffa.dart` stops re-exporting `package:opentelemetry/api.dart`,
  `MinioClient`, `TelemetryHook`, and the moved graphql surfaces.
- Pure-Dart graphql codegen helpers (schema parser, type mapper, entity/
  DTO/union/repository generators, cache/diff/SDL) stay in core.
- Light seams stay in core: `TraceObserver` (new — replaces the concrete
  `OtelTracer` reads in `Hook`/`UseCase`/`StreamUseCase`), the failure-
  reporter registry (no-op default), and `ArtifactHook`.

**Capabilities become opt-in plugins**
- New in-repo companions (federated family shape): `packages/zuraffa_graphql`
  (client, gql documents, heavy codegen, validator, slice orchestrator,
  generate command), `packages/zuraffa_storage` (`MinioClient` + both MinIO
  hooks), `packages/zuraffa_observability` (otel tracer/reporter/
  `TelemetryHook`, simulation `OtelAdapter`, `ZuraffaObservability.init`
  wiring the otel-backed `TraceObserver`).
- New `zfa plugin` capability facet: `list` renders capabilities/packages/
  resolvable-state; `enable <name>` persists `capabilities.<name>` in
  `.zfa.json` additively and idempotently, printing the package to add;
  unknown ids refuse naming the catalog.
- The `zfa graphql` command entry is gated: not-enabled → guidance naming
  `zfa plugin enable graphql`; enabled-but-missing → guidance naming the
  package + `dart pub get`; enabled+resolvable → runs seamlessly.

## TDD evidence (red → green → audit)

- RED first: manifest/barrel pins failed on the untrimmed tree; the
  plugin-gate pins captured the pre-existing generation-only behavior.
- GREEN: pins 22/22; companions 47 / 14+1skip / 19 tests green
  (`dart analyze` 0 errors in all three); affected root lanes
  +541 / +734 / +22 all green.
- Mutation probes killed: gate disabled → U6 fails; heavy dep
  reintroduced → U1 fails. (The audit caught a vacuous first version of
  the U1 regex — fixed with the mutation, re-proven red→green.)
- Full evidence: `specs/1653-trim-heavy-deps/tdd/verification.md`
  (verdict **PASS_WITH_GAPS**), `tdd/cycle-log.md`, `red` evidence in the
  cycle log, `CHANGELOG.md` migration map.

## Known gaps (follow-ups, recorded in verification.md)

- Core→companion delegation for `graphql generate` is seam-designed and
  gate-tested, not yet process-tested end-to-end.
- The default lane was verified in chunks (kernel-cache disk hazard),
  not as one invocation.
