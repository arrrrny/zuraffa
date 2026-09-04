# Bug Fix: cli-phantom-write-1022

- **Slug**: cli-phantom-write-1022
- **Applied**: 2026-09-04
- **Branch**: fix/cli-phantom-write-1022
- **Issue**: #1022

## Summary

Fixed the phantom write bug in `zfa cli <EntityName>`: the command now writes the generated file to disk via `FileUtils.writeFile()` and emits a proof.v1 receipt to `.zfa/receipts/`.

## Changes

### 1. `lib/src/plugins/cli/cli_plugin.dart`
- Added imports: `dart:io`, `package:crypto`, `FileUtils`, `ReceiptStore`, `GenerationReceipt`
- `_CliGeneratorCommand.run()`: after `generateForEntity()`, calls `FileUtils.writeFile()` to write the file to disk, then emits a `proof.v1` receipt via `ReceiptStore.save()`

### 2. `lib/src/commands/entity_command.dart`
- Added imports: `package:args/command_runner.dart`, `CliGeneratorPlugin`
- Added `case 'cli':` to the entity subcommand switch
- Added `_handleCli()` method that delegates to `CliGeneratorPlugin.createCommand()`
- Updated help text to list `cli` subcommand

### 3. `test/cli/standard/cli_plugin_generator_test.dart`
- Added imports: `dart:io`, `package:args/command_runner.dart`, `package:path/path.dart`
- Added `disk write (issue #1022)` test group:
  - Creates a temp dir, runs the `cli` command, asserts the file exists on disk
  - Creates a stub entity use-case file so dart analyze can resolve imports
  - Runs `dart analyze` on the generated file (compile gate)
  - Cleans up generated file and stub in tearDown

## Verification

- `dart analyze lib/src/plugins/cli/cli_plugin.dart lib/src/commands/entity_command.dart` — 0 issues
- `dart test test/cli/standard/cli_plugin_generator_test.dart` — 11/11 passed (including the new disk write + compile gate test)
