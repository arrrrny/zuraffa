# Bug Fix: 1184-stale-binary-warning

- **Fixed**: 2026-09-06
- **Branch**: fix/1184-stale-binary-warning
- **Issue**: #1184

## Change list

1. `lib/src/cli/binary_staleness.dart` (NEW) — `BinaryStaleness` +
   `StalenessReport`: marker read (`zfa.build_commit`), enclosing zuraffa
   worktree detection (nearest `pubspec.yaml` with `name: zuraffa`), worktree
   HEAD resolution (`git rev-parse HEAD`, injectable spawner), probe with the
   five silence rules, and the one-line warning text.
2. `lib/src/cli/cli_runner.dart` — `CliRunner` gains optional injectable
   `staleness` + `onStalenessWarning` (defaults: real probe / stderr).
   `run()` calls `_warnIfBinaryStale()` once before ANY dispatch (empty args,
   `--version`, help, subcommands) so every shell invocation is covered;
   `runCapturing()` (MCP protocol) deliberately does not warn.
3. `lib/src/commands/doctor_checks.dart` — new named check
   `binary-staleness` (WARN + `suggestedFix: scripts/rebuild.sh` when stale;
   PASS when fresh; SKIP on any unknowable input). Runs in both text and
   `--format json` modes.
4. `scripts/rebuild.sh` — after installing the compiled `zfa`, records
   `git rev-parse HEAD` into `$INSTALL_DIR/zfa.build_commit` and
   `build/zfa_bundle/bundle/bin/zfa.build_commit`; removes the marker when
   not inside a git checkout (staleness becomes unprovable → silent).
5. `test/cli/binary_staleness_test.dart` (NEW) — 16 hermetic tests
   (U1–U15 + sub-behaviors), red-first.
6. `test/commands/doctor_checks_test.dart` — U11's pinned check-id registry
   gains `binary-staleness` (the registry is the contract under test).

## Warning contract

- Fire: shell `zfa …` invoked (a) with a marker-carrying installed binary,
  (b) inside a zuraffa worktree, (c) whose HEAD differs from the marker.
- Text: `⚠️ installed zfa (<build-commit>) is older than this checkout
  (<head>) — run scripts/rebuild.sh` (commits abbreviated to 12 chars).
- Stream: stderr (stdout stays machine-parseable).
- Count: exactly one line per invocation.
- Silence: source runs, marker-less installs, non-zuraffa cwd, non-git
  worktrees, git failures — always silent; never crashes, never changes exit
  codes.
