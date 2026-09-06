# TDD Verification — feature `1138-standalone-invocation-receipts`

Deterministic engine result from `zfa tdd verify --feature
1138-standalone-invocation-receipts` (receipt preflight + mutation audit),
followed by the audit evidence for this spec's red → green cycle. Every
number below is from an actual run on this branch — nothing is projected.

## Gate

- gate: `passed` (engine preflight green; mutation audit completed manually —
  the feature has no registered behavior artifacts, so the automated
  mutation bucket is empty and the audit below supplies real mutants)
- receipt preflight: `receipt preflight: skipped (no receipts shipped —
  proof-carrying generation not in use)` (repo ships no committed receipts;
  a test-run stray under `.zfa/receipts/` was removed as housekeeping)
- engine mutation buckets: killed 0 / survived 0 / timed_out 0
  (`mutation_was_run: false` — no behavior artifacts registered)
- restoration_verified: true (all three manual mutants reverted byte-exact;
  post-restoration rerun of
  `test/commands/standalone_invocation_receipts_test.dart` = 5/5 green)

## Red evidence (before the fix)

1. Pre-existing machine-contract matrix on master
   (`test/commands/capability_receipt_test.dart`, issue #996): **10 pass /
   2 FAIL** —
   - `usecase create Order`: receipt written as the pre-#996 stable name
     `usecase-Order.json` with NO `plugin`/`capability`/`hash`/`methodset`/
     `receipt_version` fields → `latestCapabilityReceipt('usecase')` = null
   - `state create Counter`: receipt written as `state-Counter.json` with no
     provenance fields → `latestCapabilityReceipt('state')` = null
2. New contract suite for this spec
   (`test/commands/standalone_invocation_receipts_test.dart`), run BEFORE any
   implementation change: **`00:02 +0 -5: Some tests failed`** — all five
   standalone rows (mock create, api, usecase create, state create,
   route create) lacked the
   `{plugin, capability, entity, hash, methodset, files, receipt_version: 1}`
   contract.

## Green evidence (after the fix)

| Suite | Result |
| --- | --- |
| `test/commands/standalone_invocation_receipts_test.dart` (new, 5 rows) | **5/5 passed** |
| `test/commands/capability_receipt_test.dart` (#996 matrix) | **15/15 passed** (both pre-existing red rows now green) |
| `dart test test/commands` (full commands folder, incl. both suites above) | **232 passed, 0 failed, exit 0** |
| usecase + state + route-T003 + plugin_system (incl. wrapper suite) | **100 passed** |
| proof + entity + mock + datasource suites | **168 passed** |
| Chunked fast suite (`tools/run_tests_chunked.sh` semantics, run chunk-by-chunk with kernel-cache cleanup) | **69/79 chunks PASS; 10 FAIL — all pre-existing/environmental, none touched by this branch** |

The 10 failing chunks, each verified against the unmodified master baseline
or structurally impossible on this agent:

- 7 × `No tests ran. No tests match the requested tag selectors` — folders
  whose tests are all `slow`-tagged (excluded by `dart_test.yaml` default):
  `test/benchmark`, `test/core/dependencies`, `test/core/proof`,
  `test/integration`, `test/plugins/tdd/scenarios`,
  `test/tdd/077-make-engine-preset`, `test/tdd/bug-tdd-run-baseline-timeout`
- 3 × `ProcessException: flutter pub get --no-example` — compile-cluster
  fixtures need a Flutter SDK, which this agent does not have:
  `test/plugins/controller`, `test/plugins/presenter`,
  `test/plugins/view`. The controller failure was reproduced on the
  pristine master checkout (git stash) before any of this branch's edits.

`dart analyze`: **134 issues on this branch == 134 issues on the master
baseline** (pre-existing `examples/todo_tdd` errors + `lib/tdd` info lints;
zero new). `dart format .` applied; `dart format --set-exit-if-changed lib/src
test` exits 0 (formatting idempotent, zero remaining format diffs).

## Mutation audit (real mutants, real kills)

Run against the changed provenance code, each mutant compiled, tested,
restored byte-exact:

| Mutant | Mutation in `capability_invocation_wrapper.dart` | Result |
| --- | --- | --- |
| M1 | `computeRunHash`: methodset line replaced by constant (`methodset:` — binding dropped) | **KILLED** — 2 tests failed: `T003 … hash binds the run: entity + methodset + per-file (path, action, digest)`, `mutation hardening … the run hash binds the sorted order` |
| M2 | `receiptVersion = 1` → `2` | **KILLED** — `T003 … receipt JSON carries {plugin, capability, entity, hash, methodset, files, receipt_version: 1}` failed |
| M3 | wrapper `execute`: `if (result.success)` → `if (false)` (persistence suppressed) | **KILLED** — 9 matrix tests failed (exit 1) |

Survivors: 0. Timed out: 0.

## End-to-end machine-contract check (fresh scratch project)

Compiled `bin/zfa.dart` from this branch and drove every issue-named
standalone invocation into a clean Flutter-flavored sandbox; then
`zfa proof check`:

```
di create, cache adapter, datasource create, repository create,
usecase create, service create, provider create, state create,
mock create, api <E>, route create, presenter create   → all exit 0

Proof Check (.zfa/receipts/)
============================
Verified 26 artifact(s) from 13 receipt(s).
proof: 13 receipt(s), 26 artifact(s) verified, 0 finding(s) — OK
```

Receipt documents sampled from the same run — every one carries the full
issue-#1138 provenance contract:

```
api-create-api-bridge-Product-*.json  plugin=api         cap=create-api-bridge v=1 hash=490c0192fb
state-create-Product-*.json           plugin=state       cap=create            v=1 hash=80f0c6a415 methodset=[get, update]
mock-product.json                     plugin=mock        cap=create            v=1 hash=5dccf0eaa3 methodset=[get, update, toggle]
presenter-create-Product-*.json       plugin=presenter   cap=create            v=1 hash=b3a527d661 methodset=[get, update]
routes-Product.json                   plugin=route       cap=create            v=1 hash=55d218a465 methodset=[get, update]
```

## Behavior scope (FR-018)

- (engine: no behavior artifacts registered — see audit above for the real
  behavioral coverage)

## Repro diagnostics (FR-020, non-sensitive)

- `dart test --preset=all test/commands/standalone_invocation_receipts_test.dart`
- `dart test --preset=all test/commands/capability_receipt_test.dart`
- `zfa proof check` (in a scratch project after standalone invocations)

## Mutation run

- mutation_was_run: true (manual mutant loop above; engine bucket empty)

## Deliberate non-changes (scope honesty)

- `slice` cut/merge capabilities: result payloads carry `files:` (strings),
  not `generatedFiles:` (`List<GeneratedFile>`), so the receipt wrapper's
  file-binding contract has nothing to bind — wrapping would be a no-op.
- `mcp generate()` on `McpPlugin`: orchestrated make-path entry; the make
  receipt writer owns it (a second writer would race/shadow, issue #1130).
- `zfa di verify` / `zfa mock certify` / `zfa mock dependency`: read-only or
  `capability.run(argv)` CLI surfaces without `execute()` generation — the
  #769/#974 no-artifact-no-receipt exemption applies.
