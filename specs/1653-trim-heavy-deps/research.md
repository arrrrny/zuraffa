# Research: 1653-trim-heavy-deps

Phase 0 output. Each decision resolves a plan-level unknown with evidence
from the tree (greps run 2026-09-15 on `1653-trim-heavy-deps` @ master
c5ed519f+).

## D1 — Which files physically carry the heavy dependencies?

**Decision**: exactly 15 in-repo source files import the four heavy
packages; they (and only they, plus their heavy-only dependents) must move
or be de-typed.

**Evidence** (`grep -rl 'package:(graphql|gql|minio|opentelemetry)/' lib bin`):

- graphql/gql (11 + barrel):
  `lib/src/graphql/client/graphql_client_factory.dart`,
  `graphql_client_provider.dart`, `subscription_stream.dart`,
  `codegen/datasource_generator.dart`, `codegen/di_generator.dart`,
  `gql/documents_dart_generator.dart`, `gql/graphql_document_builder.dart`,
  `gql/naming_utils.dart` (no direct heavy import — rides the gql family),
  `preservers/gql_file_preserver.dart`,
  `validators/graphql_validator.dart`, plus the barrel's re-exports.
- opentelemetry (3): `lib/src/core/otel_tracer.dart`,
  `otel_failure_reporter.dart`, `telemetry_hook.dart`
  (`import 'package:opentelemetry/api.dart' show Attribute, Span;`).
- opentelemetry-adjacent (de-type, do NOT move):
  `lib/src/simulation/simulation_adapters.dart`
  (otel api + sdk imports), `lib/src/core/hook.dart`,
  `lib/src/domain/usecase.dart`, `lib/src/domain/stream_usecase.dart` —
  these read ONLY `OtelTracer.instance.currentTraceId` / `currentSpanId`
  (plain strings), so a light in-core seam replaces the concrete read.
- minio (1): `lib/src/core/minio_client.dart`.
- `lib/zuraffa.dart` re-exports `package:opentelemetry/api.dart` directly
  (line 210) — that line is deleted with the migration entry.

**Rationale**: moving by "imports a heavy package" is mechanically
checkable (a test can enforce it — the dependency-manifest pin) and keeps
the pure-Dart GraphQL codegen helpers (schema_parser, type_mapper,
entity_generator, …) in core where core-only codegen users still need them.

**Alternatives considered**:
- Move ALL of `lib/src/graphql/` — rejected: over-moves pure-Dart
  generators that never touch the heavy packages, widening the breaking
  surface for nothing.
- Keep heavy code but guard imports behind `deferred` loading — rejected:
  Dart deferred loading does not remove pubspec dependencies; the lockfile
  complaint (the issue's headline) would remain.

## D2 — How deep do opentelemetry TYPES reach into core?

**Decision**: one seam de-type. `HookContext.traceId/spanId` are strings;
the only otel-typed core surface is `TelemetryHook` (Attribute/Span),
which moves wholesale to `packages/zuraffa_observability`.

**Evidence**: `domain/usecase.dart:70-71`, `stream_usecase.dart:69-70`,
`core/hook.dart:192-193` read `OtelTracer.instance.currentTraceId /
currentSpanId`; nothing else in `domain/` touches otel.

**Rationale**: a light `TraceObserver` seam in core (returns
`String? traceId` / `String? spanId`; no-op default) preserves the
HookContext data for every core user, and the otel-backed observer
registers from the companion when enabled — the seams-are-contracts rule
(FR-009).

**Alternatives considered**: keep `OtelTracer` in core behind a null
check — rejected: it imports `package:opentelemetry`, keeping the dep.

## D3 — Where does heavy code GO?

**Decision**: three companion packages under `packages/`:
`zuraffa_graphql` (graphql/gql client + gql documents + heavy codegen),
`zuraffa_storage` (minio MinioClient), `zuraffa_observability`
(otel tracer/reporter + TelemetryHook + the simulation otel adapter).
Standard independent Dart packages (own pubspec, own test dir); NOT a pub
workspace, so the root package's CI resolution is untouched.

**Rationale**: the spec's Assumption names the federated family shape;
separate packages per capability keep each adopter's tree minimal (the
anti-goal would be one mega-companion re-coupling all three stacks).
In-repo placement makes the enabled-path (FR-007) testable via path
dependencies and keeps the whole feature in one reviewable PR-family.

**Alternatives considered**:
- Separate GitHub repos — rejected for this feature: untestable in-repo,
  splits the review; the shape stays publishable later.
- Pub workspace — rejected: changes root resolution semantics and CI
  flows for every unrelated suite; the benefit (shared lockfile) is not
  wanted here.

## D4 — How does "enabled" persist and how does zfa see it?

**Decision**: `.zfa.json` gains `plugins: {graphql: bool, storage: bool,
observability: bool}` written by `zfa plugin enable <name>` (idempotent);
`zfa plugin list` renders name/state/backing-package from a static
in-core registry (`OptionalPlugin` catalog). "Resolvable" = the backing
package appears in the TARGET project's `package_config.json`
(the same resolution seam `ZuraffaBarrelExports` already uses — precedent
for reading package_config).

**Rationale**: `.zfa.json` is the documented project-memory config
surface (AGENTS.md); package_config reading has in-repo precedent
(`zuraffa_barrel_exports.dart`), so FR-007's "resolvable" check needs no
new discovery machinery.

**Alternatives considered**:
- Enabled = "package in package_config" only (no .zfa.json flag) —
  rejected: FR-006 requires an explicit recorded enablement and the
  enable step must work BEFORE the package is added (it prints what to
  add).
- New sidecar file — rejected: `.zfa.json` exists for exactly this.

## D5 — What happens to the CLI surface for graphql?

**Decision**: `zfa graphql generate` and the plugin-derived options stay
REGISTERED in core but become gated: enabled + resolvable → the command
delegates to the companion implementation (path-resolvable in-repo via
the companion package's CLI entry; spawned through the `ZfaExecutable`
no-JIT seam rules); otherwise → exit non-zero with the FR-008 guidance.
No command is removed; no flag changes.

**Rationale**: "seamlessly run as a zfa command when enabled" is the
maintainer's directive; keeping registration in core with delegation
preserves the UX while the heavy code lives in the companion.

**Alternatives considered**:
- Move command registration into the companion (plugin discovery) —
  rejected for this feature: dynamic command discovery is a larger
  architectural change (spec 1601's territory); the gated-stub keeps this
  feature's diff scoped.

## D6 — What moves in TESTS?

**Decision**: the 3 test files importing heavy packages move to the
companion packages' test trees (adjusted imports); core keeps a NEW pin
suite: the dependency-manifest pin (no heavy package in root pubspec, no
heavy import anywhere under `lib/`, no heavy export in the barrel — the
FR-001..004 mechanical enforcement) and the plugin-gate suites.

**Rationale**: the pin suite is what keeps core lean forever (SC-001/002
become regression-enforced, not one-time).

**Alternatives considered**: keep heavy suites in core with a skip
marker — rejected: dead weight in core CI; the companions own their
coverage.
