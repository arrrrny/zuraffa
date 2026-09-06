# Bug Assessment: 1184-stale-binary-warning

- **Assessed**: 2026-09-06
- **Issue**: #1184 (medium)
- **Verdict**: REAL bug, reproducible by construction, root cause understood.

## Root cause

`scripts/rebuild.sh` compiles `bin/zfa.dart` into a native bundle and copies
the executable to `$ZURAFFA_BIN` (default `~/.local/bin/zfa`). The compiled
snapshot carries no record of the source state it was built from, and the CLI
never compares itself against the checkout it runs inside. After any source
fix, the installed binary keeps executing pre-fix code and silently
reproduces the old bug — the operator (or agent) burns debugging time on a
false repro, with no signal that the fix "didn't work" only because the
binary predates it.

The script's own comments reference the sibling record
`.specify/bugs/rebuild-stale-binary` (partial-cleanup staleness of build
caches); #1184 is the operator-facing twin: even with a perfectly clean
rebuild, nothing surfaces that the INSTALLED binary is older than the
checkout it is being run against.

## Selected fix (matches the issue's suggested mechanism)

1. **Record at build time** — `scripts/rebuild.sh` writes the build commit to
   `<install-dir>/zfa.build_commit` (and into the in-place bundle dir) right
   after installing the compiled `zfa`. `dart build cli` has no
   `--define`/`--dart-define` support (verified against the Dart 3.13.3 CLI),
   so a compile-time `String.fromEnvironment` embed was not available; a
   marker file next to the binary is the minimal, dependency-free recording
   mechanism and keeps the source tree clean during builds.
2. **Warn at startup (shell path only)** — `CliRunner.run` (NOT
   `runCapturing`, whose stdout is machine-parsed MCP protocol) probes once
   before dispatch: read the marker next to the running executable, walk up
   from the effective working directory (honoring `-C`) to the nearest
   `pubspec.yaml` with `name: zuraffa`, resolve its `git rev-parse HEAD`, and
   emit ONE line on stderr when the two commits differ. Every unknowable
   input (source run under the Dart VM, no marker, no zuraffa worktree, no
   resolvable HEAD) is silent — an advisory must never fire on unprovable
   input. Exit codes, stdout, and all command behavior are untouched.
3. **`zfa doctor` check** — new named check `binary-staleness` (WARN with
   `suggestedFix: scripts/rebuild.sh`; warn-only so doctor's exit contract
   is unchanged). Skips honestly when any input is unknowable.

## Constraint compliance

- Staleness warning added: yes (startup line + doctor check).
- No CLI behavior change beyond the warning: exit codes untouched; stdout of
  the shell path untouched (warning goes to stderr); `runCapturing` untouched;
  doctor gains one WARN/SKIP/PASS check (warn/skip do not affect doctor's
  exit code — `ok` is `status != fail`).
- One PR for the bug: yes.

## Test strategy (TDD)

`test/cli/binary_staleness_test.dart` (16 tests, written first — red was
`+0 -1` compile failure at the missing API surface, green `+16` after
implementation). Hermetic: temp-dir worktrees with real `git init` +
`--allow-empty` commits, injected `binaryDir` simulating the installed
binary; covers marker read, checkout detection (incl. `zuraffa_example`
non-match), all five silence rules, the one-line warning contract, the
`run()`-only emission (and `runCapturing()` cleanliness), and the doctor
check's WARN/PASS/SKIP verdicts.
