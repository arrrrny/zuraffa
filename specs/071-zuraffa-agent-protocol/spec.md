# Feature Specification: ZAP — Zuraffa Agent Protocol, an open interop spec for agent↔framework integration

**Feature Branch**: `spec/0809-zuraffa-agent-protocol`
**Feature Directory**: `specs/071-zuraffa-agent-protocol`

**Created**: 2026-09-03

**Status**: Draft

**Input**: Issue [#809](https://github.com/arrrrny/zuraffa/issues/809) —
"[VISION] 📜 Zuraffa Agent Protocol (ZAP): an open interop spec for
agent↔framework integration". Part of 🧭 VISION 2030 (#804), Pillar B: Agent
runtime. References #791 (MCP v2 — MCP becomes ONE transport; ZAP is the
contract above it). Exit codes follow #778. Receipt digesting follows the
`proof.v1` sha256 pattern from #807; the evidence hash chain follows the
tamper-evident chain from #788/#828 (`CycleLog`).

## Mission

Lock-in kills adoption; ad-hoc kills reliability. Today every agent framework
(Claude, custom, LangGraph, OpenAI) integrates with zuraffa differently — or
through MCP only, which is a transport, not a contract. There is no public,
versioned statement of what an agent may ask zuraffa to do, what evidence
zuraffa will certify, or what a verifiable outcome looks like. Hallucinated
tool calls are merely discouraged, not structurally impossible.

ZAP (Zuraffa Agent Protocol) is a small, versioned, open spec for how ANY
agent framework talks to zuraffa: **mission envelopes** (request work under
budget and policy), **evidence packets** (certified per-step outcomes), and
**checkpoint requests** (save/restore session state), answered by **receipt
verification** (a digest-chained verdict the client can independently
re-verify). Every message is JSON; every message has a JSON Schema (draft-07);
the wire is NDJSON over stdio — the seam where MCP (#791) later slots in as
one transport among possible transports.

This feature delivers the first slice (v0, protocol version `0.1`):

1. the spec documents (this file + `contracts/zap.md` + machine-readable
   JSON Schemas and golden examples committed under `schemas/` and `golden/`);
2. a structural validator + typed message layer in `lib/src/zap/`;
3. a conformance suite and self-test command `zfa zap conform` (exit 0/1,
   `--format text|json` per #778);
4. a reference client (`ZapClient`) that drives a full session and
   independently verifies the receipt's chain digest;
5. a host command `zfa zap serve` (NDJSON over stdio) that executes mission
   steps under budget and policy gates and issues receipts;
6. one external demo: a **non-MCP client** (`examples/zap_demo/
   foreign_client.dart` — pure Dart SDK, ZERO zuraffa imports) driving a full
   TDD loop (witnessed red → green → verify) through a real `zfa zap serve`
   process;
7. an interop proof: the reference client and the independent foreign client
   both complete sessions against the SAME unmodified host — no code changes
   on either side.

The pitch to the ecosystem, per the issue: "if your agent speaks ZAP, it can
build production Flutter apps on zuraffa — verified, budgeted, policy-gated."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The protocol is published and machine-checkable (Priority: P1)

A tool author (or an agent-framework author) wants to implement ZAP without
reading zuraffa's source. They read `specs/071-zuraffa-agent-protocol/
contracts/zap.md` (the human-readable wire contract), take the committed
draft-07 JSON Schemas (`schemas/*.schema.json`) and the golden examples
(`golden/*.golden.json`), and validate their implementation against them. The
schemas and goldens are not stale documentation drift: a repo test re-derives
them from the code (the source of truth) and fails on any byte drift. Every
message that reaches typed parsing passes structural validation first, with
precise error paths (`steps[0].phase: must be one of ...`), so a hallucinated
or malformed tool call is rejected structurally, never interpreted.

**Why this priority**: the issue's core deliverable is the open spec itself;
without a published, drift-checked contract there is nothing to conform to.

### User Story 2 - `zfa zap conform` self-tests the reference implementation (Priority: P1)

A maintainer (or CI) runs `zfa zap conform`. The command runs the conformance
suite: schema self-integrity, golden positive validation, golden↔typed
round-trips, a table of malformed messages that MUST be rejected with precise
errors, and an in-process reference-client session (mission → evidence →
receipt, with the client independently recomputing the chain digest). All
checks pass → exit 0; any check fails → exit 1. `--format json` emits a
single parseable verdict object (per #778) and `--format text` prints
per-check lines with a final machine summary line
`zap: conform checks=<n> passed=<n> failed=0 — OK`.

**Why this priority**: the issue's first done-when criterion is "the
conformance suite passes for the reference client" — this command is that
criterion's executable form.

### User Story 3 - An external non-MCP client drives a full TDD loop (Priority: P1)

An agent author runs the demo:
`dart examples/zap_demo/foreign_client.dart` (from the repo root). The client
spawns a real `zfa zap serve` process, speaks ZAP over its stdin/stdout — no
MCP anywhere — and drives a **full TDD loop**: a mission whose steps are
`red` (a real failing check, exit ≠ 0), then `green` (the fixed check, exit
0); it saves a checkpoint, restores it, then completes the loop with a
`verify` step. The host executes each step as a real subprocess under the
mission's budget and tool-allowlist, streams an evidence packet per step, and
issues a receipt whose `tdd-discipline` check certifies the loop shape (red
failed, green passed) and whose `chainDigest` the client recomputes from the
received evidence packets and compares. The client prints the final receipt
JSON and exits with the receipt's exit code (0 pass / 1 fail).

**Why this priority**: the issue's named deliverable — "One external demo: a
non-MCP client driving a full TDD loop".

### User Story 4 - Two independent implementations interop with zero code changes (Priority: P1)

An auditor runs the interop test suite. Client A is the reference `ZapClient`
(importing `package:zuraffa/zap.dart`). Client B is the foreign client
(`examples/zap_demo/foreign_client.dart`, pure `dart:io`/`dart:convert`, zero
zuraffa imports — hand-rolled JSON per the published schemas). BOTH drive the
same host implementation (`zfa zap serve`, spawned from the same entry point
`bin/zfa.dart`, same flags) through complete sessions, and both independently
verify their receipts. Neither the host nor either client is modified between
the two runs — interop is proven by the published contract alone, not by
adapter code on either side.

**Why this priority**: the issue's second done-when criterion — "Two
independent implementations interop without code changes on either side".

### Edge Cases

- A malformed NDJSON line (not JSON, not an object) → `error` envelope,
  `code: schema`; the session continues (never dies).
- A structurally valid message of a host→agent-only type sent inbound
  (evidence, or a receipt) → `error`, `code: direction`.
- Wrong protocol version (`"zap": "2.0"`) → `error`, `code: version`.
- A mission whose step count exceeds the budget → `error`, `code: budget`
  BEFORE any step executes.
- A mission whose step executable is not in the tool allowlist → `error`,
  `code: policy` BEFORE any step executes; commands are tokenized and run
  without a shell, so shell injection is structurally impossible.
- A "green" step that exits non-zero, or a session whose first green arrives
  with no red ever witnessed → execution proceeds, evidence is reported, and
  the RECEIPT verdict is `fail` with the `tdd-discipline` check naming the
  violation.
- Restoring an unknown `stateId` → `error`, `code: bad-checkpoint`. Checkpoint
  for a mission never submitted → `error`, `code: unknown-mission`.
- A step exceeding its `timeoutSeconds` → killed, evidence `exit: 124` with a
  timeout note; the receipt verdict is `fail`.
- Evidence `output` is capped (2000 chars) so a chatty step cannot blow up the
  wire.

## Requirements *(mandatory)*

**FR-001 — Wire envelope.** ZAP v0 runs over NDJSON (one JSON object per
line, UTF-8) on stdio. Every message carries `"zap": "0.1"` (the protocol
version; `1.0` is reserved for the first stable release), `"type"` (one of
`mission`, `evidence`, `checkpoint`, `receipt`, plus the auxiliary
`error`), `"id"` (non-empty string) and `"ts"` (ISO-8601 UTC, `Z` suffix).

**FR-002 — Mission envelope.** Agent→host request for work:
`missionId`, `agent`, `goal`, optional `feature`, `budget {maxSteps}` (≥1),
`policy {riskTier: standard|elevated|admin, toolAllowlist: [executables]}`,
`steps` (≥1 of `{id, command, phase: red|green|refactor|verify, description?,
timeoutSeconds?}`). JSON Schema published at `schemas/mission.schema.json`.

**FR-003 — Evidence packet.** Host→agent certified step outcome:
`missionId`, `stepId`, `phase`, `command` (echo of the executed command),
`exit`, `digest` (sha256 hex of the captured output), `at`, optional
`durationMs` and capped `output`.

**FR-004 — Checkpoint message.** Agent→host `kind: save|restore`; host→agent
`kind: saved|restored` with `stateId`, `digest` (sha256 of the canonical
snapshot), `steps` (evidence count at snapshot), `at`. Snapshots persist to
`.zfa/zap/checkpoints/<stateId>.json` (atomic tmp+rename) when a checkpoint
directory is configured, so state survives process restarts.

**FR-005 — Receipt.** Host→agent verdict per mission: `verdict: pass|fail`,
`exit: 0|1`, `chainDigest` (sha256 evidence-chain head), `stepsExecuted`,
`stepsTotal`, `checks[]` (`name`, `ok`, `detail?`), `at`. Named checks:
`mission-schema`, `budget`, `policy`, `steps-executed`, `tdd-discipline`,
`evidence-chain`.

**FR-006 — JSON Schema per message.** Draft-07 schema for each of the five
types, defined in code (`lib/src/zap/zap_schema.dart` — the source of truth),
exportable via `zfa zap schema [--type <t>] [--export <dir>]`, committed
under `specs/071-zuraffa-agent-protocol/schemas/`. A repo test fails on drift
between the committed files and the code.

**FR-007 — Structural validation first.** Every inbound message passes
`ZapValidator` (a draft-07 subset engine: type, enum, required, properties,
items, minLength, minItems, uniqueItems, pattern, minimum, maximum,
additionalProperties) BEFORE typed parsing. Rejections carry precise
JSON-path errors. Golden examples validate positively; a negative table of
malformed messages must all be rejected.

**FR-008 — Conformance suite.** `zfa zap conform` runs: schema
self-integrity, golden positives, golden↔typed round-trips, the negative
table, a reference-client session (pass), and a discipline-violation session
(receipt `fail`). Exit 0/1; `--format text|json` per #778.

**FR-009 — Host.** `zfa zap serve` reads NDJSON on stdin, writes NDJSON on
stdout (human logs to stderr), processes lines sequentially, exits 0 at EOF,
never dies on a bad message.

**FR-010 — Budget gate.** The session budget is FIXED by the first mission's
`maxSteps`; later missions may not raise it (self-escalation rejected) and
cumulative executed steps may not exceed it. Violations → `error`,
`code: budget`, before execution.

**FR-011 — Policy gate.** The session policy (riskTier + allowlist) is fixed
by the first mission; commands are tokenized on whitespace (no shell), the
executable token must be in the allowlist. Violations → `error`,
`code: policy`, before execution.

**FR-012 — TDD discipline verdict.** Cumulative session discipline: every
`red` evidence must have `exit ≠ 0`; every `green`/`verify` evidence must
have `exit == 0`; at least one `red` must precede the first `green`.
Violation → receipt `verdict: fail` with `tdd-discipline` check `ok: false`
and a `detail` naming the violated rule.

**FR-013 — Evidence chain.** sha256 chain over certified facts
(`v0.1`, missionId, stepId, phase, command, exit, digest, at, prev-link),
genesis `genesis`, head exposed as `chainDigest`. Clients recompute the chain
from received evidence packets and compare — receipt verification.

**FR-014 — Reference client.** `ZapClient` (injectable streams): submit
missions, await receipts, save/restore checkpoints, collect evidence,
recompute + verify the chain digest.

**FR-015 — Foreign demo client.** `examples/zap_demo/foreign_client.dart`:
pure SDK, zero zuraffa imports, spawns `dart bin/zfa.dart zap serve`, drives
the full TDD loop (red→green via mission 1, checkpoint save + restore,
verify via mission 2), verifies the receipt, prints receipt JSON, exits with
the receipt exit. `examples/zap_demo/tdd_loop.dart` provides the real
red/green/verify commands.

**FR-016 — Timeouts and capping.** Per-step `timeoutSeconds` (default 60,
max 600): timeout → kill, `exit: 124`. Evidence `output` capped at 2000
chars.

**FR-017 — Open, not framework-locked.** The contract files (schemas,
goldens, `contracts/zap.md`) are the interop surface: the foreign client
builds against them alone. No zuraffa-specific type is required on the wire.

### Key Entities

- `ZapMessage` (sealed) → `MissionEnvelope`, `EvidencePacket`,
  `CheckpointMessage`, `ZapReceipt`, `ZapError` — `lib/src/zap/zap_message.dart`
- `ZapSchema` (draft-07 maps per type) — `lib/src/zap/zap_schema.dart`
- `ZapValidator` / `ZapValidationIssue` — `lib/src/zap/zap_validator.dart`
- `ZapGoldens` — `lib/src/zap/zap_golden.dart`
- `ZapConformance.run()` → report — `lib/src/zap/zap_conformance.dart`
- `ZapHost` / `ZapSession` / `ZapCheckpointStore` — `lib/src/zap/zap_host.dart`
- `ZapStepExecutor` (+ subprocess & scripted impls) —
  `lib/src/zap/zap_executor.dart`
- `zapEvidenceChain` / chain link computation — `lib/src/zap/zap_chain.dart`
- `ZapClient` — `lib/src/zap/zap_client.dart`
- `ZapCommand` (`conform`, `serve`, `schema`) —
  `lib/src/commands/zap_command.dart`
- Public import surface: `package:zuraffa/zap.dart` (a barrel re-exporting
  every type above; consumers never import `src/` directly)

## Success Criteria *(mandatory)*

- **SC-001** (US1): JSON Schema (draft-07) exists per message type, is
  committed under the spec dir, and the committed bytes equal the code-derived
  schemas (drift test green).
- **SC-002** (US2): `zfa zap conform` exits 0 with every check green
  (goldens, round-trips, negatives rejected, reference session verified);
  `--format json` emits one verdict object; exit 1 propagates when a check
  fails.
- **SC-003** (US3): the foreign client demo exits 0 against a real
  `zfa zap serve` subprocess, with a full TDD loop (red exit ≠ 0 witnessed,
  then green, then verify), a checkpoint save + restore, and a client-verified
  `chainDigest`.
- **SC-004** (US4): the reference `ZapClient` and the foreign client BOTH
  complete sessions against the same unmodified host entry point
  (`dart bin/zfa.dart zap serve`), each verifying its receipt — interop with
  zero code changes on either side.
- **SC-005** (edge cases): malformed input, wrong version, budget breach,
  policy breach, direction violations, unknown checkpoint, and discipline
  violations are each caught and reported with the documented error code /
  verdict shape — hallucinated tool calls are structurally impossible, not
  merely discouraged.

## Assumptions

- v0 ships exactly one transport (NDJSON stdio). MCP (#791) becomes a
  transport ABOVE this contract in a later slice; the stream-based
  host/client seam is where it plugs in.
- v0 checkpoint/restore is per-`stateId` within a configured checkpoint
  directory; cross-mission budget/policy rules are deliberately strict
  (first mission fixes both) — a documented v0 constraint.
- Receipt "verification" in v0 is digest-chain re-computation (tamper
  evidence), not asymmetric cryptographic signing; signing is future work.
- The demo's TDD loop is a real executed red/green/verify sequence (a real
  failing check, then the fix, then the suite) but runs in the demo fixture,
  not a full generated Flutter app — the protocol contract, not app
  generation, is what v0 proves.
- `examples/zap_demo/` scripts are pure-SDK (no pubspec): they run with
  `dart <file>` and import nothing from zuraffa — that independence IS the
  interop argument.
