# Fix — #1550: reset invalidates the corpus baseline cache; compose verifies the green-unit premise

- **Slug**: 1550-reset-stale-corpus-baseline-cache
- **Branch**: `fix/1550-reset-stale-corpus-baseline-cache`
- **Fixes**: https://github.com/arrrrny/zuraffa/issues/1550

## Change 1 — reset invalidates the baseline caches (the third store)

`lib/src/plugins/tdd/commands/reset_command.dart`:

- After deleting the registry (`tdd/artifacts.json`) and run-state
  (`tdd/run-state.json`), reset now also deletes:
  - the corpus-wide baseline cache
    `.zfa/corpus/run-baseline.json`
    (`CorpusBaselineCache.pathFor(projectRoot:)`, spec 069 T004), and
  - the feature-local baseline snapshot
    `specs/<feature>/tdd/run-baseline.json`
    (`RunBaselineCache.pathFor(featureDir:)`).
- Both invalidations are announced BEFORE acting (`will invalidate the
  corpus baseline cache (…; spec 069 T004)` / `will invalidate the
  feature baseline cache (…)`), like every other reset effect, and are
  reported in the verdict details under the new additive key
  `invalidated_caches`.
- Deletion is the invalidation: the next run's driver finds no cache,
  re-captures the suite baseline LIVE, and stamps the new capture
  post-reset. The stale pre-reset snapshot can no longer claim the
  dropped behaviors are green.
- The doc comment's store inventory is updated: registry + run-state +
  baseline caches are the mutable stores a restart needs clean
  (append-only cycle-log and journal history remain untouched).

Why deletion instead of the issue's fix #3 (fingerprint the registry/
journal generation): the brief forbids changing the corpus cache
fingerprint logic or the state machine. Deleting the cache on reset
achieves the same forced miss for the reset path without widening the
fingerprint surface; the general #1505 family (other stale-cache paths)
stays open for its own fix.

## Change 2 — compose verifies the green-unit premise; stale premise = `stale-evidence`

`lib/src/plugins/tdd/services/composition_targets.dart`:

- In `discover()`, the green-unit premise is now verified against the
  REGISTRY first: a unit row carrying green cycle-log evidence whose
  registry record is ABSENT returns
  `CompositionTargetFailure(code: 'stale-evidence', …)` — an actionable
  refusal that names the stale evidence (the artifacts it certified were
  dropped, canonically by a reset; the #1264 tombstone lives in the
  journal, which discovery does not consult) and directs the operator to
  re-derive (`zfa tdd gen <id>` + re-drive) instead of a dead-end
  remedy.
- The sibling anomaly (record PRESENT, subject file missing on disk)
  stays `missing-anchor-subject` — the registry premise is intact, the
  tree drifted (pinned by `composition_targets_test.dart` U3,
  unchanged).

`lib/src/plugins/tdd/commands/compose_command.dart`:

- New `ComposeOutcome.staleEvidence('stale-evidence')`; discovery
  failures map by code (`no-green-units` → `no-green-units`,
  `stale-evidence` → `stale-evidence`, everything else →
  `runner-error` as before). Exit code stays 1 — a refusal, never a
  partial anchor set.

## Hard constraints honored

- No corpus cache fingerprint logic changed
  (`CorpusBaselineCache.dependencyFingerprint` untouched).
- No run state machine changed (driver, make, run outcomes untouched;
  make's `_compositionFallback` already disengages on any discovery
  failure).
- Reset's ownership rules untouched (delete set unchanged; the caches
  are not behavior-owned files — they are reset's own mutable stores).
- `dart analyze`: no new warnings on the changed files.
