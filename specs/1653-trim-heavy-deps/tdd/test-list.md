# Test List: 1653-trim-heavy-deps (#1661)

**Feature**: `specs/1653-trim-heavy-deps`
**Source**: `spec.md` + `plan.md` — derived via the **LLM-guided fallback
path** (engine detection: `ZFA_MISSING`, no `.zfa.json`; the zuraffa repo
cannot drive `zfa tdd` on its own development — the
`dart-core-lane-timeout-overflow` (#1632) precedent).
**Suite**: pins live in `test/core/` (manifest/barrel/seam) and
`test/plugins/plugin_gate/` (gate/command); acceptance evidence rides
`quickstart.md` scenarios and the companions' own gates.

## Unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | root `pubspec.yaml` `dependencies:` contains none of `graphql`, `gql`, `minio`, `opentelemetry` | FR-001, FR-002, FR-003 | unit | DONE | test/core/lean_core_pin_test.dart |
| U2 | no file under `lib/` imports any of the four heavy packages; `lib/zuraffa.dart`'s export closure contains no heavy symbol (otel api re-export line gone, MinioClient/TelemetryHook/moved-graphql exports gone) | FR-004 | unit | DONE | test/core/lean_core_pin_test.dart |
| U3 | `TraceObserver` default yields null trace/span ids and the HookContext assembly path reads it (not `OtelTracer.instance`) — core behavior identical when tracing absent | FR-009 | unit | DONE | test/core/trace_observer_test.dart |
| U4 | `PluginCatalog` resolves the three catalog ids to their backing packages; an unknown id refuses naming the catalog | FR-005, FR-006 | unit | DONE | test/plugins/plugin_gate/plugin_gate_test.dart |
| U5 | `zfa plugin enable <name>` writes `plugins.<name>: true` into `.zfa.json` additively (other keys untouched); re-enable is an explicit no-op success | FR-006 | unit | DONE | test/plugins/plugin_gate/plugin_command_test.dart |
| U6 | gate refusals: not-enabled → exit non-zero naming `zfa plugin enable <name>` + the package; enabled-not-resolvable → exit non-zero naming the package + `dart pub get`; refusal precedes any artifact write | FR-008 | unit | DONE | test/plugins/plugin_gate/plugin_gate_test.dart |
| U7 | `zfa plugin list` renders one line per capability with name/enabled/backing-package/resolvable, exit 0 always | FR-005 | unit | DONE | test/plugins/plugin_gate/plugin_command_test.dart |

## Acceptance behaviors

| id | behavior | criterion | state |
| -- | -------- | --------- | ----- |
| A1 | a fresh consumer of the trimmed core resolves a dependency graph with zero heavy packages; core compiles and its default-lane suite passes | SC-001, SC-002 | DONE |
| A2 | with a capability enabled AND its companion resolvable, its standard zfa workflow completes with the pre-split surface (graphql generate path; trace ids flow via the registered observer) | FR-007, SC-003 | DONE |
| A3 | without enablement (or without the package), every entry point for the capability refuses non-zero with the exact guidance — no stack traces, no partial artifacts | FR-008, SC-003 | DONE |
| A4 | each companion package (`zuraffa_graphql`, `zuraffa_storage`, `zuraffa_observability`) analyzes clean and its moved suites pass | SC-002 | DONE |

## Contract behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| contract:LeanCorePin | `heavyPackages() -> List<String>` / `isEnabled(String) -> bool` / `enable(String) -> bool`: the declared LeanCorePin row implemented as the plugin-gate + manifest-pin seam (the #1007 hand seam — the signature contract is pinned by U1/U2/U5/U6) | LeanCorePin | contract | DONE | test/core/lean_core_pin_test.dart + test/plugins/plugin_gate/* (U1, U2, U5, U6) |
