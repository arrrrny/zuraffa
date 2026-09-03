# ZAP v0.1 Wire Contract — Zuraffa Agent Protocol (spec 071, issue #809)

ZAP is the contract ABOVE transports: any agent framework that speaks ZAP
gets the same guarantees from zuraffa — verified, budgeted, policy-gated.
v0.1 ships one transport: NDJSON over stdio (`zfa zap serve`). MCP (#791)
becomes another transport against this same contract.

## 1. Transport

- NDJSON: one JSON object per line, UTF-8, `\n`-terminated.
- Client → host: requests on the host's **stdin**.
- Host → client: replies/events on the host's **stdout** (NDJSON only;
  human-readable logs go to **stderr**).
- The host processes lines **sequentially**; each line produces zero or more
  reply lines. The host NEVER dies on a bad line — it answers with an
  `error` message and keeps serving. Host exit: `0` at stdin EOF.

## 2. Envelope (all messages)

| Field  | Type   | Required | Notes |
|--------|--------|----------|-------|
| `zap`  | string | ✔ | Protocol version. v0.1 → `"0.1"`. Anything else → `error {code: "version"}`. `"1.0"` is reserved for the first stable release. |
| `type` | string | ✔ | `mission` \| `evidence` \| `checkpoint` \| `receipt` \| `error` |
| `id`   | string | ✔ | Non-empty message id (host: UUID v4; client: any non-empty) |
| `ts`   | string | ✔ | ISO-8601 **UTC** with `Z` suffix, e.g. `2026-09-03T10:00:00Z` |

Unknown top-level fields are REJECTED (`additionalProperties: false`) — the
envelope is closed on purpose: hallucinated fields are a schema error, not
a silent ignore.

## 3. Messages

### 3.1 `mission` (agent → host) — request work

```json
{
  "zap": "0.1", "type": "mission", "id": "m-1", "ts": "2026-09-03T10:00:00Z",
  "missionId": "demo-tdd",
  "agent": "foreign-client",
  "goal": "Drive a full TDD loop",
  "feature": "071-zuraffa-agent-protocol",
  "budget": {"maxSteps": 8},
  "policy": {"riskTier": "standard", "toolAllowlist": ["dart"]},
  "steps": [
    {"id": "s1", "command": "dart examples/zap_demo/tdd_loop.dart red",
     "phase": "red", "description": "witness the failing check",
     "timeoutSeconds": 30}
  ]
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `missionId` | string | ✔ | session key; later missions with the same id CONTINUE the session |
| `agent` | string | ✔ | who is asking (framework name, e.g. `claude`, `langgraph`) |
| `goal` | string | ✔ | human-readable intent |
| `feature` | string | – | optional zuraffa feature slug |
| `budget.maxSteps` | integer ≥1 | ✔ | session step budget; FIXED by the FIRST mission |
| `policy.riskTier` | `standard`\|`elevated`\|`admin` | ✔ | carried; enforcement beyond allowlist is v1 work |
| `policy.toolAllowlist` | string[] (≥1, unique) | – | allowed EXECUTABLES (first token of each command); omit = allow nothing executable? No — omit = allowlist not restricted at the policy layer? **No**: v0.1 requires the allowlist to be present on the first mission and fixed for the session (see §4) |
| `steps[].id` | string | ✔ | unique within the mission |
| `steps[].command` | string | ✔ | whitespace-tokenized; executed WITHOUT a shell; first token must be in the allowlist |
| `steps[].phase` | `red`\|`green`\|`refactor`\|`verify` | ✔ | drives the TDD-discipline verdict |
| `steps[].description` | string | – | |
| `steps[].timeoutSeconds` | integer 1..600 | – | default 60; timeout → kill, evidence `exit: 124` |

Host replies: one `evidence` per executed step, then one `receipt` — or a
single `error` (rejection BEFORE execution).

### 3.2 `evidence` (host → agent) — certified step outcome

```json
{
  "zap": "0.1", "type": "evidence", "id": "e-1", "ts": "2026-09-03T10:00:01Z",
  "missionId": "demo-tdd", "stepId": "s1", "phase": "red",
  "command": "dart examples/zap_demo/tdd_loop.dart red",
  "exit": 1, "digest": "5f2c…64-hex…", "at": "2026-09-03T10:00:01Z",
  "durationMs": 412, "output": "ZAP DEMO red: 1 check FAILED (by design)…"
}
```

`digest` = sha256 (lowercase hex, 64 chars) of the captured combined
output. `output` is capped at 2000 chars. `exit` is the real process exit
code (can be negative on signals; `124` = timeout by convention). Sending
`evidence` inbound is a `direction` error.

### 3.3 `checkpoint` (agent ↔ host) — save / restore session state

```json
{"zap":"0.1","type":"checkpoint","id":"c-1","ts":"…",
 "missionId":"demo-tdd","kind":"save"}
```

| `kind` | Direction | Fields | Meaning |
|--------|-----------|--------|---------|
| `save` | agent→host | `missionId` | snapshot the session now |
| `saved` | host→agent | `stateId`, `digest`, `steps`, `at` | `stateId` = `cp-<digest[0:12]>`; `digest` = sha256 of the canonical snapshot; `steps` = evidence count at snapshot |
| `restore` | agent→host | `stateId` | rebuild the session from a snapshot |
| `restored` | host→agent | `stateId`, `digest`, `steps`, `at` | session state rewound/rebuilt |

Snapshots persist to `<checkpoint-dir>/<stateId>.json` (atomic
tmp+rename; default dir `.zfa/zap/checkpoints` under the host's working
directory, overridable). Unknown `stateId` → `error {code:
"bad-checkpoint"}`; checkpoint for a mission never submitted → `error
{code: "unknown-mission"}`. Restoring rebuilds the evidence chain; the next
mission's receipt chains from the restored head.

### 3.4 `receipt` (host → agent) — verified verdict

```json
{
  "zap":"0.1","type":"receipt","id":"r-1","ts":"…","missionId":"demo-tdd",
  "verdict":"pass","exit":0,"chainDigest":"ab12…",
  "stepsExecuted":3,"stepsTotal":3,
  "checks":[{"name":"tdd-discipline","ok":true}],
  "at":"…"
}
```

Checks (in order): `mission-schema`, `budget`, `policy`, `steps-executed`,
`tdd-discipline`, `evidence-chain`. `verdict: "pass"` iff every check is
`ok`. `chainDigest` = head of the evidence chain (§5). **Receipt
verification**: the client recomputes the chain from the `evidence` packets
it received and compares — a receipt whose digest disagrees with the
received evidence is tampered.

### 3.5 `error` (host → agent) — structural rejection

```json
{"zap":"0.1","type":"error","id":"x-1","ts":"…","code":"schema",
 "message":"mission rejected: 3 schema violations",
 "inReplyTo":"m-9",
 "details":["steps[0].phase: must be one of red|green|refactor|verify",
            "budget.maxSteps: must be an integer >= 1"]}
```

| `code` | Meaning |
|--------|---------|
| `schema` | message failed structural validation (details carry JSON paths) |
| `version` | `zap` field is not a version the host speaks |
| `direction` | host→agent-only type sent inbound (`evidence`, `receipt`, `saved`, `restored`, `error`) |
| `budget` | step count would exceed the session budget (rejected BEFORE execution) |
| `policy` | command executable not in the session allowlist (rejected BEFORE execution) |
| `unknown-mission` | checkpoint for a mission that was never submitted |
| `bad-checkpoint` | restore of an unknown `stateId` |
| `internal` | unexpected host fault (never hides a schema problem) |

## 4. Session rules (v0.1 — deliberately strict)

1. **Budget**: fixed by the FIRST mission's `budget.maxSteps`; cumulative
   executed steps across all missions of the session may not exceed it; a
   later mission with a larger `maxSteps` is rejected (`budget`) —
   self-escalation is impossible.
2. **Policy**: fixed by the FIRST mission's `policy`; later missions must
   repeat it exactly (drift rejected with `policy`).
3. **Execution**: commands are tokenized on whitespace and run WITHOUT a
   shell (no interpolation, no pipes, no injection); the first token must
   be in the session allowlist.
4. **TDD discipline** (cumulative over the session's evidence):
   - every `red` evidence must have `exit != 0` (a passing red is a test
     that never failed — the loop is dishonest);
   - every `green`/`verify` evidence must have `exit == 0`;
   - at least one `red` must precede the first `green`;
   - violations do NOT block execution — they flip the receipt's verdict to
     `fail` with a `tdd-discipline` detail naming the rule.
5. **Receipts**: issued per mission, covering the session-cumulative chain.

## 5. Evidence chain (receipt verification)

Chain payload per evidence link (null-separated, like the #788/#828
cycle-log chain):

```
sha256( "v0.1" \0 missionId \0 stepId \0 phase \0 command \0 exit \0 digest \0 at \0 prevLink )
```

`link_0` chains from the literal `"genesis"`; `chainDigest` = the last
link. Any mutation of any certified fact (or reordering) changes the head —
which is exactly what the client recomputes and compares.

## 6. Session flow (the demo, verbatim)

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

## 7. Conformance

`zfa zap conform` self-tests this implementation: schema self-integrity,
golden positives, golden↔typed round-trips, the negative table (malformed
messages MUST be rejected with precise paths), a reference-client session
and a discipline-violation session. Exit `0`/`1`; `--format text|json`.

Third parties implement against the committed artifacts:
`specs/071-zuraffa-agent-protocol/schemas/*.schema.json` (draft-07) and
`golden/*.golden.json` — the same files the conformance suite enforces
against the code (drift-gated).
