# Assessment — Bug 1719 (provider create: `--force`/`--revert` no-ops + duplicate members)

Date: 2026-09-19
Branch: fix/1719-provider-force-revert-duplicate-members
Inputs: `.specify/bugs/1719-provider-force-revert-duplicate-members/issue.md`,
live CLI reproduction on a scratch fixture (service `--init` + appended
methods, then provider create with `--init`), source read of the provider
and service generation paths.

## Root causes (three, one shared shape)

### D1a — `--force` no-op on the provider fresh-file write

`ProviderBuilder.generate()` writes a NEW provider with:

```dart
return FileUtils.writeFile(
  filePath, withHeader, 'provider',
  force: options.force,   // <-- plugin-level GeneratorOptions (const default false)
  ...
);
```

The per-invocation flag travels on `GeneratorConfig.force` (set by
`CreateProviderCapability._generateFiles` from `args['force']`), but the
builder reads the plugin-level `GeneratorOptions` instead. `FileUtils.writeFile`
then takes the `exists && !force` branch and returns `action: 'skipped'`,
which `CapabilityCommand` surfaces as `⏭ Skipped (use --force to overwrite)`
— even though `--force` was passed. The CLI constructs plugins with the
default `const GeneratorOptions()`, so `options.force` is always false;
the flag is dropped on the floor.

The same line also passes `dryRun: options.dryRun` / `verbose:
options.verbose`, so `--dry-run` on a NEW file actually writes it (verified
live during triage). The fix routes all three through the config.

### D1b — `--revert` never reaches the provider config

`CapabilityCommand` parses the global `--revert` flag and puts
`args['revert'] = true` into the capability args, but
`CreateProviderCapability._generateFiles` never reads the key —
`GeneratorConfig(revert: ...)` keeps its default `false`. The builder's
delete path (`config.revert && !config.appendToExisting` →
`FileUtils.deleteFile`) is therefore unreachable from the CLI, and the run
degrades to the D1a skip. Same story in `CreateServiceCapability`.

Additionally, the capability's service-existence precheck throws a
`StateError` when the service interface is missing — a `--revert` run (which
only deletes the provider) must not be blocked by that precondition.

### D2 — duplicate, signature-mangled provider members

`ProviderBuilder` extracts the service interface via
`MethodExtractor.extractMethodsFromInterface`, which carries `isGetter` and
`parameterCount` (added for issue #1570). The builder ignores both and emits
EVERY interface member as a method with a required `params` parameter:

- `Stream<bool> get isInitialized` → `Stream<bool> isInitialized(NoParams params)`
- `Future<void> dispose()` → `Future<void> dispose(NoParams params)`

Then, when the provider itself runs with `--init`
(`config.generateInit == true`), the init block appends the canonical
members (`Stream<bool> get isInitialized`, `initialize(InitializationParams)`,
`dispose()`) WITHOUT checking what the extraction already emitted. For an
`--init` service the three init members exist in the interface, so each is
emitted twice: once mangled by the extraction path, once canonical —
`duplicate_definition` × 3, non-compiling output.

### D3 — `--force` no-op on the service interface write

`ServicePlugin.generate()` writes the interface with
`force: options.force` — the identical D1a shape on the service side. The
`ServiceCreateCommand` correctly sets `args['force']`, the capability
forwards it into `GeneratorConfig.force`, and the plugin then drops it in
favor of the plugin-level options. `FileUtils` skips the existing file and
the command reports "Re-run with --force to overwrite the existing service
file." `--revert` is likewise dropped (`CreateServiceCapability` never
forwards `args['revert']`, and `ServiceCreateCommand` does not even declare
the flag).

## Remediation plan

1. **Provider flag plumbing** (`create_provider_capability.dart`):
   forward `args['revert']` into `GeneratorConfig.revert`; skip the
   service-existence precheck when reverting.
2. **Provider builder** (`provider_builder.dart`):
   - fresh-file write reads `config.force` / `config.dryRun` /
     `config.verbose` (per-invocation flags win);
   - interface extraction emits signature-faithful members — getters stay
     getters, `parameterCount == 0` members keep no `params` (reuse of the
     #1570 `ParsedUseCaseInfo` metadata);
   - the init block emits its members exactly once and interface-extracted
     members with the same name are skipped — one implementation member per
     interface member, matching interface signatures.
3. **Service flag plumbing** (`create_service_capability.dart`):
   forward `args['revert']`; (`force` is already forwarded).
4. **Service plugin** (`service_plugin.dart`): interface write reads
   `config.force` / `config.dryRun` / `config.verbose`.
5. **Service create command** (`service_create_command.dart`): declare the
   `--revert` flag, pass it through, and surface `deleted` actions as a
   success outcome (prose + JSON verdict) instead of the zero-files refusal.

## Constraints honored

- Provider INTERFACE emission (`ServiceInterfaceBuilder`) is untouched —
  only the provider implementation body/membership changes.
- No behavior change when the flags were already working (fresh creates,
  append/inject path keeps `force: true` semantics).
- One PR for the whole bug; TDD red→green with the regression suite
  `test/fixes/bug_1719_provider_force_revert_duplicate_members_test.dart`.

## Red evidence

`tdd/red-T001-bug1719.log` — the 6-test regression suite fails 0/6 before
the fix with exactly the defect signatures (`skipped` instead of
`overwritten`/`deleted`; duplicate member counts).
