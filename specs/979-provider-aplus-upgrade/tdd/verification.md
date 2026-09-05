# TDD Verification: 979 — provider A+ upgrade

**Verdict: GREEN — all five orders implemented and tested (red → green),
all acceptance criteria PROVED by executed runs.**

Method: every behavior got a failing test FIRST (cycle-log.md records the
red evidence: the dead-flag set `[domain, params, returns, type, data,
init]`, `--init` parse failure, missing receipt/verify modules), then the
implementation, then the full verification battery below. No step below
was claimed without being run in this session.

## 1. Orders → implementation

| Order | Implementation | Proved by |
|---|---|---|
| 1 — GENERATED header + receipt | `ProviderBuilder.generatedHeader` stamped on every fresh emission (`headerFor`); append/inject paths preserve it (`_insertImportBelowHeader`); `ProviderReceiptWriter` persists `.zfa/receipts/provider-<Entity>.json` (proof.v1 + `interface`/`methods`/`stubCount`) via new `ReceiptStore.saveNamed`; emitted by `zfa provider create` AND the make post-pass | `provider_receipt_test.dart` (4 tests), real-CLI demo §below, `tools/proof_smoke.sh` |
| 2 — stub-escape gate | `ProviderVerifier` (AST: any `UnimplementedError` construction in a method body — parse-level AST types it as a `MethodInvocation` of the class name, both shapes matched); `zfa provider verify <Entity>` exits 1 + `--> fix:` naming file + method; make post-pass: committed provider with surviving stubs fails the run, fresh stubs are named + receipted (stub-first preserved) | `provider_verify_test.dart` (6), `provider_make_postpass_test.dart` (4, slow tier, run with `--preset=all`) |
| 3 — dead-flag purge | All six parent flags deleted from `ProviderCommand` (grep: zero `argParser.add*` left); `init` + `type` enum wired into `CreateProviderCapability.inputSchema`; configSchema advertises the same knobs (schema ≡ grammar); `zfa manifest --verify [ids]` certifies via `PluginCommand.consumedParentFlags` | `provider_schema_grammar_parity_test.dart` (5), `provider_manifest_verify_test.dart` (3), real-CLI runs below |
| 4 — conformance check | After generation the make post-pass AST-verifies provider ⊇ interface methods (MethodExtractor on the Service file); missing method → exit 1 + `--> fix:`; `provider verify` runs the same gate standalone | `provider_verify_test.dart` (conformance pos/neg), `provider_make_postpass_test.dart` (conformance miss) |
| 5 — tests | 24 new failing-first tests under `test/plugins/provider/` (20 fast tier + 4 slow tier), incl. append/inject round-trip | all green below |

## 2. Test runs (ACTUAL counts)

- **Fast suite, chunked** (tools/run_tests_chunked.sh semantics — same
  chunk list via `DRY_RUN=1`, same `dart test <chunk> --exclude-tags
  flutter` per chunk, same kernel cleanup; run through a resumable
  wrapper because this sandbox reaps background processes): **74/74
  chunks — 70 PASS + 4 SKIP (slow-tier-only folders), 0 failures.**
- **`dart test test/commands`** (135 tests, run directly — NOTE: the
  chunked runner has a pre-existing coverage gap: a top-level folder
  with >40 test files and no test subfolders, like `test/commands`, is
  never emitted as a chunk): **135/135 passed.**
- **New provider suite**: `dart test test/plugins/provider/` →
  **+28 All tests passed** (20 new fast-tier + 8 pre-existing).
- **Slow tier, provider**: `dart test
  test/plugins/provider/provider_make_postpass_test.dart --preset=all`
  → **4/4 passed** (fresh stubs visible + exit 0; committed stubs →
  exit 1 + fix lines; filled bodies → exit 0; conformance miss → exit 1).
- **Slow tier, make**: `dart test test/commands/make_command_test.dart
  --preset=all` → 15/16 passed. The 1 failure (#412 full-bundle,
  `Multiple operations for lib/src/di/index.dart` transaction conflict)
  is **pre-existing on clean master** — reproduced by stashing all
  working-tree changes and running the same test on 77e69f24 (same
  failure). Not caused by this spec; the DI transaction conflict is
  outside 979's scope.
- **`dart analyze lib test --no-fatal-warnings`**: 314 issues, of which
  20 error/warning — **identical totals to the clean-master baseline**
  (314/20): zero new findings; the touched dirs analyze clean.
- **`dart format .`**: "Formatted 1987 files (0 changed)" on the re-run —
  **zero remaining formatting diffs** (`git diff --stat` shows only the
  intended code changes).
- **`bash tools/proof_smoke.sh`**: **PROOF SMOKE PASSED** (entity + make
  receipts, green fresh check, unprovenanced rogue flagged, tampered
  artifact red).

## 3. Acceptance criteria — PROVED

- **AC-1 provenance, green/red**: unit test runs `ProofChecker` after a
  real `provider create` → `ok: true`; after a one-line hand-edit →
  `[modified]` finding naming `cart_provider.dart`, `ok: false`. Real
  CLI: digest-level check exits 0 on fresh generation
  (`proof: 1 receipt(s), 1 artifact(s) verified, 0 finding(s) — OK`) and
  exits 1 with the `[modified] cart_provider.dart` finding after a hand
  edit. (With a coverage root, the standalone `service create` file is
  `unprovenanced` — service receipts are spec #978's unmerged scope; in
  `make` runs the make receipt covers the whole tree, which is exactly
  what the passing proof smoke proves.)
- **AC-2 stub gate both ways**: real CLI `zfa provider verify Cart` on a
  generated provider → `stubs: 1`, finding names file + method + fix
  line, exit 1; after filling the body → `✅ verified`, exit 0. Unit
  tests pin both directions plus the `--json` envelope
  (`{schema:1, ok:false, findings:[{kind:'stub', method:'execute',
  fix:'--> fix:...'}]}`).
- **AC-3 no dead flags**: grep — `rg -c "argParser.add"
  lib/src/commands/provider_command.dart` → **0 matches**; parity test
  pins the parent grammar empty and the six knobs live on
  `zfa provider create`; real CLI `zfa manifest --verify provider` →
  `✓ provider — every plugin-specific parent option is functional or
  absent`, exit 0. Unscoped `zfa manifest --verify` honestly reports the
  88 remaining #876-family dead flags in the seven commands that have
  their own pending A+ specs (repository/usecase/service/mock/state/
  test/sqlite/route — master still carries them; each is a separate
  issue, out of 979's scope).
- **AC-4 conformance tested**: provider missing `rollback` from its
  interface → verify exit 1 + `--> fix:` naming `rollback`; full mirror →
  exit 0. The make post-pass fails a run when the interface declares a
  method the provider lacks (tested with a hand-added `rollback`).

## 4. Real-CLI evidence (executed, abridged)

```
$ zfa provider create --name Cart
  ✨ lib/src/data/providers/cart/cart_provider.dart
$ head -1 .../cart_provider.dart
// GENERATED by zfa provider — DO NOT EDIT BY HAND.
$ cat .zfa/receipts/provider-Cart.json →
  interface: CartService, methods: ['cart'], stubCount: 1, schema: proof.v1
$ zfa proof check            → 0 findings — OK (fresh), exit 0
$ echo '// hand edit' >> ... → [modified] cart_provider.dart, exit 1
$ zfa provider verify Cart   → [stub] cart: ... + --> fix: ..., exit 1
$ (fill the stub body)       → ✅ verified, exit 0
$ zfa provider create --name Billing --init → parses; dispose member present
$ zfa manifest --verify provider → ✓ certified, exit 0
```

## 5. Honest limitations

- The make post-pass suite and the #412 make test are slow-tier (the
  repo's own convention for real make runs); the fast suite covers the
  other 20 new tests. The slow suites WERE run here explicitly (results
  above).
- `test/commands` is invisible to the chunked runner (pre-existing gap,
  >40 files, no subdirs) — it was run directly: 135/135.
- The #412 failure is pre-existing on master (proven by stash-run);
  filed context only, no fix attempted here (out of scope).
- `zfa manifest --verify` unscoped is red by design on this tree (the
  other plugins' dead flags) — scoped to provider it is green, which is
  what order 3 requires ("must be able to certify the flag surface
  afterward").
