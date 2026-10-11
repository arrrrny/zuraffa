# Plan: 1505-corpus-baseline-invalidation

- **Spec ID**: 1505-corpus-baseline-invalidation
- **Created**: 2026-09-13
- **Source**: GitHub issue #1505 (companion: #1550)

## Technical Context

- **Primary artifact**: `lib/src/plugins/tdd/services/corpus_baseline_cache.dart`
  (`CorpusBaselineCache.dependencyFingerprint()` — the ONLY behaviour change
  site; per the hard constraint no other file changes behaviour).
- **Function under change**: `Future<String?> dependencyFingerprint(String
  projectRoot)` — sha256 over an ordered byte stream. Current inputs:
  pubspec.yaml bytes + pubspec.lock bytes + the profile's extracted suite
  template. Missing pubspec AND lock → null (no corpus reuse).
- **Caller (unchanged)**: `run_driver_core.dart` step 6b — computes the
  fingerprint once per run, `read()`s the corpus cache on match, writes the
  cache only for unscoped live captures. Signature stays identical, so the
  caller needs no edit.
- **Hash inputs after the fix** (in stable order):
  1. pubspec.yaml bytes (unchanged)
  2. pubspec.lock bytes (unchanged)
  3. suite template bytes (unchanged)
  4. `test/` tree content digest (NEW — SC-1)
  5. `lib/` tree content digest (NEW — SC-1)
  6. `.zfa/` memory/manifest state digest (NEW — SC-2):
     `.zfa/manifests/**` + `.zfa/context.json` + `.zfa/AGENT_CONTRACT.md`
- **Test site**: `test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
  (T004 unit group + driver group; TddFixture conventions, spy runners).

## Tree hashing design (deterministic, no git dependency)

Direct content hashing over directory trees (issue #1505's option A), NOT
git HEAD + dirty-state hashing (option B) — the TddFixture suite runs in
`Directory.systemTemp` dirs with no git repo, so option B would silently
degrade; content hashing is environment-independent and exact.

For each tree (`test/`, `lib/`, and the `.zfa/` state set):

1. `Directory.list(recursive: true, followLinks: false)`; keep regular
   files only (symlinks skipped — cycles and platform drift).
2. Sort entries by project-relative POSIX path (list order is
   filesystem-dependent — sorting is mandatory for determinism).
3. Contribute per file: utf8(relPath) + `\n` + 8-byte big-endian content
   length + raw content bytes (length prefix removes any
   path/content-boundary ambiguity).
4. Absent vs empty tree: contribute an explicit `absent` marker vs an
   empty-but-present marker (semantics differ; distinguishing costs
   nothing and keeps the hash honest).
5. Unreadable file (permissions races): contribute
   `<path>\nunreadable\n` instead of failing the whole fingerprint —
   fail-safe per the #741 stance (worst case is a rare miss, never a
   crash, never a wrong hit).

## Run-mutated state exclusion (SC-3 — the reuse-preserving half)

The fingerprint is computed at driver step 6b and the cache is WRITTEN in
the same step; anything a normal run mutates afterwards would make the
NEXT feature's fingerprint differ and force a spurious suite re-run —
destroying the spec 069 economics. Therefore the `.zfa/` contribution is a
closed allow-list of run-STABLE state, not a blanket `.zfa/**` walk:

- INCLUDED: `.zfa/manifests/**` (corpus-manifest.json, corpus-carveout.json
  — read-only harness inputs), `.zfa/context.json`,
  `.zfa/AGENT_CONTRACT.md` (agent memory/contract state).
- EXCLUDED (run-mutated or the cache itself): `.zfa/corpus/**`
  (progress.json, run.lock, run-baseline.json — the cache file),
  `.zfa/runs/**`, `.zfa/receipts/**`, `.zfa/plans/**`,
  `.zfa/blueprints/**`, `.zfa/decisions/**`, `.zfa/provenance/**`.

Same rationale excludes mtime-based hashing everywhere: content is hashed,
never metadata (SC-1's "pure mtime changes do NOT flip it").

## Backwards compatibility / migration

None needed. Previously-written cache files carry the OLD fingerprint; the
new computation differs by construction → first read after upgrade misses
→ the live suite re-runs once → the cache is rewritten under the new
fingerprint. Self-healing, no migration path, no version bump in the JSON
(the `dependency_fingerprint` field already opaque).

## Performance

Two additional recursive directory walks + reads per driver invocation
(step 6b only — once per run, not per behavior). For the zuraffa repo
itself (~10 MB of lib/ + test/ text) SHA-256 streaming costs tens of
milliseconds — negligible against a suite spawn (≥ seconds).

## Rollout / risks

- Risk: real corpus lanes generate lib/test files per feature, so each
  feature's fingerprint now differs from the previous feature's — the
  suite re-runs per feature in the corpus lane. This is CORRECT (a
  baseline captured before feature A's generated tests exist is not the
  baseline of the suite feature B faces — that staleness is exactly the
  #1505 damage class) and accepted by the issue's Expected clause.
- Risk: large binary fixtures under test/ slow hashing — acceptable
  (single-digit MB class; once per run).
- Guard retained: the consumption-site command-equality check
  (`corpusReused.command != suiteTemplate`) is untouched — legacy profiles
  without a Keys block keep their defense.

## Verification strategy

- Unit (fast tier): fingerprint flip assertions for test/, lib/, and .zfa
  state changes; stability assertions for mtime-only and run-mutated state
  changes; round-trip read() miss/hit.
- Driver: the #1505 repro end-to-end — suite spy captures a red baseline,
  the test file is fixed, the second feature's run must NOT report
  `corpus-wide reuse` and must re-run the suite; plus the negative: with no
  relevant change the second run still reuses (economics preserved).
- `dart analyze` on changed files: no new warnings.
