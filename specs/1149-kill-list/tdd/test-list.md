# TDD Test List — EPIC #1149 Kill List

Part of #1132 (EPIC 1: Machine Contract). One PR per kill/merge; one PR for the fix list.
Every behavior below is written as a failing test FIRST (RED), then made to pass (GREEN).

## RED evidence collected before implementation (CLI reproduction)

| # | Defect | Reproduction | Observed (RED) |
|---|--------|--------------|----------------|
| R1 | graphql getList naming + `type` collision | `zfa make Product --methods=getList --with=graphql` | emits `usecase CreateProduct` in `create_product_usecase.dart` (exit 0) |
| R2 | cli phantom | `zfa make Product --with=cli` | prints "Generation complete" + exit 0; `lib/src/cli/commands/product_command.dart` does NOT exist |
| R3 | module drift / uncompilable output | inspect `ModuleOrchestratorBuilder` | emits `Map<String, ZuraffaRouteBuilder>` — type does not exist in core (`ZuraffaRouteHandler` is the contract) |
| R4 | tui silent no-op | `zfa make Product --with=tui` | "No files generated." exit 0 (TuiPlugin is not a `FileGeneratorPlugin`) |
| R5 | observer dishonest surface | `zfa observer create Gizmo` (no Gizmo entity) | exit 0 + file with import `../../entities/gizmo/gizmo.dart` that cannot resolve; zero tests; zero artifacts in demo apps |
| R6 | benchmark empty | `zfa benchmark list` / `run` | "No benchmark scenarios registered." exit 0 |
| R7 | shadcn phantom layouts | `shadcn_plugin.dart` schema enum + builder switch | `grid`/`table` advertised but fall through to list widget with misleading filename |

## PR 1 — kill(1149-gql): fold naming fix + FileSystem injection into graphql; alias; delete gql

- [ ] T1.1 `GraphqlBuilder` getList operation name is `Get<Entity>List` (RED: falls through to `Create<Entity>`) — `test/plugins/graphql/graphql_builder_test.dart`
- [ ] T1.2 `GraphqlBuilder` operation names for get/create/update/delete/watch/watchList stay correct
- [ ] T1.3 `GraphqlBuilder` accepts an injected `FileSystem` and writes through it (no real disk I/O with a fake)
- [ ] T1.4 `GraphqlPlugin.generateWithContext` reads `gql-type`/`gql-returns` context keys (collision-free with the usecase plugin's `type` default)
- [ ] T1.5 `PluginAliasResolver` expands `gql` → `graphql`
- [ ] T1.6 `PlanResolver` resolves `--with=gql` to the GraphqlPlugin (unknown-plugin warning gone)
- [ ] T1.7 `ZfaConfig.isPluginEnabledByDefault('graphql')` honors the legacy `gql` key (deprecation cycle)
- [ ] T1.8 `zfa gql` command is gone; `zfa graphql` remains; `--gql` flag still resolves (deprecated alias flag) and `--no-gql` excludes graphql
- [ ] T1.9 #259 regression test updated: gql assertions become alias assertions, graphql exposure assertions remain

## PR 2 — fix(1149-cli-phantom): persist the file the CLI promises

- [ ] T2.1 `CliGeneratorPlugin.generateWithContext` WRITES the command file to `<outputDir>/cli/commands/<snake>_command.dart` (RED: writes nothing)
- [ ] T2.2 dry-run does not write; force overwrites; existing file without force is skipped
- [ ] T2.3 generated content names `<Entity>Command extends StandardCommand`

## PR 3 — merge(1149-module): one generator for the FeaturePlugin class

- [ ] T3.1 `ModuleOrchestratorBuilder` emits `Map<String, ZuraffaRouteHandler>` (compiles against core) — RED: emitted `ZuraffaRouteBuilder` (nonexistent)
- [ ] T3.2 `ModuleCommand` delegates the plugin file to the same builder (one generator); scaffold output contains `extends ZuraffaPlugin` + `pluginId`
- [ ] T3.3 post-scaffold gate runs `dart pub get` + `dart analyze` in the scaffolded package; failure is exit 1; `--no-gate` skips; missing toolchain prints an honest skip notice (no fake success)

## PR 4 — decide(1149-observer-tui): observer deprecated honestly; tui wired

- [ ] T4.1 `zfa observer` prints a removed-verdict naming the modern approach (direct stream subscription) and exits 64
- [ ] T4.2 observer plugin/generator/command files are deleted; no registration remains in loader or code generator
- [ ] T4.3 `zfa make X --with=observer` warns "Unknown plugin" and does not crash the plan
- [ ] T4.4 `TuiPlugin` is a `FileGeneratorPlugin`; `generateWithContext` derives fields from the entity (EntityAnalyzer), use cases from methods, and PERSISTS both screens via FileUtils.writeFile (RED: silent no-op)
- [ ] T4.5 `zfa make Product --with=tui` (pipeline condition: plugin in registry + FileGeneratorPlugin) emits and writes 2 screen files
- [ ] T4.6 generated TUI screens use relative entity/use-case imports (no `package:zuraffa/domain/...`)

## PR 5 — fix(1149-fix-list): shadcn layouts, benchmark scenarios, feature capabilities

- [ ] T5.1 shadcn advertised layouts are exactly `list`/`form` in schema + command (grid/table removed — not implemented)
- [ ] T5.2 `zfa benchmark list` ships first-party scenarios; `zfa benchmark run` executes them and reports real metrics
- [ ] T5.3 first-party scenarios are pure-Dart, deterministic-setup, and measure real zuraffa utility work
- [ ] T5.4 the 8 single-plugin feature capabilities collapse into one parameterized `PluginFeatureCapability` registered 8×; capability names (MCP contract) unchanged
- [ ] T5.5 xray deck compile-gate: verified already landed via #1042 (deck analyzes clean; `_safeMockType` gate). Added regression coverage for the generated deck surface (no dangling imports, real `XRayMockType` values)

## Verification

- `dart analyze` on every changed file: clean
- Targeted `dart test` for each new/changed test file: real pass counts recorded in `tdd/verification.md`
