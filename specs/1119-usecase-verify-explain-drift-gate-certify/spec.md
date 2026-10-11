# Spec 1119 — [A+ UPGRADE] usecase: add zfa usecase verify, --explain, drift gate, --certify

Issue: https://github.com/arrrrny/zuraffa/issues/1119
Branch: `spec/1119-usecase-verify-explain-drift-gate-certify`

## Problem

The usecase plugin is the weakest of the 12 at C+. It has per-method
`--json` verdicts (spec #972) and usecase receipts, but:

- no verify gate — nothing re-proves the generated `*_usecase.dart`
  files still match the contract the generator prescribes;
- no certify — `zfa usecase create` cannot fail the run when the
  generated surface is non-conformant (mock already certifies);
- no explain — nothing tells a human WHICH methods were generated, with
  WHICH factory/future/stream/void variant, bound to WHICH result type,
  throwing WHICH exception type;
- no drift detection — the receipt binds the entity source hash
  (`spec.sha256`, issue #1034 pattern) but nothing ever consults it, so
  a usecase set generated from a since-edited entity silently stays
  "green";
- only ONE capability (`CreateUseCaseCapability`) — no verify capability
  on the plugin/MCP surface, and the create capability keeps its request
  resolution monolithic (duplicating the CLI command's config-building).

## Goals / What was built

1. **`zfa usecase verify <Entity>`** (`UsecaseVerifyCommand`): re-runs
   the per-method conformance gate against the generated
   `*_usecase.dart` files. Exit 0 when every method's signature matches
   the contract; exit 1 with `--> fix:` lines on drift (the same shape
   `zfa route verify` / `zfa service verify` use). `--json` emits ONE
   canonical `zuraffa.verdict.v1` envelope (issue #1105) with the
   per-method results in `details.methods` and findings carrying
   machine-stable kinds (`missing_file`, `missing_class`,
   `missing_method`, `signature_mismatch`, `parse_error`,
   `entity_drift`).

2. **`--certify` on `zfa usecase create`** (mirrors mock's certify):
   after generation, runs the verify gate over the methods the run
   wired (created + appended + already-present). Exit 1 when generation
   succeeded but verify failed; the `--json` envelope flips to
   `verdict: "fail"` with the conformance findings. The certification
   outcome rides the receipt (`input.certified`).

3. **`--explain` on `zfa usecase create`**: emits a human-readable block
   describing which methods were generated, which variant each uses
   (`Future<T>` / `Stream<T>` / `Future<void>`), which base class each
   extends (`UseCase` / `StreamUseCase` / `CompletableUseCase`), which
   result type is bound, which params type is bound, which exception
   type is thrown (`CancelledException` — the only exception the
   generated body can raise, via `cancelToken?.throwIfCancelled()`).
   In `--json` mode the block rides the additive `explain` envelope key
   (issue #1122 pattern — base envelope byte-compatible otherwise).

4. **Drift detection** (issue #1034 same pattern): verify compares the
   CURRENT entity source against the create receipt's
   `spec.sha256` binding; exit 1 with an `entity_drift` finding when the
   hash diverges (entity edited or deleted after generation). A run
   without a receipt still gates the files and reports
   `receiptBound: false` honestly — it never invents a drift verdict
   without proof.

5. **Split create (de-monolithic)**: the request-resolution both the
   CLI command and the capability duplicate moves to one shared
   `UsecaseCreateRequest` resolver; the plugin gains a second standalone
   capability `VerifyUsecaseCapability` (provenance receipts keyed
   `usecase-verify-<entity>-<timestamp>.json`, issue #996 contract) so
   the plugin surface is no longer one-capability-only.

## Success criteria (measurable)

- SC-1: `zfa usecase verify <Entity>` exits 0 on a freshly created
  entity's usecase set and 1 on a tampered one, with a `--> fix:` line
  for every finding.
- SC-2: `zfa usecase create --certify` exits 1 when any requested
  method's on-disk file is non-conformant (proven by pre-tampering) and
  0 otherwise; the `--json` envelope verdict is `fail` in the failing
  case.
- SC-3: `zfa usecase create --explain` prints the explain block (non-json)
  and carries `explain` in the envelope (json) listing, per method:
  class, base class, variant, result type, params type, exception type.
- SC-4: after editing the entity source post-create, `zfa usecase
  verify` exits 1 with the `entity_drift` finding naming the receipt's
  binding; before editing, it exits 0.
- SC-5: the create `--json` per-method verdict shape is unchanged
  (`name`/`action`/`reason` only) — extend, never break.
- SC-6: `usecase_verify_test.dart` + `usecase_certify_test.dart` pass;
  the per-method verdict shape test (SC-5) lives in the certify suite.

## Constraints

- Use the canonical receipt envelope (issue #1105) for receipts/verdicts.
- Do not change the per-method verdict shape on create — extend, do not
  break.
- The gate re-derives expectations by driving the REAL generator
  (`EntityUseCaseGenerator.buildUsecaseSource`) — grammar and gate share
  one derivation so they cannot drift (spec #1127 principle).
- Exit codes speak the ratified protocol (SPEC 917): 0 success, 1
  failure/drift findings, 2 usage.

## Non-goals

- Migrating other plugins' envelopes (issue #1105 sweep is its own spec).
- Custom/orchestrator/polymorphic/stream-type usecases: the gate covers
  the entity-method surface (`get/getList/list/create/update/toggle/
  delete/watch/watchList`) — the per-method vocabulary spec #972 gave
  verdicts for.
