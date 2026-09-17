The Proof Receipts & Verification Gates system is zuraffa's **cryptographic provenance layer** — every generated artifact ships with a verifiable receipt, and every verification gate re-derives the proof against the live tree. The architecture is built on a single principle: **a claim without a re-derivable digest is not proof**.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     GENERATION LAYER                              │
│  entity create → make → build → mock create → tdd gen           │
│         │                                                         │
│         ▼                                                         │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │  ReceiptWriter   │    │  ReceiptWriter   │                   │
│  │  (proof.v1)      │    │  (test.v1)       │                   │
│  │  .zfa/receipts/  │    │  test-<entity>.json│                  │
│  └────────┬─────────┘    └────────┬─────────┘                   │
│           │                       │                              │
│           ▼                       ▼                              │
│  ┌──────────────────────────────────────────┐                    │
│  │         VERIFICATION ENGINES              │                    │
│  │  ┌────────────┐  ┌────────────────────┐  │                    │
│  │  │ProofChecker│  │ProofChainChecker   │  │                    │
│  │  │ (digests,  │  │ (6 chain checks)   │  │                    │
│  │  │  findings) │  │ proof-chain.v1     │  │                    │
│  │  └─────┬──────┘  └────────┬───────────┘  │                    │
│  │        │                  │               │                    │
│  │        └──────────────────┼───────────────┘                    │
│  │                           ▼                                    │
│  │  ┌────────────────────────────────────┐                      │
│  │  │        VERDICT ENVELOPE             │                      │
│  │  │    zuraffa.verdict.v1               │                      │
│  │  │    (canonical --json output)        │                      │
│  │  └────────────────────────────────────┘                      │
│  └──────────────────────────────────────────┘                    │
│                           │                                     │
│                           ▼                                     │
│  ┌──────────────────────────────────────────┐                    │
│  │              GATES (exit codes)            │                    │
│  │  proof check  → 0/1                          │                   │
│  │  proof chain  → 0/1/2                        │                   │
│  │  manifest --verify → 0/3                     │                   │
│  │  engine check → 0/1                          │                   │
│  └──────────────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

Sources: [lib/src/core/proof/proof_checker.dart](lib/src/core/proof/proof_checker.dart#L1-L520), [lib/src/core/proof/proof_chain_checker.dart](lib/src/core/proof/proof_chain_checker.dart#L1-L1109), [lib/src/core/project/receipt_store.dart](lib/src/core/project/receipt_store.dart#L1-L411)

## Receipt Schemas

zuraffa maintains **three distinct receipt document families**, each with its own schema and storage location:

| Schema | Document Kind | Storage Path | Producer | Purpose |
|--------|--------------|-------------|----------|---------|
| `proof.v1` | Generation receipt | `.zfa/receipts/<stamp>-<cmd>-<target>.json` | `ReceiptStore.save()` | Per-run artifact provenance |
| `test.v1` | Test receipt | `.zfa/receipts/test-<entity>.json` | `TestReceiptStore.write()` | Per-method test-to-usecase binding |
| `engine.gate.v1` | Gate refusal | `.zfa/engine.gate.<Entity>.refused.json` | `EngineGateReceipt.write()` | Cert-gate block with fix command |

**Additional specialized receipts** use the `proof.v1` envelope with stable filenames:

| Stable Name | Producer | Consumer |
|------------|----------|----------|
| `mock-<entity>.json` | `zfa mock create --certify` | Engine checker cert leg |
| `routes-<entity>.json` | `zfa route create` | Route verify reader |
| `routes-<entity>-verify.json` | `zfa route verify` | Proof chain checker |
| `provider-<entity>.json` | Provider plugin | Provider verify gate |
| `engine.receipt.json` | `zfa make engine` | Engine checker receipt leg |

Sources: [lib/src/core/project/receipt_store.dart](lib/src/core/project/receipt_store.dart#L200-L300), [lib/src/core/project/test_receipt.dart](lib/src/core/project/test_receipt.dart#L1-L192), [lib/src/engine/engine_gate_receipt.dart](lib/src/engine/engine_gate_receipt.dart#L1-L153)

## The GenerationReceipt Model

A `GenerationReceipt` is the foundational proof document. Every generation verb (`entity create`, `make`, `di create`, etc.) writes one. It binds:

- **Command identity** — `command`, `target`, `repro` (one-line reproduction)
- **Input context** — the flags, fields, and plugin ids consumed
- **Spec binding** — optional `GenerationReceiptSpec` with SHA-256 of the source spec
- **File bindings** — `GenerationReceiptFile[]` with path, action, SHA-256, bytes, and optional snapshot

The `GenerationReceiptFile` carries a **content snapshot** when the artifact is ≤ 16 KB (`ReceiptStore.maxSnapshotBytes`). This snapshot enables **precise line diffs** on drift instead of a bare digest mismatch. The `ProofChecker` uses an LCS (Longest Common Subsequence) diff algorithm bounded at 400 lines per side, with a 60-line output cap.

The `runHash` field (issue #996) binds the entity, methodset, and every per-file `(path, action, sha256)` tuple into a single re-derivable digest — agents can verify a whole run from the receipt alone.

Sources: [lib/src/core/project/receipt_store.dart](lib/src/core/project/receipt_store.dart#L1-L199), [lib/src/core/proof/proof_checker.dart](lib/src/core/proof/proof_checker.dart#L450-L520)

## ProofChecker: The Digest Engine

`ProofChecker.check()` is the core verification engine behind `zfa proof check`. It walks every receipt and re-derives every digest against the live tree. It produces a `ProofReport` (schema `proof.v1`) with zero or more `ProofFinding` objects.

### Finding Categories

| Kind | Severity | Condition | Exit Code |
|------|----------|-----------|-----------|
| `modified` | drift | Receipted artifact bytes ≠ recorded SHA-256 | 1 |
| `deleted` | drift | Receipted artifact missing from disk | 1 |
| `stale_spec` | drift | Spec consumed by generation has changed | 1 |
| `stale_usecase` | drift | Usecase source changed after test generation | 1 |
| `unprovenanced` | drift | File under audited coverage root has no receipt | 1 |
| `manifest_drift` | drift | Repository contract manifest method-table hash mismatch | 1 |
| `manifest_corrupt` | drift | Repository contract manifest unreadable | 1 |

### Key Behaviors

**Latest-wins semantics**: When multiple receipts cover the same artifact path, the most recent (by timestamp, ties broken by filename) supersedes older proofs. Regeneration replaces — the history is append-only but the check is point-wise.

**Tombstone handling** (issue #1429): A receipt entry with `action: 'delete'` represents a sanctioned removal. When the artifact is missing *and* the latest receipt entry is a deletion, no `deleted` finding fires — this is provenance, not drift. Recreating the artifact still lands in the digest check.

**Sanctioned append** (issue #1327): Append-only logs (`cycle-log.md`) whose receipt carries a snapshot and whose current disk bytes still start with exactly those bytes pass the check. The receipted prefix is untouched — appends are the sanctioned evolution class. Without a snapshot, there is nothing to pin the prefix against.

**Coverage roots**: When `coverageRoots` are passed (e.g. `zfa proof check lib/src`), every file under those roots must be covered by a receipt or the check fails with `unprovenanced` findings. This is the CI gate for generated-code paths — it answers "does every file under `lib/src` have a provenance receipt?"

Sources: [lib/src/core/proof/proof_checker.dart](lib/src/core/proof/proof_checker.dart#L80-L200), [lib/src/core/proof/proof_checker.dart](lib/src/core/proof/proof_checker.dart#L260-L400)

## ProofChainChecker: The End-to-End Chain

`ProofChainChecker` (issue #1148, VISION-4, EPIC 5) is the **six-check auditor** that validates the entire proof chain in one command: `zfa proof chain`.

### The Six Chain Checks

```
spec → plan → behaviors → gen → verify-red → make → receipt → realize → world
   │        │         │           │            │          │         │
   │        │         │           │            │          │         └─ Check 6: xray_coverage
   │        │         │           │            │          └─────── Check 5: usecase_verify
   │        │         │           │            └────────── Check 4: route_verify
   │        │         │           └───────────── Check 3: test_integrity (+runtime)
   │        │         └──────────────── Check 2: behavior_coverage
   │        └─────────────────────────── Check 1: receipt_digest
   └────────────────────────────────────── (deep findings from ProofChecker)
```

| # | Check Kind | What It Validates | Severity When Failing |
|---|-----------|-------------------|----------------------|
| 1 | `receipt_digest` | Every receipted artifact's SHA-256 matches disk | **drift** (exit 1) |
| 2 | `behavior_coverage` | Every spec behavior has green cycle-log evidence | **gap** (reported, not failed) |
| 3 | `test_integrity` | Generated test files exist and imports resolve | **drift** |
| 4 | `route_verify` | Declared route tables have passing verify verdicts | **gap** / **info** |
| 5 | `usecase_verify` | Usecase entities pass the conformance gate | **drift** / **gap** |
| 6 | `xray_coverage` | Xray coverage kinds are traced | **gap** |

### Severity Semantics

The chain checker uses a three-tier severity model that is **fundamentally different** from the simple proof check:

- **`drift`** — Something that EXISTS contradicts its proof. A receipted artifact whose digest no longer matches, green evidence naming a deleted test, a failed route verify verdict. **Drift exits 1.**
- **`gap`** — A link of the chain that does not exist YET. A behavior without green evidence, a route table never verified, an untraced coverage kind. **Gaps are reported, never silently green — and never exit-failing.**
- **`info`** — Advisory context. Runtime not exercised without `--run-tests`, a route verify explicitly skipped with a reason.

This design enforces a critical principle: **missing proof is honest disclosure, not failure**. A project with no receipts gets a vacuous green (exit 0) — the absence of proof is reported, not assumed.

### Exit Codes (SPEC 917)

| Code | Meaning | Condition |
|------|---------|-----------|
| 0 | intact | No drift, no infra errors (gaps are OK) |
| 1 | drift | At least one drift finding |
| 2 | infra | Stores unreadable (`.zfa/receipts` is a file, not a directory) |

Sources: [lib/src/core/proof/proof_chain_checker.dart](lib/src/core/proof/proof_chain_checker.dart#L80-L200), [lib/src/core/proof/proof_chain_checker.dart](lib/src/core/proof/proof_chain_checker.dart#L400-L800)

## The Proof Chain Report

The `ProofChainReport` (schema `proof-chain.v1`) is the machine-verifiable verdict. Every item carries:

```
{
  "check": "receipt_digest",        // which of the 6 checks
  "category": "receipt_digest",     // stable machine category
  "severity": "drift|gap|info",     // the severity tier
  "file": "lib/src/...",            // project-relative POSIX path
  "expected": "sha256 abc123...",   // what the chain expects
  "actual": "sha256 def456...",     // what the tree actually holds
  "fix": "zfa entity create Product" // one pasteable command
}
```

The report exposes aggregate counts per check kind, plus `driftCount`, `gapCount`, `infoCount`, and `infraErrors`. The `ok` getter is `infraErrors.isEmpty && driftCount == 0` — gaps do NOT fail.

Sources: [lib/src/core/proof/proof_chain_checker.dart](lib/src/core/proof/proof_chain_checker.dart#L100-L200)

## Test Receipts (test.v1)

The `TestReceipt` (schema `test.v1`, spec 980 / FR-003) is the test plugin's proof record. It maps every generated test to:

- The **usecase method** it exercises (`get`, `create`, `execute`, …)
- The **acceptance path** (`success` or `failure`)
- The **SHA-256 digest** of the test file
- The **usecase source path and digest** it was generated against

The `ProofChecker` uses test receipts for two checks:

1. **Test file integrity** — re-derives the test file's digest
2. **Usecase/test drift** — detects when the usecase source changed after the tests were generated against it

The `ProofChainChecker` additionally checks that test files exist on disk and that all imports resolve.

Sources: [lib/src/core/project/test_receipt.dart](lib/src/core/project/test_receipt.dart#L1-L192), [lib/src/core/proof/proof_checker.dart](lib/src/core/proof/proof_checker.dart#L350-L440)

## Specialized Receipts

### Engine Gate Receipt (`engine.gate.v1`)

When the cert-gate blocks — a CORE entity referenced by the engine tree is uncertified, unsatisfied, corrupt, or stale — the block writes a machine-readable refusal receipt carrying the entity, the reason, and the **exact fix command** (`zfa mock create <Entity> --certify`). Two homes:

- `zfa engine check <Entity>` → `.zfa/engine.gate.<Entity>.refused.json`
- `zfa tdd run-engine <feature>` → `specs/<feature>/tdd/engine.gate.<Entity>.refused.json`

Sources: [lib/src/engine/engine_gate_receipt.dart](lib/src/engine/engine_gate_receipt.dart#L1-L153)

### Engine Receipt (`engine.v1` / `engine.receipt.v2`)

Every `zfa make engine <Entity>` run writes `.zfa/engine.receipt.json` recording the entity digest, methods generated, per-method mock certification, DI wiring, engine check outcome, and generated file paths. The v2 receipt (`specs/<feature>/tdd/engine.receipt.json`) is the cross-pipeline contract that the CERT-GATE reads.

Sources: [lib/src/engine/engine_receipt_writer.dart](lib/src/engine/engine_receipt_writer.dart#L1-L316)

### Mock Cert Receipt (`mock-cert.<Entity>.json`)

The per-method proof that a Tier-1 mock satisfies its interface, plus the SHA-256 digest of the contract test that proved it. Written by `zfa mock create <Entity> --certify`.

Sources: [lib/src/plugins/mock/certification/mock_cert_receipt.dart](lib/src/plugins/mock/certification/mock_cert_receipt.dart#L1-L167)

## Cycle Evidence

`CycleEvidence` parses `tdd/cycle-log.md` for red/green/refactor evidence per behavior. A behavior has red evidence when a `## `-delimited section carries both `- behavior: <id>` and `- kind: red` (and green evidence for `- kind: green`). The evidence chain links red-hash → green-hash → refactor-hash per behavior.

The chain checker uses green evidence for behavior coverage, and additionally detects **evidence-without-artifact** (issue #1264): green evidence whose test file is missing from disk is drift, not a valid green.

Sources: [lib/src/plugins/tdd/services/cycle_evidence.dart](lib/src/plugins/tdd/services/cycle_evidence.dart#L1-L347)

## CLI Commands

### `zfa proof check`

Verifies every receipt in `.zfa/receipts/` against the current tree.

```
zfa proof check                    # text verdict, exit 0/1
zfa proof check --format=json      # proof.v1 JSON envelope
zfa proof check lib/src            # audit coverage root
```

When coverage roots are passed, every file under those roots must be covered by a receipt or the check fails with `unprovenanced` findings.

### `zfa proof chain`

Validates the whole proof chain end-to-end.

```
zfa proof chain                    # text verdict, exit 0/1/2
zfa proof chain --json             # proof-chain.v1 JSON envelope
zfa proof chain --run-tests        # execute registered test files
```

### `zfa proof prune`

Deletes receipts whose every artifact is missing (dead sandbox / interrupted-run receipts). Dry run by default; `--apply` deletes. Partial receipts (some artifacts missing) are kept — they may be hand-repairable.

Sources: [lib/src/commands/proof_command.dart](lib/src/commands/proof_command.dart#L1-L388)

## Verdict Envelope

Every `--json` verify-gate command emits the canonical `zuraffa.verdict.v1` envelope as its **last stdout line**. The envelope provides a uniform surface:

```jsonc
{
  "schema": "zuraffa.verdict.v1",
  "command": "zfa <verb> [args]",
  "verdict": "pass|fail|skip|error|stopped",
  "exit_class": 0|1|2|3|4|64,
  "subject": { "kind": "route|state|usecase|cache|mock|entity|...", "id": "<Entity>" },
  "artifacts": { "created": [...], "modified": [...], "deleted": [...] },
  "receipts": [".zfa/receipts/..."],
  "findings": [{ "kind": "...", "fix": "zfa ...", "file": "...", "member": "...", "extras": ... }],
  "drifts": ["..."],
  "details": { ... },
  "timestamp": "2026-09-05T12:00:00.000Z"
}
```

The `details` map is the only plugin-specific surface; everything else is uniform across emitters. `VerdictEnvelope.fromJson` throws `VerdictSchemaException` the moment `schema` is anything but `zuraffa.verdict.v1` — old envelopes break loudly, never silently re-interpreted.

Sources: [lib/src/core/verdict_envelope.dart](lib/src/core/verdict_envelope.dart#L1-L598)

## Verification Gate Inventory

Every verify-gate command in the codebase must ship `--json` (SPEC 1106). The known gates:

| Command | Subject Kind | Schema |
|---------|-------------|--------|
| `zfa proof check` | entity | `proof.v1` |
| `zfa proof chain` | feature | `proof-chain.v1` |
| `zfa di verify` | di | `zuraffa.verdict.v1` |
| `zfa datasource check` | datasource | `zuraffa.verdict.v1` |
| `zfa route verify` | route | `zuraffa.verdict.v1` |
| `zfa cache verify` | cache | `zuraffa.verdict.v1` |
| `zfa provider verify` | provider | `zuraffa.verdict.v1` |
| `zfa verify` | generic | `zuraffa.verdict.v1` |
| `zfa verify-red` | behavior | `zuraffa.verdict.v1` |
| `zfa manifest --verify` | manifest | `manifest-verify.v1` |

Sources: [test/commands/verify_gate_json_sweep_test.dart](test/commands/verify_gate_json_sweep_test.dart#L1-L156)

## Next Steps

- **[CLI Commands & Subcommands](6-cli-commands-and-subcommands)** — explore the full command surface including `zfa proof`, `zfa mock create --certify`, `zfa route verify`, and `zfa manifest --verify`
- **[Code Generation Engine & Proof Receipts](9-code-generation-engine-and-proof-receipts)** — understand how receipts are written during generation
- **[TDD Cycle & Spec-Driven Development](13-tdd-cycle-and-spec-driven-development)** — see how cycle-log evidence integrates with the proof chain
- **[Testing Infrastructure & Test Organization](14-testing-infrastructure-and-test-organization)** — explore the test receipt system and contract tests
- **[Error Handling & Exit Code Protocol](22-error-handling-and-exit-code-protocol)** — understand the full SPEC 917 exit code taxonomy