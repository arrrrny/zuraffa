# Spec: `zfa mock json --help` must print usage, not crash (Issue #761)

## Context

`zfa mock json --help` exits 1 with `❌ Error: Null check operator used on a null value`.
Every sibling (`mock create`, `mock data`, `mock method`, `mock inject`) prints help fine.

Stack trace (captured on master `6921c730`, Dart 3.13.3):

```
#0  Command.invocation (package:args/command_runner.dart:288:23)
#1  Command._usageWithoutDescription
#2  Command.usage
#3  Command.printUsage
#4  CommandRunner.runCommand (...:196:17)   ← per-command --help path
```

## Root cause (verified by inspection, to be reproduced RED first)

Two layers:

1. **Duplicate registration.** `PluginCommand`'s constructor auto-registers every
   plugin capability as a `CapabilityCommand`; for `MockPlugin`,
   `JsonMockCapability.name == 'json'` puts a `json` command on `MockCommand`'s
   argParser. `MockCommand`'s constructor then manually registers the richer
   `JsonMockCommand` under the same name.
2. **Half-failed registration, silently swallowed.** In `package:args` 2.7.0,
   `Command.addSubcommand` (a) writes the subcommand-map entry, (b) calls
   `argParser.addCommand(name, ...)` — which throws `ArgumentError` on the
   duplicate — and (c) only *then* sets `command._parent = this`. The throw at
   (b) skips (c); `MockCommand`'s `catch (_) {}` swallows it. The dispatched
   `JsonMockCommand` therefore has `parent == null`, so its `runner` getter
   (`parent == null → _runner`) resolves to `null`, and `Command.invocation`
   crashes on `runner!.executableName`. Dispatch itself never touches
   `invocation`, which is why `zfa mock json <Entity>` still works — only
   `--help` crashes.

## Requirements

- **FR-1**: `zfa mock json --help` (and `-h`) MUST print the command's usage
  text and exit 0. `--help` must never crash for any registered subcommand.
- **FR-2**: `zfa mock json <EntityName> [options]` behavior MUST remain on
  `JsonMockCommand` (dispatch, flags, output) — no user-visible runtime change.
- **FR-3**: The fix must remove the failure-masking `catch (_) {}` so a future
  registration conflict surfaces instead of silently half-registering.
- **FR-4**: Sibling subcommands (`mock data`, `mock create`, `mock method`,
  `mock inject`) must keep working and printing help (regression guard).
- **FR-5**: Fix must be at the registration mechanism level (no per-command
  help hacks): `PluginCommand` must not auto-register a capability whose
  subcommand the concrete command class registers itself.

## RED criteria (test first, must fail on master)

- `test/commands/mock_command_help_test.dart`:
  1. Black box: `CliRunner(exitOnCompletion: false).runCapturing(['mock','json','--help'])`
     → output contains usage for `mock json` and does NOT contain
     `Null check operator` — currently FAILS with the null-check error.
  2. Structural: `MockPlugin(...).createCommand()` → `subcommands['json']`
     is a `JsonMockCommand` with `parent != null` — currently FAILS
     (`parent == null` is the exact broken state).

## GREEN criteria

- Both tests pass after the fix.
- Targeted suites for mock command / capability command / cli runner pass.
- `dart analyze` clean, `dart format` clean on touched files.

## Out of scope

- Unifying `CapabilityCommand` vs first-party subcommand UX across all plugins
  (systemic follow-up, tracked separately by the manifest/CLI conformance
  issues).
- Changing `mock json` flags or output format.
