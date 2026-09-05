---
feature: 076-corpus-walk
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: 2026-09-05
updated_at: 2026-09-05
suite_baseline: red (+0/-43, commands absent)
---

# Test List: 076-corpus-walk

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`. All drive the real CLI entry
point (`CliRunner.runCapturing`) against a temp driven-app fixture
(`test/commands/helpers/corpus_walk_fixture.dart`); the per-feature
steps are the fixture's scripted fake zfa binary (the repo's canonical
fake-zfa pattern — the spec 049/051 spawn contract).

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| A1  | the corpus family lists catalog/run/ledger alongside import | US1 | example | PASS | `test/commands/corpus_catalog_command_test.dart::A1` |
| A2  | catalog exposes --target/--source/--reclassify/--project | US1 | example | PASS | `corpus_catalog_command_test.dart::A1` |
| A3  | catalog without --target is a usage error (exit 2) | US1 | example | PASS | `corpus_catalog_command_test.dart::A1` |
| A4  | an engine spec classifies CORE, a presentation spec SKIN | US1.AC1 | example | PASS | `corpus_catalog_command_test.dart::A2` |
| A5  | the machine summary line counts core/skin and reports ok | US1.AC1 | example | PASS | `corpus_catalog_command_test.dart::A2` |
| A6  | a neutral spec falls back to CORE (engine-first default) | US1.AC1 | example | PASS | `corpus_catalog_command_test.dart::A2` |
| A7  | the committed catalog file records name/classification/sha256/readiness | US1.AC1 | example | PASS | `corpus_catalog_command_test.dart::A3` |
| A8  | not-ready features are cataloged with their reason | US1.AC1 | example | PASS | `corpus_catalog_command_test.dart::A3` |
| A9  | regeneration is deterministic (byte-identical except timestamps) | US1.AC1 | example | PASS | `corpus_catalog_command_test.dart::A3` |
| A10 | no manifest and no --source stops with import guidance (exit 2) | US1.AC3 | example | PASS | `corpus_catalog_command_test.dart::A4` |
| A11 | --source walks the source corpus directly (no manifest needed) | US1.AC1 | example | PASS | `corpus_catalog_command_test.dart::A4` |
| A12 | regeneration keeps a committed CORE->SKIN edit (same spec hash); --reclassify recomputes | US1.AC2 | example | PASS | `corpus_catalog_command_test.dart::A5` |
| A13 | a manifest feature whose spec.md is missing stops with recovery guidance (exit 2) | US1.AC4 | example | PASS | `corpus_catalog_command_test.dart::A6` |
| A14 | run exposes --target/--budget/--project/--zfa-bin | US2 | example | PASS | `corpus_run_walk_command_test.dart::A1` |
| A15 | run without --target / without a catalog / with an invalid budget stops at exit 2 with guidance | US2.AC4/AC5 | example | PASS | `corpus_run_walk_command_test.dart::A1` |
| A16 | every feature gets run-then-verify, in catalog order | US2.AC1 | example | PASS | `corpus_run_walk_command_test.dart::A2` |
| A17 | the walk continues past a failing feature (no stop-on-roadblock) | US2.AC1 | example | PASS | `corpus_run_walk_command_test.dart::A2` |
| A18 | a completing run + passing gate is green | US2.AC1 | example | PASS | `corpus_run_walk_command_test.dart::A3` |
| A19 | a completing run + failing gate is partial (gate named) | US2.AC1 | example | PASS | `corpus_run_walk_command_test.dart::A3` |
| A20 | a failed run is blocked (outcome named) | US2.AC1 | example | PASS | `corpus_run_walk_command_test.dart::A3` |
| A21 | a not-ready feature is blocked without being spawned | US2.AC3 | example | PASS | `corpus_run_walk_command_test.dart::A3` |
| A22 | within budget (M+K <= budget) exits 0 with result=ok | US2.AC1 | example | PASS | `corpus_run_walk_command_test.dart::A4` |
| A23 | over budget (M+K > budget) exits 1 with result=over-budget, breach named | US2.AC2 | example | PASS | `corpus_run_walk_command_test.dart::A4` |
| A24 | the default budget is 5 (epic exit criterion: M+K <= 5) | US2 | example | PASS | `corpus_run_walk_command_test.dart::A4` |
| A25 | the walk results land in .zfa/corpus/walks/<target>.json | US2 | example | PASS | `corpus_run_walk_command_test.dart::A5` |
| A26 | an empty catalog stops with exit 2 (a walk of nothing is a misfire) | US2 | example | PASS | `corpus_run_walk_command_test.dart::A6` |
| A27 | ledger exposes --target/--project/--zfa-bin | US3 | example | PASS | `corpus_ledger_command_test.dart::A1` |
| A28 | ledger without --target / without a catalog stops with guidance (exit 2) | US3 | example | PASS | `corpus_ledger_command_test.dart::A1` |
| A29 | the first ledger run writes the baseline and exits 0 | US3.AC1 | example | PASS | `corpus_ledger_command_test.dart::A2` |
| A30 | an unchanged walk diffs clean (exit 0, result=clean, machine summary exact) | US3.AC2 | example | PASS | `corpus_ledger_command_test.dart::A3` |
| A31 | a spec change that stays green renews the hash (exit 0) | US3.AC4 | example | PASS | `corpus_ledger_command_test.dart::A3` |
| A32 | a green contract regressing to partial is a contract-break (exit 1) | US3.AC3 | example | PASS | `corpus_ledger_command_test.dart::A4` |
| A33 | a green contract regressing to blocked is a contract-break (exit 1) | US3.AC3 | example | PASS | `corpus_ledger_command_test.dart::A4` |
| A34 | a removed green feature is a contract-break (exit 1) | US3.AC5 | example | PASS | `corpus_ledger_command_test.dart::A4` |
| A35 | a new feature breaking an existing contract fails CI (regression + addition reported, exit 1) | US3.AC3 | example | PASS | `corpus_ledger_command_test.dart::A4` |
| A36 | a new green feature is an addition (exit 0, recorded in the ledger) | US3 | example | PASS | `corpus_ledger_command_test.dart::A5` |
| A37 | a new non-green feature is an addition (reported, exit 0 — the budget governs new gaps) | US3 | example | PASS | `corpus_ledger_command_test.dart::A5` |
| A38 | a corrupt ledger JSON stops with recovery guidance (exit 2) | US3.AC6 | example | PASS | `corpus_ledger_command_test.dart::A6` |

## Inner loop: unit behaviors

One per functional requirement in `spec.md` (the classifier and budget
parser carry direct unit coverage inside the command tests; every
misfire class is asserted by its exit code and `--> fix:` hint).

| id  | behavior | traces | kind | state | test |
|-----|----------|--------|------|-------|------|
| U1  | The classifier scores skin signals vs core signals over name + spec (ties CORE) | FR-001 | example | PASS | A4/A6 |
| U2  | The catalog preserves committed manual classifications for unchanged hashes unless --reclassify | FR-002 | example | PASS | A12 |
| U3  | The walker drives every feature through tdd run + tdd verify and never stops at a failure | FR-003 | example | PASS | A16/A17 |
| U4  | The budget gate exits 0 iff partial+blocked <= budget, else 1 with the non-green named | FR-004 | example | PASS | A22/A23 |
| U5  | Not-ready features are blocked and never spawned | FR-005 | example | PASS | A21 |
| U6  | Walk results persist with verdict/gate/outcome/walk-time sha256 | FR-006 | example | PASS | A25 |
| U7  | The ledger baseline commits verdict+sha256+classification | FR-007 | example | PASS | A29 |
| U8  | The diff detects regressions (exit 1) and leaves the committed ledger untouched on a break | FR-008 | example | PASS | A32-A35 |
| U9  | Every misfire stops at exit 2 with a --> fix: hint | FR-009 | example | PASS | A10/A13/A15/A26/A28/A38 |

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| `zfa tdd run` / `zfa tdd verify` (spawned) | subprocess | spec 049/051 machine summary lines (`run: feature=… result=…`, `mutation: gate=…`) | P1 (the fixture's fake zfa binary) |

## Routing provenance

Per-behavior routing decisions: every behavior routes through the real
CLI entry point (`CliRunner.runCapturing`) — the command surface is the
contract; the per-feature spawns are the scripted fake zfa binary
(declared: the spec 049/051 spawn contract, `--zfa-bin`).

route: A1-A13 -> catalog command lane [declared: spec.md US1]
route: A14-A26 -> run command lane [declared: spec.md US2]
route: A27-A38 -> ledger command lane [declared: spec.md US3]
