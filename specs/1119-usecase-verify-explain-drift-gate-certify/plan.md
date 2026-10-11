# Plan — spec 1119 usecase verify / explain / drift gate / certify

## Technical Context

- Plugin: `usecase` (`lib/src/plugins/usecase/`), generation via
  `EntityUseCaseGenerator.generateWithVerdicts` (per-method verdicts,
  spec #972), receipts via `UseCaseCreateCommand._writeReceipt`
  (proof.v1, issue #1138 provenance, spec binding via
  `_entitySpecReceipt` → `GenerationReceiptSpec{path, sha256}`).
- Envelope: `VerdictEnvelope` (`lib/src/core/verdict_envelope.dart`,
  SPEC 1105, `zuraffa.verdict.v1`) with the additive `explain` block
  (issue #1122) already supported by `withExplain`.
- Exit protocol: `ExitProtocol` (SPEC 917): 0/1/2 (+ fix lines via
  `ExitProtocol.fixLine`).
- Conformance-gate precedent: `ServiceConformanceChecker` (spec #1127) —
  re-derive the expected source by driving the real builder, audit the
  on-disk file with the analyzer AST (`FileParser` + `AstHelper`).
- Drift precedent: create receipts already bind the entity source
  (`GenerationReceiptSpec`); issue #1034 pattern = compare current
  source hash vs the receipt's binding.
- Verify-command precedent: `ServiceVerifyCommand` (receipt-then-flags
  knob resolution, `--> fix:` lines, canonical `--json` envelope),
  `RouteVerifyCommand` (verdict/exit-code table, drift honesty).
- Capability surface: `PluginCommand` auto-registers capabilities as
  subcommands; manual first-party subcommands must be listed in
  `manualSubcommandNames` (issue #761 duplicate-registration hazard).

## Method contract (the shape the gate re-derives)

Per method (entity `E`, config knobs from the create request):

| method | file | class | base | execute returns | params | exception |
|--------|------|-------|------|-----------------|--------|-----------|
| get | `get_e_usecase.dart` | `GetEUseCase` | `UseCase` | `Future<E>` | `QueryParams<E>` (or `NoParams`) | `CancelledException` |
| getList/list | `get_e_list_usecase.dart` | `GetEListUseCase` | `UseCase` | `Future<List<E>>` | `ListQueryParams<E>` | `CancelledException` |
| create | `create_e_usecase.dart` | `CreateEUseCase` | `UseCase` | `Future<E>` | `E` | `CancelledException` |
| update | `update_e_usecase.dart` | `UpdateEUseCase` | `UseCase` | `Future<E>` | `UpdateParams<Id, Patch>` | `CancelledException` |
| toggle | `toggle_e_usecase.dart` | `ToggleEUseCase` | `UseCase` | `Future<E>` | `ToggleParams<Id, Field>` | `CancelledException` |
| delete | `delete_e_usecase.dart` | `DeleteEUseCase` | `CompletableUseCase` | `Future<void>` | `DeleteParams<Id>` | `CancelledException` |
| watch | `watch_e_usecase.dart` | `WatchEUseCase` | `StreamUseCase` | `Stream<E>` | `QueryParams<E>`/`NoParams` | `CancelledException` |
| watchList | `watch_e_list_usecase.dart` | `WatchEListUseCase` | `StreamUseCase` | `Stream<List<E>>` | `ListQueryParams<E>` | `CancelledException` |

The gate derives these by calling the refactored
`EntityUseCaseGenerator.buildUsecaseSource(config, method)` and parsing
the result — never by hardcoding the table (hardcoding drifts; the
derivation cannot).

## Work breakdown (dependency-ordered)

1. `EntityUseCaseGenerator.buildUsecaseSource` — extract the in-memory
   source build from `_generateForMethod` (pure refactor, no behavior
   change; `_generateForMethod` calls it then writes).
2. `UsecaseConformanceChecker` (`conformance/`) — per-method gate:
   parse expected vs actual, findings with kinds + `--> fix:` lines;
   plus `describeMethod` (the explain contract reader).
3. `UsecaseDriftChecker` — entity hash vs receipt `spec.sha256`.
4. `UsecaseReceiptReader` — latest `usecase-create-<entity>-*.json`.
5. `UsecaseCreateRequest` — shared create-request resolution extracted
   from `CreateUseCaseCapability._generateFiles` (split; the capability
   and the CLI command resolve identically).
6. `UsecaseVerifyCommand` (`zfa usecase verify <Entity>`) + registration
   in `UseCaseCommand` (`manualSubcommandNames` + addSubcommand).
7. `UseCaseCreateCommand --certify / --explain` (gate after generation;
   envelope extension only — verdict shape untouched).
8. `VerifyUsecaseCapability` + plugin `capabilities` registration.
9. Tests: `usecase_verify_test.dart`, `usecase_certify_test.dart`.

## Risks / mitigations

- **Breaking the create verdict shape** → the certify/explain additions
  only ADD keys outside `details.methods[*]`; SC-5 test pins the shape.
- **Gate drift from grammar** → gate drives the real generator's build
  path; a grammar change updates expectations automatically.
- **Receipt absence** → verify reports `receiptBound: false` and gates
  by conventional file discovery; drift is only ever claimed with a
  binding on disk.
- **Analyzer parse cost** → per-method parse of small files, only on
  verify/certify paths (not on plain create).
