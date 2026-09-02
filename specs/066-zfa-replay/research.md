# Research: `zfa replay` (spec 066)

Repo-grounded findings this plan relies on. Every claim verified against the
working tree at branch point `bd535c07` (master, 2026-09-03).

## 1. The cycle-log machine format is replayable as recorded

- **Writer**: `lib/src/plugins/tdd/services/cycle_log.dart`. `append()` renders the
  entry via `CycleLogEntry.toMarkdown()` and appends `- schema: 1`, `- prev-hash:`,
  `- hash:` lines. The chain is **per behavior**: `lastHashFor(behaviorId)` →
  genesis for the behavior's first hashed entry, red → green → refactor after.
- **Chain payload**: `CycleLog.payloadFromFields` (public, lines 87–108) —
  `['v1', behaviorId, kind, exit, command, criterion, test, timestamp, prevHash]
  .join('\x00')`, sha256-hex by `_chainHash`. The doc comment states the payload
  builder is shared "so both sides hash byte-identical payloads" — replay
  recomputes it from parsed fields; no second implementation.
- **Reader**: `lib/src/plugins/tdd/services/cycle_evidence.dart` —
  `parseEntries(raw)` yields `ParsedCycleEntry {behaviorId, kind, at, exit,
  criterion, test, command, schema, prevHash, hash}` per `## `-delimited section
  (`- behavior:` line required; hand-written prose sections are skipped naturally).
  Command backticks are stripped by the regex — equal to the recorded runner
  command. Legacy hash-less entries parse with `null` hash fields (`isHashed ==
  false`).
- **Generation block** (green entries): `cycle_entry.dart` renders
  `- generation:` then per step `  - step: <cmd>` / `    exit: <n>` /
  `    purpose: <p>`, or `  (none)`. `parseEntries` does NOT parse this block —
  replay adds a section-scoped extraction (plan.md Decision 4).
- **No narrative parsing**: `specs/031-scaffold-todo-example/tdd/cycle-log.md` is
  hand-written narrative (`## Cycle 1: …` + prose bullets) — zero sections carry
  `- behavior:`, so `parseEntries` yields nothing for it. Confirmed: the
  zero-parseable edge case (spec exit 2) is real and reachable.

## 2. The doctor does NOT recompute the chain today

`grep chainHashFor lib/src/plugins/tdd/commands/doctor_command.dart` — no matches.
The doctor checks state-vs-evidence drift only. Replay's integrity stage is
genuinely the first chain verifier in the repo; it uses the writer's own
`payloadFromFields` so no drift is possible.

## 3. TreeSnapshot is the established tree-compare primitive

`lib/src/plugins/tdd/services/tree_snapshot.dart` — `capture(projectRoot,
trees: ['test','lib'])` fingerprints files (`file:<sha256>`), dirs (`directory`),
links (`link:<target>`) keyed by **project-relative, forward-slash paths**;
`changedPaths(other)` is a symmetric sorted diff. Missing trees contribute no
entries. Path-stability (FR-009) is inherent — the sandbox root never appears in
keys.

## 4. Sandbox precedent: gen's stale-mirror + the driver-test fixture pattern

- `gen_command.dart` (stale check) renders the expected gen pair into
  `Directory.systemTemp.createTemp('zfa_gen_stale_')` and byte-compares — replay's
  sandbox generalizes this to a whole-tree compare.
- `test/plugins/tdd/helpers/tdd_fixture.dart` builds a temp project (pubspec,
  `.specify/memory/tdd-profile.md`, `specs/<feature>/tdd/artifacts.json` registry,
  synthetic tests) plus a **scripted POSIX sh fake zfa binary** (per-step exit
  codes + stdout machine lines via config files). `run_command_test.dart` drives
  the real `CliRunner.runCapturing(['tdd','run', …, '--zfa-bin', fakeZfaBin])`
  in-process. Replay tests reuse exactly this pattern: recorded gen steps target
  the fake binary, recorded green commands target shell scripts — no `dart test`
  inside fixtures (kernel-cache safe).
- `seedRedEvidence` (fixture lines 126–149) shows the machine entry shape; replay
  tests seed via the **real `CycleLog.append`** instead so chain lines are
  byte-exact by construction.

## 5. Exit-code + summary-line house contracts to mirror

- `run_command.dart`: `static const _exitComplete/_exitStopped/_exitRunnerError/
  _exitCorruptState/_exitConcurrentRun = 0..4`; progress lines
  `[run] <behavior> <step> -> <outcome>`; final summary
  `run: feature=<f> result=<r> …`.
- `cli_runner.dart::_runDispatched`: `UsageException` → exit **64**; commands
  signal outcomes via the `exitCode` setter.
- `parseTddTimeoutMinutes` (`services/tdd_timeout.dart`): shared `--timeout`
  parser (bug #742).
- Feature dir resolution: `p.join(projectRoot, 'specs', feature)` after
  `_stripSpecsPrefix` + `_validateFeatureSegment` (run_command.dart lines
  180–201).
- Top-level registration: `cli_runner.dart::_addCoreCommands` (line ~177); tdd
  subcommands: `tdd_command.dart` constructor.

## 6. `ArtifactRegistry` behavior on re-gen (why sandbox gen re-runs cleanly)

`services/artifact_registry.dart`: registering an existing record whose files
exist is a **no-op** (`Ownership.reused`, registry unmodified); conflicts only
arise for unowned pre-existing files. In the sandbox the registry + files are
copied together, so recorded gen steps re-run in the same ownership state they
originally ran in — deterministic, no ownership surprises.

## 7. No existing NDJSON emitter to reuse

`grep ndjson|jsonl lib/` → only `tdd/audit.log` JSONL appends (gen adoption
audit, bug #840) and the write-ahead `journal.json` (bug #828). The `--events`
NDJSON writer is net-new but follows the audit.log one-JSON-object-per-line
pattern; `jsonEncode` needs no new dependency.

## 8. Exit vocabulary decision (spec FR-013)

#778's table: 0 success / 1 runtime failure / 2 partial-skip / 64 usage. Replay
maps: divergence (integrity, drift, verify) and infra failure (missing log,
unknown behavior, sandbox failure) → 1; zero replayable behaviors → 2; usage via
`usageException` → 64. This matches the issue's "Exit codes per #778" while
staying inside the house vocabulary (`run`/`corpus` use 0–4 for loop states —
replay is not a loop driver and has no run-state to corrupt, so 3/4 have no
replay meaning).
