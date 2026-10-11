# Spec 1325 — publish 6.2.2 day-zero fix: the merged #1307 fix must be the artifact users resolve

GitHub issue: arrrrny/zuraffa#1325
Severity: critical — every freshly scaffolded app fails to compile at day
zero while the fix that repairs it sits merged but unpublished.

## Problem

The #1307 remediation (root-anchoring `.pubignore`'s `benchmark/` line to
`/benchmark/`) is merged to master, but the package was never republished:
`pubspec.yaml` said `version: 6.2.0` and pub.dev's latest was the broken
6.2.1 (published BEFORE the fix, missing `lib/src/core/benchmark/` from
its tarball). Any freshly scaffolded app therefore resolved 6.2.1 and
failed to compile at day zero:

```
zfa setup deal_list --platforms=ios,macos
cd deal_list && flutter pub get && flutter test
  → pubspec.lock resolves zuraffa-6.2.1 →
  Error: Error when reading
  '.../lib/src/core/benchmark/benchmark_contract.dart':
  No such file or directory
```

Root cause: release-process gap — merging a publish-blocking fix does not
bump the version nor trigger a publish. The repo source was fixed; the
published artifact fleet was not.

Release-state note (2026-09-09, at spec time): commit `956867fa chore:
release 6.2.2` is on master and pub.dev lists 6.2.2 as latest (published
2026-09-08T20:03:48Z, maintainer action). The remaining gap this spec
owns: the issue is still open (its only PR, #1340, was closed unmerged),
the release verification evidence was never recorded in the repo, and no
guard detects the next version-vs-pub.dev drift. This spec therefore
treats "bump + publish" as release gates to VERIFY against the live
artifact fleet, and owns the evidence + the recurrence guard.

## Acceptance criteria (from the issue)

1. **Version bump**: `pubspec.yaml` version MUST be `6.2.2` on master
   (bumped from 6.2.0; 6.3.0 not warranted — no API change since 6.2.0,
   fixes only).
2. **Publish**: `dart pub publish` MUST have succeeded and made 6.2.2 the
   latest version on pub.dev; `dart pub publish --dry-run` on the master
   tree MUST pass with 0 errors (warnings permitted — see the
   warnings-only release policy in FR-3) and the tarball file set MUST
   include `lib/src/core/benchmark/`.
3. **Tarball smoke test**: a fresh `dart pub cache add zuraffa --version
   6.2.2` plus a scratch app importing `package:zuraffa/zuraffa.dart`
   MUST compile without errors; `lib/src/core/benchmark/
   benchmark_contract.dart` MUST be present in the published tarball.
4. **Publish-drift CI guard** (optional, recommended): a CI check that
   fails when the repo's `pubspec.yaml` version differs from pub.dev's
   latest on master — detecting the exact gap (fix merged, not published)
   before users do.

## Requirements

- **FR-1**: master's `pubspec.yaml` declares `version: 6.2.2` (criterion 1).
- **FR-2**: pub.dev's `latest.version` for `zuraffa` is `6.2.2`
  (criterion 2).
- **FR-3**: `dart pub publish --dry-run` on the master tree reports 0
  errors and its upload set includes
  `lib/src/core/benchmark/benchmark_contract.dart` (criterion 2).
  **Warnings-only release policy (approved)**: warnings do not block a
  release — pub.dev only rejects on errors, real publishes proceed past
  warnings via the interactive prompt, and 6.2.2 itself published from
  this warning state. The zero-warning "Package validation passed"
  variant is explicitly NOT required: the repo carries 4 pre-existing
  cosmetic warnings (3 checked-in-but-gitignored files; plural
  `examples/`/`tools/`/`docs/` layout names) that predate 6.2.2 and are
  untouched since the release commit; removing them would violate FR-8's
  no-source-change constraint. 0 errors + benchmark paths in the upload
  set is the accepted pass shape.
- **FR-4**: the published 6.2.2 archive at pub.dev contains
  `lib/src/core/benchmark/benchmark_contract.dart` and the full
  `lib/src/core/benchmark/` + `lib/src/plugins/benchmark/` sets
  (criterion 3).
- **FR-5**: a scratch consumer app that depends on `zuraffa 6.2.2` from
  pub.dev (after `dart pub cache add zuraffa --version 6.2.2`) and imports
  `package:zuraffa/zuraffa.dart` compiles (AOT `dart compile exe`) with
  zero errors (criterion 3).
- **FR-6**: the same scratch consumer pinned to `zuraffa 6.2.1` reproduces
  the issue's day-zero failure — the smoke test demonstrably kills the
  broken artifact (red evidence for the release gate; criterion 3).
- **FR-7**: a publish-drift guard workflow (`.github/workflows/
  publish_drift.yml`) runs on push to master (plus manual/scheduled
  dispatch), compares `pubspec.yaml`'s `version:` with pub.dev's latest,
  and exits non-zero with a remedy message on drift (criterion 4). It
  MUST NOT run on pull_request — version bumps precede publish by design,
  so PR-time drift is expected; master-time drift is the gap.
- **FR-8**: no source-code changes (`lib/`, `bin/`, `tool/` untouched) —
  this is a release task; the fix is already merged (#1307, shipped in
  6.2.2).

## Success criteria

- **SC-1**: `grep '^version:' pubspec.yaml` → `version: 6.2.2` (FR-1).
- **SC-2**: pub.dev API `latest.version == "6.2.2"`, published
  2026-09-08 (FR-2).
- **SC-3**: `dart pub publish --dry-run` reports 0 errors and lists the
  benchmark files in the upload set; a warnings-only exit (65 with N
  warnings) is the accepted pass shape under the FR-3 warnings-only
  policy (FR-3).
- **SC-4**: `tar -tzf` over the downloaded pub.dev 6.2.2 archive shows
  `lib/src/core/benchmark/benchmark_contract.dart` (FR-4).
- **SC-5**: scratch app on 6.2.2 compiles clean (exit 0) (FR-5).
- **SC-6**: scratch app on 6.2.1 fails with the missing-file error naming
  `benchmark_contract.dart` (FR-6, red evidence).
- **SC-7**: drift guard self-test: with a deliberately mismatched version
  the check exits 1; against the live state it exits 0 (FR-7).
- **SC-8**: `git diff --name-only master -- lib/ bin/ tool/` for this
  branch is empty (FR-8).

## Non-goals

- No source changes — the #1307 fix is merged; this is publish evidence +
  guard only.
- No re-publish of an identical version (pub.dev rejects duplicate
  versions; 6.2.2 is already live — verified, not re-run).
- No changelog edits (the 6.2.2 entry is already on master, dated
  2026-09-08, and includes the #1313 publish-time export guard line).
