# Fix: make-missing-plugin-options

- **Slug**: make-missing-plugin-options
- **Branch**: fix/make-missing-plugin-options
- **Issue**: https://github.com/arrrrny/zuraffa/issues/548
- **Status**: applied

## Remediation applied

Reordered the two initialization guards in `CliRunner._ensureInitialized`
(`lib/src/cli/cli_runner.dart`) so `_loadAndRegisterPlugins()` runs **before**
`_addCoreCommands()`. This ensures `MakeCommand`'s `argParser` (built in its
constructor via `_addPluginOptions`, which iterates `registry.plugins`) is created
against the fully-populated plugin registry. Previously the core commands — and
therefore `MakeCommand` — were constructed before plugins loaded, so no
plugin-derived options (`--type`, `--cache-storage`, `--ttl`, `--gql-type`,
`--input-type`, `--use-service`) were registered, and `PluginManager.buildContext`
threw `Could not find an option named --type` when it called
`argResults.wasParsed(key)` for an active plugin's schema property.

## Files changed

- `lib/src/cli/cli_runner.dart` — reordered init guards; the `xray` (`_noPluginCommands`)
  skip logic is preserved.

## Verification

- `dart analyze lib/src/cli/cli_runner.dart` → no issues.
- `zfa make --help` now lists plugin-derived options (e.g. `--type`,
  `--cache-storage`, `--ttl`, `--gql-type`, `--input-type`).
- `zfa make Product --preset=crud --with=view --methods=get --xray` generates 14
  files and exits 0 (previously crashed with the "Could not find an option named
  --type" error).
- `test/commands/make_command_xray_default_test.dart` passes.
