# 1505-corpus-baseline-invalidation

- **Spec ID**: 1505-corpus-baseline-invalidation
- **Created**: 2026-09-13
- **Source**: GitHub issue #1505 (companion: #1550)
- **Type**: bug (correctness of the corpus-wide baseline cache)
- **Priority**: P1
- **Branch**: feat/1505-corpus-baseline-invalidation

## Problem

`zfa tdd run <feature>` reuses a garbage full-suite baseline from
`.zfa/corpus/run-baseline.json` (spec 069 T004, `CorpusBaselineCache`) even
after the test files that produced the failures are fixed. Every `tdd
refactor` preflight diffs the live suite against the stale failure names,
marks current failures as "new", and refuses all refactors — a phantom
failure wall that only manual deletion of the cache file lifts.

Measured impact (issue #1505, #1467 bug-whole cycle): a baseline with 713
load-failure entries captured on 2026-09-10 was reused across 3 engine
restarts despite every failing test having been fixed, because
pubspec.yaml/pubspec.lock never changed.

## Root cause

`CorpusBaselineCache.dependencyFingerprint()` is sha256 over **pubspec.yaml
+ pubspec.lock + the profile's suite template only**. Test files, lib/
sources, and generated code are not part of the fingerprint, so fixing them
never invalidates the cache. The fingerprint also ignores `.zfa/`
memory/manifest state, so a baseline captured during an in-flight entity
setup (different declared entities / manifests) is reused for a completely
different feature.

## Goal

The corpus baseline must be invalidated whenever anything that can change
test outcomes changes, while cache hits for genuinely unchanged suites keep
working (the spec 069 corpus economics must not regress into a suite re-run
per feature when nothing relevant changed).

## User Scenarios & Testing

### User Story 1 — Fixed tests invalidate the baseline (Priority: P1)

An agent fixes the test files that produced the baseline's failures and
re-runs `zfa tdd run <feature>`. The corpus cache must MISS (the live suite
re-runs and a fresh baseline is captured), so `tdd refactor` never diffs
against failure names that no longer exist.

**Why this priority**: this is the exact reported failure — without it every
post-fix run is blocked by phantom "new failure" refusals.

**Independent Test**: seed a corpus cache keyed to fingerprint F; change any
file under `test/`; recompute the fingerprint — it must differ from F and
`read()` must return null.

**Acceptance Scenarios**:

1. **Given** a cached corpus baseline captured under fingerprint F, **When**
   a file under `test/` is created, modified, or renamed (content change),
   **Then** `dependencyFingerprint()` no longer returns F and `read()`
   misses (safe fallback to the live suite).
   **Type**: acceptance
2. **Given** the same cached baseline, **When** a `zfa tdd run` drives a
   second feature after a test-file fix, **Then** the run log does NOT
   report `corpus-wide reuse` and the suite spy re-runs (driver-level
   #1505 repro).
   **Type**: acceptance

### User Story 2 — Source changes invalidate the baseline (Priority: P1)

An agent changes `lib/` sources (the code under test) or generated code.
Test outcomes can change, so the cached baseline must invalidate the same
way as for test files.

**Why this priority**: the baseline's meaning ("pre-existing failures") is
defined by the suite's inputs; lib/ is the primary one.

**Independent Test**: seed a cache keyed to F; modify a file under `lib/`;
the fingerprint must differ from F.

**Acceptance Scenarios**:

1. **Given** a cached corpus baseline under F, **When** any file under
   `lib/` changes content (or is created/renamed), **Then** the fingerprint
   differs from F and the cache misses.
   **Type**: acceptance

### User Story 3 — .zfa/ memory/manifest state participates (Priority: P2)

A baseline captured under one declared project state (corpus manifests,
`.zfa/` agent memory/contract state) must not be silently reused after that
state changes — a reset or manifest edit must force a fresh capture (the
#1550 second-order effect).

**Why this priority**: it closes the remaining stale-reuse family (entity
setup across features) but the dominant damage is already covered by
stories 1–2.

**Independent Test**: seed a cache keyed to F; write
`.zfa/manifests/corpus-manifest.json`; the fingerprint must differ from F.

**Acceptance Scenarios**:

1. **Given** a cached corpus baseline under F, **When** a file under
   `.zfa/manifests/` or the `.zfa/` agent memory contract (context.json /
   AGENT_CONTRACT.md) is created or changed, **Then** the fingerprint
   differs from F and the cache misses.
   **Type**: acceptance

### User Story 4 — Unchanged suites keep hitting (Priority: P1)

The corpus cache must keep reusing the baseline when nothing that can change
test outcomes changed — the spec 069 economics contract (a fingerprint
match reuses the snapshot across features; the suite is not re-run).

**Why this priority**: an always-miss cache would regress the corpus lane
into one suite run per feature — the exact cost 069 T004 exists to remove.

**Production caveat** (review F2): in a REAL corpus lane the TDD loop writes
`lib/` (GREEN implementation) and `test/` (new tests) for every feature, so
SC-1's inputs — and therefore the fingerprint — change after each feature
and the cross-feature hit rate is ≈ 0. The reuse this story guarantees holds
for a lane whose features do not change the hashed inputs. The economics
guard's fixture writes no `lib/`/`test/` files, so it pins the mechanism,
not the production hit rate.

**Independent Test**: seed a cache keyed to F; touch file mtimes, run steps
that mutate run-state/receipts/progress, add unrelated specs/ artifacts;
the fingerprint must still be F and `read()` must hit.

**Acceptance Scenarios**:

1. **Given** a cached corpus baseline under F, **When** only non-outcome
   state changes (file mtimes, `.zfa/corpus/progress.json`,
   `.zfa/corpus/run.lock`, `.zfa/receipts/**`, specs/ planning artifacts,
   the cache file itself), **Then** the fingerprint stays F and `read()`
   returns the cached snapshot.
   **Type**: acceptance

## Measurable Success Criteria

1. SC-1: `dependencyFingerprint()` output changes when ANY file under
   `test/` or `lib/` changes, is created, or is deleted (content-based —
   pure mtime changes do NOT flip it).
2. SC-2: `dependencyFingerprint()` output changes when files under
   `.zfa/manifests/`, `.zfa/context.json`, or `.zfa/AGENT_CONTRACT.md`
   change.
3. SC-3: `dependencyFingerprint()` output is UNCHANGED by run-mutated state
   (`.zfa/corpus/**`, `.zfa/runs/**`, `.zfa/receipts/**`, `.zfa/plans/**`,
   `.zfa/blueprints/**`, `.zfa/decisions/**`, `.zfa/provenance/**`, mtimes).
   This is the *reuse-preserving* half only: it does not claim a production
   hit rate, since a feature that generates `lib/`/`test/` code legitimately
   flips SC-1's inputs and misses (see the US-4 production caveat).
4. SC-4: driver-level: after a test-file fix, the second `zfa tdd run`
   re-runs the live suite (no `corpus-wide reuse` line); with no relevant
   change, the second run still reports `corpus-wide reuse` and zero
   additional suite spawns.
5. SC-5: a project with neither pubspec.yaml nor pubspec.lock still has no
   fingerprint (null) — no corpus reuse, honest live baseline.
6. SC-6: `dart analyze` on the changed files reports no new warnings; the
   full corpus_economics test file passes.

## Hard Constraints

- Fix ONLY the fingerprint calculation in
  `lib/src/plugins/tdd/services/corpus_baseline_cache.dart` (its private
  helpers and doc comments). No caller changes, no reset/compose changes.
- Must not break cache hits for genuinely unchanged suites (US-4).
- Must remain fail-safe: hashing is best-effort per file; an unreadable
  file contributes its path with an unreadable marker instead of crashing
  the fingerprint.

## Out of scope

- `tdd reset` cache invalidation and compose green-unit premise checks
  (#1550 remedies 1–2) — separate issue.
- The per-feature `RunBaselineCache` (#741) fingerprinting.
- Fingerprinting `.specify/memory/tdd-profile.md` beyond the already-hashed
  suite template extraction.
- Re-keying the corpus cache after a feature's GREEN phase (write the
  snapshot under the fingerprint the NEXT feature will see) to restore the
  cross-feature hit rate in real lanes — review F2's follow-up, with the
  caveat that the captured failure set must still describe the tests the
  next feature runs.
- git HEAD sha + dirty-state hashing (rejected: the fixture-driven test
  suites run in temp dirs with no git repo; direct content hashing is
  deterministic and environment-independent).
