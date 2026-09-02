# Implementation Plan: `zfa replay` — deterministically re-execute a feature's recorded TDD history

**Branch**: `066-zfa-replay` | **Date**: 2026-09-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/066-zfa-replay/spec.md` (seeded from GitHub issue #806)

## Summary

Make the recorded TDD history executable. `tdd/cycle-log.md` already carries a
tamper-evident, per-behavior hash chain (bug #828), but nothing can take a recorded
cycle and *re-run* it. `zfa replay` (tdd subcommand + top-level dream surface) spins
a clean sandbox copy of the project, and per behavior re-executes the reproducible
half of its recorded cycle: the recorded generation steps (from the green entry's
`generation:` block) re-run inside the sandbox with a `TreeSnapshot` compare of the
sandbox's `test/`+`lib/` trees against the real project's (normalized, path-stable
diff), and the recorded green verify command re-runs in the sandbox asserting the
recorded exit. A new integrity stage recomputes the evidence chain exactly as
`CycleLog.append` built it and structurally validates red evidence. Clean replay is
a silent pass; any divergence is reported at behavior + step granularity (history
tamper → broken chain link named; artifact drift → A/M/D paths; verify divergence →
expected/actual exit). Exit codes follow #778 (0/1/2/64); `--events <path>` ships an
NDJSON event log aligned with #791's streaming direction. Red reproduction and
refactor re-execution are explicitly out of v0 scope (documented honest cuts).

## Technical Context

**Language/Version**: Dart 3.13+ (repo pins `sdk: ^3.11.0`; 3.13.3 stable used in
this environment). The package is pure Dart — no Flutter SDK surface is touched;
flutter-tagged tests are excluded by the fast-suite runner.

**Primary Dependencies**: `args` (command parsing), `path`, `crypto` (sha256 chain
recompute — already a dependency of cycle_log), `package:test`. No new
dependencies.

**Storage**: N/A — file-contract driven. Reads `specs/<feature>/tdd/cycle-log.md`
(via `CycleEvidence.parseEntries`), the real project's `test/`+`lib/` trees (via
`TreeSnapshot.capture`), and writes only inside a temp sandbox (plus the optional
`--events` NDJSON file the caller names).

**Testing**: `package:test` via `dart test`; fast suite chunked through
`tools/run_tests_chunked.sh` (excludes `flutter`/`slow` tags, clears kernel caches
per chunk). Replay mechanics are proven with the fixture pattern the `tdd run`
driver tests established: a temp project, a scripted fake `zfa` binary for gen
steps, shell-script "test runners" for verify, and cycle-log histories seeded
through the REAL `CycleLog.append` writer so the machine format (schema-1 chain
lines) is byte-exact by construction.

**Target Platform**: CLI (`bin/zfa.dart`) — the zuraffa generation pipeline and its
TDD plugin.

**Project Type**: CLI / code-generation framework plugin (pure Dart).

**Performance Goals**: No runtime-performance surface. A replay costs one sandbox
copy (lib/ + test/ trees), one subprocess per recorded gen step, one subprocess per
recorded green command, and two `TreeSnapshot.capture` walks — the same order of
work `verify-red` already does every run.

**Constraints**: Disk-safe verification on cloud agents (chunked runner, no
whole-tree `dart test`); the real project must remain byte-identical across a
replay (read-only contract, SC1); sandbox always cleaned up unless `--keep-sandbox`.

**Scale/Scope**: One new tdd subcommand (`replay_command.dart`), one thin top-level
command (`replay_command.dart` under `lib/src/commands/`), three new pure services
(`replay_history.dart`, `replay_sandbox.dart`, `replay_runner.dart`), one parser
extension (generation-block steps on green entries), registration edits in
`tdd_command.dart` + `cli_runner.dart`, fast tests + one slow scenario test + spec
artifacts. No changes to `run_command.dart`, `cycle_log.dart`, `cycle_evidence.dart`
(parser gains a field, rendering untouched), or any pipeline step.

## Constitution Check

- **Generation-only implementation**: replay executes *recorded* commands; it never
  writes project sources. The only writes it performs land in its own temp sandbox
  (FR-006/FR-007).
- **Test ownership (044)**: untouched — gen replay re-runs the recorded `zfa tdd
  gen` commands, which enforce their own ownership rules inside the sandbox.
- **Honest evidence**: replay appends nothing to any cycle-log (FR-007) — a replay
  is a verification, not a cycle. Its outputs are stdout contract + NDJSON events.
- **Planner purity (#625 finding 2)**: untouched — no planner is involved.
- **Machine contracts**: `replay: feature=… result=… replayed=… skipped=…
  diverged=…` summary line as the final stdout line on every code path (FR-013),
  #778 exit-code vocabulary (0/1/2/64), NDJSON event log under `--events` (FR-014).
- **Read-only discipline**: the real project is snapshotted, never written; the
  sandbox is `Directory.systemTemp`-owned and `finally`-deleted.

## Project Structure

### Documentation (this feature)

```text
specs/066-zfa-replay/
├── spec.md              # this feature's spec (issue #806 seed)
├── plan.md              # this file
├── research.md          # repo-grounded findings (chain payload, writer formats)
├── data-model.md        # ReplayBehavior / ReplayStepResult / ReplayReport / events
├── contracts/replay.md  # CLI + NDJSON event contracts (exact lines/shapes)
├── quickstart.md        # replay a feature in 3 commands
├── checklists/          # spec quality gates
└── tasks.md             # /speckit.tasks output
└── tdd/
    ├── test-list.md     # /speckit.tdd.plan output (behaviors, one per row)
    ├── cycle-log.md     # red/green evidence from THIS feature's own TDD loop
    └── verification.md  # /speckit.tdd.verify output
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── commands/
│   ├── replay_command.dart        # NEW: zfa tdd replay (thin: parse → delegate)
│   └── tdd_command.dart           # EDIT: addSubcommand(ReplayCommand(plugin))
└── services/
    ├── replay_history.dart        # NEW: group parsed entries per behavior, replayability
    │                              #   + generation-step parsing + chain integrity stage
    ├── replay_sandbox.dart        # NEW: temp sandbox create/seed/delete contract
    └── replay_runner.dart         # NEW: gen replay (steps + TreeSnapshot compare),
                                   #   verify replay (recorded command), report shaping

lib/src/commands/
└── replay_command.dart            # NEW: top-level zfa replay (feature id or cycle-log
                                  #   path → delegate to the same capability)
lib/src/cli/cli_runner.dart       # EDIT: register the top-level command

test/plugins/tdd/
├── services/
│   ├── replay_history_test.dart   # NEW: grouping, gen-step parsing, chain validation
│   └── replay_sandbox_test.dart   # NEW: seeding + cleanup contract
├── commands/
│   └── replay_command_test.dart   # NEW: fast-tier end-to-end via CliRunner.runCapturing
└── scenarios/
    └── sc_018_replay_full_history_test.dart  # NEW (slow): full-history clean replay
                                               #   + mutation catches (SC1–SC7)
```

No changes to `run_command.dart`, `cycle_log.dart`'s writer, `tree_snapshot.dart`,
`step_runner.dart`, or any make/wire/compose pipeline step.

## Key Technical Decisions

1. **Three pure services, one thin command** (house shape). `ReplayHistory` (pure
   parsing/integrity), `ReplaySandbox` (filesystem contract), `ReplayRunner` (stage
   execution + report) — the command layer only parses args, prints the contract
   lines, and sets `exitCode`. Every stage is unit-testable without a CLI.
2. **Chain validation reuses `CycleLog.payloadFromFields` verbatim** (FR-004). The
   payload builder is already public and documented as "the doctor's view of a
   rendered entry … both sides hash byte-identical payloads"; replay recomputes
   sha256 over it from the parsed fields and asserts the prev-hash linkage per
   behavior. No second hashing implementation can drift from the writer's.
3. **Grouping is file-order, chain-walk is per-behavior.** `CycleLog.append` chains
   each behavior's entries independently (genesis → red → green → refactor), so
   replay validates each behavior's hashed entries as an independent chain —
   matching the writer exactly and keeping a legacy hash-less entry (schema-0)
   neutral: it contributes no link, exactly as the writer treats it.
4. **Generation-step parsing extends the reader, not the format.** Green entries
   render `- generation:` / `  - step: <cmd>` blocks (cycle_entry.dart); parseEntries
   ignores them today. Replay adds a section-scoped regex extraction (`- step:` /
   `    exit:` / `    purpose:` lines) as a `ParsedGenerationStep` list on a wrapper
   type — the writer's rendering and `ParsedCycleEntry` stay untouched.
5. **Artifact compare = after-gen sandbox trees vs real project trees.** The sandbox
   is seeded FROM the real project, so a deterministic generator leaves
   `changedPaths` empty; any hand-edit of a generated file, or generator drift after
   a spec change, surfaces as the real tree differing from the re-rendered sandbox
   tree. Paths are project-relative (TreeSnapshot contract) — the sandbox root never
   leaks (FR-009). This is the same "render expected, compare" philosophy as gen's
   stale-mirror check, generalized to the whole tree.
6. **Verify replay runs the recorded command as recorded** — via the shell, cwd =
   sandbox, exit compared to the recorded exit (0 for green). No re-derivation of
   "what should run": the log is the source of truth. Package-resolution gaps degrade
   to a skip-with-warning (FR-011) because an environment gap is not a reproduction
   failure.
7. **Exit codes per #778, summary line per house contract.** 0 clean / 1 divergence
   or infra failure / 2 nothing-replayable / 64 usage (free via `usageException`);
   the `replay:` summary is the last stdout line on every code path, mirroring
   `run:` and `compose:`.
8. **NDJSON events are additive.** Without `--events` nothing changes; with it, one
   JSON object per line with a fixed event vocabulary (`replay.start`, `step.start`,
   `step.end`, `replay.end`), written even on divergence, `replay.end.exit` equal to
   the process exit — the exact shape an agent harness or #791 MCP streaming needs.

## Risks & Considerations

- **Accidental writes to the real project**: the read-only contract (SC1) is tested
  by byte-comparing a real-tree `TreeSnapshot` before/after a replay. The sandbox
  never receives a path pointing back into the real project; `--keep-sandbox` only
  *preserves* the temp dir.
- **Sandbox size / disk hygiene**: seeding copies `lib/` + `test/` + the feature's
  spec dir + `.specify/` — for this repo a few MB. The sandbox is deleted in a
  `finally`; slow-tier scenario tests create their own temp fixtures the same way
  the `tdd run` driver tests already do (no kernel caches involved — replay never
  invokes `dart test` against the repo's own suite).
- **Kernel-cache blowup**: replay never runs the repo's own test suite; fixture
  "test runners" are shell scripts. The chunked runner remains the only test
  execution path during development (disk guard respected).
- **Nondeterministic recorded commands**: if a recorded command embeds absolute
  paths from the original machine, its sandbox re-run may fail — that IS a
  divergence (the history is not reproducible as recorded), reported with the step
  named; FR-011 only covers package-resolution gaps.
- **Hash-less narratives cannot replay**: by design (Assumptions); the zero-
  parseable-entries case surfaces as exit 2 with an explicit message rather than a
  silent pass.

## Dependencies

- Spec 046-tdd-verify-red — the red-evidence entry contract replay validates.
- Spec 047-tdd-make — the green entry's `generation:` block replay re-executes.
- Bug #828 — the schema-1 evidence chain replay recomputes (the tamper-evidence
  layer).
- Spec 049-tdd-run — the run/step exit-code and summary-line vocabulary replay
  follows.
- Issues #804/#806 — VISION 2030 Pillar A: this feature is the replay slice.
- Issues #778 (exit codes), #791 (NDJSON streaming direction), #787 (journal/cycle
  log lineage) — the machine-contract anchors named in the issue.
