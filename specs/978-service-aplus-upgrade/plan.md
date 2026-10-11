# Plan: 978 — service A+ upgrade

## Approach

Minimal, additive changes on three surfaces (plugin, capability, generic
capability command), mirroring patterns already established in the codebase:

| Concern | Pattern reused | Files |
| --- | --- | --- |
| Structured skip | presenter/controller #420/#769 skip-note + `--> fix:` | `service_plugin.dart` |
| Schema defaults parity | provider #768 schema≡positional-CLI parity | `service_plugin.dart`, `create_service_capability.dart` |
| JSON verdict | #778 single-object verdict (proof/doctor/zap) | `create_service_capability.dart`, `capability_command.dart` |
| Make e2e + receipts | make_receipt_test (in-process `CliRunner.runCapturing`) | new test |

## Changes

1. `lib/src/plugins/service/service_plugin.dart`
   - Delete the dead backward-compat guard (documented as such; the condition
     `!isEntityBased && !isCustomUseCase` is unsatisfiable).
   - `serviceSnake == null` → print skip reason + `--> fix:` hint, return `[]`
     (empty result keeps the CapabilityCommand #769 zero-file guard armed:
     exit 1, no `✅ Success`).
   - `configSchema`: add `params`, `returns`, `type` (enum), `init` alongside
     `service`.
   - `generateWithContext`: read `init` from context data.
2. `lib/src/plugins/service/capabilities/create_service_capability.dart`
   - `inputSchema`: add `init` (boolean); add `enum` to `type` to mirror the
     CLI's allowed values.
   - `execute`: attach `data['verdict']` = `{schema: 1, ok, file, methods, type}`.
3. `lib/src/commands/capability_command.dart`
   - Verdict hook: when the caller passed `--json` (machine mode) and the
     capability returned a `verdict` map, print exactly one JSON object and set
     the exit code from `verdict['ok']`.
   - `--> fix:` line on the missing-required-arguments error path.
4. ~~`lib/src/commands/service_command.dart` first-party `create` subcommand~~ —
   dropped during GREEN: package:args dispatches subcommands directly (the
   parent's #856 usage report only fires bare), and the generic
   `CapabilityCommand` machinery — flag synthesis from the updated
   inputSchema, required validation, coercion, the verdict hook, the `--> fix:`
   error path — already covers every service-create behavior. A first-party
   subclass would duplicate that machinery for zero contract gain. No change
   to `service_command.dart` shipped.

Plus one make-triad repair inside the service plugin (discovered by the
order-3 RED): `generateWithContext` now defaults entity methods to
`['get','update','toggle']` — mirroring the usecase/repository siblings — and
`ServiceInterfaceBuilder` gained the `toggle` case, so the triad's interface,
provider and usecases agree on path and member surface.

## Tests (all fast-tier, failing-first)

- `test/plugins/service/service_plugin_skip_verdict_test.dart` (order 1)
- `test/plugins/service/service_schema_grammar_parity_test.dart` (order 2)
- `test/plugins/service/make_service_triad_test.dart` (order 3)
- `test/plugins/service/service_method_append_test.dart` (order 4)
- `test/plugins/service/service_create_json_verdict_test.dart` (order 5)

## Risks

- `configSchema` additions surface as new `zfa make` flags (`--params`,
  `--returns`, `--type`, `--init`): additive; buildContext merges them into
  `context.data`, which `generateWithContext` already reads.
- `CapabilityCommand` verdict hook is generic but gated on machine mode +
  `data['verdict']` — existing capabilities/tests unaffected (verified against
  `capability_command_test.dart`).
