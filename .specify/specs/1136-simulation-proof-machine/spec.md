# 1136-simulation-proof-machine

- **Spec ID**: 1136-simulation-proof-machine
- **Created**: 2026-09-18
- **Source**: GitHub issue #1136 (EPIC 5 — priority high)
- **Type**: epic
- **Priority**: P1

## Problem

Features must be developed against certified simulated reality — not raw mocks — and every TDD cycle must be reproducible into *proof*. The sub-issues landed most of the machinery (simulation worlds #968/#1146, spec-mutation arena #967/#1147, MCP replay #1358, sync chaos #1359, proof chain #1148), but four gaps keep the epic from closing:

1. **No `--world` selector on `simulate run`.** The exit criterion names `zfa simulate run --world=v3`; today the scenario is positional-only and deterministic replay is a separate verb. A payment-failure world fixture does not exist either.
2. **`zfa mcp replay` reads scenario files, not sessions.** `McpSessionStore` persists session *state* but no tool-call sequence; the epic requires replaying an agent session recorded through the store.
3. **Chaos has exactly one hardcoded scenario.** `zfa sync simulate` knows only `offline-flap`; the scripted failing remote is inline, not a pluggable chaos script, so payment-decline classes cannot enter the harness.
4. **The proof chain has no typed simulation/fuzz checks.** Spec-fuzz rounds write no receipt at all, and world-run receipts' `world_hash` is never independently re-derived — drift between a receipt and the world manifest it names goes undetected.

## Goal

Close EPIC 5 by closing those four gaps and re-verifying all three exit criteria with real runs:

- `zfa simulate run --world=<name>` selects a world by name and executes it deterministically (recorded seed, digest-match proof); a committed payment-failure world `v3` demonstrates it.
- `zfa mcp replay <session>` resolves a session id from `McpSessionStore` (calls recorded via the `session_record` v2 tool) and re-executes it against the scaffolded server.
- `zfa sync simulate --scenario payment-decline` drives the real sync strategy through transient card declines on a scripted remote, alongside `offline-flap`.
- `zfa spec fuzz <feature>` writes a proof.v1 receipt; `zfa proof check` re-derives every world-run receipt's `world_hash` from the committed manifest and reports mismatch as drift.

## Command contracts

### `zfa simulate run --world=<name> [--feature <f>]` (Lane 1)
1. `--world` names the world manifest (`specs/<feature>/tdd/worlds/<name>.world.json`) — same resolution as the positional scenario.
2. Deterministic by construction: if a prior green receipt exists, the recorded seed is reused and the run digest must match (replay proof inline); otherwise the manifest seed is used and recorded.
3. Exit criterion: payment-failure flow (world `v3`) → receipt names `world-hash`; two consecutive `--world=v3` runs prove the same `run_digest`.

### `zfa mcp replay <session-id-or-file>` (Lane 3)
1. Argument resolution: an existing file path behaves exactly as today (back-compat); otherwise the id is looked up in `.zfa/mcp_sessions/<id>.json`.
2. `McpSessionStore.appendCall(id, {tool, arguments, expect_contains})` persists the agent tool-call sequence; the v2 tool `session_record` records calls during live sessions.
3. Re-execution against the real scaffolded server over stdio JSON-RPC; verdict per call; proof-carrying receipt gains `source: session-store|scenario-file`.

### `zfa sync simulate --scenario payment-decline` (Lane 4)
1. Scripted failing remote: first N create calls decline with a payment-domain error, then a flap window, then recovery — driving the REAL `PushOnlySyncStrategy`.
2. Green = zero loss + zero duplicates across the per-key ledger (same bar as `offline-flap`).

### Proof receipts (Lane 5)
1. `zfa spec fuzz` writes `.zfa/receipts/spec-fuzz-<feature>.json` (proof.v1, files = the committed spec-fuzz reports, extras = mutations/killed/survived/seed/budget/certified).
2. `ProofChecker` re-derives `world_hash` for every `world-run-*` receipt from the named world manifest; mismatch or missing manifest → `world_drift` finding.
3. `ReceiptRecord` carries the raw document so typed extras survive `loadAll`.

## Success criteria (the epic's exit criteria — all must pass with real runs)

1. A payment-failure flow developed against a world manifest; the receipt names the world hash; `zfa simulate run --world=v3` is deterministic (two runs, same digest).
2. `zfa spec fuzz 004-login-ui` finds at least one survived mutant (absence of `--json` on a route = spec weakness class).
3. `zfa proof check` on a fully-built feature shows a complete receipt chain: spec → plan → gen → verify-red → green → realize → receipt, and detects drift as receipt mismatch.

## Hard constraints

- Do NOT change existing `zfa tdd run` semantics.
- Sub-issues implemented as ordered lanes; one conventional commit per lane (`feat(968):`, `feat(967):`, `feat(1136):`).
- Real verification only: exit criteria and `/speckit.tdd.verify` audit run in-session; `tdd/verification.md` produced from the real `zfa tdd verify` run — never copied or back-dated.

## References

- #1136 (epic), #968/#1146 (simulation worlds), #967/#1147 (spec-mutation arena), #1358 (mcp replay), #1359 (sync simulate chaos), #1148 (proof chain), #807 (proof-carrying receipts)

## Out of scope

- OCR/payment production adapters (the chaos *harness* extension only)
- Flutter-side worlds (Dart-only lanes)
- Any change to `tdd run`'s loop semantics
