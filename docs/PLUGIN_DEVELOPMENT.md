# Plugin Development Guide

This guide explains how to build third-party generation plugins for Zuraffa. It covers architecture, lifecycle, code generation patterns, and testing.

## Architecture Overview

Zuraffa plugins implement interfaces from the core plugin system and produce `GeneratedFile` outputs using `FileUtils.writeFile`.

Key components:

- Plugin contracts in `lib/src/core/plugin_system`
- File generation helpers in `lib/src/utils/file_utils.dart`
- Code generation helpers in `lib/src/core/builder` and `lib/src/core/ast`
- Plugin implementations in `lib/src/plugins`

## Plugin Lifecycle

All plugins implement the `ZuraffaPlugin` lifecycle:

- `validate` for configuration checks
- `beforeGenerate` for pre-generation setup
- `generate` for file creation (only in `FileGeneratorPlugin`)
- `afterGenerate` for post-generation work
- `onError` for error handling

`PluginRegistry` orchestrates these lifecycle calls in order.

## Minimal Plugin Walkthrough

The minimal plugin example is in [minimal_plugin_example.dart](file:///Users/arrrrny/Developer/zuraffa/examples/custom_plugin/minimal_plugin_example.dart). It:

- Implements `FileGeneratorPlugin`
- Writes a single file using `FileUtils.writeFile`
- Returns a list of `GeneratedFile` results

## Advanced Plugin Walkthrough

The advanced plugin example is in [advanced_plugin_example.dart](file:///Users/arrrrny/Developer/zuraffa/examples/custom_plugin/advanced_plugin_example.dart). It shows:

- Building Dart code with `code_builder`
- Emitting formatted code using `SpecLibrary`
- Writing the result via `FileUtils.writeFile`

## Code Builder Patterns

Zuraffa uses `code_builder` and `SpecLibrary` to ensure consistent formatting. A typical flow:

1. Build `Class`, `Method`, and `Field` specs with `code_builder`.
2. Emit a library using `SpecLibrary`.
3. Write the output using `FileUtils.writeFile`.

## Append Strategy

For append mode, use `AppendExecutor` with `AppendRequest.method` to insert methods into existing classes. This preserves user edits while extending generated files.

## Testing Strategy

Recommended testing approach:

- Create a temporary output directory
- Run `generate` with a small `GeneratorConfig`
- Assert file existence and contents
- Use append mode tests to verify AST-based insertion

Relevant test folders in this repository:

- `test/plugins/*` for plugin unit tests
- `test/integration/*` for multi-plugin workflows

## Integration Notes

For custom tooling, register plugins using `PluginRegistry` and execute lifecycle stages in the same order as core generation. The `CodeGenerator` currently wires built-in plugins directly; third-party integration can use a custom registry or wrapper.

## Checklist for Third-Party Plugins

- Implement `id`, `name`, and `version`
- Validate configs with `validate`
- Return `GeneratedFile` objects with proper `type` values
- Respect `dryRun`, `force`, and `verbose` flags
- Provide tests for generation and append mode
