# Plan: ZAP — Zuraffa Agent Protocol (spec 071, issue #809)

## Summary

Implement ZAP v0 as a pure-Dart protocol layer + CLI surface + external demo.
Four core message types (mission, evidence, checkpoint, receipt) plus an
auxiliary error type; NDJSON-over-stdio transport; draft-07 JSON Schema per
message; structural validation before typed parsing; conformance self-test
(`zfa zap conform`); reference client with digest-chain receipt
verification; host (`zfa zap serve`) with budget/policy/TDD-discipline gates;
and a pure-SDK foreign client demo proving two-implementation interop with
zero code changes.

## Technical Context

- **Language/framework**: Dart 3.13 (repo pins `sdk: ^3.11.0`), pure Dart —
  no Flutter. Deps already present: `crypto` (sha256), `uuid` (message ids),
  `args` (CLI). No new dependencies.
- **Patterns reused from the repo**:
  - NDJSON wire + injected-stream testability: `ShellProtocol` /
    `AgentShell` (issue #808, `lib/src/agent/shell/`).
  - Hand-written `toJson`/`fromJson` message classes with stable key order
    (`MissionDocument`, `GenerationReceipt`) — NOT json_serializable.
  - sha256 digest discipline: `proof.v1` receipts (#807,
    `receipt_store.dart`) and the per-behavior hash chain (#788/#828,
    `CycleLog`) — ZAP's evidence chain follows the same chain-link shape.
  - JSON Schema emission: `SchemaCommand` (draft-07 map, printed verbatim).
  - Verifier-style CLI: `ProofCheckCommand` (`--format text|json`,
    `exitCode = ok ? 0 : 1`, machine summary last line, per #778).
  - Core-command registration: `_addCoreCommands()` in
    `lib/src/cli/cli_runner.dart`.
- **Layout**: implementation in `lib/src/zap/` (new top-level protocol
  library — ZAP is a cross-cutting contract, not a plugin); CLI in
  `lib/src/commands/zap_command.dart`; tests in `test/zap/` (new top-level
  test folder, auto-picked by the chunked runner); demo in
  `examples/zap_demo/` (pure-SDK scripts, no pubspec — independence is the
  argument); published contract artifacts in
  `specs/071-zuraffa-agent-protocol/{schemas,golden,contracts}/`.

## Constitution Check

- The feature is additive: no existing command, schema, or test surface
  changes beyond one registration line in `cli_runner.dart` + its import.
- All gates deterministic: hermetic in-process tests for the protocol layer;
  the interop tests spawn real subprocesses (`dart bin/zfa.dart zap serve`,
  `dart examples/zap_demo/*.dart`) — the established `run_zfa_source` /
  MCP-demo e2e pattern — but remain network-free and temp-dir-isolated.
- No secrets, no network, no clocks in assertions (timestamps are carried,
  never asserted literally).
- Disk hygiene: tests never run nested `dart test` trees; the two subprocess
  spawns per interop file are JIT-started single scripts (no kernel-cache
  accumulation); the chunked runner clears caches between chunks as usual.

## Phases

1. **Spec + schemas (T001, RED)** — write the spec docs, the wire contract,
   and the failing tests for the message layer / validator / golden files.
   Red = load errors on the not-yet-existing `lib/src/zap/` (the 066
   precedent) plus recorded per-file red runs.
2. **Protocol layer (T002, GREEN)** — implement `zap_protocol`,
   `zap_schema`, `zap_validator`, `zap_message`, `zap_golden`, `zap_chain`,
   `zap_executor`, `zap_host`, `zap_client`, `zap_conformance` +
   `zap_command.dart` (conform/serve/schema) + registration + smoke test.
   Export schemas/goldens into the spec dir; drift test green.
3. **External demo (T003, GREEN)** — `examples/zap_demo/tdd_loop.dart`
   (real red/green/verify commands) + `foreign_client.dart` (pure SDK,
   spawns the real host, drives the full loop, verifies the receipt) + e2e
   test.
4. **Interop proof (T004, GREEN)** — reference client against the real
   `dart bin/zfa.dart zap serve` subprocess + the foreign client session,
   both unmodified — the cross-implementation interop test.
5. **Refactor + verify (T005)** — `dart format .`, `dart analyze` (zero new
   issues vs baseline), chunked suite (no new failures), deliberate-mutant
   sampling on the new code with byte-exact restoration, cycle-log appended
   through the real `CycleLog.append` writer, `/speckit.tdd.verify` run →
   `tdd/verification.md` from the REAL run.

## Testing Strategy

- **Unit (fast tier)**: `test/zap/zap_message_test.dart`,
  `zap_validator_test.dart`, `zap_schema_test.dart`,
  `zap_golden_test.dart`, `zap_host_test.dart` (in-process host with the
  scripted executor — no subprocesses),
  `zap_conformance_test.dart` (drives the real CLI in-process via
  `CliRunner.runCapturing`), `zap_command_smoke_test.dart`.
- **Acceptance (still fast tier; ~15–25s)**: `test/zap/zap_client_test.dart`
  (reference client, in-process), `test/zap/zap_interop_test.dart` (two
  subprocess sessions against the same host entry point).
- **Fixtures**: `examples/zap_demo/tdd_loop.dart` — deterministic,
  side-effect-free red/green/verify commands; checkpoints in
  `Directory.systemTemp` per test.
- **Baseline**: fast tier green at branch point `aad75c08` (master).
