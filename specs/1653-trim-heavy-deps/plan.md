# Implementation Plan: Lean Core — heavy integrations become opt-in zfa plugins

**Branch**: `1653-trim-heavy-deps` | **Date**: 2026-09-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/1653-trim-heavy-deps/spec.md` (issue [#1661](https://github.com/arrrrny/zuraffa/issues/1661))

## Summary

Drop `graphql`, `gql`, `minio`, and `opentelemetry` from the core zuraffa
package's dependencies and public barrel so a core-only consumer's resolved
graph stops carrying the heavy stacks (the issue's +439-lockfile-line
complaint), while keeping every heavy capability reachable through zfa: a
plugin gate (`list` / `enable`, persisted in `.zfa.json`) plus seamless
delegation — when a capability is enabled and its companion package is
resolvable, the existing zfa command surface works unchanged; when not, every
entry point refuses with guidance naming the exact fix. The heavy-backed
files move to companion packages under `packages/` (the federated-plugin
family shape the repo already scaffolds); core keeps the LIGHT seams
(`Hook`/`HookContext` trace fields, failure-reporter registry, module
lifecycle) with no-op defaults.

## Technical Context

**Language/Version**: Dart 3.11+ (repo SDK constraint `^3.11.0`; verified locally with Dart 3.13.2 stable)

**Primary Dependencies**: core keeps `args`, `logging`, `path`, `yaml`,
`uuid`, `zorphy`(+annotation), `json_annotation`, `crypto`, `http`,
`code_builder`, `dart_style`, `analyzer` (CLI/codegen), `get_it`, `meta`,
`glob`, `archive`, `hive_ce`, `nocterm`, `vm_service` (out of scope per
spec Assumptions). REMOVED from core: `graphql`, `gql`, `minio`,
`opentelemetry` — they move to the companion packages.

**Storage**: N/A for core behavior; `.zfa.json` gains a `plugins:` section
(enablement persistence); companion packages are standard Dart packages.

**Testing**: `dart test` (fast unit suite by default; `--preset=regression`
for the slow tier — `test/README.md`, AGENTS.md "Validation guidance").
`dart analyze` on touched files. Companion packages get their own
`dart analyze`/`dart test` gates. Heavy-surface suites move with their code;
`dart pub get` in the root proves the manifest trim resolves.

**Target Platform**: Any OS with a Dart 3.11+ VM; CLI only in the core
package's own paths (no Flutter SDK in the CLI path — Constitution VII).

**Performance Goals**: Negligible runtime delta; the plugin-list command
cold-starts under a second (SC-004). Dependency resolution shrinks (the
feature's point).

**Constraints**: The retained core surface must compile byte-compatibly for
core-only users apart from the REMOVED heavy exports (breaking, documented
per FR-010). No hand-edited generated code. The `before_specify` branch
contract and the TDD no-JIT spawn rules (AGENTS.md) hold. Existing heavy
workflows (e.g. `zfa graphql generate`) must keep working when the plugin
is enabled — the command surface does not change shape.

**Scale/Scope**: 15 in-repo files import the four heavy packages (12
graphql/gql, 3 opentelemetry + 2 otel-adjacent consumers to de-type, 1
minio + doc-comment exports); ~25 barrel export lines slim; ~3 test files
move/adjust; +1 CLI command family (`zfa plugin`), +3 companion package
skeletons under `packages/`.

## Constitution Check

`.specify/memory/constitution.md` is an unfilled scaffold; the de-facto
constitution is `AGENTS.md` (the `016` plan precedent):

| Gate (AGENTS.md) | Status |
|---|---|
| No legacy one-shot generator | N/A — no generation-flow change |
| Prefer `zfa make` over `zfa feature` | N/A |
| No hand-created entities | N/A — `OptionalPlugin` is a CLI-internal model, not a domain entity |
| No direct `build_runner` in agent flows | Companion packages declare builders only if codegen requires; tests use `dart test` |
| Fixed layout `lib/src/domain/entities/...` | N/A — no domain entities added to core |
| `dart pub get --no-example` before `dart format lib test`; CI enforces format | Applies — every phase ends pub-get + format + analyze |
| No-JIT rule for zfa spawns | Applies — any child spawn goes through `ZfaExecutable`/`scripts/zfa` seams |
| STOP-ON-ROADBLOCK | Applies — any zfa misfire stops the run |
| Slow-tier discipline (`test/README.md`) | Applies — heavy-surface e2e suites get `slow`/`e2e` tags, not the default lane |

**Post-design re-check**: the split ADDS packages but keeps every heavy
runtime class OUT of the core compile closure — no gate violated. The
`plugins:` section of `.zfa.json` follows the existing `.zfa.json` config
contract (project memory surface per AGENTS.md).

## Project Structure

### Documentation (this feature)

```text
specs/1653-trim-heavy-deps/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── plugin-gate.md   # zfa plugin CLI contract
│   └── core-surface.md  # retained/moved export contract
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/                          # CORE — lean
├── zuraffa.dart              # barrel: heavy exports REMOVED (FR-004), light seams retained
└── src/
    ├── core/
    │   ├── hook.dart                 # stays; trace fields de-typed from OtelTracer reads
    │   ├── trace_observer.dart       # NEW light seam (traceId/spanId source, no-op default)
    │   ├── failure_reporter*.dart    # stay; default reporter becomes the no-op one
    │   ├── telemetry_hook.dart       # MOVES to packages/zuraffa_observability (otel-typed)
    │   ├── otel_tracer.dart          # MOVES (opentelemetry)
    │   ├── otel_failure_reporter.dart# MOVES (opentelemetry)
    │   └── minio_client.dart         # MOVES to packages/zuraffa_storage
    ├── domain/                       # stays; usecase/stream_usecase read TraceObserver, not OtelTracer
    ├── graphql/                      # heavy-importing files MOVES to packages/zuraffa_graphql;
    │                                 # pure-Dart codegen helpers stay (no heavy import)
    ├── plugins/graphql/              # CLI plugin: thin gate — enabled+resolvable → delegate;
    │                                 # else refuse with guidance (FR-007/FR-008)
    └── plugins/plugin_gate/          # NEW: OptionalPlugin registry + `zfa plugin` command
packages/
├── zuraffa_graphql/          # companion: graphql/gql-backed code (client, gql docs, heavy codegen)
├── zuraffa_storage/          # companion: minio-backed MinioClient
└── zuraffa_observability/    # companion: opentelemetry tracer/reporter/TelemetryHook
test/                         # core suites; heavy-surface suites MOVE with their code
```

**Structure Decision**: In-repo companion packages under `packages/`
(standard Dart packages, not a pub workspace — the root package resolves
independently so CI's root-only flows are untouched; companions are exercised
by their own `dart pub get`/`dart test` and by path-dependent fixture tests).
This matches the spec Assumption ("federated-plugin family shape"), keeps the
diff reviewable per package, and makes the enabled-path testable in-repo via
path dependencies.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none — three-package split is the feature itself, not accidental complexity) | | A single `zuraffa_integrations` mega-companion would couple GraphQL/S3/telemetry adopters to each other's transitive trees — exactly the problem the issue reports, re-created at one level up. |
