# Spec: `zfa entity --help` must print usage regardless of cwd (Issue #764)

## Context

Outside a Dart/Flutter project root, `zfa entity --help` exits 1 with:

```
❌ No pubspec.yaml found in current directory.
```

`--help` must never fail. Every other root command prints usage regardless of
cwd. (The empty-args path `zfa entity` already prints help fine — only the
explicit `--help`/`-h` tokens fall through to the guard.)

## Root cause (code-traced)

`EntityCommand.execute` computes `subCommand = args[0]`, then — *before* the
subcommand `switch` — runs `_checkDependencies()` and `exit(1)`s on failure.
There is no special-case for `--help`/`-h`, so the pubspec guard fires first
and usage is unreachable outside a project root. Inside a project, `--help`
reaches `default:` and prints help via the "Unknown subcommand" path —
incidentally proving the help body itself is cwd-independent.

## Requirements

- **FR-1**: `zfa entity --help` and `zfa entity -h` MUST print the command's
  usage text and exit 0 from any directory — before the pubspec guard runs.
- **FR-2**: The pubspec guard behavior for entity *operations* (create,
  add-field, list, build, …) MUST remain exactly as today: still blocked
  outside a project with the actionable message.
- **FR-3**: `zfa entity` (no args) keeps printing help and exiting 0.

## RED criteria (test first, must fail on master)

`test/commands/entity_help_test.dart`:

1. `CliRunner(exitOnCompletion: false).runCapturing(['-C', <empty temp dir>,
   'entity', '--help'])` → output contains usage markers (e.g. `Usage` /
   `create` / `add-field`) and does NOT contain `No pubspec.yaml found`.
   Currently fails (guard message instead of usage).
2. Same for `-h`. Currently fails.
3. Guard regression guard: `['-C', <empty temp dir>, 'entity', 'list']` still
   reports the pubspec error (FR-2). Passes pre- and post-fix.

## GREEN criteria

1–3 pass; inside-project `entity --help` unchanged behavior (help + exit 0);
`dart analyze` clean; `dart format` clean; surrounding command suites pass.

## Out of scope

- Per-subcommand help (`entity create --help`) — separate UX work.
- Reordering the guard for non-help paths.
