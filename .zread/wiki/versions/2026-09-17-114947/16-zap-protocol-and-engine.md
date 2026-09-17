The ZAP (Zuraffa Agent Protocol) is the **versioned interop contract** sitting above transports — any agent framework that speaks ZAP gets the same guarantees from zuraffa: verified, budgeted, policy-gated. It is the framework's answer to the fragmentation of agent integrations, providing a single contract that MCP (#791) and any future transport can ride. v0.1 ships one transport: NDJSON over stdio (`zfa zap serve`), with the protocol designed so transports are swappable beneath a stable message layer.

The ZAP engine lives in `lib/src/zap/` and is exposed through the public barrel at `lib/zap.dart`. The wire contract itself is codified in `specs/071-zuraffa-agent-protocol/contracts/zap.md`, with committed schema and golden files under `specs/071-zuraffa-agent-protocol/schemas/` and `specs/071-zuraffa-agent-protocol/golden/` — the same artifacts third parties validate against, and the same artifacts the conformance suite enforces against the code via a drift gate.

## Architecture: Layered Design

The ZAP stack is organized into four deliberate layers, each with a single responsibility and a testable boundary:

```
┌─────────────────────────────────────────────────────────────┐
│  Transport Layer (NDJSON over stdio, MCP, in-process wire)  │
├─────────────────────────────────────────────────────────────┤
│  Host Layer (ZapHost, ZapSession, ZapCheckpointStore)        │
│  - Sequential line processing, never dies on bad messages   │
│  - Session state, budget/policy enforcement, TDD discipline  │
├─────────────────────────────────────────────────────────────┤
│  Execution Layer (ZapStepExecutor interface + implementations)│
│  - SubprocessZapStepExecutor: real subprocess, no shell      │
│  - ScriptedZapStepExecutor: deterministic test doubles       │
├─────────────────────────────────────────────────────────────┤
│  Message & Verification Layer                                │
│  - ZapProtocol: NDJSON codec + envelope constants            │
│  - ZapSchema: draft-07 JSON schemas (source of truth)        │
│  - ZapValidator: structural validation with path-precise errors │
│  - ZapMessage: typed message family (sealed class hierarchy) │
│  - ZapChain: sha256 evidence chain for receipt verification  │
│  - ZapGoldens: canonical examples + canonical JSON export    │
└─────────────────────────────────────────────────────────────┘
```

The design follows a **fail-safe-by-construction** philosophy: the host never throws on message-level problems — every rejection becomes an `error` envelope and serving continues. The version gate (`zap` field) runs before any message interpretation, and structural validation runs before any semantic handling. This means a hallucinated field, a wrong protocol version, or a malformed mission all produce precise, classifiable rejections with JSON-path detail, never a silent misinterpretation or a crash.

Sources: [lib/zap.dart](lib/zap.dart#L1-L57), [lib/src/zap/zap_protocol.dart](lib/src/zap/zap_protocol.dart#L1-L82), [lib/src/zap/zap_host.dart](lib/src/zap/zap_host.dart#L1-L50)

## The Wire Protocol: NDJSON Envelopes

ZAP uses **NDJSON** (one JSON object per line, UTF-8, `\n`-terminated) as its transport framing. This is the same discipline as the agent shell wire (#808). The host reads request envelopes from stdin and writes reply envelopes to stdout; human-readable logs go to stderr. The host processes lines **sequentially** — session state is order-sensitive — and exits 0 at stdin EOF.

Every message carries a common envelope:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `zap` | string | ✔ | Protocol version. v0.1 → `"0.1"`. Anything else → `error {code: "version"}`. |
| `type` | string | ✔ | `mission` \| `evidence` \| `checkpoint` \| `receipt` \| `error` |
| `id` | string | ✔ | Non-empty message id (host: UUID v4; client: any non-empty) |
| `ts` | string | ✔ | ISO-8601 **UTC** with `Z` suffix, e.g. `2026-09-03T10:00:00Z` |

The envelope is **closed** (`additionalProperties: false`) on purpose: hallucinated fields are a schema error with the field's path, not a silent ignore. This is a deliberate security property — an agent that sends `priority: "URGENT"` to a mission that doesn't expect it gets rejected at `priority`, not a silent drop.

Sources: [specs/071-zuraffa-agent-protocol/contracts/zap.md](specs/071-zuraffa-agent-protocol/contracts/zap.md#L1-L30), [lib/src/zap/zap_protocol.dart](lib/src/zap/zap_protocol.dart#L34-L82)

## The Five Message Types

ZAP defines five wire types, four core plus one auxiliary:

### 1. `mission` (agent → host) — request work

The mission is the unit of work. It carries a session key (`missionId`), an identity (`agent`), a human-readable `goal`, an optional `feature` slug, a fixed `budget`, a fixed `policy`, and an ordered list of `steps`. Each step is a unit of work with an `id`, a `command` (whitespace-tokenized, executed without a shell), a `phase` (`red`|`green`|`refactor`|`verify`), an optional `description`, and an optional `timeoutSeconds` (1..600).

The first mission for a `missionId` **fixes** the budget and policy for the entire session. Subsequent missions with the same `missionId` continue the session but cannot escalate the budget or drift the policy — these are rejected before any step executes.

### 2. `evidence` (host → agent) — certified step outcome

After each step executes, the host emits an evidence packet. It carries the certified facts: `missionId`, `stepId`, `phase`, `command` (echo of what ran), `exit` (real process exit code; `124` = timeout by convention; can be negative on signals), `digest` (sha256 hex of the **full** captured output), `at` (ISO-8601 UTC completion time), `durationMs`, and `output` (capped at 2000 chars as a preview — the digest always covers the full output, never the capped preview).

Evidence is **host-to-agent only**. Sending it inbound is a `direction` error.

### 3. `checkpoint` (agent ↔ host) — save / restore session state

Checkpoints are the session's persistence seam. Four `kind` values operate in two directions:

| `kind` | Direction | Fields | Meaning |
|--------|-----------|--------|---------|
| `save` | agent→host | `missionId` | snapshot the session now |
| `saved` | host→agent | `stateId`, `digest`, `steps`, `at` | `stateId` = `cp-<digest[0:12]>`; `digest` = sha256 of the canonical snapshot; `steps` = evidence count at snapshot |
| `restore` | agent→host | `stateId` | rebuild the session from a snapshot |
| `restored` | host→agent | `stateId`, `digest`, `steps`, `at` | session state rewound/rebuilt |

Snapshots persist to `<checkpoint-dir>/<stateId>.json` using atomic tmp+rename writes (the `SnapshotStore` discipline from #808). The `stateId` is host-generated (`cp-` + 12 lowercase hex chars — the first 12 of the snapshot digest) and is always resolved **inside** the checkpoint dir, so a client-controlled id can never traverse out via an absolute path or `../`. On restore, the host recomputes the snapshot digest and rejects any record that no longer hashes to its certified `digest` — a planted or hand-edited checkpoint file is not a session.

### 4. `receipt` (host → agent) — verified verdict

The receipt is the protocol's cryptographic anchor. It carries: `verdict` (`pass`|`fail` — pass iff every check is ok), `exit` (0 for pass, 1 for fail — the client's exit code), `chainDigest` (head of the evidence chain), `stepsExecuted`, `stepsTotal`, `checks` (an ordered list), and `at`.

The six checks, in order: `mission-schema`, `budget`, `policy`, `steps-executed`, `tdd-discipline`, `evidence-chain`. The `tdd-discipline` check is the cumulative TDD enforcement: every `red` evidence must have `exit != 0` (a passing red is a test that never failed — the loop is dishonest), every `green`/`verify` evidence must have `exit == 0`, and at least one `red` must precede the first `green`. Violations do **not** block execution — they flip the receipt's verdict to `fail` with a `tdd-discipline` detail naming the specific rule violated.

### 5. `error` (host → agent) — structural rejection

The auxiliary rejection channel. Error codes form a taxonomy:

| `code` | Meaning |
|--------|---------|
| `schema` | message failed structural validation (details carry JSON paths) |
| `version` | `zap` field is not a version the host speaks |
| `direction` | host→agent-only type sent inbound |
| `budget` | step count would exceed the session budget (rejected BEFORE execution) |
| `policy` | command executable not in the session allowlist (rejected BEFORE execution) |
| `unknown-mission` | checkpoint for a mission that was never submitted |
| `bad-checkpoint` | restore of an unknown `stateId`, or a persisted record whose snapshot no longer hashes to its certified `digest` |
| `internal` | unexpected host fault (never hides a schema problem) |

Sources: [lib/src/zap/zap_message.dart](lib/src/zap/zap_message.dart#L1-L475), [lib/src/zap/zap_schema.dart](lib/src/zap/zap_schema.dart#L1-L377), [specs/071-zuraffa-agent-protocol/contracts/zap.md](specs/071-zuraffa-agent-protocol/contracts/zap.md#L31-L150)

## The Evidence Chain: Cryptographic Receipt Verification

The evidence chain is the protocol's **tamper-evident core**. It is a sha256 hash chain over the certified facts of every evidence packet, folded in order, genesis-linked — the same discipline as the TDD cycle-log chain (#788/#828).

The chain payload per evidence link is null-separated (byte-stable, order-stable):

```
sha256( "v0.1" \0 missionId \0 stepId \0 phase \0 command \0 exit \0 digest \0 at \0 prevLink )
```

`link_0` chains from the literal `"genesis"`; `chainDigest` = the last link. Any mutation of any certified fact (or any reordering) changes the head.

**The verification split**: the host exposes `chainDigest` in the receipt; the client **independently recomputes** the chain from the evidence packets it received and compares. This is the protocol's trust-minimization property — the client never trusts the host's receipt; it verifies the cryptographic commitment against its own witnessed evidence. The host's `evidence-chain` check is `ok: true` by construction (the chain is computed over the evidence the host itself emitted), but the real verification happens on the client side.

Sources: [lib/src/zap/zap_chain.dart](lib/src/zap/zap_chain.dart#L1-L53), [lib/src/zap/zap_client.dart](lib/src/zap/zap_client.dart#L145-L150)

## The Host: Session State & Enforcement

`ZapHost` processes NDJSON lines sequentially and emits reply lines through an injected callback — the seam `zfa zap serve` wires to stdin/stdout, and tests wire to in-memory lists. The host's state model is built around `ZapSession`, which holds the mission ID, the fixed budget, the fixed risk tier, the fixed tool allowlist, the cumulative evidence list (as chain-fact maps), and the cumulative step counts.

The host's processing pipeline for each inbound line is:

1. **Decode** — `ZapProtocol.decodeLine`; a `FormatException` becomes a `schema` error envelope.
2. **Version gate** — `zap` must equal `zapProtocolVersion`; otherwise a `version` error.
3. **Structural validation** — `ZapValidator.validate`; failures become `schema` errors with path-precise details.
4. **Direction gate** — only `mission` and checkpoint `save`/`restore` are inbound; everything else is a `direction` error.
5. **Mission handling** — for a new session: budget check (steps ≤ maxSteps), allowlist check (every step's executable must be in the allowlist), then execute. For a continuing session: budget cannot escalate, policy cannot drift, cumulative steps must fit, then execute.
6. **Execution** — each step runs through the injected `ZapStepExecutor`; evidence is emitted per step; a receipt is emitted after all steps.
7. **Checkpoint handling** — `save` snapshots the session (with digest-certified persistence); `restore` loads, digest-verifies, mission-matches, and rebuilds the session.

The host **never dies on a bad message** — every rejection is an `error` envelope, and the session keeps serving. A genuinely unexpected fault (outside the message handling path) becomes an `internal` error envelope.

Sources: [lib/src/zap/zap_host.dart](lib/src/zap/zap_host.dart#L55-L653)

## The Step Executor: No-Shell Subprocess Execution

`ZapStepExecutor` is an abstract interface with two implementations. The production executor, `SubprocessZapStepExecutor`, runs each mission step as a **real subprocess without a shell**:

- The command is whitespace-tokenized; the first token is the executable, the rest are arguments.
- `Process.start(executable, args, workingDirectory: ...)` is used directly — no shell interpolation, no pipes, no injection.
- Both stdout and stderr are drained to completion **before** the digest is computed, because the certified digest covers the full combined output.
- A per-step timeout applies: on `TimeoutException`, the process is killed with SIGKILL (SIGTERM can be trapped — the executor escalates straight to SIGKILL so a step that ignores SIGTERM doesn't hang the sequential serve loop forever), and the exit is normalized to `124` (the timeout convention).
- The digest is `sha256` over the **full** combined output; the capped preview (2000 chars) is applied only to the `output` field, never to the digest.

The test executor, `ScriptedZapStepExecutor`, is a deterministic handler used by the conformance suite and tests — it takes a `stepId → result` handler and records invocations.

Sources: [lib/src/zap/zap_executor.dart](lib/src/zap/zap_executor.dart#L1-L168)

## The Client: Independent Verification

`ZapClient` is the reference implementation, speaking the protocol over injectable streams — the same seam a process boundary, an MCP transport (#791), or a test wire provides. It is constructed with an inbound stream factory and a send function. `ZapClient.overProcess(Process)` wires it to a live process's stdin/stdout.

The client's key responsibilities:
- **Submit** missions and await their receipts (with a 30s timeout and fast-fail on error envelopes — a rejected mission never produces a receipt, so waiting would only burn the timeout).
- **Collect** evidence packets, checkpoint replies, and error envelopes in wire order.
- **Request** checkpoints (`save`/`restore`) and await the corresponding replies.
- **Recompute** the evidence chain from received packets — `recomputeChainDigest(missionId)`.
- **Verify** receipts — `verifyReceipt(receipt)` checks that `verdict == 'pass'`, every check is `ok`, and the recomputed chain digest equals the receipt's `chainDigest`.

The client **never dies on a bad line**: a line that decodes but violates the typed contract is dropped, and consuming continues.

Sources: [lib/src/zap/zap_client.dart](lib/src/zap/zap_client.dart#L1-L235)

## Validation: A Deliberately Small Draft-07 Subset

`ZapValidator` is a hand-written draft-07 JSON Schema subset engine — exactly the keywords the ZAP schemas use: `type`, `enum`, `required`, `properties`, `items`, `additionalProperties`, `minLength`, `minItems`, `uniqueItems`, `pattern`, `minimum`, `maximum`. Every rejection carries the **JSON path** of the offending value, so a hallucinated tool call is rejected with `steps[0].phase: must be one of red|green|refactor|verify` — not with a shrug.

The validator is also a **third-party entry point**: `ZapValidator.validateWith(value, schema)` validates arbitrary decoded values against any schema limited to the same subset, and `ZapValidator.validateRaw(value)` rejects non-objects before schema dispatch.

The schemas themselves are **closed** (`additionalProperties: false`) and deliberately avoid draft-07 conditionals so every draft-07 validator (including minimal third-party ones) can enforce them. Kind-specific requirements (e.g. `restore` needs `stateId`) live in the typed layer, not the schema.

Sources: [lib/src/zap/zap_validator.dart](lib/src/zap/zap_validator.dart#L1-L303), [lib/src/zap/zap_schema.dart](lib/src/zap/zap_schema.dart#L1-L40)

## Golden Examples & Canonical Serialization

`ZapGoldens` provides one canonical message per core type (`mission`, `evidence`, `checkpoint`, `receipt`), fresh deep-copied on every call. These are the same examples the conformance suite validates, the committed `golden/*.golden.json` files carry, and third parties validate their implementations against. The evidence digest in the golden is the real sha256 of the canonical output string (derived, never hand-typed), so the golden is internally consistent by construction.

`zapCanonicalJson(value)` produces the exact file bytes `zfa zap schema --export` writes: two-space-indented JSON plus one trailing newline. Every drift gate byte-compares committed files against this, so the published contract is **writer-canonical**, not merely structurally equal.

Sources: [lib/src/zap/zap_golden.dart](lib/src/zap/zap_golden.dart#L1-L185)

## Conformance Suite

`ZapConformance.run()` is the executable form of the issue's first done-when criterion: "the conformance suite passes for the reference client". It runs seven check groups:

1. **Schema self-integrity** — every schema is a draft-07 object schema with a closed envelope.
2. **Golden positives** — every golden example validates against its schema.
3. **Golden ↔ typed round-trips** — `fromJson(toJson())` equals the golden map for every type.
4. **Negative table** — malformed messages MUST be rejected with precise paths (not JSON, missing fields, bad enums, zero budget, empty steps, hallucinated fields, wrong types, unknown types, wrong version).
5. **Reference-client session** — an in-process, scripted session verifies the receipt verdict, the chain digest, and `verifyReceipt`.
6. **Discipline-violation session** — a dishonest loop (red that passes) must flip the receipt to `fail` with the `tdd-discipline` rule named.
7. **Drift gate** (when `--drift-dir` is given) — byte-compares committed `schemas/*.schema.json` and `golden/*.golden.json` against the code's canonical serialization.

`zfa zap conform` exits 0 on pass, 1 on fail, with `--format text|json` output (JSON emits a single parseable verdict object per #778).

Sources: [lib/src/zap/zap_conformance.dart](lib/src/zap/zap_conformance.dart#L1-L440)

## CLI Surface

The `zfa zap` command exposes three subcommands:

| Subcommand | Purpose |
|------------|---------|
| `zfa zap conform` | Run the conformance self-test. `--format text|json`, `--drift-dir <dir>` gates the published contract files against the code. |
| `zfa zap serve` | Run the ZAP host over stdio: NDJSON missions/checkpoints on stdin, evidence/receipts on stdout. `--cwd`, `--checkpoint-dir`, `--timeout` options. |
| `zfa zap schema` | Print a draft-07 schema; `--export <dir>` writes the schemas + golden examples (the publishable contract). |

The serve command wires `ZapHost.handleLine` to stdin/stdout with per-line flushing (replies MUST flush per line since the client reads line-by-line). Logs go to stderr. The host is constructed with a working directory, a checkpoint directory (default `.zfa/zap/checkpoints` under the working directory), and a default per-step timeout (default 60s, clamped to 1..600).

Sources: [lib/src/commands/zap_command.dart](lib/src/commands/zap_command.dart#L1-L283)

## Session Flow (The Demo, Verbatim)

The canonical session flow, as documented in the contract:

```
client                                          host (zfa zap serve)
  │ mission{steps:[red,green], budget:8} ───────▶ validate schema/budget/policy
  │◀── evidence{s1, phase:red, exit:1} ───────── run step 1 (real subprocess)
  │◀── evidence{s2, phase:green, exit:0} ──────── run step 2
  │◀── receipt{verdict:pass, chainDigest} ─────── verdict
  │ checkpoint{kind:save} ───────────────────────▶ snapshot
  │◀── checkpoint{kind:saved, stateId, digest} ──
  │ checkpoint{kind:restore, stateId} ───────────▶ rebuild
  │◀── checkpoint{kind:restored, steps:2} ────────
  │ mission{steps:[verify]} ─────────────────────▶ continues session
  │◀── evidence{s3, phase:verify, exit:0} ────────
  │◀── receipt{verdict:pass, chainDigest} ────────
  │ (client recomputes chain over evidence s1..s3, compares, exits 0)
```

This flow demonstrates the protocol's full value proposition: the client submits work under budget and policy, witnesses certified evidence, receives a cryptographically-verifiable receipt, checkpoints and restores session state, and continues — all with independent verification at every step.

Sources: [specs/071-zuraffa-agent-protocol/contracts/zap.md](specs/071-zuraffa-agent-protocol/contracts/zap.md#L150-L215)

## Next Steps

With the ZAP Protocol & Engine documented, the natural progression through the catalog is:

- **[Simulation Worlds & Certified Test Environments](17-simulation-worlds-and-certified-test-environments)** — ZAP's checkpoint and evidence mechanisms integrate with the simulation world infrastructure for certified test environments.
- **[State Management & Sync Framework](18-state-management-and-sync-framework)** — the checkpoint snapshots feed into the broader state management and offline-first sync framework.
- **[Proof Receipts & Verification Gates](15-proof-receipts-and-verification-gates)** — the evidence chain and receipt verification are part of the broader proof receipt ecosystem.
- **[MCP Server Reference](11-mcp-server-reference)** — MCP (#791) becomes a transport above the ZAP contract.