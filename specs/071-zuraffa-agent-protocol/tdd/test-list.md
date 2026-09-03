---
feature: 071-zuraffa-agent-protocol
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 5
planned_at: 071-zuraffa-agent-protocol
updated_at: 071-zuraffa-agent-protocol
suite_baseline: green
---

# Test List: ZAP — Zuraffa Agent Protocol (spec 071, issue #809)

Baseline: fast tier green at branch point `aad75c08` (master). All protocol
unit tests are hermetic and in-process (scripted executor); the interop
tests spawn real subprocesses (`dart bin/zfa.dart zap serve`,
`dart examples/zap_demo/*.dart`) — network-free, temp-dir-isolated.

## Outer loop: acceptance behaviors

The 8 A-rows trace the 5 success criteria in `spec.md`; the `traces` column
names the SC each row covers. A-rows drive the real CLI entry point
in-process (`CliRunner.runCapturing`) or real subprocesses where the
behavior IS the process boundary.

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | The published contract is machine-checkable: every committed schema file under `specs/071-zuraffa-agent-protocol/schemas/` and golden file under `golden/` byte-equals the code-derived map (drift gate); goldens validate positively against their schemas | SC1 | example | DONE | `test/zap/zap_golden_test.dart::A1: committed schemas and goldens match the code (no drift)` |
| A2 | `zfa zap conform` (in-process real CLI) exits 0, prints per-check lines, and ends with the machine summary `zap: conform checks=<n> passed=<n> failed=0 — OK` | SC2 | example | DONE | `test/zap/zap_conformance_test.dart::A2: zfa zap conform passes with the machine summary line` |
| A3 | `zfa zap conform --format json` emits ONE parseable verdict object (`ok:true`, counts, checks list) and sets exit 0; a failing check (injected via a conformance hook) flips the verdict and the exit code to 1 | SC2 | example | DONE | `test/zap/zap_conformance_test.dart::A3: json verdict object and failing-check exit propagation` |
| A4 | The reference `ZapClient` completes a full session (mission → evidence → receipt → checkpoint save/restore → mission → receipt) against a REAL `dart bin/zfa.dart zap serve` subprocess, verifying the receipt digest | SC4 | example | DONE | `test/zap/zap_interop_test.dart::A4: reference client drives the real zfa zap serve subprocess` |
| A5 | The foreign demo client (`dart examples/zap_demo/foreign_client.dart`, pure SDK, zero zuraffa imports) drives a full TDD loop through a real `zfa zap serve` subprocess: exits 0, prints a final receipt with `verdict:pass`, `tdd-discipline` ok, and its own `chainVerified:true` marker | SC3 | example | DONE | `test/zap/zap_interop_test.dart::A5: foreign client drives a full TDD loop end-to-end` |
| A6 | Cross-implementation interop with zero code changes: the reference client and the foreign client both complete verified sessions against the SAME unmodified host entry point (`dart bin/zfa.dart zap serve`, identical command) | SC4 | example | DONE | `test/zap/zap_interop_test.dart::A6: two independent clients, same unmodified host` |
| A7 | Hallucinated/undisciplined input is structurally rejected: malformed JSON line, wrong version, direction violation, budget breach, policy breach each produce the documented `error` code; the session survives and keeps serving | SC5 | example | DONE | `test/zap/zap_host_test.dart::A7: the host rejects malformed input with precise codes and keeps serving` |
| A8 | A dishonest TDD loop (red exits 0, or green exits 1) is executed but FAILED in the receipt: `verdict:fail`, `exit:1`, `tdd-discipline` check `ok:false` with the rule named | SC5 | example | DONE | `test/zap/zap_host_test.dart::A8: discipline violations flip the receipt verdict` |

## Inner loop: unit behaviors

### `lib/src/zap/zap_schema.dart` (draft-07 per type)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | `ZapSchema.forType` returns a draft-07 object for each of the five types: `$schema` is draft-07, `type:object`, non-empty `required`, envelope `zap/type/id/ts` required, `zap` enum `["0.1"]`, `type` enum bound to the message type | FR-006 | example | DONE | `test/zap/zap_schema_test.dart::U1: every message type has a draft-07 schema with the envelope` |
| U2 | `ZapSchema.all()` covers exactly the five types and each map is deeply JSON-encodable | FR-006 | example | DONE | `test/zap/zap_schema_test.dart::U2: all() covers exactly the five types` |
| U3 | The mission schema pins the contract: required missionId/agent/goal/budget/policy/steps, budget.maxSteps integer ≥1, policy.riskTier enum, steps items require id/command/phase, phase enum, timeoutSeconds 1..600, `additionalProperties:false` at the envelope | FR-002 | example | DONE | `test/zap/zap_schema_test.dart::U3: the mission schema pins the v0 contract` |

### `lib/src/zap/zap_validator.dart` (structural validation first)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U4 | The golden mission validates positively (zero issues) | FR-007 | example | DONE | `test/zap/zap_validator_test.dart::U4: the golden mission validates` |
| U5 | Missing required fields are rejected with the field's JSON path in the issue (`steps[0]`, `budget.maxSteps`, top-level `missionId`) | FR-007 | example | DONE | `test/zap/zap_validator_test.dart::U5: missing required fields are rejected with paths` |
| U6 | Wrong property types, bad enum values, pattern mismatches (`ts` ISO-Z, `digest` hex64), minItems/minimum violations are each rejected with a precise path | FR-007 | example | DONE | `test/zap/zap_validator_test.dart::U6: types, enums, patterns, bounds are enforced` |
| U7 | Unknown properties under `additionalProperties:false`, non-object lines, and array roots are rejected | FR-007 | example | DONE | `test/zap/zap_validator_test.dart::U7: closed envelopes and non-objects are rejected` |

### `lib/src/zap/zap_message.dart` (typed layer)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U8 | `ZapProtocol.encodeLine`/`decodeLine` round-trip a message map; garbage lines throw `FormatException` | FR-001 | example | DONE | `test/zap/zap_message_test.dart::U8: the NDJSON line codec round-trips` |
| U9 | `ZapMessage.fromJson` dispatches the five types; each golden message round-trips `fromJson(toJson())` to an equal map; key order is stable | FR-002..005 | example | DONE | `test/zap/zap_message_test.dart::U9: typed messages round-trip` |
| U10 | Malformed messages throw `ZapSchemaException` whose issues carry the validator's paths; a wrong `zap` version throws with a version-classified issue | FR-007 | example | DONE | `test/zap/zap_message_test.dart::U10: malformed input throws with path evidence` |

### `lib/src/zap/zap_chain.dart` (receipt verification primitive)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U11 | The chain over ordered evidence facts produces genesis→link1→link2→link3; mutating any certified fact changes the head; the host's `chainDigest` equals the independently recomputed head | FR-013 | example | DONE | `test/zap/zap_message_test.dart::U11: the evidence chain is tamper-evident` |

### `lib/src/zap/zap_golden.dart` (golden examples + drift)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U12 | `ZapGoldens.example(type)` validates against its schema and round-trips through the typed layer | FR-006 | example | DONE | `test/zap/zap_golden_test.dart::U12: golden examples validate and round-trip` |

### `lib/src/zap/zap_host.dart` (session semantics — in-process, scripted executor)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U13 | Happy path: mission(red exit 1, green exit 0) → one evidence per step + receipt `pass` (six checks ok) whose `chainDigest` recomputes identically; later missions continue the session and the receipt covers the cumulative chain | FR-005, FR-009 | example | DONE | `test/zap/zap_host_test.dart::U13: a clean mission produces evidence and a verified receipt` |
| U14 | Gates reject before execution: budget breach (steps > maxSteps, and cumulative over-run), budget escalation (later mission with larger maxSteps), policy breach (executable not in allowlist), policy drift (later mission changing policy) — each `error` with the right code, executor never invoked | FR-010, FR-011 | example | DONE | `test/zap/zap_host_test.dart::U14: budget and policy gates reject before execution` |
| U15 | Checkpointing: save → `saved` with stateId/digest/steps; restore → `restored`; unknown stateId → `bad-checkpoint`; checkpoint before any mission → `unknown-mission`; snapshots persist to disk and survive a NEW host instance (fresh process semantics: same dir) | FR-004 | example | DONE | `test/zap/zap_host_test.dart::U15: checkpoints save, restore, persist, and fail named` |
| U16 | Direction + version: inbound evidence/receipt/saved/restored/error → `direction`; `"zap":"2.0"` → `version`; a garbage non-JSON line → `schema` error and the host keeps serving subsequent lines | FR-001, FR-009 | example | DONE | `test/zap/zap_host_test.dart::U16: direction, version, and garbage lines never kill the host` |
| U17 | Timeout → evidence `exit:124` with a timeout note; receipt `fail`; output capped at 2000 chars | FR-016 | example | DONE | `test/zap/zap_host_test.dart::U17: timeouts and output capping` |
| U18 | TDD discipline rules (cumulative): red exit 0 → `fail` naming the red rule; green exit 1 → `fail` naming the green rule; green with no red ever witnessed → `fail` naming the order rule; refactor exit 0 → neutral/pass | FR-012 | example | DONE | `test/zap/zap_host_test.dart::U18: the discipline rules name their violation` |

### `lib/src/zap/zap_client.dart` (reference client)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U19 | `ZapClient` (in-process, injectable streams): submit collects evidence + resolves the receipt; checkpoint save/restore round-trip; `recomputeChain` equals the host's; `verifyReceipt` is true for the honest receipt and false for a tampered digest | FR-014 | example | DONE | `test/zap/zap_client_test.dart::U19: the reference client submits, checkpoints, and verifies receipts` |

### `lib/src/commands/zap_command.dart` (CLI surface)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U20 | `zfa zap --help` lists `conform`, `serve`, `schema` (registration smoke, the sc-pattern) | FR-008, FR-009 | example | DONE | `test/zap/zap_command_smoke_test.dart::U20: zfa zap --help lists the three subcommands` |
| U21 | `zfa zap schema --type mission` prints the mission draft-07 schema (parseable, `$schema` draft-07); `zfa zap schema --export <dir>` writes the five schema files + four golden files | FR-006 | example | DONE | `test/zap/zap_conformance_test.dart::U21: zfa zap schema prints and exports` |
