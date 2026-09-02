# Feature Specification: `zfa replay` — deterministically re-execute a feature's recorded TDD history

**Feature Branch**: `066-zfa-replay`

**Created**: 2026-09-03

**Status**: Draft

**Input**: Issue [#806](https://github.com/arrrrny/zuraffa/issues/806) — "[VISION] ⏪ `zfa replay`: deterministically re-execute any feature's TDD history". Part of 🧭 VISION 2030 (#804), Pillar A: Proof-carrying generation. Builds on #787 (evidence chain, cycle-log format) and the run-state store proven by #791's resume direction; exit codes follow #778.

## Mission

`tdd/cycle-log.md` is already an honest history: since bug #828 every machine-appended
entry carries the certified facts (behavior, kind, criterion, test, command, exit,
timestamp) and a per-behavior tamper-evident hash chain (`prev-hash` → `hash`). But the
log is only *readable* today — the doctor checks state-vs-evidence drift, yet nothing
can take a recorded history and *re-execute* it to prove the recorded loop still
reproduces: that the recorded generation commands still render byte-identical
artifacts, and that the recorded green command still passes. "It broke between Tuesday
and Wednesday" has no bisectable command; a recorded history cannot rot loudly.

This feature adds the first slice (v0) of `zfa replay`: a command that spins a clean
sandbox copy of the project, replays a behavior's recorded cycle — every recorded gen
step re-run and the artifact trees snapshot-compared (normalized, path-stable diff),
the recorded green verify command re-run — and either passes clean (silent pass) or
reports a precise, behavior-level diff naming the divergent step. Tamper detection is
layered in from day one: a mutated cycle-log entry breaks the recorded hash chain, a
mutated artifact shows up as generation drift, a mutated implementation shows up as a
verify divergence — each caught *with the step named*. History becomes executable
documentation that either runs or screams.

**Honest v0 scope**: replay re-executes the *gen → verify* half of a behavior's
recorded cycle. Red *reproduction* (re-witnessing the test fail against a
pre-implementation tree) requires pre-make state snapshots that no pipeline step
records today; v0 instead structurally validates red evidence (recorded paths exist,
non-zero exit, classification present) and re-executes what IS reproducible: gen and
the green verify. Refactor entries are reported as recorded but never re-executed
(refactors already shaped the current tree; re-running them is not idempotent).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A recorded behavior cycle replays clean in a sandbox (Priority: P1)

A maintainer (or a fresh agent instance recovering context after a crash) has a
feature whose cycle-log records a full machine-format cycle for a behavior: red
evidence, a green entry carrying the recorded generation steps and the recorded green
command. They run `zfa tdd replay <feature> --behavior <id>` (or the top-level
`zfa replay` dream surface). The command builds a clean sandbox copy of the project
from a temp directory, re-runs the recorded generation steps inside it, snapshots the
sandbox's `test/` + `lib/` trees and compares them against the real project's trees
(a normalized, path-stable diff — relative paths, sorted, A/M/D classified), then
re-runs the recorded green verify command inside the sandbox. Generation is
byte-identical and the verify exits 0 exactly as recorded: the command prints the
per-step progress lines, the final machine summary `replay: feature=<f>
result=clean replayed=1 skipped=0 diverged=0`, and exits 0. The real project is never
written to — replay is read-only against it, and the sandbox is deleted afterwards.

**Why this priority**: this is the entire v0 slice the issue names ("Replay a single
behavior's cycle (gen → verify) in a temp project") and the proof-carrying core —
without a clean replay path there is nothing to diverge from.

**Independent Test**: A fixture project with one behavior whose cycle-log is seeded
through the real `CycleLog.append` writer (schema-1 chain lines) with red + green
entries whose recorded gen steps and green command target the fixture's fake `zfa`
and runner scripts: `zfa tdd replay` exits 0 with `result=clean`, the gen step
reports the artifact trees identical, the verify step reports green, and the real
project's files are untouched afterwards.

### User Story 2 - An injected mutation into any replayed step is caught, with the step named (Priority: P1)

Something drifted since the history was recorded. Three tamper surfaces, one catch
contract — each reports a precise, behavior-level divergence and exits 1:

1. **History tamper**: a field inside a hashed (schema-1) cycle-log entry is edited
   (e.g. a green entry's `- exit:` flipped from 0 to 1, or a command string swapped).
   The replay recomputes the per-behavior hash chain (`CycleLog.payloadFromFields` +
   prev-hash linkage, exactly what `CycleLog.append` chained) and reports the
   integrity divergence naming the behavior and the kind of the first broken link.
2. **Artifact drift**: a generated artifact on disk no longer matches what the
   recorded gen step produces (a hand-edited generated test, or generator drift after
   a spec change). The gen replay's tree comparison reports the drift naming the
   changed/added/missing paths (A/M/D, sorted, project-relative).
3. **Verify divergence**: the recorded green command no longer passes (someone broke
   `lib/` between Tuesday and Wednesday). The verify replay reports the divergence
   naming the behavior, the recorded exit and the actual exit.

**Why this priority**: "Divergent: a precise, behavior-level diff report" and the
issue's own Done-when ("An injected mutation into any replayed step is caught, with
the step named") — replay without teeth is a no-op.

**Independent Test**: For each tamper surface, mutate one thing (a cycle-log field /
a generated test file's rendered content source / the subject implementation the
recorded command exercises), re-run `zfa tdd replay`, and assert exit 1 with
`result=divergent` and a report line naming the exact behavior + step (and for
artifact drift, the exact paths; for integrity, the exact entry kind).

### User Story 3 - Full recorded history replays in one invocation (Priority: P2)

A reviewer wants to replay instead of re-reading. `zfa tdd replay <feature>` with no
`--behavior` walks every behavior the log records, in file order, driving each
behavior's cycle through the same integrity → gen → verify stages, one
`[replay] <behavior> <stage> -> <outcome>` progress line per stage, and aggregates:
`result=clean` only when every replayed behavior is clean; any divergence fails the
whole run with exit 1 and the divergent behaviors named. Behaviors whose recorded
history is unplayable (only-red so far, no generation block, no recorded green
command) are *skipped with a warning each* — if nothing at all is replayable the run
is `result=partial` with exit 2; otherwise skips are warnings inside a clean run.
`--keep-sandbox` preserves the sandbox for debugging (its path is printed);
without it the sandbox is always deleted, even on failure.

**Why this priority**: the second Done-when ("Replaying the todo example's full
recorded history passes clean") is the whole-history path, and the aggregate
semantics are what make replay a review surface.

**Independent Test**: A fixture with two replayable behaviors and one only-red
behavior: full replay exits 0 with `replayed=2 skipped=1 diverged=0`; tampering the
second behavior's green command output flips the run to `result=divergent` exit 1
while the first behavior still reports clean steps.

### User Story 4 - Replay speaks machine: NDJSON events and #778 exit codes (Priority: P2)

An agent harness runs replay as part of its recovery loop. `--events <path>` writes a
newline-delimited JSON event log — one JSON object per line: `replay.start`, then
`step.start` / `step.end` per stage with behavior + step + status (+ paths on drift,
expected/actual exit on verify divergence, named entry kind on integrity failure),
terminated by `replay.end` carrying the aggregate result and the final exit code —
the streaming direction #791 aligns on. Exit codes follow the #778 vocabulary: 0
clean, 1 divergence (integrity, artifact drift, verify divergence, or replay
infrastructure failure), 2 nothing replayable, 64 usage (bad invocation). Without
`--events` the command stays on the house machine contract: `[replay]` progress lines
plus the final `replay:` summary line.

**Why this priority**: agents are the stated audience ("Agents are stateless — replay
is how they regain context"), but the contract is additive plumbing on top of a
working US1–US3 core.

**Independent Test**: Run a clean replay with `--events <path>`: the file parses as
NDJSON, starts with `replay.start`, carries one `step.end` per replayed stage with
`status: identical|green`, and ends with `replay.end` whose `exit` field equals the
process exit code.

### Edge Cases

- **Missing cycle-log** (`specs/<feature>/tdd/cycle-log.md` absent): exit 1 with an
  explicit "no recorded history" message — replaying a history that does not exist is
  a runtime failure, not a skip.
- **Cycle-log exists but carries zero machine-parseable sections** (e.g. a
  hand-written narrative log from before the bug-#828 format, like
  `specs/031-scaffold-todo-example/tdd/cycle-log.md`): no behavior has recorded
  facts to replay → `result=partial`, exit 2, with a message saying the log carries
  no machine-format entries. Replay never executes prose.
- **Unknown `--behavior` id** (not in the log): exit 1 naming the requested id and
  the behaviors that ARE recorded.
- **Behavior has only red evidence** (loop in progress): integrity stage still runs;
  gen and verify are skipped with warnings (`no generation block`, `no green
  command`); the behavior counts as skipped.
- **Legacy hash-less entries** (schema-0): valid but unverifiable — chain validation
  skips them with a warning (`unverified: schema-0`), mirroring the doctor's
  never-fails-unhashed stance. An entry that carries hash lines but is missing a
  certified fact the payload covers is an integrity divergence (tampered or
  malformed).
- **Sandbox verify cannot resolve packages** (no usable package config could be
  carried into the sandbox): verify is skipped with a warning; gen replay still ran.
- **Recorded command cannot be spawned** (binary missing, sandbox setup failed):
  runner-error divergence, exit 1, the failing step named.
- **Empty tree drift**: a gen step that produces nothing (all recorded paths
  unchanged) is `identical`, not an error.

## Requirements *(mandatory)*

### Functional Requirements

**Surfaces and selection**

- **FR-001**: The command MUST be available as `zfa tdd replay <feature>` with the
  house TDD command contract (`--project`/`--project-root`, `--timeout` via the
  shared `parseTddTimeoutMinutes`, `--zfa-bin` for spawned generation steps) AND as
  the top-level dream surface `zfa replay` accepting either a feature id or a path
  to a cycle-log file (e.g. `zfa replay tdd/cycle-log.md` from inside a feature's
  `tdd/` directory), delegating to the same capability. Both surfaces MUST support
  `--behavior <id>` (single-behavior replay), `--events <path>`, and
  `--keep-sandbox`.
- **FR-002**: The history source MUST be `specs/<feature>/tdd/cycle-log.md`, parsed
  with the shared `CycleEvidence.parseEntries`. A missing log MUST stop with exit 1
  ("no recorded history for feature …"). A log with zero parseable behavior sections
  MUST yield `result=partial` with exit 2 (nothing replayable).
- **FR-003**: Entries MUST be grouped by behavior id preserving file order within
  each behavior; `--behavior <id>` MUST filter to one behavior, and an id the log
  does not record MUST stop with exit 1 naming the id and the recorded behaviors.

**Integrity stage**

- **FR-004**: For every hashed (schema-1) entry, replay MUST recompute the evidence
  chain exactly as `CycleLog.append` built it: sha256 over
  `CycleLog.payloadFromFields(...)` with the entry's parsed facts and its recorded
  `prev-hash`, asserting (a) the recomputed hash equals the recorded `hash` and (b)
  the recorded `prev-hash` equals the previous hashed entry's hash for that behavior
  (or `CycleLog.genesisHash` for the first). Any mismatch MUST be a divergence
  naming the behavior and the entry kind as the broken link.
- **FR-005**: Red entries MUST be structurally validated: every recorded `test:`
  path MUST exist in the real project tree, the recorded `exit:` MUST be non-zero,
  and a red entry MUST carry a classification. Violations are divergences named
  `red:<violation>` against the behavior. Red reproduction (re-witnessing the
  failure) is explicitly out of v0 scope and MUST NOT be attempted.

**Sandbox and gen replay**

- **FR-006**: The sandbox MUST be a fresh temp directory
  (`Directory.systemTemp.createTemp('zfa_replay_')`) seeded by copying from the real
  project: `pubspec.yaml`, `pubspec.lock` (if present), `analysis_options.yaml` (if
  present), `.zfa.json` (if present), the `lib/` and `test/` trees, the feature's
  `specs/<feature>/` directory, `.specify/` (memory/config the commands read), and
  `.dart_tool/package_config.json` (if present — its relative `rootUri`s resolve
  inside the copied tree, giving the sandbox working package resolution without a
  pub get). The copy MUST exclude `.git`, `build/`, and the dart test kernel caches
  under `.dart_tool/test/`. Absent sources are skipped silently; the sandbox path is
  printed in the header line.
- **FR-007**: The sandbox MUST be deleted in a `finally` block unless
  `--keep-sandbox` is given; with the flag the path MUST be printed in the summary
  line. Replay MUST NOT write anything into the real project (read-only contract),
  and MUST NOT append anything to the real cycle-log — a replay is a verification,
  not a cycle.
- **FR-008**: Gen replay MUST re-run the recorded generation steps — the `step:`
  commands parsed from the behavior's green entry `generation:` block, in recorded
  order — inside the sandbox (cwd = sandbox root, the step's `--project` targeting
  the sandbox, `--zfa-bin` resolution for `zfa` invocations). After the steps run,
  the sandbox's `test/` + `lib/` trees MUST be snapshot-captured
  (`TreeSnapshot.capture`) and compared against the real project's same trees via
  `changedPaths`: any difference is an artifact-drift divergence listing the
  project-relative paths classified added/modified/missing (sorted). A green entry
  with no generation block (or `(none)`) MUST skip gen replay with a warning.
- **FR-009**: The tree comparison MUST be normalized and path-stable: entries keyed
  by project-relative forward-slash paths (TreeSnapshot's contract), so the sandbox
  root's absolute location never leaks into the report.

**Verify replay**

- **FR-010**: Verify replay MUST re-run the behavior's recorded green `command:` in
  the sandbox via the shell (`cwd` = sandbox), under the `--timeout` budget, and
  compare the actual exit against the recorded exit: a green entry records 0, so a
  non-zero (or unspawnable) outcome is a verify divergence naming the behavior,
  expected and actual exits. A green entry with no recorded command MUST skip
  verify with a warning.
- **FR-011**: If the real project carries a `pubspec.yaml` but no
  `.dart_tool/package_config.json` (never resolved), verify MUST be skipped with a
  `no package resolution` warning rather than reported as a divergence (the
  divergence vocabulary is for *reproduction* failures, not environment gaps); gen
  replay still runs. A present package config is mirrored into the sandbox (FR-006)
  and verify proceeds.

**Aggregation, contract, events**

- **FR-012**: Refactor entries MUST be reported as recorded (`refactor: recorded,
  not re-executed` warning per behavior) but MUST NOT be re-executed in v0.
- **FR-013**: Exit codes MUST follow the #778 vocabulary: 0 — clean (every replayed
  stage reproduced; skips allowed as warnings); 1 — any divergence (integrity,
  artifact drift, verify divergence) or replay infrastructure failure (missing log,
  unknown behavior, sandbox setup failure); 2 — nothing replayable (zero
  parseable behaviors, or every behavior skipped); 64 — usage errors
  (via `usageException`). The final stdout line on every code path MUST be the
  machine summary `replay: feature=<f> result=<clean|divergent|partial>
  replayed=<n> skipped=<n> diverged=<k>`.
- **FR-014**: `--events <path>` MUST write the NDJSON event log: `replay.start`
  (feature, behaviors, at), `step.start` / `step.end` per stage (behavior, step,
  status, plus `paths` on drift, `expected`/`actual` on verify divergence, `entry`
  kind on integrity failure), and a terminal `replay.end` (result, replayed,
  skipped, diverged, exit, at). Each line MUST be a single JSON object; the file
  MUST be written even when the run diverges, and `replay.end.exit` MUST equal the
  process exit code.

### Key Entities

- **ReplayBehavior** — one behavior's grouped history: id, ordered
  `ParsedCycleEntry`s (red/green/refactor), derived replayability (has gen steps?
  has green command?).
- **ReplayStepResult** — one stage outcome per behavior: stage (`integrity` | `gen`
  | `verify`), status (`identical` | `green` | `drift` | `diverged` | `skipped`),
  detail (paths / exits / broken entry kind), used for both the progress lines and
  the events.
- **ReplayReport** — the aggregate: per-behavior step results, replayed/skipped/
  diverged counts, final result label and exit code; rendered as the `replay:`
  summary line and the `replay.end` event.
- **ReplaySandbox** — the seeded temp project copy; owns creation, seeding, and the
  guaranteed cleanup contract (FR-006/FR-007).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC1**: A fixture feature with two behaviors carrying full schema-1 recorded
  cycles (seeded through the real `CycleLog.append` writer) replays clean
  end-to-end: exit 0, `result=clean replayed=2 skipped=0 diverged=0`, gen steps
  report identical trees, verify steps report green, and the real project's files
  are byte-identical before/after the run (read-only contract).
- **SC2**: Flipping one certified fact inside a hashed entry (a green `- exit:` or a
  command string) breaks the replay: exit 1, `result=divergent`, and the divergence
  names the behavior and the `green` entry as the broken chain link.
- **SC3**: Mutating what a recorded gen step renders against (divergent generation
  source) flips the gen stage to drift: exit 1 with the affected
  project-relative path(s) listed as modified.
- **SC4**: Breaking the subject implementation the recorded green command exercises
  flips the verify stage: exit 1 naming the behavior with expected 0 and the actual
  non-zero exit.
- **SC5**: A three-behavior feature (two replayable, one only-red) replays with
  `replayed=2 skipped=1 diverged=0` exit 0; the same feature with nothing
  replayable (narrative-only log) yields `result=partial` exit 2.
- **SC6**: A clean run with `--events` produces a parseable NDJSON file whose last
  line is `replay.end` with `exit: 0`; a divergent run's event log carries the
  divergence event with the named step and `replay.end.exit == 1`.
- **SC7**: `zfa replay <feature>` and `zfa replay <path>/tdd/cycle-log.md` reach the
  same capability as `zfa tdd replay <feature>` (identical summary and exit); an
  unknown behavior id stops with exit 1.

The "todo example" Done-when is verified per SC1's protocol: the fixture history is
recorded through the real `CycleLog.append` writer — the same machine format every
pipeline-driven feature's full history uses — and replayed clean end-to-end. The
`example/` Flutter app itself predates the machine format (its `specs/031` log is
hand-written narrative with no parseable behavior sections) and is covered by the
zero-parseable-entries edge case (exit 2), not by a clean replay.

## Out of Scope

- **Red reproduction** — re-witnessing a red entry's failure requires pre-make state
  snapshots (time-travel); v0 validates red evidence structurally and replays
  gen → verify only.
- **Refactor re-execution** — refactor entries are reported, never replayed (v0).
- **The global `.zfa/journal.jsonl` generation journal (#787)** — not implemented in
  the repo; replay keys on the per-feature cycle-log only.
- **MCP streaming integration (#791 proper)** — replay only ships the NDJSON event
  vocabulary; wiring it as MCP `notifications/progress` is #791's surface.
- **Cross-machine bit-identical artifact guarantees** — the chain hashes certify the
  history's integrity; artifact comparison is same-machine content equality.
- **A real Flutter-app-level replay of `example/`** — needs the Flutter SDK at
  replay time; the fast suite covers the mechanics via fixture projects, and the
  capability is SDK-agnostic by construction (it runs recorded commands).

## Assumptions

- The machine cycle-log format (bug #828, schema 1) is the replayable format;
  narrative pre-format logs are reported as nothing-replayable, never parsed as
  behaviors.
- Recorded gen steps are re-runnable as written: they are the same `zfa tdd gen …`
  commands the pipeline spawns, and the fixture harness proves the flow with a
  scripted fake `zfa` binary exactly like `tdd run`'s driver tests do.
- `--zfa-bin` defaults to resolving `zfa` from PATH for gen replay, mirroring
  `tdd run`'s step-spawning contract.
- The recorded green command is shell-runnable in the sandbox; if the project
  relied on a package config that cannot be mirrored, FR-011's skip-with-warning
  applies rather than a hard failure.
