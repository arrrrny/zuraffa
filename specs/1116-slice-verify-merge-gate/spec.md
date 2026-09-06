# Spec 1116 — [SLICE] zfa slice verify: one receipt, five sub-receipts, the merge gate

Issue: https://github.com/arrrrny/zuraffa/issues/1116
Branch: `spec/1116-slice-verify-merge-gate`
Parent: #1012 (ENGINE-SKIN-SPLIT) — depends on #1109 (engine v2), #1110
(cert-gate), #1113 (unified journal), #1114 (slice compose), #1115 (xray).

## Problem

The engine-receipt is a per-entity artifact (`engine.receipt.json` v2,
#1109) and the journal is a per-feature artifact (`journal.json`,
#1113) — but nothing aggregated them per SLICE. A feature could not be
verified as a single unit: engine cert-gate + skin contract + slice
boundary + journal verdicts never referenced one slice id, and there
was no merge gate for the slice worktree.

## What was built

1. **`slice.receipt.json`** (`.zfa/slices/<feature-id>/slice.receipt.json`,
   schema `slice.receipt.v1`) — the slice-level aggregation with the
   issue's exact field names:

   ```json
   {
     "schema": "slice.receipt.v1",
     "feature_id": "004-login-ui",
     "generated_at": "...",
     "verdict": "green",
     "engine": {"status": "green", "n_methods": 5, "n_mocks_certified": 5},
     "skin":   {"status": "green", "n_routes": 2, "n_contract_rows": 6, "n_platforms_audited": 4},
     "cert":   {"status": "green", "uncertified_entities": [], "differential_passed": true},
     "xray":   {"status": "green", "layers": {"engine": 12, "skin": 4, "shared": 0}, "violations": []},
     "journal": {"status": "green", "cycles": 2, "violations": 0, "final_state": "green"},
     "rerun": {}
   }
   ```

   Section status vocabulary: `pending` (compose skeleton — the lane
   has not run), `green`, `red`. The whole `verdict` is `green` only
   when every section is green.

2. **`zfa slice verify <feature-id>`** — one command, full audit. For a
   FEATURE slice (`.zfa/slices/<id>/slice.yaml`) it aggregates the five
   sub-receipts, writes `slice.receipt.json` (atomically) and prints a
   one-line status; exit 0 only on green. Every red section names its
   violator and the EXACT re-run command (`zfa engine check <Entity>`,
   `zfa tdd run-skin <id>`, `zfa mock certify <Entity>`,
   `zfa slice check <id>`, `zfa tdd run <id>`). A cut slice keeps the
   #961 import check — the dispatch is by slice kind.

   Sub-receipt sources (tolerant of the specs/ mount the worktree
   lanes write to):
   - engine: `engine/engine.receipt.json` (v2, #1109) or
     `specs/<id>/tdd/engine.receipt.json`;
   - cert: `engine/mock-cert/mock-cert.<E>.json` (#1001/#1110), deduped
     by entity across the slice layout, the specs mount and the
     `test/mock/` convention; `differential_passed` = no cert's sandbox
     reported `tests_failed > 0`;
   - skin: `skin/skin.receipt.json` (skin.v1) or
     `specs/<id>/tdd/04-skin-receipt.json`; green = every behavior
     conformed; `n_contract_rows` = `contract_rows_audited`;
     `n_platforms_audited` = `platform_slot_fills`;
   - xray: the slice boundary audit (#1114 check, #1115 layers) —
     manifest layer counts `{engine, skin, shared}` plus the compliance
     violations;
   - journal: `journal.json` (#1113) at the slice root or the specs
     mount — `{cycles, violations, final_state}` from the entries.

3. **`zfa slice id <feature-id>`** — prints the stable slice id: the
   resolved `FeatureContract.id` (spec 1098) when a contract is
   declared, else the slug normalization (pure function of the input).
   Stable across re-compositions.

4. **Compose writes the skeleton** — `zfa slice compose` writes the
   empty `slice.receipt.json` (every section `pending`) into the slice
   (spec 1114's composer, 1116's skeleton). Running engine + skin +
   cert + xray in the slice worktree fills the sub-receipts.

5. **The merge gate** — `zfa slice merge <feature-id>` on a feature
   slice runs the receipt audit FIRST and refuses red or pending with
   the one-line status, every re-run command, and the
   `zfa slice verify <id>` fix path. Green prints
   `merge gate: ... receipt is green` and the merge may proceed.

6. **The slice check is receipt-aware** — the #1114 compliance walk
   exempts the receipt artifact family (`slice.receipt.json`,
   `journal.json`, `engine/engine.receipt*.json`, `engine/mock-cert/**`,
   `skin/skin.receipt.json`, `skin/contract-schema.json`): they are the
   feature's own record, the way receipts/ and specs/ are, not slice
   source. The layer audit still walks the real sources.

## Files

- `lib/src/plugins/slice/receipts/slice_receipt.dart` — the schema,
  skeleton, atomic writer/reader, `slugFeatureId`.
- `lib/src/plugins/slice/receipts/slice_receipt_aggregator.dart` — the
  five-section aggregator (`SliceReceiptAggregator`).
- `lib/src/plugins/slice/slice_command.dart` — `id` subcommand, the
  verify dispatch (feature → receipt audit, cut → #961 import check),
  the merge gate.
- `lib/src/plugins/slice/generators/feature_slice_composer.dart` — the
  compose skeleton.
- `lib/src/plugins/slice/capabilities/slice_check_capability.dart` —
  the receipt-artifact exemption.
- `test/plugins/slice/slice_receipt_test.dart` — the acceptance tests
  (R1–R7).

## Out of scope (honest boundary)

The full `zfa make engine <entities> && zfa engine check <entities> &&
zfa tdd run-skin <id>` chain against a REAL generated engine slice
requires build_runner/zorphy codegen plus a Flutter SDK (unavailable in
this environment); the sub-receipts the e2e proof writes carry the
exact schemas the real producers write (`engine.receipt.v2`,
`mock-cert` schema 1 spec 1001, `skin.v1`, journal schema 1 — verified
against `EngineReceiptWriter.writeV2`, `MockCertReceipt.toJson`,
`SkinReceiptDocument.toJson`, `JournalWriter.append`).
