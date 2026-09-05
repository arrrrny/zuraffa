# Verification: `zfa tdd theater` (spec 1006-tdd-theater-replay-tui)

**Date**: 2026-09-05 · **Branch**: `spec/1006-tdd-theater-replay-tui` · **Dart**: 3.13.3 (stable)
**Method**: test-first TDD — every behavior below was written and observed RED before
the implementation that turned it green. Evidence entries live in `tdd/cycle-log.md`,
appended by the real `CycleLog.append` writer (schema-1 hash chain). The mutation
phase ran the REAL `mutation_test` tool (v1.8.0) per source file against the
theater test scope (`tools/run-theater-tests.sh`, the `run-tdd-tests.sh` pattern:
kernel-dir cleanup + `-j 1` serialization).

## Test-first evidence (red)

Pre-implementation, `dart run bin/zfa.dart tdd theater 004-login-ui` → **exit 64**,
`Could not find a subcommand named "theater" for "zfa tdd"`. The new test files:

```text
00:00 +0 -1: loading test/plugins/tdd/theater/theater_data_test.dart [E]
  Error when reading 'lib/src/plugins/tdd/services/theater_data.dart': No such file or directory
00:00 +0 -1: loading test/plugins/tdd/theater/theater_screen_test.dart [E]
  Error when reading 'lib/src/plugins/tdd/widgets/theater_screen.dart': No such file or directory
00:00 +1 -2: zfa tdd theater A5 … [E] / A7 … [E]   (assertion failures on the missing command)
```

3 red entries recorded (`1006-A5-A7` classification `assertionFailure`,
`1006-A1-A4` and `1006-U1-U5` classification `loadError`), transcripts embedded.

## Green evidence (this run — real numbers)

| Suite | Result |
|---|---|
| `test/plugins/tdd/theater/` (theater_data_test + theater_screen_test + fixture) | **12 passed, 0 failed** |
| `test/plugins/tdd/commands/theater_command_test.dart` | **3 passed, 0 failed** |
| `test/plugins/tdd/commands` (fast chunk, re-run after final edits) | **160 passed, 0 failed** |
| Full fast suite via the chunked protocol (76 chunks) | **75/76 chunks green** — see the flake note below |
| E2E pty run (`nocterm.runApp(TheaterScreen(…))` inside a real 110×30 pty, `q` to quit) | **exit 0**, 5753 bytes of rendered output; verified to contain every pane: header `zfa tdd theater — 004-login-ui (read-only)`, all 3 behavior cards (A1/A2/A3, FR-001..003, green/red/pending), the timeline rows `A1 (red)`/`A1 (green)`/`A2 (red)`, the status line `behaviors=3 cycles=3 receipts=2`, and the key map |

**Flake note (honest)**: during the first full-suite pass,
`test/plugins/tdd/commands/view_command_test.dart: U-V7` failed once — the
parallel `corpus_differential_command_test` had just printed `dart pub get
failed in worktree … resolution failed` (shared pub-cache/temp-project
contention). U-V7 passes in isolation (`dart test --plain-name "U-V7*"`) AND the
whole `test/plugins/tdd/commands` chunk passes on re-run (160/160 above). No
theater code is involved in that pair; this diff is additive files plus two
registration lines in `tdd_command.dart`.

## Gates

- **`dart analyze`**: whole repo `345 issues found` — all pre-existing (largest
  groups: the `examples/todo_tdd` Flutter subproject, unresolved in this
  environment, and `lib/tdd/*` generated-subject infos). The 8 files of this
  feature (`theater_data.dart`, `theater_screen.dart`, `theater_command.dart`,
  `tdd_command.dart`, the three test files + fixture):
  **`No issues found!`** Zero new issues.
- **`dart format .`**: `Formatted 1985 files (0 changed)` — zero remaining
  formatting diffs (`git diff --stat` clean apart from this feature's files).
- **Read-only contract (hard constraint)**: A6 hashes the whole fixture tree
  (`specs`, `lib`, `test`, `.zfa`, `.`) before/after a real
  `CliRunner.runCapturing` invocation — byte-identical (`changedPaths` empty
  both directions). The theater performs zero writes by construction: the
  loader only reads; the screen holds only transient selection state.

## Mutation phase (real runs, per file)

Config: `<theater files>` + `bash tools/run-theater-tests.sh` (per-mutant
`dart test test/plugins/tdd/theater/ test/plugins/tdd/commands/theater_command_test.dart -j 1`).

| File | Mutants | Detected | Undetected | Score |
|---|---|---|---|---|
| `lib/src/plugins/tdd/services/theater_data.dart` | 114 | 113 | 1 | **99.1%** |
| `lib/src/plugins/tdd/widgets/theater_screen.dart` | 124 | 106 | 18 | **85.5%** |
| `lib/src/plugins/tdd/commands/theater_command.dart` | 45 | 28 | 17 | **62.2%** |
| **Total** | **283** | **247** | **36** | **87.3%** |

The tests were strengthened between audit rounds (82→113 / 50→106 / 21→28
detected) by adding exactly the mutants' behaviors: vocabulary-completeness
checks, receipt-layout attribution (test-path-only, backslash separators,
same-timestamp file-name tie-break written in reverse store order so insertion
order cannot masquerade as the tie-break), missing-field honesty
(`'test - exit 0 at -'`), malformed-fence parse edges, error-message anchors
(including the empty-registry path), keyboard navigation (arrows/Tab/Enter/Esc,
Enter-in-receipt-is-a-no-op), the expanded card's own description, and the
`receipt-file:`/`hash:` detail lines.

**Accepted survivors (reviewed, not equivalent-blindness)**:
- 1 in the loader: `i + 1 >= lines.length` → `==` is a true equivalent (the
  loop bound guarantees `i + 1 <= length`).
- 18 in the screen: row-highlight color conditions and defensive double-clamp
  bounds (`clamp(0, length - 1)` inside a branch the arrow keys already clamp);
  rendering-color choices are not text-observable through the tester.
- 17 in the command: `--help`/description prose beyond the contract anchors;
  the TTY-launch branch (`nocterm.runApp`) which cannot execute under piped
  CI stdout; one length-equivalent `'specs/'` literal (only `.length` is read).
The three theater files are now also wired into the root `mutation-test.xml`
so future `zfa tdd verify` audits keep them in scope.

## Success criteria — verified vs not

| Criterion (issue #1006) | Verification | Status |
|----|--------------|--------|
| `zfa tdd theater 004-login-ui` opens the TUI and renders all behaviors | A1: `NoctermTester` pump of `TheaterScreen` fed by the real `TheaterData.load` from a real fixture → all 3 behaviors, criteria, statuses + timeline + status bar render; E2E pty run renders the identical panes and quits clean (`q`, exit 0); A5: the command loads 3/3/2 and prints the machine summary | **VERIFIED** |
| Three panes: left cards (scrollable, click to expand) / right timeline (click cycle → diff, click behavior → receipt) / bottom live status; `[?]` classifier verdict | A1/A1b, A2, A3/A3b, A4/A4b — tap and keyboard paths both tested, incl. the honest empty pane for a missing cycle-log | **VERIFIED** |
| Clicking a behavior shows its receipt (action: satisfied, evidence, file) | A2: tap A1 → `action: satisfied`, the evidence line (`test … exit 0 at …`), `file: lib/src/login/a1_subject.dart`, and the #807 backing (`receipt-file: … (create, N bytes)`, sha256) | **VERIFIED** |
| Driven entirely from `.zfa/receipts/<feature>/*.json` and `tdd/cycle-log.md`, no separate state | U2 (both receipt layouts: per-feature dir + flat attributed store), U3 (full journal-row parse), A6 (tree byte-identity — no writes, no state files) | **VERIFIED** |
| Read-only; no mutation | A6 TreeSnapshot before/after byte-identical; the loader performs zero writes (code-reviewed + mutation-audited) | **VERIFIED** |
| The TUI compiles and runs on macOS | Compiles: `dart analyze` clean, pure Dart + `nocterm` (no `package:flutter` import — the tui plugin's own `no_flutter_import_test` discipline), zero platform-specific code. Runs: proven on a real Linux pty (above). **Not run on macOS hardware in this environment** — the engine is the same pure-Dart nocterm the repo's tui plugin already ships cross-platform | **COMPILE VERIFIED; macOS RUN NOT DIRECTLY VERIFIED (honest gap)** |

Issue #1006 done-when mapping: all three exit criteria are either verified
above or carry the one disclosed gap (no macOS hardware here). The TTY guard
follows the tui plugin's FR-009 discipline (actionable refusal + exit 1 +
summary line on non-TTY stdout, A5).

## Not verified here (honest gaps)

- A run on real macOS: no macOS environment exists on this agent. The code is
  pure Dart with no platform branches; the identical engine (nocterm 0.9.0)
  ships in the repo's tui plugin.
- The sandbox's Dart VM reports `stdout.hasTerminal == false` even inside a
  real pty (stdin reports true — an environment quirk; Python's `isatty(1)`
  in the same pty returns True). The pty proof therefore drove
  `nocterm.runApp(TheaterScreen(…))` directly; the command's own TTY-guard
  branch is covered by A5's non-TTY contract test. On a real terminal
  (macOS/Linux desktop) the guard passes and the command launches the same
  `runApp` path.
- The 4 slow-tier chunks (benchmark/integration/property) are excluded from
  the fast suite by `dart_test.yaml` design; the chunked protocol ran the
  fast tier as specified.
