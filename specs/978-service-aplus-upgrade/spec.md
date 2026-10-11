# Spec: 978 — service A+ upgrade

## Summary

Kill the legacy silent no-op in the service plugin, restore schema≡grammar parity
for the service grammar (params/returns/type/init), and prove the make-triad and
method-append flows end to end, with a machine-readable `--json` verdict on
`zfa service create`.

## Current State (bugs)

- **Legacy silent no-op** (`lib/src/plugins/service/service_plugin.dart:93-104`):
  the backward-compat guard is dead code (`!isEntityBased && !isCustomUseCase`
  is a contradiction), and the live `serviceSnake == null → return []` path
  returns an empty success with no printed reason, no skipped action, and exit 0
  upstream — the exact anti-pattern family fought in #769.
- **Schema drift**: `configSchema` advertises only `service`
  (service_plugin.dart:56-61) while the CLI offers `params`/`returns`/`type`/
  `init`. `init` is unreachable through `zfa service create` (the
  `CreateServiceCapability.inputSchema` omits it, and `CapabilityCommand`
  synthesizes subcommand flags from that schema). JSON agents and `zfa make`
  (which synthesize flags/data from `configSchema`) see an incomplete contract.
- **No method-append test** for `MethodCapability(targetType: 'service')`
  proving hand-written member preservation.
- **No make-pipeline proof**: `zfa make <Entity> --service` has no end-to-end
  test.

## Orders

1. **Structure the legacy skip**: the silent `[]` return becomes a structured
   skip verdict — logged reason + `--> fix:` line, aligned with #769 semantics
   (the CLI zero-file guard exits non-zero). Test proves no silent empty success.
2. **Schema ≡ grammar**: map `params`/`returns`/`type`/`init` into
   `configSchema` (and `init` into the create capability's `inputSchema`).
   Test asserts every CLI flag exists in the schema and vice versa (mini treaty
   check for this plugin).
3. **Make-pipeline test**: `zfa make <Entity> --service` in a temp project
   produces the service interface + DI wiring + provider files, with receipts —
   end-to-end behavioral test.
4. **Method-append test**: `zfa service method` on an existing service
   preserves hand-written members and appends correctly (mirror repository
   append tests).
5. **`--json` verdict on create**: `{file, methods[], type, schema:1}`;
   `--> fix:` on error paths.

## Hard Constraints

- Do not change the triad activation logic in `make` — test it, don't rewire it.
- Failing-first tests under `test/plugins/service/`.

## Acceptance Criteria (ALL must hold)

- AC-1: Legacy config path never yields silent empty success — tested.
- AC-2: Schema/grammar parity test green.
- AC-3: Make-pipeline test green (service + DI + provider artifacts verified by
  content).
- AC-4: Append test green; `--json` envelope asserted.
