# Research: `zfa tdd corpus` (spec 051-corpus-harness)

Phase 0 output. Each NEEDS CLARIFICATION from the plan's Technical Context
is resolved as a Decision / Rationale / Alternatives triple, grounded in the
merged code the harness consumes (specs 044–050, current master
`11de4bfc`).

## R1 — Where does the corpus manifest live, and who writes it?

**Decision**: the manifest is READ-ONLY input to the harness at
`.zfa/manifests/corpus-manifest.json`, exactly the contract
`specs/050-corpus-import/data-model.md` (branch `origin/050-corpus-import`,
unmerged) pins: `features: [{name, ready, reason}]` in source-lexicographic
order, plus `sourceCorpus` and `importedAt` (the only field that differs
across identical re-imports). 051 does not write it; the fixtures write it
directly, and #627's import will emit it verbatim when implemented.

**Rationale**: the 050-corpus-import data-model is the agreed contract
between the two features ("Corpus Manifest: the contract between import and
batch driving"). Honoring it now means #627's implementation lands without
any harness change. Reading it as read-only also matches how `run` consumes
`tdd/test-list.md` — a consumer, never an author.

**Alternatives considered**: (a) let 051 define its own manifest path —
rejected: breaks the documented #627 contract on arrival; (b) re-derive the
feature list by scanning `specs/` — rejected: readiness marks and
deterministic order are manifest state, not derivable from directory
listing, and the spec's US1 names the manifest as the source.

## R2 — How are `zfa tdd run` and `zfa tdd verify` invoked per feature?

**Decision**: as sub-processes through the same spawn contract `StepRunner`
established (spec 049): argv `tdd run <feature> --project <root>` /
`tdd verify --feature <f> --project <root>`, executed via the resolved
entrypoint — the `--zfa-bin` override when given, else
`dart <pkg>/bin/zfa.dart` (a `.dart` entrypoint runs through `dart`;
anything else, i.e. a scripted fake or compiled binary, executes
directly). Success agreement = the sub-process's exit code AND its
documented machine summary line (`run: feature=... result=...` /
`mutation: gate=...`), parsed by the same last-`<verb>:`-line scan
`StepRunner._parseSummaryLine` uses.

**Rationale**: sub-process isolation is the whole reason 049's driver can
claim a step crash never corrupts driver state; the corpus is one more
level of the same recursion. The `--zfa-bin` hook is what makes the entire
harness testable with a scripted fake (the fixture pattern
`TddFixture.writeFakeZfaBin` already proves works for `run`). The run exit
codes are already a documented contract: 0 complete, 1 stopped, 2
runner-error, 3 corrupt-state, 4 concurrent-run. The verify command exits
non-zero whenever the gate is not PASS and prints
`mutation: gate=<label> killed=... survived=... timed_out=...`.

**Alternatives considered**: (a) in-process invocation via
`CliRunner.runCapturing` — rejected: a feature-level crash (or `exit()`
call) would take the orchestrator down with it, and the 049 contract
explicitly spawns sub-processes; (b) consuming `run-state.json` instead of
the summary line — rejected for gating decisions: state files are
per-behavior bookkeeping, while the summary line is the documented
machine contract (FR-009/FR-010); state files ARE additionally read for
the stopped_at behavior:step detail the ledger records.

## R3 — Where does corpus progress live and how does resume work?

**Decision**: `.zfa/corpus/progress.json`, written atomically
(temp-file + rename, the `RunStateStore.save` pattern) after every
completed feature. Shape: per-feature entries
`{name, state, gate?, waiver?, stopped_at?}` where state ∈
`pending | driving | done | stopped | waived`; plus an in-flight marker
`{feature, owner_pid}` and a `dropped` list (features removed from the
manifest mid-stream, retained per the run command's dropped semantics).
Resume = the first manifest feature (in manifest order) whose state is not
`done`/`waived`; features before it are never re-driven (the runner skips
them, exactly as `run` skips DONE behaviors).

**Rationale**: the spec's US1/US2 requires per-feature persistence after
every feature and resume from the first incomplete feature; atomic rename
guarantees a crash mid-write leaves the previous file intact; the pid
in-flight refusal (signal-0 liveness probe, owner-or-dead passes) is the
FR-010 concurrency guard and mirrors `RunStateStore.refusalReason`
line-for-line. Dropped semantics mirror the run command's (US edge case:
"removed features keep their progress entries marked dropped
(append-only)").

**Alternatives considered**: (a) one file per feature under
`.zfa/corpus/features/` — rejected: 120 tiny files for O(1) lookups the
single-file map already gives; the spec's assumption explicitly blesses
"per-feature state files and an aggregate progress file" — the aggregate
file suffices; (b) deriving progress from per-feature run-state.json
files — rejected: those are behavior-level, not gate-level; corpus-done
means the verify gate passed, which lives nowhere today.

## R4 — What exactly does the gap ledger record, and what is its file?

**Decision**: `.zfa/corpus/gap-ledger.json` — a JSON array, appended by the
runner, never rewritten except atomically (load → append → rename).
Entries carry the spec's FR-007 six fields plus bookkeeping:
`{id, at, feature, behavior, step, outcome, failing_command, issue_link,
status}` where `id` is `gap-###` (monotonic), `behavior`/`step` name the
stop point (`run` failures record the run summary's `stopped_at`
`behavior:step`; verify failures record step `verify` and the gate label
as outcome), `issue_link` starts null (the placeholder the maintainer
fills when filing), and `status` ∈ `open | filed | merged | resolved`. A
resolved gap is a NEW entry (`{kind: resolution, resolves: gap-003, ...}`)
— the old entry is never edited (US4.AC2). Totals: found = entries;
filed = entries with a non-null issue link; merged = status merged;
blocking = open gaps whose feature is not currently done/waived.

**Rationale**: the ledger must be append-only, resume-safe, and survive as
history; JSON gives CI-friendly totals and the fixture tests exact-equality
assertions. The resolution-as-new-entry rule comes straight from
US4.AC2. `status`/`issue_link` are maintainer-edited fields (filing the
issue is a human act); the runner only ever appends `open` entries and
resolution entries.

**Alternatives considered**: (a) markdown ledger (cycle-log style) —
rejected: totals require parsing prose; the spec demands ledger totals in
the report (FR-008) and a parseable ledger; (b) JSONL — rejected: JSON
array + atomic rename matches the store pattern already in the codebase
and keeps one decoder.

## R5 — What are the audit's provenance sources and carve-out contract?

**Decision**: `zfa tdd corpus audit` walks the app's `lib/` (every regular
file, recursive, excluding nothing but staying inside `lib/`) and
attributes each file by, in priority order:
1. **artifact registry**: every `specs/*/tdd/artifacts.json` record's
   `subject_path` (absolute or project-relative) — attributed to that
   feature's `zfa tdd gen <behavior>` loop invocation;
2. **cycle-log refactor evidence**: every `changed:` file list on refactor
   entries in `specs/*/tdd/cycle-log.md` — attributed to the entry's
   `command`;
3. **setup/import provenance records**: every `.zfa/provenance/*.json`
   file of shape `{command, at, files: [...]}` — attributed to `command`
   (this is the record format #626/#627 must emit; 051 defines the
   consumer);
4. **carve-out manifest**: `.zfa/manifests/corpus-carveout.json` of shape
   `{carveouts: [{path, reason}]}` — the sole exemption list, versioned
   app content.
Any file left unattributed fails the audit BY NAME, non-zero. Output:
`.zfa/corpus/audit-report.json` (per-file attribution map, carve-out list,
counts) + the human summary line
`audit: files=<n> attributed=<n> carveout=<n> unattributed=<n>
result=<pass|fail>`. Relative paths in records resolve against the project
root; matching normalizes to POSIX-style project-relative paths.

**Rationale**: the spec's US3/FR-005 names exactly these sources ("drawn
from the cycle logs' recorded generation steps, the import/setup
provenance, and the declared manual-UI carve-out manifest"). The artifact
registry is the machine-readable file→command mapping the loop already
writes per behavior; the refactor `changed:` lists are the only other
file-producing evidence in cycle logs (green `generation:` steps record
commands, whose created files are exactly what artifacts.json registers);
`.zfa/provenance/` is the documented landing spot for setup/import records
(the 051 spec's edge case says the audit "consumes the setup/import
provenance records, not only loop cycle logs" and its assumptions note
"#626/#627 must emit theirs"). The carve-out as a versioned JSON manifest
satisfies US3.AC3 (removing an entry → the file fails) and keeps the
exemption machine-checkable.

**Alternatives considered**: (a) parse generation-step commands to infer
created files — rejected: commands like `zfa entity create User` do not
carry their output paths; inferring would duplicate the pipeline's mapping
logic and drift; (b) carve-out as comments in source files — rejected: not
versioned-content-checkable, and editing source to satisfy the audit
inverts the proof; (c) `.gitignore`-style patterns — rejected: exact paths
keep the manifest honest and the removal semantics exact (SC-003).

## R6 — How do waivers work (never silent)?

**Decision**: a maintainer-authored, versioned
`.zfa/corpus/waivers.json`: an array of
`{feature, gate, reason, actor, at}` records. The runner consults it only
when evaluating a verify outcome: if the actual gate label equals the
waiver's `gate` for that feature, the feature is marked `waived` with the
full waiver record copied into progress (and surfaced in the run/status
final report). Any other outcome is NOT covered (a waiver for
`not_assessed` does not absorb `fail_survived`). A waived feature counts
as corpus-done; the report always lists waivers with reason + actor + at.

**Rationale**: FR-004/US2.AC2-3 make waivers explicit, recorded, and
outcome-scoped; gating the file on the exact outcome prevents a broad
waiver silently absorbing a different failure (SC-002: 0 silent
absorptions). The file is maintainer-authored exactly like the carve-out
manifest — the runner never writes it.

**Alternatives considered**: (a) a `--waive` CLI flag on corpus run —
rejected: a flag is an in-the-moment act, not a versioned, reviewable
record, and the spec wants the waiver visible in progress AND reports
(read by later runs); (b) waiver entries inside the ledger — rejected: the
ledger records gaps (failures); a waiver is a decision, and mixing the two
makes "worked-around progress never counts" harder to audit.

## R7 — Exit codes and machine summary lines (the CI contract)?

**Decision**: each corpus subcommand ends with one machine line and a
documented exit code:
- `corpus run` → `corpus: features=<n> done=<n> waived=<n> stopped=<n>
  not_ready=<n> pending=<n> dropped=<n> gaps=<n> result=<r>
  [stopped_at=<feature>]`; exit 0 complete, 1 stopped (roadblock or gate),
  2 runner-error, 3 corrupt-state, 4 concurrent-run — mirroring `run`'s
  scheme so operators transfer their intuition one level up.
- `corpus status` → the same line shape (read-only; result=complete|
  incomplete); exit 0 exactly when every manifest feature is done or
  waived (FR-009), 2 runner-error, 3 corrupt-state.
- `corpus audit` → `audit: files=<n> attributed=<n> carveout=<n>
  unattributed=<n> result=<pass|fail>`; exit 0 pass, 1 fail (naming every
  unattributed file), 2 runner-error.
Key=value parsing uses the same `(\w+)=([^\s]+)` scan StepRunner applies,
so CI consumes them identically.

**Rationale**: the loop commands' contract style (every command ends with
`<verb>: key=value ...`; exit code semantics documented in the command
docstring) is the house style FR-009/SC-005 demand ("same contract style
as the loop commands", "stable for CI consumption"). Reusing `run`'s exit
code meanings keeps the STOP-ON-ROADBLOCK story uniform.

**Alternatives considered**: boolean exit (0/1) everywhere — rejected: the
repo's loop commands already separate stopped/runner-error/corrupt/
concurrent, and the corpus must surface the same distinctions to script
recovery flows.

## R8 — What about the `.zfa/` directory itself (no precedent in lib/)?

**Decision**: the harness introduces a tiny path helper
(`corpus_manifest_store.dart` exposes the directory constants) resolving
`.zfa/…` against the driven project root. No global `ProjectPaths` class
lands in 051 — the 050-corpus-import plan reserved that name for its own
`manifestsDirectory`; when #627 lands it can adopt/promote the helper
without contract change (the paths already match its data-model).

**Rationale**: `grep` shows zero `ProjectPaths` / `.zfa` references in
`lib/` today; creating the full abstraction now would guess at #627's
shape. The constant-per-file approach matches how the tdd services own
their own paths (`RunStateStore.path`, `cycle_log.dart`).

**Alternatives considered**: (a) put corpus state under `specs/` —
rejected: `specs/` is imported corpus content owned by #627's copy rules
(import never touches `specs/<f>/tdd/`, but corpus-level state is not spec
content at all); (b) `.specify/` — rejected: that's spec-kit tooling
state, not app state.

## R9 — Test strategy with a scripted fake (the 3-feature fixture)?

**Decision**: the slow-tier scenario drives the exact US1 independent
test: a fixture app with a manifest of 3 features (one whose fake `run`
completes + fake `verify` gates pass; one whose fake `run` stops
`stopped` at a scripted behavior; one `not-ready`). Assertions: feature 1
reaches done+gated, the run stops non-zero on feature 2 with a complete
ledger entry, feature 3 is never spawned (argv log proves zero
invocations), progress persisted; then "fix" the gap (re-script the fake),
re-run, and assert feature 1 is NOT re-driven (0 duplicate invocations)
and the run completes. Fast-tier tests cover each store/runner unit with
an injected spawner (no real processes), the gate matrix over all five
`MutationGateDecision` labels (SC-002), audit attribution including the
planted unattributed file (SC-003), ledger completeness (SC-004), and the
status contract line (SC-005).

**Rationale**: mirrors the proven `run_command_test.dart` harness
(CliRunner in-process + fake zfa sub-process + argv log), which the 049
spec already blessed for exactly this driver-correctness class.

**Alternatives considered**: driving the REAL pipeline for the fixture
corpus — rejected: the harness's job is orchestration policy, not pipeline
correctness; the real loop is covered by specs 044–049's own tests, and
the 051 spec pins the runner to consume `run`/`verify` "as merged".
