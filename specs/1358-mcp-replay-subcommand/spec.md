**Template Version**: `zuraffa-1.0`

# Spec: 1358-mcp-replay-subcommand

GitHub issue: arrrrny/zuraffa#1358 (labels: verify-misfire, empty-implementation)
Epic: #1136 Phase A sub-issue 3 — MCP session replay ("re-executes agent
tool-call sequences as certified scenarios")

## Summary

`zfa mcp replay` does not exist — the registered subcommands are
`serve|list-tools` (+ the scaffold capability), and the invocation exits 2
with `Could not find a subcommand named "replay"`. The session store
(`.zfa/mcp_sessions/`) persists session STATE (subscriptions, pending
refactors), not tool-call sequences — there is nothing recorded to replay
and nothing to replay it WITH.

## Problem

An empty implementation gap: the epic's verb has no surface and no session
format. The minimal honest build is a scenario-KEYED replay: a committed
JSON scenario file IS the recorded session (diffable, reviewable), and
`zfa mcp replay` re-executes its tool-call sequence against the REAL
scaffolded MCP server over the stdio wire.

## Locked decisions

1. Contract: `zfa mcp replay <session-file>` where the file is
   `{"session": "<name>", "calls": [{"tool": "<name>", "arguments": {...},
   "expect_contains": "<optional substring>"}]}`. The file is the recorded
   session (agents record it by writing JSON; no recorder process is
   required for v1).
2. Execution: spawn the scaffolded `bin/mcp_server.dart` (the same binary
   `serve`/`list-tools` drive) on the stdio JSON-RPC wire — initialize,
   then one `tools/call` per entry, id-matched responses. No server →
   honest refusal naming `zfa mcp scaffold`.
3. Verdicts per call: `ok` (executed; `expect_contains` matched when
   given), `missing-tool` (JSON-RPC error -32602/not-found),
   `mismatch` (executed but expectation absent), `error` (any other
   failure). One line per call plus a summary
   `mcp-replay: session=<s> calls=N ok=M failed=K`.
4. Receipt: `.zfa/receipts/mcp-replay-<session>.json` carrying the
   scenario, per-call verdicts, and digests of outputs — a proof-carrying
   artifact (#807 family). Exit 0 iff failed == 0; missing/malformed
   scenario file is exit 2 (usage) / 1 respectively.
5. Registration joins the real `addSubcommand` family (`serve`,
   `list-tools`) — `zfa mcp` has no legacy flag surface to protect.

## Functional requirements

- **FR-1 (happy path)**: a scenario whose calls hit existing tools
  executes end-to-end: exit 0, per-call `ok` lines, the summary line, and
  the receipt on disk.
- **FR-2 (honest verdicts)**: a call to an unregistered tool is
  `missing-tool`; an unsatisfied `expect_contains` is `mismatch`; any
  other wire/execution failure is `error` — each fails the run (exit 1).
- **FR-3 (inputs)**: a missing scenario file exits 2 with the usage; a
  malformed scenario exits 1 naming the file; an unscaffolded project
  exits 1 with the `zfa mcp scaffold` hint (before any spawn).
- **FR-4 (integration)**: `zfa mcp --help` lists `replay`; `serve` and
  `list-tools` are unaffected.

## Acceptance scenarios (measurable)

1. **Given** a scaffolded project whose server registers an `echo` tool
   and a scenario with two `echo` calls (one with a matching
   `expect_contains`), **when** `zfa mcp replay <file>` runs, **then**
   exit 0, `mcp-replay: session=<name> calls=2 ok=2 failed=0`, and
   `.zfa/receipts/mcp-replay-<name>.json` exists.
2. **Given** a scenario with a call to a tool the server does not
   register, **when** replay runs, **then** exit 1 and the call line
   reads `missing-tool`.
3. **Given** a call whose `expect_contains` is absent from the tool's
   output, **when** replay runs, **then** exit 1 and the call line reads
   `mismatch`.
4. **Given** no `bin/mcp_server.dart`, **when** replay runs, **then**
   exit 1 naming the scaffold fix before spawning anything.
5. **Given** a missing scenario file path, **when** replay runs, **then**
   exit 2 with the usage line.
6. **Given** `zfa mcp --help`, **when** inspected, **then** `replay` is
   listed among the subcommands.

## Success criteria

- **SC-001**: The epic sub-issue-3 verb is wired: an agent can re-execute
  a committed tool-call sequence and get a verdict + receipt.
- **SC-002**: The mcp suites and the plugin registration tests stay green.

## Assumptions

- Scenario files are hand/agent-authored JSON (v1); a recording mode is a
  future extension and out of scope.
- `expect_contains` is the only assertion operator v1 needs.
