# Contract: zfa plugin gate (CLI surface)

The optional-capability gate. Core owns registration and the gate; the
companion packages own the heavy implementations. Exit codes follow the
repo convention: 0 success, non-zero refusal (guidance on stdout/stderr,
never a stack trace).

## `zfa plugin list`

- Lists every `OptionalPlugin` in the catalog, one per line, with:
  name, enabled state, backing package, resolvable state.
- Exit 0 always (listing is never a failure).

```text
$ zfa plugin list
graphql        disabled  package: zuraffa_graphql        (not added)
storage        disabled  package: zuraffa_storage        (not added)
observability  enabled   package: zuraffa_observability  (resolvable)
```

## `zfa plugin enable <name>`

- `<name>` must be a catalog id; unknown names exit non-zero listing the
  catalog.
- Writes `capabilities.<name>: true` into the project's `.zfa.json`
  (additive; other keys untouched).
- Prints the backing package to add when it is not yet resolvable.
- Idempotent: enabling an enabled plugin succeeds as an explicit no-op
  (exit 0, `already enabled`), never duplicates config.

## Gated capability commands (e.g. `zfa graphql generate ...`)

- Enabled AND resolvable → the command runs with its pre-split surface
  (same args, same flags, same outputs), backed by the companion
  package.
- Enabled but NOT resolvable → exit non-zero:
  `zuraffa_graphql is enabled but not resolvable in this project — add
  it to pubspec.yaml and run dart pub get`
- Not enabled → exit non-zero:
  `graphql is an optional capability — run 'zfa plugin enable graphql'
  and add package:zuraffa_graphql`
- Refusals happen BEFORE any artifact generation (no partial output).

# Contract: core surface (retained / moved)

## Retained in core (compile-compatible for core-only users)

- `Result` / `AppFailure` / `UseCase` / `StreamUseCase` / `CancelToken`
- DI container, `PackageModule` lifecycle
- `Hook` / `HookContext` (trace fields now sourced from the light
  `TraceObserver` seam — values unchanged when tracing is active via the
  plugin; `null` when absent, which matches today's no-span behavior)
- failure-reporter registry (default reporter becomes the no-op one;
  the otel-backed reporter registers from the plugin)
- pure-Dart GraphQL codegen helpers that never import the heavy packages
  (schema parser, type mapper, entity/repository/dto/union generators,
  slice orchestrator, error-mapping config)

## Moved out of core (breaking — FR-010 migration map)

| Old core symbol | New home |
| --- | --- |
| `MinioClient` (`src/core/minio_client.dart`) | `package:zuraffa_storage` |
| `TelemetryHook` (`src/core/telemetry_hook.dart`) | `package:zuraffa_observability` |
| `OtelTracer` (`src/core/otel_tracer.dart`) | `package:zuraffa_observability` |
| `OtelFailureReporter` (`src/core/otel_failure_reporter.dart`) | `package:zuraffa_observability` |
| `export 'package:opentelemetry/api.dart'` (barrel line) | import `package:opentelemetry` from `zuraffa_observability` |
| `package:graphql`/`package:gql`-importing `src/graphql/**` (client factory/provider/subscription stream, gql document builder + dart generator + preserver, heavy datasource/di codegen, graphql validator) | `package:zuraffa_graphql` |
| simulation otel adapter (`simulation_adapters.dart` otel-backed adapter) | `package:zuraffa_observability` |

## Dependency manifest contract (the permanent pin)

- Root `pubspec.yaml` MUST NOT contain `graphql:`, `gql:`, `minio:`, or
  `opentelemetry:` in `dependencies:` (FR-001..003).
- No file under core `lib/` MAY import any of the four packages
  (FR-004's mechanical form); the barrel's export closure contains no
  heavy symbol.
- Enforced by a core pin suite reading the manifest and the import
  graph — a violation fails the default lane, not a slow tier.
