# TDD Verification — feature `1193-realize-mocked-to-real-swap`

Written from the ACTUAL runs performed on this branch (every command below
was executed; outputs are quoted from the transcripts, not asserted).
Toolchain: Dart 3.13.3 (stable) on linux_x64 (`dart --version`). Flutter is
not installed in this environment — the pure-Dart CLI lanes and the fast
suite run without it; Flutter-dependent tiers are out of scope here.

## Gate

- gate: `passed`
- analyze: `dart analyze lib test` → **0 errors, 0 warnings, 104 info-level
  lints, all pre-existing in untouched files** (98 × `lib/tdd/*` subject
  naming in the mutation-test subject corpus, plus pre-existing
  `prefer_collection_literals`-style idioms in `make_command.dart` and
  `world_utils.dart`; **0 lints in any file this spec created or touched**)
- fast suite (chunked): `tools/run_chunks_range.sh` (the ranged driver of
  `tools/run_tests_chunked.sh`; the environment reaps detached processes,
  so the run was driven in four foreground ranges 1-15, 16-45, 46-75,
  76-90) → **90/90 chunks, 0 failed, 3,553 tests passed** (every chunk
  reported `All tests passed!`; 6 chunks reported the runner's SKIP — no
  fast-tier tests). A single un-chunked `dart test test/plugins/tdd`
  invocation was tried first and hit the documented disk bound
  (`No space left on device` while loading the kernel cache — the exact
  failure mode `tools/run_tests_chunked.sh` exists to prevent); the
  kernel caches were cleaned and the mandated chunked runner used.
- deterministic verify: `dart run bin/zfa.dart tdd verify --feature
  1193-realize-mocked-to-real-swap` → exit 0, **gate `not_assessed` — "no
  behavior artifacts registered"** (honest: this spec's behaviors live in
  the repo's own test tree — the 1110-cert-gate-engine precedent — there
  is no `specs/<feature>/tdd/artifacts.json` scope to mutation-audit, and
  `mutation_test` is not a dev dependency of this repo). The command
  wrote this file's `not_assessed` stub first; the substance below is the
  real verification record.
- format: `dart format .` → first pass `Formatted 2379 files (10 changed)`
  (the spec's new files); second run → `Formatted 2379 files (0 changed)`

## Red → green evidence (the loop, honestly)

### RED (reproduced on the pre-change tree — /home/z/my-project/scripts/red_repro_1193.sh)

```
$ dart run bin/zfa.dart tdd realize 090-tdd-fixture --adapter firestore --project <fx>
   era: MOCKED
   contract gate RED (baseline): ... (baseline exit 65) ...
realize: entity=090-tdd-fixture adapter=firestore feature=090-tdd-fixture
         contract=mock-broke-contract ... result=blocked
   → the feature TARGET was misresolved as an ENTITY (the 913 surface has
     no feature mode); no scaffold, no ladder, no REAL tier
$ grep -n "enum BehaviorState" lib/src/plugins/tdd/models/behavior.dart
53:enum BehaviorState { pending, blocked, red, green, mocked, done }
   → no REAL tier in the ladder state machine
$ ls lib/src/plugins/tdd/services/{adapter_scaffold,ladder_journal,realize_receipt}.dart
   → cannot access ...: No such file or directory   (all three)
```

The four new test files also failed to LOAD on the pre-change tree
(`AdapterScaffold`, `AdapterScaffoldException`, `ScaffoldPlan`,
`LadderJournal`, `LadderAdvance`, `RealizeReceiptWriter`, `EntitySwap`,
`BehaviorState.real` — all absent; `dart test` reported
`00:00 +0 -1: ... loading ... [E]` for each).

### GREEN (the same surface on this branch)

1. **The new machinery, unit-level (fast suite):**
   - `test/plugins/tdd/services/adapter_scaffold_test.dart` → **6/6**
     (naming matrix, same-interface derivation off the mock's
     `implements` clause, multi-line signature normalization,
     constructor/private/static exclusion, seam-header emission,
     honest refusals)
   - `test/plugins/tdd/services/ladder_journal_test.dart` → **11/11**
     (MOCKED→REAL→DONE walk, GREEN→DONE and REAL→DONE completions,
     unrelated behaviors untouched, absent-state handling, manifest
     retirement + digest, idempotent re-retirement, unified journal
     entry shape, `BehaviorState.real` round-trip + laneCounts green
     tier)
   - `test/plugins/tdd/services/realize_receipt_test.dart` → **3/3**
     (stable file name, double-shaped proof.v1 document with
     files/digests/gates/ladder/ratios, parseable by
     `GenerationReceipt.fromJson`, on-disk write)

2. **The command surface, acceptance-level:**
   - `test/plugins/tdd/commands/realize_feature_test.dart` → **9/9** —
     SC-1 (complete(mocked) → complete(real) via
     `FeatureProvenanceReader`, zero test-file byte edits), SC-2
     (differential drift blocks: rollback, MOCKED era, manifest kept,
     no receipt), SC-3 (receipt: files, re-derivable digests, gate
     outcome, ratios, ladder), FR-002 (scaffold + nuance ledger +
     never generation-receipted; dev-filled seam + gated hand-delta →
     realized), FR-007 (--dry-run writes nothing), FR-003 (already-real
     idempotent no-op), FR-001 (uncertified receipt blocks with the
     `zfa mock create User --certify` fix), FR-005 (manifest/mock-cert
     metadata skipped, never a runner-error)
   - 913 back-compat (SC-4): `realize_command_test.dart` **8/8**,
     `realize_state_test.dart` **3/3**, `di_rebind_test.dart` **4/4**
     (the U5 import-drop regression introduced mid-loop was caught by
     these very tests and fixed by deriving import suffixes from the
     declaration files' real basenames), `realize_mock_command_test.dart`
     unchanged and green in the chunked run
   - Whole TDD plugin tree: `dart test test/plugins/tdd/services
     test/plugins/tdd/commands` → **+998, 0 failed**

3. **The full fast suite (chunked, mandated): 90/90 chunks, 0 failed,
   3,553 tests passed** (ranges 1-15, 16-45, 46-75, 76-90; each range
   ended `RANGE DONE ... failed_chunks=0`).

4. **End-to-end through the real CLI with REAL `dart test` subprocesses
   (no injected runners — /home/z/my-project/scripts/green_proof_1193.dart,
   archived from the transient `tool/green_proof_1193.dart`):**
   ```
   $ dart run tool/green_proof_1193.dart
   PASS: fixture pub get
   PASS: dry-run exits 0 with result=planned
   PASS: dry-run wrote nothing (bytes identical)
   PASS: dry-run manifest kept / no scaffold
   PASS: first run blocked with the scaffold landed
          (contract gate RED: the scaffold's UnimplementedError bodies
           fail the REAL mock-era suite against the real binding)
   PASS: scaffold file exists with the seam header
   PASS: bindings rolled back to the mock era
   PASS: second run realizes (REAL suite green, gates pass)
   PASS: ladder advanced MOCKED->REAL->DONE
   PASS: provenance derives complete(real)
   PASS: zero test edits (contract suite unchanged)
   PASS: manifest retired, fixture kept
   PASS: run-state B-001 = done / realize-state era = REAL
   PASS: receipt written; digests re-derive from disk; gates+ratios+ladder
   PASS: re-run is an already-real no-op
   GREEN PROOF: all checks passed
   ```
   The e2e fixture's contract test registers the generated DI modules and
   asserts through `getIt<UserRepository>()` — the same suite file runs
   unchanged (byte-identical) against the mock binding (baseline) and
   the real binding (the swap); the differential runs through the
   project-owned `tool/realize_driver.dart` protocol with the committed
   `mockOutput` oracle.

## Success criteria — PROVED vs not

- SC-1 (complete(mocked) → complete(real), zero test edits): **PROVED** —
  in-process (A1, via `FeatureProvenanceReader`) and end-to-end (green
  proof, real `dart test`).
- SC-2 (failing differential gate blocks REAL): **PROVED** — A2: rollback
  to byte-identical mock-era bindings, era stays MOCKED, manifest kept,
  provenance still complete(mocked), no receipt written.
- SC-3 (receipt records the swap — files, digests, gate outcome):
  **PROVED** — A1b: every `action: update` digest re-derives from the
  on-disk bytes; the retired manifest carries `action: delete` with its
  pre-deletion digest; the document parses as `proof.v1` through
  `GenerationReceipt.fromJson`.
- SC-4 (913 entity/behavior surface unchanged): **PROVED** — the
  pre-existing realize test files pass unmodified (8/8, 3/3, 4/4 and the
  realize-mock suite in the chunked run).
- The mutation-audit gate of `zfa tdd verify`: **NOT ASSESSED** (no
  artifacts registry scope for this spec's repo-internal behaviors —
  same shape as spec 1110; reported honestly, not faked).
