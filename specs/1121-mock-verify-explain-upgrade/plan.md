# PLAN — SPEC 1121 (mock verify + explain, B+ → A+)

## Technical context

- **Plugin**: mock (`lib/src/plugins/mock/`), commands in `lib/src/commands/mock_command.dart`.
- **Conformance shape (shared with MockCertify, AC-9)**: `MockCertificationService.certify()`
  computes the `MockCertification` record from the FINAL on-disk state (interface members via
  `MethodExtractor.extractMethodsFromInterface`, mock members via `AstHelper`, fixture digests)
  and `MockCertifier.gate()` turns it into a `CertifyReport{passed, fixLines}` (structural
  drift + scoped `dart analyze`, warnings non-fatal). File:
  `lib/src/plugins/mock/services/mock_certification.dart`. Verify re-runs exactly this pair —
  no parallel implementation.
- **Canonical envelope (issue #1105)**: `VerdictEnvelope` (`lib/src/core/verdict_envelope.dart`),
  schema `zuraffa.verdict.v1`, emitted as the LAST stdout line via `toJsonLine()`; diagnostics
  to stderr in `--json` mode. Findings ride `VerdictFinding{kind, fix, file, member}`.
- **Exit protocol (spec 917)**: 0 success, 1 failure/drift (the `--> fix:` family), 2 usage —
  the same mapping `ServiceVerifyCommand` (spec 1127) uses for the sibling verify verb.
- **Receipt source for explain**: `loadMockCertReceipt(projectRoot, entity)` reads
  `test/mock/<snake>/mock-cert.<Entity>.json` (spec 1001) whose `methods` is the ordered
  per-method satisfaction list — the per-method certification status.
- **Fixture selector (#1034)**: the selector is declared as `static ... forMethod(<T> x)` in
  `lib/src/data/mock/<snake>_mock_data.dart` (detection regex shared with
  `MockProviderBuilder._forMethodSelectorParamType`); bindings on disk appear as
  `<Entity>MockData.forMethod(params.<field>)` inside the generated mock lane files.

## Design

### `MockVerifyCommand` (`lib/src/commands/mock_verify_command.dart`)

`zfa mock verify <Entity> [--json] [--project <dir>] [--verbose]` — a manual subcommand of
`MockCommand` (mirrors `ServiceVerifyCommand`):

1. Parse the entity (positional; usage exit 2 with a fix line when absent).
2. Resolve the project root (flag, else CWD via `ProjectRoot`).
3. Read-only certification: `MockCertificationService.certify(entity:, outputDir:
   <root>/lib/src, files: <on-disk fixtures>, projectRoot:)` — the entity-mode
   interface/mock pair resolves exactly as generation resolves it
   (`data/datasources/<snake>/<snake>_datasource.dart` ↔ `<snake>_mock_datasource.dart`); the
   `mock_data` fixture (`data/mock/<snake>_mock_data.dart`) is hashed when present.
4. Refusal (exit 1, `missing_file` finding) when the mock datasource does not exist — fix line
   names `zfa mock create <Entity> --certify`. Refusal (exit 1, `missing_file` finding) when
   the interface does not exist — nothing to conform to.
5. `MockCertifier().gate(certification:, projectRoot:)` → `CertifyReport`. The gate's fix
   lines already carry the `--> fix:` prefix and name the missing/incorrect members.
6. Output:
   - human: `Mock Verify — <entity>` header, interface/file/members lines, then
     `✅ verified: ...` (exit 0) or one `❌ [<kind>]` + fix line per finding (exit 1);
   - `--json`: one `VerdictEnvelope` on stdout (verdict pass/fail, exit_class 0/1, subject
     `{kind: mock, id: <entity>}`, findings mapped from the report, `drifts` = fix lines,
     `details.certification` = the certification envelope view); diagnostics on stderr.
7. Read-only guarantee (AC-5): the command performs no writes of any kind.

### `MockExplainCapability` (`lib/src/plugins/mock/capabilities/explain_mock_capability.dart`)

`zfa mock explain <Entity> [--json] [--project <dir>]` — a `ZuraffaCapability`
(`name: explain_mock`, manifest-visible via `MockPlugin.capabilities`) following the
`CertifyMockCapability` pattern: `run(List<String> args) → Future<int>` owns exit codes;
`plan/execute` throw `UnsupportedError` (the CLI owns exit codes).

The report (AC-6):

- **coverage**: per interface method, in declaration order — covered when the mock class
  implements it; certification status per method from the committed spec-1001 receipt:
  `certified` (satisfied), `certified-red` (receipt pins it unsatisfied), `uncertified`
  (implemented but never certified), `missing` (interface member absent from the mock).
- **skipped**: interface methods the mock does not implement. **invented**: mock methods the
  interface never declared.
- **registry**: the deterministic registry id + conformance boolean from the certification.
- **selector** (`MockData.forMethod`, #1034): whether the entity's mock-data file declares a
  single-positional-parameter `static ... forMethod(...)` selector and its discriminator
  parameter type; plus every `forMethod(params.<field>)` binding found on disk in the mock
  lane files (mock datasource, mock provider when present), reported per file.

Output: human explain block (AC-6) or `--json` envelope whose `details.explain` carries the
full structured report (AC-7). Refusals: missing mock artifacts → exit 1 + `missing_file`
finding + fix line; usage → exit 2.

### Wiring

- `MockPlugin.capabilities` gains `MockExplainCapability` (manifest visibility).
- `MockCommand` gains manual subcommands `verify` (`MockVerifyCommand`) and `explain`
  (`MockExplainCommand`); `manualSubcommandNames` gains `verify`/`explain` so the
  auto-registered `CapabilityCommand`s never collide (issue #761 guard).

## Test strategy

`test/plugins/mock/mock_verify_test.dart` (fast tier, `CliRunner(exitOnCompletion: false)` +
`CwdGuard.exclusive` + `runCapturing(['-C', tempDir, ...])`, `MockCertifier.analyzeRunnerOverride`
for the analyze seam — the `mock_certify_gate_test.dart` pattern):

- pass path: scaffold `Product` entity → `mock create Product` → `mock verify Product` →
  exit 0, conformance line, no fix lines; tree unchanged (AC-1, AC-5).
- drift path: drift the mock (remove `update`) → `mock verify Product` → exit 1, `--> fix:`
  names `update` and `ProductDataSource` (AC-2).
- no-mock path: `mock verify Ghost` → exit 1, `missing_file` finding + fix naming
  `zfa mock create` (AC-3).
- `--json` paths: conforming → envelope parses (`VerdictEnvelope.fromJson`), schema
  `zuraffa.verdict.v1`, verdict pass, exit_class 0, subject `{mock, Product}`, empty findings;
  drifted → verdict fail, exit_class 1, findings non-empty, drifts non-empty (AC-4).
- explain paths: `mock explain Product` → coverage lines for `get`/`update`/`toggle`, skipped
  list after drift, per-method status; `mock explain Product --json` → envelope with
  `details.explain` (AC-6, AC-7).

Real-`dart analyze` confidence comes from the sibling integration tier; the fast tier pins the
contract (same split `mock_certify_gate_test.dart` uses).

## Risks

- **Gate reuse vs drift**: mitigated — verify calls the SAME `certify()` + `gate()` functions
  certify uses; no shape duplication (AC-9).
- **`--json` stdout pollution**: generator prints inside `certify()` are AST-only reads (no
  prints); the gate prints nothing. Envelope stays the only stdout document.
- **Static analyze override leak**: `dart test` runs each file in its own isolate; the test
  tearDown resets `MockCertifier.analyzeRunnerOverride` (the existing guard pattern).
