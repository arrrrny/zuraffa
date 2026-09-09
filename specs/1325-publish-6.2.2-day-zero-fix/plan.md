# Plan 1325 — publish 6.2.2 day-zero fix: verify the artifact fleet, guard the gap

GitHub issue: arrrrny/zuraffa#1325
Branch: `feat/1325-publish-6.2.2-day-zero-fix`

## Technical Context

- **Language/runtime**: pure Dart package (`pubspec.yaml` SDK `^3.11.0`;
  toolchain Dart 3.13.3 stable). No Flutter needed for the release gates
  — the scratch consumer compiles with the pure Dart SDK
  (`dart compile exe`); Constitution VII (pure-Dart core) holds.
- **Release surfaces**:
  - `pubspec.yaml` `version:` — master carries `956867fa chore: release
    6.2.2`; the bump 6.2.0 → 6.2.2 is already merged. This branch must
    NOT touch it again (pub.dev rejects duplicate-version publishes, and
    the bump already exists — re-editing would be drift).
  - `dart pub publish` — 6.2.2 is live on pub.dev (published
    2026-09-08T20:03:48Z, maintainer action; the pub.dev API is the
    source of truth for "published"). This branch re-proves the tree is
    publishable via `dart pub publish --dry-run` (0 errors under the
    FR-3 warnings-only policy — warnings permitted, the zero-warning
    "Package validation passed" variant is not required; benchmark files
    in the upload set) and does NOT re-publish.
  - Tarball verification — the published archive is pulled from
    `https://pub.dev/api/archives/zuraffa-6.2.2.tar.gz` and inspected
    with `tar -tzf` for `lib/src/core/benchmark/benchmark_contract.dart`
    and the full benchmark sets.
- **Export guard (already on master)**: `test/core/
  publish_set_exports_test.dart` — the #1307/#1325 publish-set guard
  (landed via the #1313 work) walks the transitive export/part graph of
  `lib/zuraffa.dart` and asserts every reached file survives the
  `.pubignore` rules: the fast-tier, no-network pin of the exact bug.
  This branch runs it as a release gate; it must stay green.
- **Drift guard (this branch adds)**: `.github/workflows/publish_drift.yml`
  — compares `grep '^version:' pubspec.yaml` with
  `https://pub.dev/api/packages/zuraffa` `latest.version` via a small
  shell step (curl + jq, both preinstalled on GitHub runners); exits 1
  with a remedy message on drift. Triggers: push to master,
  workflow_dispatch, daily schedule. Explicitly NOT pull_request —
  version bumps precede publish by design, so PR-time drift is expected;
  master-time drift is the #1325 gap class (fix merged, artifact fleet
  not moved). A comment in the workflow documents the "reproduce with"
  remedy.
- **Verification environment constraints** (cloud agent): targeted checks
  only — never the full test suite (kernel-cache disk ceiling, task
  brief). The branch's changed files are spec `.md` artifacts + one
  workflow YAML: zero `.dart` changes, so the per-changed-file
  analyze/test loops are no-ops; the publish-set guard test is run
  explicitly because it covers the release surface this PR attests.

## Approach

1. Spec artifacts under `specs/1325-publish-6.2.2-day-zero-fix/` record
   the release gates as measurable success criteria (SC-1..SC-8).
2. Behaviors first: the TDD test-list maps B1–B5 to the criteria. Red
   evidence is produced at the artifact level — a scratch consumer pinned
   to the broken published 6.2.1 must fail to compile with the issue's
   exact missing-file error (the "mutant" the release gate must kill),
   and the drift guard's check must fail on a deliberately mismatched
   version (self-test red).
3. Green evidence: the same scratch consumer pinned to 6.2.2 compiles
   clean (AOT `dart compile exe`), dry-run passes, the live tarball
   contains the benchmark sets, and the drift guard passes against the
   live state.
4. The only implementation delta on this branch is the drift-guard
   workflow (criterion 4, optional-but-recommended, chosen YES — the root
   cause is a process gap and the guard is the process fix). No lib/bin/
   tool changes.

## Non-goals

- No re-publish (identical-version publish is rejected by pub.dev; 6.2.2
  is already live).
- No source changes (hard constraint: release task, fix already merged).
- No changelog edits (6.2.2 entry already on master).

## Risks

- pub.dev API/archive fetches may be rate-limited from CI/sandboxes —
  every fetch uses plain `curl` with a descriptive User-Agent and fails
  loudly (non-zero exit) rather than silently passing.
- `dart compile exe` of the scratch consumer resolves the full dependency
  graph (slow first time) — acceptable; it is the strongest "day zero
  compiles" proof available without Flutter, and the scratch lives
  outside the repo (deleted after evidence is recorded).
