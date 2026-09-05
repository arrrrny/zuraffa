# Feature Specification: `zfa dream` — plain-English feature to spec to tested PR (issue #1010, VISION track)

**Feature Branch**: `spec/1010-zfa-dream-one-command-app`

**Created**: 2026-09-05

**Status**: Draft

**Input**: Issue [#1010](https://github.com/arrrrny/zuraffa/issues/1010) — "[VISION] zfa dream — plain-English feature to spec to tested PR". The end of the vision stack: a feature description in plain English produces a spec, a plan, receipts, and a PR. This is the personality on top of the proven infrastructure from Clusters 1–7.

## Mission

Every capability the vision stack promised already exists and is proven: the LLM-facing MCP v2 tool surface (`handleV2ToolCall`), the spec grammar + validation gates (`zfa tdd plan`'s parser chain), the engine cycle (`zfa tdd run`, resumable, evidence-beats-state), the view/skin lane (`zfa tdd view`, the sanctioned handcraft seam), proof-carrying receipts (`ReceiptStore`, `proof.v1`), and branch/PR conventions (AGENTS.md). What does not exist is the **one command** that chains them: today a human or agent must drive five commands and re-prompt the LLM by hand between failures.

`zfa dream "<feature description>"` is that command: it asks the MCP v2 `dream_draft_spec` tool for a spec draft constrained by the plan schema, ingests the draft through `zfa ttd ingest` (the validation gate the dream loop re-prompts on), derives the plan artifacts, runs the engine cycle to green, runs the skin cycle (opening a hand-edit branch when the view scaffold is emitted), writes two receipts, and opens a PR — draft while the engine is not green.

The dream command is a **thin orchestrator**: it adds no new LLM client (the only completion abstraction it touches is the existing `LlmClient` seam inside the v2 tool), and every phase delegates to an existing command or the existing v2 surface.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - One command from sentence to PR (Priority: P1)

An agent (or a human in a terminal) runs `zfa dream "A page that lists the user's favorite deals, sorted by expiration"` in a project. The command drafts a spec via the MCP v2 tool, validates it through ingest, writes `specs/<feature>/spec.md`, derives `tdd/test-list.md` + `tdd/traceability.md` via the real plan command, runs the engine cycle until it is green, runs the skin cycle over the widget lane, writes an engine receipt and a skin receipt into `.zfa/receipts/`, commits the feature artifacts, and opens a PR. The PR contains the spec, the three plan files (`plan.md`, `tdd/test-list.md`, `tdd/traceability.md`), the cycle-log when the engine produced one, and both receipts.

**Why this priority**: this is the issue's literal exit criterion.

**Independent Test**: drive `DreamRunner.execute` over a sandbox fixture with a fake LLM client and a step spawner that delegates ingest/plan to the REAL in-process commands; assert the artifact set, the two receipt files, the recorded git/gh argv, the exit code, and the final summary line.

### User Story 2 - Ingest failure re-prompts the LLM (Priority: P1)

The first draft names an entity that collides with the framework export surface (e.g. `Credentials`, the bug #942 trap) or leaves a contract ambiguous. `zfa tdd ingest` refuses with a `--> fix:` line and a non-zero exit. The dream loop feeds the refusal text back to the v2 draft tool as feedback; the next draft renames the entity (the deterministic drafter applies the `--> fix: rename` suggestion, `<Name>Entity`); ingest accepts. The loop is bounded (`--max-retries`, default 3) and every attempt is reported in the summary line.

**Why this priority**: deliverable 1(b) — "if ingest fails (entity name collision, contract ambiguity), re-prompts the LLM with the error".

**Independent Test**: a fake LLM whose first draft declares entity `Credentials` (a real framework export) and whose second draft renames it; assert the refusal text reached the LLM's second prompt, and that the accepted spec landed on disk.

### User Story 3 - Draft is constrained by the plan schema (Priority: P1)

The v2 tool's prompt carries the schema constraint — Template Version pin, FR/AC grammar, Key Entities, External Dependencies & Contracts, Layer Contracts, plus the dream-only AdaptiveViewSlots and Skin Contract sections — so the draft is ingestable, not free prose.

**Why this priority**: deliverable 1(a).

**Independent Test**: the deterministic drafter's output (no LLM configured) is fed to the REAL `zfa tdd plan` command and exits 0; the LLM path is proven with a fake client returning the same shape.

### User Story 4 - Skin hand-edit opens a branch (Priority: P2)

A widget-lane behavior's view step emits the deterministic scaffold (`outcome=scaffolded` — the sanctioned handcraft seam). Dream opens a `skin/<feature>` branch for the human/agent and records the pending hand-edit in the skin receipt; the PR still opens.

**Independent Test**: scripted view step returning `outcome=scaffolded`; assert the `git checkout -b skin/<feature>` argv was recorded and the receipt records the hand-edit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001 (draft via v2 tool)**: `zfa dream "<description>"` MUST obtain its spec draft by calling the MCP v2 tool `dream_draft_spec` through the existing in-process v2 surface (`handleV2ToolCall`), passing the feature description, the plan-schema constraint, and — on retries — the ingest refusal feedback. The command MUST NOT add a new LLM client: the tool's only completion seam is the existing `LlmClient` abstraction; when no client is configured the tool falls back to a deterministic schema-valid drafter and the result is labeled `drafter=deterministic` end-to-end (summary line + receipts).
- **FR-002 (ingest gate)**: `zfa tdd ingest <feature> --draft <path>` MUST validate a draft through the same parser/gate chain `zfa tdd plan` uses (template-version drift → exit 3; behavior derivation failure, coverage gate, undeclared dependencies, declaration refusal → exit 2), PLUS the dream-specific gates: intra-draft duplicate entity names, entity names colliding with the framework export surface (`FrameworkExportSurface`, bug #942), and contract ambiguity (a Layer Contracts interface declared under two layers, or a dependency row with an empty Contract cell) → exit 2 with `--> fix:` lines. On success it MUST write `specs/<feature>/spec.md` (refusing to overwrite an existing spec.md unless `--force`) and emit the summary line `ingest: feature=<f> result=accepted entities=<n> dependencies=<n> contracts=<n>`.
- **FR-003 (re-prompt loop)**: When ingest refuses, dream MUST re-invoke the draft tool with the refusal output as feedback, up to `--max-retries` (default 3) attempts total; the deterministic drafter MUST apply the `--> fix: rename the entity` suggestion deterministically. Exhausted retries stop the run honestly (exit 1, no PR opened, nothing written as spec.md).
- **FR-004 (plan artifacts)**: After a successful ingest, dream MUST write `specs/<feature>/plan.md` from the draft result and run the REAL `zfa tdd plan <feature>` (exit 0 required) so `tdd/test-list.md` and `tdd/traceability.md` are produced by the existing command, not by dream.
- **FR-005 (engine cycle to green)**: Dream MUST run `zfa tdd run <feature> --project <root>` and treat green as exit 0 AND `result=complete` in the run summary line. The engine cycle is resumable: dream re-runs up to `--engine-attempts` (default 2) while the result is `stopped`. A run that is not green after the budget stops the pipeline honestly (exit 1, PR opens as DRAFT with the engine receipt recording the stopped state — "draft: true until engine green").
- **FR-006 (skin cycle)**: After the engine cycle, dream MUST read the widget-lane behaviors from `tdd/test-list.md` (TestListReader) and run `zfa tdd view <id> --feature <f>` for each. `outcome=scaffolded` MUST open the hand-edit branch `skin/<feature>` (via `git checkout -b`, the AGENTS.md branch convention) and record the pending hand-edit in the skin receipt. When there is no widget lane, the skin cycle records `skin=skipped` honestly and still writes the skin receipt.
- **FR-007 (receipts)**: Dream MUST write exactly two `proof.v1` receipts via `ReceiptStore`: an engine receipt (command `dream-engine`, files = the feature's cycle-log/run-state/spec/plan/test-list/traceability as they exist on disk) and a skin receipt (command `dream-skin`, files = the draft + view artifacts as they exist). Receipts MUST record the drafter label, attempt count, and outcomes in `input`.
- **FR-008 (PR)**: Dream MUST commit the feature artifacts on the current branch (creating the `<feature-dir>` branch first when the current branch is a default branch) and open a PR via `gh pr create` — `--draft` if and only if the engine is not green; a ready PR otherwise. `--no-pr` MUST skip the git/gh phase entirely (tests, CI). PR/git failures are reported honestly and fail the command; the summary line always records the PR outcome.
- **FR-009 (machine contract)**: Dream's last stdout line MUST be `dream: feature=<f> result=<complete|stopped|error> drafter=<llm|deterministic> attempts=<n> engine=<green|stopped> skin=<green|hand-edit|skipped> pr=<url|draft|none|failed>`; `--json` MUST emit a `verdict.v1` envelope. Dream MUST be invocable as the top-level `zfa dream` (registered in the core command table) and every spawned phase runs as a subprocess through the injectable spawner seam (`ProcessResult`-shaped, the StepRunner pattern), so a phase crash cannot corrupt the orchestrator.
- **FR-010 (v2 tool contract)**: `dream_draft_spec` MUST be listed by `v2ToolDefinitions()` with an input schema (`feature`, `description`, `feedback`), return `{specMarkdown, planMarkdown, drafter}`, and dispatch through `handleV2ToolCall` with an optional injectable `LlmClient` (additive parameter, default null). An LLM completion MUST be parsed as labeled fenced blocks; an empty/unparseable completion MUST fall back to the deterministic drafter (labeled honestly, never a silent pass).

### Key Entities

- `DreamCommand` (new, `lib/src/commands/dream_command.dart`) — thin CLI surface (ReplayCommand pattern) → `DreamRunner.execute`.
- `DreamRunner` (new, `lib/src/plugins/tdd/services/dream_runner.dart`) — the orchestrator: draft → ingest (re-prompt loop) → plan.md + `tdd plan` → engine cycle → skin cycle → receipts → PR. All process spawning behind a `DreamSpawner` seam; exit codes mirror the run command's honesty rules.
- `IngestCommand` (new, `lib/src/plugins/ttd/commands/ingest_command.dart`) — the draft validation gate + spec.md placement; registered under `zfa tdd`.
- `DreamCapability` (new, `lib/src/mcp/capabilities/dream_capability.dart`) — the v2 tool body: prompt composition, `LlmClient` delegation, deterministic fallback, feedback repair.
- `dream_draft_spec` (v2 tool, `lib/src/mcp/v2_tools.dart`) — definition + dispatch case, additive `llmClient` parameter on `handleV2ToolCall`.

## Success Criteria *(mandatory)*

- **SC1**: `zfa dream "A page that lists the user's favorite deals, sorted by expiration"` over a sandbox fixture with a fake LLM: exit 0; on disk: `spec.md`, `plan.md`, `tdd/test-list.md`, `tdd/traceability.md`, `tdd/draft-spec.md`, two `.zfa/receipts/*dream-*.json` receipts; the spawner log shows the real ingest/plan argv and the git/gh PR argv (draft flag absent because the engine is green).
- **SC2**: A first draft with a colliding entity name is refused by ingest (real command, exit 2, `--> fix: rename`); the refusal text appears in the LLM's second prompt; the second draft is accepted.
- **SC3**: The deterministic drafter's spec passes the REAL `zfa tdd plan` (exit 0) — the draft is schema-constrained, not free prose; `v2ToolDefinitions()` lists `dream_draft_spec` (12 tools).
- **SC4**: A `scaffolded` view outcome records the `git checkout -b skin/<feature>` argv and a skin receipt with the hand-edit pending; a non-green engine opens the PR with `--draft` and dream exits 1.
- **SC5**: `dart analyze` zero new issues vs baseline; `dart format lib test` zero diffs; the chunked fast suite green; `zfa tdd verify --feature 1010-zfa-dream-one-command-app` dispatched for real and `tdd/verification.md` written from the real runs.
