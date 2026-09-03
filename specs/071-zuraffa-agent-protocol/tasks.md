# Tasks: ZAP — Zuraffa Agent Protocol (spec 071, issue #809)

**Input**: Design documents from `specs/071-zuraffa-agent-protocol/`
(spec.md, plan.md, contracts/zap.md)

**Prerequisites**: plan.md (required), spec.md (required), contracts/zap.md

**Tests**: MANDATORY — the tdd extension drives this feature test-first.
Behavior markers (`[A1]`–`[A8]`, `[U1]`–`[U21]`) trace to
`specs/071-zuraffa-agent-protocol/tdd/test-list.md`; every behavior's test
is written and observed RED before the implementation task that turns it
green may run.

**Organization**: Phase 1 = spec docs; Phase 2 = message/schema layer
(T001); Phase 3 = conformance + host + client (T002); Phase 4 = external
demo (T003); Phase 5 = interop proof (T004); Phase 6 = verification &
polish (T005).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4 + edge cases)
- Include exact file paths in descriptions

## Path Conventions

Repo-root package (matches plan.md): implementation under `lib/src/zap/` +
`lib/src/commands/zap_command.dart`, tests under `test/zap/`, external demo
under `examples/zap_demo/` (pure SDK, no pubspec), published contract
artifacts under `specs/071-zuraffa-agent-protocol/{schemas,golden}/`.

---

## Phase 1: Spec documents

**Purpose**: the open spec itself — the interop surface

- [X] T000 Write `specs/071-zuraffa-agent-protocol/spec.md` (mission, US1–US4,
  edge cases, FR-001..FR-017, SC-001..SC-005), `plan.md`, `tasks.md` (this
  file), `contracts/zap.md` (the human-readable wire contract), and
  `tdd/test-list.md`

## Phase 2: Message + schema layer (T001 — RED)

**Purpose**: the published contract, machine-checkable. Test-first: the
failing tests land BEFORE `lib/src/zap/` exists; red observed and recorded.

- [X] T001a [P] [U1] [U2] [U3] Write the failing schema tests FIRST in
  `test/zap/zap_schema_test.dart`: `ZapSchema.forType` returns a draft-07
  object for each of the five types (`$schema` draft-07, `type: object`,
  non-empty `required`, envelope fields `zap/type/id/ts` required and
  `zap` enum-bound to `0.1`, `type` enum-bound to the message type);
  `ZapSchema.all()` covers exactly the five types — observe red
- [X] T001b [P] [U4] [U5] [U6] [U7] Write the failing validator tests FIRST
  in `test/zap/zap_validator_test.dart`: `ZapValidator.validate` accepts the
  golden mission; rejects with precise JSON-path errors: missing required
  field, wrong property type, bad enum value, pattern mismatch (ts + digest
  hex64), `minItems`/`minimum` violations, unknown property under
  `additionalProperties: false`, non-object line, array-typed root —
  observe red
- [X] T001c [P] [U8] [U9] [U10] Write the failing message tests FIRST in
  `test/zap/zap_message_test.dart`: `ZapProtocol.decodeLine`/`encodeLine`
  round-trip; `ZapMessage.fromJson` dispatches the five types; golden
  mission/evidence/checkpoint/receipt round-trip
  (`fromJson(toJson()) == original`); malformed inputs throw
  `ZapSchemaException` carrying the validator's path errors; envelope
  version mismatch throws — observe red
- [X] T001d Implement `lib/src/zap/zap_protocol.dart` (version `0.1`, type
  names, NDJSON line codec), `zap_schema.dart` (five draft-07 schema maps —
  the source of truth), `zap_validator.dart` (draft-07 subset engine with
  `ZapValidationIssue{path, message}`), `zap_message.dart` (sealed
  `ZapMessage`: `MissionEnvelope`/`EvidencePacket`/`CheckpointMessage`/
  `ZapReceipt`/`ZapError`, hand-written `toJson`/`fromJson`, schema-first
  parse) — turns T001a–T001c green (depends on T001a–c red)
- [X] T001e [U11] Write the failing chain tests FIRST in
  `test/zap/zap_message_test.dart` (group `zapEvidenceChain`): the chain
  over three evidence facts produces the documented genesis→link1→link2→
  link3 head; mutating one certified fact changes the head — observe red;
  then implement `lib/src/zap/zap_chain.dart`
  (`zapChainLink`/`zapEvidenceChain`/`zapGenesis`) — green

## Phase 3: Conformance + host + reference client (T002 — GREEN)

**Purpose**: the self-test command, the host, the reference client

- [X] T002a [P] [U12] Write the failing golden-file tests FIRST in
  `test/zap/zap_golden_test.dart`: `ZapGoldens` validates positively against
  `ZapSchema`; the committed
  `specs/071-zuraffa-agent-protocol/schemas/*.schema.json` and
  `golden/*.golden.json` bytes equal the code-derived maps (drift gate) —
  observe red; then implement `lib/src/zap/zap_golden.dart` + the export
  (`zfa zap schema --export`) and generate the committed files — green
- [X] T002b [P] [U13] [U14] [U15] Write the failing host tests FIRST in
  `test/zap/zap_host_test.dart` (in-process, scripted executor): happy-path
  mission (red exit 1, green exit 0) → evidence per step + receipt
  `verdict: pass` with all six checks green and a recomputable
  `chainDigest`; discipline violation (red exits 0) → receipt `fail` naming
  `tdd-discipline`; budget breach rejected before execution (`error`,
  `code: budget`); budget fixed by first mission (later mission with larger
  `maxSteps` rejected); policy breach rejected before execution (`error`,
  `code: policy`); wrong version → `error`, `code: version`; inbound
  evidence/receipt → `error`, `code: direction`; checkpoint save→restore
  round-trip with `stateId` + `digest`; restore of unknown `stateId` →
  `error`, `code: bad-checkpoint`; checkpoint before any mission →
  `error`, `code: unknown-mission`; timeout → evidence `exit: 124` and
  receipt `fail`; output capping at 2000 chars — observe red
- [X] T002c Implement `lib/src/zap/zap_executor.dart`
  (`ZapStepExecutor`, `SubprocessZapStepExecutor` — no shell, tokenized
  commands, timeout kill → 124; `ScriptedZapStepExecutor` for tests),
  `lib/src/zap/zap_host.dart` (`ZapHost` line processor + `ZapSession` +
  `ZapCheckpointStore` with atomic tmp+rename persistence),
  `lib/src/zap/zap_client.dart` (`ZapClient`: submit/checkpoint/collect/
  recompute + `verifyReceipt`) — turns T002b + the client tests green
- [X] T002d [P] [A2] [A3] Write the failing conformance + smoke tests FIRST
  in `test/zap/zap_conformance_test.dart` + `test/zap/
  zap_command_smoke_test.dart`: `zfa zap --help` lists `conform`, `serve`,
  `schema`; `zfa zap conform` (in-process `CliRunner.runCapturing`) exits 0
  with the final machine line `zap: conform checks=<n> passed=<n> failed=0
  — OK`; `--format json` emits one parseable verdict object with
  `checks/passed/failed/ok`; a failing check (injected) flips exit to 1 —
  observe red; then implement `lib/src/zap/zap_conformance.dart` +
  `lib/src/commands/zap_command.dart` (conform/serve/schema) and register
  `ZapCommand` in `lib/src/cli/cli_runner.dart` `_addCoreCommands()` —
  green

## Phase 4: External demo — non-MCP client driving a full TDD loop (T003)

- [X] T003a [A5] Write the failing e2e test FIRST in
  `test/zap/zap_interop_test.dart` (group foreign demo): running
  `dart examples/zap_demo/foreign_client.dart` from the repo root exits 0
  and its stdout's last line is the receipt JSON with
  `"verdict":"pass"`,`"exit":0`, a `tdd-discipline` check `ok`, and a
  client-verified `chainDigest` (re-parse the printed receipt and assert
  the client's `"chainVerified":true` marker) — observe red
- [X] T003b Implement `examples/zap_demo/tdd_loop.dart` (pure SDK:
  `red` exits 1 with a real failing check, `green` exits 0, `verify` exits
  0) and `examples/zap_demo/foreign_client.dart` (pure SDK, zero zuraffa
  imports: spawns `dart bin/zfa.dart zap serve`, mission 1 red+green,
  checkpoint save + restore, mission 2 verify, recomputes the chain,
  prints the receipt, exits with the receipt exit) + `examples/zap_demo/
  README.md` — turns T003a green

## Phase 5: Cross-implementation interop proof (T004)

- [X] T004a [A4] [A6] Write the failing interop tests FIRST in
  `test/zap/zap_interop_test.dart` (groups reference client + both
  clients): the reference `ZapClient` completes a full session against a
  real `dart bin/zfa.dart zap serve` subprocess (receipt `pass`, digest
  verified); the reference client AND the foreign client drive the SAME
  unmodified host entry point (same command, same flags — asserted
  literally) and both verify their receipts — observe red, then complete
  the wiring (host `--cwd`/`--checkpoint-dir` flags if needed) — green

## Phase 6: Verification & polish (T005 — REFACTOR + VERIFY)

- [X] T005a Refactor pass: `dart format .` (zero diff after), `dart
  analyze` zero NEW issues vs the pre-feature baseline, naming/structure
  cleanup — no behavior change
- [X] T005b Full verification: `tools/run_tests_chunked.sh` — zero new
  failures vs baseline; record ACTUAL pass/fail counts per chunk
- [X] T005c Append the red/green evidence entries to
  `specs/071-zuraffa-agent-protocol/tdd/cycle-log.md` through the REAL
  `CycleLog.append` writer (schema-1 hash chain), from the REAL commands
  and outputs captured in this session
- [X] T005d Run `/speckit.tdd.verify` (fallback LLM-guided audit per the
  command file — `.zfa.json` is absent in this repo, engine detection
  `ZFA_MISSING`): deliberate-mutant sampling on the new code (≥3 mutants,
  each caught, byte-exact restoration), rubric answers, real counts —
  write `specs/071-zuraffa-agent-protocol/tdd/verification.md` FRESH from
  this run
- [X] T005e Cleanup: remove scratch fixtures/build artifacts, `df -h .`
  health check, confirm no token/secret in the diff, PR
