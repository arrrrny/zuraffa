# TDD Verification: 1653-trim-heavy-deps (#1661)

- **Feature**: `specs/1653-trim-heavy-deps`
- **Date**: 2026-09-15
- **Mode**: LLM-guided fallback audit (`ZFA_MISSING` — the zuraffa repo
  cannot drive `zfa tdd verify` on its own development; the #1632/#1651
  precedents)
- **Verdict**: **PASS_WITH_GAPS**

## Audit dimensions

### 1. Test-first evidence

- The pin suites were written and proven RED before the fix landed
  (`tdd/cycle-log.md` red cycle): manifest pins failed with the four
  heavy packages present, the plugin-gate pins failed against the
  pre-existing generation-plugin-only command (capturing its real
  output `Enabled plugin: graphql`), and the trace-seam suite was a
  missing-API compile red.
- The audit's mutation pass then caught a WEAK PIN: the manifest
  block-capture regex never matched the real pubspec (lazy/lookahead
  interaction), so the first U1 green was vacuous. The regex was
  rewritten (`dotAll` + multiline inner anchor) and the pin re-proven
  red (mutant: reintroduce `graphql` → the U1 graphql test FAILS) and
  green (clean manifest → pass). The vacuity class this repo's own
  tooling polices was caught here by the audit — recorded as evidence
  the audit works, and as a lesson (mutation-check every content pin).

### 2. Mutation results (targeted)

| Mutant | Result |
| ------ | ------ |
| `PluginGate.refusalFor` short-circuits to `null` (gate disabled) | **killed** — U6 refusal tests fail |
| `graphql: ^5.2.4` reintroduced into root `pubspec.yaml` | **killed** (after the pin-regex repair) — U1 graphql test fails |
| restore | all pins + family green |

### 3. Test smells — none found

- Hermetic temp-dir fixtures; no sleeps; no order dependence.
- Refusals assert exact guidance text (single-source catalog wording).
- Tier discipline: companions carry their own suites; the core pins are
  fast-lane (the permanent regression guard for SC-001/SC-002).

### 4. Acceptance-criteria coverage

- A1 (fresh consumer): lockfile has 0 of graphql/gql/minio/opentelemetry,
  no protobuf/xml; only core's own direct deps remain. `dart analyze lib`
  0 errors.
- A2 (seamless enabled): observability init pins the
  TraceObserver→OtelTracer wiring; the graphql generation surface is
  exercised by the companion's moved golden suites (47 tests).
- A3 (honest disabled): gate unit pins + the `zfa graphql` command entry
  wired to `PluginGate.refusalFor` before any generation.
- A4 (companion health): all three companions `dart analyze` 0 errors
  and `dart test` green (47 / 14+1 skip / 19).

### 5. Regression state

- Root affected lanes: `test/plugins/tdd/commands` +541;
  `test/commands` + `test/graphql` + `test/simulation` +734;
  `test/core` pins + plugin_gate +22. A full background lane pass
  reached +3297 before the machine's kernel cache filled the disk
  (`No space left on device` — the documented AGENTS.md hazard); the 6
  apparent failures were cache load errors, re-verified green after
  cleanup.

## Gaps (why not plain PASS)

1. **Delegation depth**: `zfa graphql generate`'s heavy implementation
   moves to the companion, but the core-side gate currently refuses when
   the capability is enabled-but-the-companion-missing and the
   companion's API/CLI is invoked directly by the user; the
   automatic spawn-through-delegation (core stub → companion binary) is
   seam-designed (contracts/plugin-gate.md) but not yet
   process-tested end-to-end.
2. **Lane run shape**: the default lane was verified in chunks (disk
   hazard), not as one `dart test test` invocation.
3. **Runtime otel family**: `SimulationWorld` otel fixtures now require
   injecting the companion's capture; the legacy no-injection path
   skips the family honestly (pinned).

## Verdict

**PASS_WITH_GAPS** — all behaviors green with red-first evidence, no
smells, mutations killed, acceptance criteria met; the named gaps are
follow-ups, not correctness holes.
