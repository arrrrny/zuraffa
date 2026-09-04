# Test List: TDD Plugin --json Verdict Envelope + Receipts

**Source spec**: spec.md
**Generated**: 2026-09-04
**Engine**: LLM fallback (no .zfa.json in root repo)

## Behaviors

### Acceptance (outer) — exit-code protocol

- **A1**: `zfa tdd run --json` emits a `verdict.v1` JSON envelope as the final stdout line on success (exit 0).
- **A2**: `zfa tdd run --json` exits with code 1 on RED (test failure), 2 on invalid grammar, 3 on manifest drift, 4 on state conflict — even when --json is set.
- **A3**: `zfa tdd plan --json` emits a `verdict.v1` envelope.

### Acceptance (outer) — gating

- **A4**: `zfa tdd run` (no --json) emits the existing `key=value` text summary, no JSON.
- **A5**: `zfa tdd gen --json` emits a `verdict.v1` envelope.
- **A6**: `zfa tdd gen` (no --json) emits the existing `key=value` text summary, no JSON.
- **A7**: `zfa tdd reset --json` emits a `verdict.v1` envelope.
- **A8**: `zfa tdd reset` (no --json) emits the existing `key=value` text summary, no JSON.

### Unit (inner) — envelope model

- **U1**: `VerdictEnvelope.toJson()` produces a stable `verdict.v1` schema with `schema`, `command`, `verdict`, `details`, `timestamp` keys.
- **U2**: `VerdictEnvelope.emit(command, verdict, details)` returns valid JSON parseable by `jsonDecode`.
- **U3**: `VerdictEnvelope` schema name is exactly `"verdict.v1"` (no drift).

### Unit (inner) — flag registration

- **U4**: `RunCommand` argParser has a `json` flag.
- **U5**: `GenCommand` argParser has a `json` flag.
- **U6**: `MakeCommand` argParser has a `json` flag.
- **U7**: `ViewCommand` argParser has a `json` flag.
- **U8**: `PlanCommand` argParser has a `json` flag.
- **U9**: `ResetCommand` argParser has a `json` flag.
- **U10**: `RealizeCommand` argParser has a `json` flag.
- **U11**: `VerifyCommand` argParser has a `json` flag.
- **U12**: `VerifyRedCommand` argParser has a `json` flag.
- **U13**: `InitCommand` argParser has a `json` flag.
- **U14**: `ComposeCommand` argParser has a `json` flag.
- **U15**: `RefactorCommand` argParser has a `json` flag.
- **U16**: `WireCommand` argParser has a `json` flag.
- **U17**: `FakeCommand` argParser has a `json` flag.
- **U18**: `FuncCommand` argParser has a `json` flag.
- **U19**: `RefereeCommand` (run/gate/rollup subcommands) have `json` flags.
- **U20**: `CorpusRunCommand`, `CorpusStatusCommand`, `CorpusAuditCommand`, `CorpusDifferentialCommand` have `json` flags.
- **U21**: `DiffCheckCommand`, `ReplayCommand`, `MigratePathsCommand` have `json` flags.

### Unit (inner) — receipts

- **U22**: `gen_command` writes a #807 receipt entry for each created artifact file (gated on --json or unconditional — decision: write receipts unconditionally, gate the JSON output only).
- **U23**: `make_command` writes a #807 receipt entry for each created artifact file.
- **U24**: `view_command` writes a #807 receipt entry for each scaffolded widget subject.

### Characterization (regression)

- **C1**: Default text output for `gen` is unchanged (existing key=value summary) when --json is absent.
- **C2**: Default text output for `reset` is unchanged when --json is absent.
- **C3**: Exit codes for all commands remain stable (0/1/2/3/4 protocol) regardless of --json presence.

## Counts

- Acceptance: 8
- Unit: 24
- Characterization: 3
- **Total: 35 behaviors**

## Traceability

- **FR-1** (VerdictEnvelope model) → U1, U2, U3
- **FR-2** (--json on 22 leaf commands) → U4..U21
- **FR-3** (gen/reset --json-gated) → A5, A6, A7, A8, C1, C2
- **FR-4** (_printVerdict helper) → A1, A3
- **FR-5** (receipts on gen/make/view) → U22, U23, U24
- **FR-7** (schema stability) → U3
- **Exit-code protocol** → A2, C3
