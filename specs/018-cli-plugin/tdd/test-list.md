---
feature: 018-cli-plugin
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 6
planned_at: master
updated_at: feat/018-cli-plugin
suite_baseline: unknown
---

# Test List: Native CLI Plugin for Zuraffa (018-cli-plugin)

The behaviors the feature must exhibit, traced to the criterion each one serves.
The companion `cycle-log.md` is the append-only evidence that each behavior
went red→green→refactor; this file is the plan.

## Outer loop: acceptance behaviors

One per success criterion in `spec.md`. Each stays red until the feature works
end to end through its real entry point (`CliApp.run(args)` or the generator).

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| A1  | An empty `CliApp` with one registered `StandardCommand` invokes the handler exactly once when run with the command's name and a valid arg vector, and exits with the contract success code | SC-001, FR-001, FR-003 | example | PENDING | `test/cli/standard/scenarios/sc_001_scaffold_test.dart::handler invoked once with parsed args` |
| A2  | Two `CliApp` instances built independently with different commands but the same `CliContract` agree on >= 80% of the contract surface (global flag names, help header, error shape fields, output schema, exit-code vocabulary, unknown-command behavior, ambiguous-name behavior) | SC-002, FR-002 | example | PENDING | `test/cli/standard/scenarios/sc_002_consistency_test.dart::surface overlap >= 0.80` |
| A3  | App B invokes App A's registered command by name through the `CommandRegistry` and receives its result, with no import of App A's command class in App B's source | SC-003, FR-004, FR-005 | example | PENDING | `test/cli/standard/scenarios/sc_003_cross_app_test.dart::cross-app invoke via registry` |
| A4  | A `StandardCommand` authored in App A is registered as a `SharedCommand` and run by App B through the standard interface, producing identical behavior with no per-app reimplementation of the handler | SC-004, FR-006 | example | PENDING | `test/cli/standard/scenarios/sc_004_share_test.dart::shared command runnable cross-app` |
| A5  | The `CliPlugin` generator, driven against a fixture entity, produces a `StandardCommand` subclass that imports the entity's existing use-case class by name and passes `dart analyze` with no manual DI wiring in the generated file | SC-005, FR-007, FR-011 | example | PENDING | `test/cli/standard/cli_plugin_generator_test.dart::generated command requires zero manual wiring` |
| A6  | Three different commands run through `CliApp` with `--output=json` each emit valid JSON on stdout matching the contract output schema, and exit with the contract exit code for their outcome (success/runtime/notFound/conflict) | SC-006, FR-008 | example | PENDING | `test/cli/standard/scenarios/sc_006_machine_readable_test.dart::uniform machine-readable output` |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them. Each line names one
observable result.

### `lib/src/cli/standard/cli_contract.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U1  | `CliContract.exitCode.success` returns 0 | FR-002 | example | PENDING | `cli_contract_test.dart::success exit code is 0` |
| U2  | `CliContract.exitCode.usage` returns 64 | FR-002 | example | PENDING | `cli_contract_test.dart::usage exit code is 64` |
| U3  | `CliContract.exitCode.runtime` returns 1 | FR-002 | example | PENDING | `cli_contract_test.dart::runtime exit code is 1` |
| U4  | `CliContract.exitCode.notFound` returns 2 | FR-002, FR-009 | example | PENDING | `cli_contract_test.dart::notFound exit code is 2` |
| U5  | `CliContract.exitCode.conflict` returns 3 | FR-002, FR-009 | example | PENDING | `cli_contract_test.dart::conflict exit code is 3` |
| U6  | `CliContract.exitCode.versionMismatch` returns 4 | FR-002, FR-009 | example | PENDING | `cli_contract_test.dart::versionMismatch exit code is 4` |
| U7  | `CliContract.exitCode.circularRef` returns 5 | FR-002, FR-009 | example | PENDING | `cli_contract_test.dart::circularRef exit code is 5` |
| U8  | `CliContract.globalFlags` includes `--help`, `--version`, `--verbose`, `--output`, `--no-color` | FR-002 | example | PENDING | `cli_contract_test.dart::global flag set is the standard five` |
| U9  | `CliContract.errorShape` has fields `code`, `message`, `details` | FR-002, FR-008 | example | PENDING | `cli_contract_test.dart::error shape has required fields` |

### `lib/src/cli/standard/command_model.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U10 | `StandardCommand` parses a single positional argument and exposes it on `Invocation.arguments` | FR-003 | example | PENDING | `command_model_test.dart::parses positional arg` |
| U11 | `StandardCommand` parses a `--flag=value` option and exposes it on `Invocation.flags` | FR-003 | example | PENDING | `command_model_test.dart::parses flag with value` |
| U12 | `StandardCommand` parses a `--flag` boolean and exposes it as `true` on `Invocation.flags` | FR-003 | example | PENDING | `command_model_test.dart::parses boolean flag` |
| U13 | `StandardCommand.handler` is invoked exactly once per `run()` call | FR-003 | example | PENDING | `command_model_test.dart::handler invoked exactly once` |
| U14 | `StandardCommand` rejects an unknown flag at parse time with a usage error | FR-003, FR-009 | example | PENDING | `command_model_test.dart::rejects unknown flag` |

### `lib/src/cli/standard/cli_app.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U15 | `CliApp.run([])` prints help to stdout and exits 0 | FR-001, FR-002 | example | PENDING | `cli_app_test.dart::empty args prints help and exits 0` |
| U16 | `CliApp.run(['--version'])` prints `CliApp.name v<CliApp.version>` and exits 0 | FR-001, FR-002 | example | PENDING | `cli_app_test.dart::--version prints name and version` |
| U17 | `CliApp.run(['--help'])` prints help and exits 0 | FR-001, FR-002 | example | PENDING | `cli_app_test.dart::--help prints help` |
| U18 | `CliApp.run(['unknown-command'])` emits the contract error shape with code `notFound` and exits 2 | FR-001, FR-008, FR-009 | example | PENDING | `cli_app_test.dart::unknown command exits notFound` |
| U19 | `CliApp.run(['known-command'])` invokes the registered handler and exits with the handler's `CommandResult.exitCode` | FR-001 | example | PENDING | `cli_app_test.dart::known command dispatches to handler` |
| U20 | `CliApp.run(['--output=json', 'known-command'])` emits the result as a single line of JSON to stdout | FR-008 | example | PENDING | `cli_app_test.dart::--output=json emits JSON` |
| U21 | When the handler throws, `CliApp` emits the contract error shape with code `runtime` and exits 1 | FR-008, FR-009 | example | PENDING | `cli_app_test.dart::handler throw exits runtime` |
| U22 | When args parsing fails, `CliApp` emits the contract error shape with code `usage` and exits 64 | FR-008, FR-009 | example | PENDING | `cli_app_test.dart::arg parse failure exits usage` |

### `lib/src/cli/standard/command_registry.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U23 | `CommandRegistry.register(cmd, ownerApp: 'A')` makes the command discoverable via `lookup('A', cmd.name)` | FR-004 | example | PENDING | `command_registry_test.dart::register then lookup` |
| U24 | Registering a second command with the same `(ownerApp, name)` throws `CommandAlreadyRegistered` | FR-004, FR-009 | example | PENDING | `command_registry_test.dart::duplicate registration throws` |
| U25 | `CommandRegistry.enumerate()` returns commands from every registered owner app without losing any | FR-004 | example | PENDING | `command_registry_test.dart::enumerate returns all` |
| U26 | `CommandRegistry.enumerateFor('A')` returns only commands owned by app `A` | FR-004 | example | PENDING | `command_registry_test.dart::enumerateFor scopes by owner` |
| U27 | Two apps registering commands with the same name do NOT silently override — both coexist under their respective `(ownerApp, name)` keys | FR-004, FR-009 | example | PENDING | `command_registry_test.dart::same name different owner coexists` |

### `lib/src/cli/standard/cross_app_invoker.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U28 | `CrossAppInvoker.invoke('A', 'greet', args)` runs App A's `greet` command and returns its `CommandResult` | FR-005 | example | PENDING | `cross_app_invoker_test.dart::invoke by owner and name` |
| U29 | Invoking a command whose name is not registered in any app throws `UnknownCommandException` | FR-005, FR-009 | example | PENDING | `cross_app_invoker_test.dart::unknown command throws` |
| U30 | Invoking a command whose owner app is not registered throws `ReferencedAppMissingException` | FR-005, FR-009 | example | PENDING | `cross_app_invoker_test.dart::missing owner app throws` |
| U31 | A cross-app invocation chain A to B to A is detected and halted with `CircularReferenceException` rather than looping | FR-009 | example | PENDING | `cross_app_invoker_test.dart::circular reference detected` |

### `lib/src/cli/standard/shared_command.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U32 | `SharedCommand.share(registry)` publishes the command's definition under its name with a version | FR-006 | example | PENDING | `shared_command_test.dart::share publishes to registry` |
| U33 | `SharedCommand.retrieve(registry, name, minVersion: '1.0.0')` returns the shared definition when the published version satisfies the minimum | FR-006 | example | PENDING | `shared_command_test.dart::retrieve satisfies version` |
| U34 | `SharedCommand.retrieve(registry, name, minVersion: '2.0.0')` throws `VersionMismatchException` when the published version is `1.0.0` | FR-006, FR-009 | example | PENDING | `shared_command_test.dart::retrieve rejects lower version` |
| U35 | A retrieved `SharedCommand` runs identically to the original (same input produces same `CommandResult`) | FR-006 | example | PENDING | `shared_command_test.dart::retrieved runs identically` |

### `lib/src/cli/standard/di_binding.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U36 | `DiBinding.bind(sharedCommand, getIt)` resolves the handler's declared dependencies from the host's `GetIt` instance | FR-007 | example | PENDING | `di_binding_test.dart::bind resolves from host DI` |
| U37 | A binding failure (missing registration in the host's `GetIt`) throws a typed `BindingException` with the dependency name | FR-007, FR-009 | example | PENDING | `di_binding_test.dart::missing dependency throws` |

### `lib/src/cli/standard/output_format.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U38 | `OutputFormat.json(result)` produces a single-line JSON string with `outcome`, `data`, and `error` keys | FR-008 | example | PENDING | `output_format_test.dart::json shape` |
| U39 | `OutputFormat.text(result)` produces a human-readable multi-line string with the contract's emoji-prefixed error format | FR-008 | example | PENDING | `output_format_test.dart::text shape` |
| U40 | `OutputFormat.detect(stdout.isTty)` returns `text` when interactive, `json` when piped | FR-008, FR-009 | example | PENDING | `output_format_test.dart::auto-detect piped` |

### `lib/src/cli/standard/edge_cases.dart`

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U41 | `UnknownCommandException` carries the unknown command name and a hint listing available commands | FR-009 | example | PENDING | `edge_cases_test.dart::unknown command has hint` |
| U42 | `AmbiguousCommandException` carries the ambiguous name and the list of matching `(ownerApp, name)` pairs | FR-009 | example | PENDING | `edge_cases_test.dart::ambiguous lists matches` |
| U43 | `CircularReferenceException` carries the chain of `(ownerApp, commandName)` pairs that formed the cycle | FR-009 | example | PENDING | `edge_cases_test.dart::circular carries chain` |
| U44 | `VersionMismatchException` carries the requested `minVersion` and the actual published version | FR-009 | example | PENDING | `edge_cases_test.dart::version mismatch carries versions` |
| U45 | `NonInteractiveContextException` is raised when a command requires interaction but stdout is piped | FR-009 | example | PENDING | `edge_cases_test.dart::non-interactive raises` |

### `lib/src/plugins/cli/cli_plugin.dart` (generator)

| id  | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U46 | `CliPlugin.id` returns `'cli'` and `CliPlugin.name` returns `'CLI Plugin'` (matches the existing plugin convention) | FR-010, FR-011 | example | PENDING | `cli_plugin_generator_test.dart::plugin metadata` |
| U47 | `CliPlugin.generate(entity)` produces a Dart file at `lib/src/cli/commands/<entity_snake>_command.dart` that imports the entity's use-case class by name | FR-011 | example | PENDING | `cli_plugin_generator_test.dart::generated file imports use case` |
| U48 | The generated command file passes `dart analyze` with no errors and no manual DI wiring (no `GetIt.instance.registerSingleton` calls in the generated code) | FR-011, SC-005 | example | PENDING | `cli_plugin_generator_test.dart::generated file is clean` |

## Invariants and edge cases still to place

Behaviors that belong to the feature but do not yet have a home component. Each
must become a numbered line above before the feature is done, or be dropped with
a reason.

- (none remaining. Every edge case from `spec.md` section Edge Cases is mapped
  to a behavior line above: unknown command (U41), ambiguous/conflicting names
  (U42, U27), missing referenced command/app (U29, U30), circular references
  (U31, U43), version mismatch (U34, U44), non-interactive context (U45).)

## Out of scope

Things a reader may expect on this list and the one-line reason they are absent.

- **Cross-process / RPC command invocation**: spec assumption "v1 scope
  boundaries: RPC transports and distributed command execution are out of scope
  for v1". Cross-app invocation in v1 is in-process only.
- **Persistent registry on disk**: same v1 boundary. The `CommandRegistry` is
  in-memory, rebuilt at every process start.
- **Shell completion**: not in the spec; deferred.
- **Localization of help text**: not in the spec; the contract's help layout is
  English-only for v1.
- **Performance benchmarking**: no performance gate in the spec. The plan sets
  a 5 ms budget as a design goal but no test asserts it.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time, so this
file is readable on its own:

- Single test: `dart test test/cli/standard/<file>.dart -P "<name>"`
- Feature suite: `dart test test/cli/standard/`
- Full repo suite: `dart test` (slow; do not run for feature work)
- Static analysis (feature scope): `dart analyze lib/src/cli/standard/ lib/src/plugins/cli/ test/cli/standard/`
- Static analysis (full repo): `dart analyze`
- Mutation: no tool configured; deliberate-mutant sampling per
  `tdd/verification.md` Phase 4.
- Coverage: `dart test --coverage=test/.coverage` then
  `dart run coverage:format_coverage`. Opt-in, not a gate.
