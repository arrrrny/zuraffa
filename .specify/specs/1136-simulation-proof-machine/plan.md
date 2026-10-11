# Plan: 1136-simulation-proof-machine

- **Spec ID**: 1136-simulation-proof-machine
- **Created**: 2026-09-18

## Architecture

```
                    EPIC 5 — the proof machine
 ┌───────────────────────────────────────────────────────────────────┐
 │ spec.md ──plan──▶ plan.md ──gen──▶ red ──green──▶ realize         │
 │    │                │            │        │          │            │
 │    └── spec fuzz ────┴── receipts (proof.v1) ── zfa proof check    │
 │         (mutation receipt)        ▲                                 │
 │                                   │ world_hash re-derivation       │
 │  worlds: specs/<f>/tdd/worlds/<name>.world.json                    │
 │     └── zfa simulate run --world=<name> (recorded seed, digest)    │
 │  sessions: .zfa/mcp_sessions/<id>.json (calls[])                  │
 │     └── zfa mcp replay <id>  (stdio JSON-RPC re-execution)        │
 │  chaos: zfa sync simulate --scenario offline-flap|payment-decline │
 └───────────────────────────────────────────────────────────────────┘
```

## Lanes (ordered; one conventional commit each)

### Lane 1 — feat(968): `simulate run --world` + payment-failure world v3
- `SimulateRunCommand`: `--world <name>` option = positional-scenario alias + deterministic mode (recorded seed reuse + inline digest-match proof, the `--replay` semantics).
- Fixture: `specs/968-simulation-worlds/tdd/worlds/v3.world.json` — `PaymentGateway` touchpoint (`charge(payment) -> ChargeResult`, `refund(payment) -> RefundResult`); storms: `payment-declined` (declines over charge calls 1–2), `gateway-timeout` (HTTP 504 at charge call 3); behaviors: retry-sync charge (green), invoke charge (red — honest failure surface), invoke refund (green). Certify with `zfa simulate certify v3`.
- Tests: `--world` resolution equivalence, determinism proof (two runs → same digest), usage errors.

### Lane 2 — feat(967): spec-fuzz exit-criterion run (no code delta)
- Real run `zfa spec fuzz 004-login-ui` against the committed 13/13-green suite; record survived mutants as the proven spec weakness evidence. (Receipt integration lands in Lane 5.)

### Lane 3 — feat(1136): MCP session replay from McpSessionStore
- `McpSession`: persisted `calls` list (`{tool, arguments, expect_contains}`), back-compat fromJson.
- `McpSessionStore.appendCall(id, ...)` — get-or-create + append + save; `callsOf(id)`.
- v2 tool `session_record` in `handleV2ToolCall` (`{sessionId, tool, arguments, expect_contains}`) — the agent-side recording seam during live sessions.
- `zfa mcp replay <arg>`: file path → legacy scenario; else session id from the store; receipt gains `source`. Empty session calls → honest refusal.
- Tests: store round-trip, v2 tool handling, replay-from-session e2e.

### Lane 4 — feat(1136): chaos harness + payment-decline scenario
- Extract per-scenario scripted remotes from `SimulateSyncCapability` into a chaos-script seam; scenarios = `offline-flap | payment-decline`.
- `payment-decline`: first calls decline with `_PaymentDeclined` (domain error), then flap window, then recovery; drives the REAL strategy; green = zero loss + zero duplicates.
- Tests: new scenario e2e, unknown-scenario refusal unchanged.

### Lane 5 — feat(1136): proof receipt chain closes over simulation + fuzz
- `ReceiptRecord.raw` (parsed document passthrough) so typed extras survive `loadAll`.
- `SpecFuzzAuditor` writes `.zfa/receipts/spec-fuzz-<feature>.json` via `saveNamed` (files = spec-fuzz.json/md digests; extras = mutations/killed/survived/seed/budget/certified/gate).
- `ProofChecker`: `world_drift` finding kind — re-derive world hash from `specs/<feature>/tdd/worlds/<scenario>.world.json` for every `world-run-*` receipt; mismatch/missing manifest = drift.
- `zfa proof check` text output names the receipt kinds verified (entity/make/tdd/route/usecase/world/fuzz).
- Tests: fuzz receipt written + validated; world-hash tamper → drift; kinds summary.

## Verification (real runs, in-session)

1. Exit 1: `zfa simulate run --world=v3 --feature 968-simulation-worlds` twice → identical `run_digest`; receipt names world hash.
2. Exit 2: `zfa spec fuzz 004-login-ui` → ≥1 survived mutant with evidence.
3. Exit 3: `zfa proof check` → complete chain over the feature's receipts; drift demo = receipt mismatch.
4. `/speckit.tdd.verify` → `zfa tdd verify --feature 004-login-ui` → committed `specs/004-login-ui/tdd/verification.md` from THIS session's run.
5. `dart analyze` changed files; `dart test` changed-file tests; `dart format .` clean.

## Risks

- World cert gate: `v3` must be certified before run (certify step in-lane).
- Fuzz run duration: budget capped; not_assessed mutants are honest verdicts, not failures.
- mcp replay e2e needs `bin/mcp_server.dart` — tests scaffold it (existing B1–B7 pattern).
