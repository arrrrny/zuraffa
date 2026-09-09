# Tasks 1325 — publish 6.2.2 day-zero fix

Dependency-ordered (MVP first: the release gates are verified before the
guard lands, so the evidence and the guard never share a blind spot).
One PR per issue (#1325). No source-code changes — hard constraint from
the issue (release task; #1307 is already merged).

## 1. Spec artifacts

- [x] T1 `specs/1325-publish-6.2.2-day-zero-fix/spec.md` — measurable
      success criteria SC-1..SC-8 mapped to the issue's acceptance
      criteria 1–4 (bump / publish / tarball smoke / drift guard), with
      the release-state note distinguishing the merged fix (repo) from
      the moved artifact fleet (pub.dev).
- [x] T2 `specs/1325-publish-6.2.2-day-zero-fix/plan.md` — technical
      context: pubspec version surface, dart pub publish / dry-run,
      tarball verification, existing publish-set export guard, drift
      guard design (triggers, no-pull_request rationale).

## 2. Release gates (verify before anything else)

- [x] T3 SC-1: `grep '^version:' pubspec.yaml` → `version: 6.2.2`
      (master, no edit needed — bump already merged via 956867fa).
- [x] T4 SC-2: pub.dev API `latest.version == 6.2.2`, published
      2026-09-08T20:03:48Z.
- [x] T5 SC-3: `dart pub publish --dry-run` — exit 65 (warnings-only
      variant), **0 errors**, benchmark files present in the upload set;
      4 pre-existing cosmetic warnings on paths untouched since the
      release commit (see tdd/verification.md SC-3 for the ACTUAL
      output — "Package validation passed" does not print while any
      warning exists).
- [x] T6 SC-4: download pub.dev 6.2.2 archive, `tar -tzf` shows
      `lib/src/core/benchmark/benchmark_contract.dart` + the full
      benchmark sets.

## 3. Behaviors first (red → green)

- [x] T7 `tdd/test-list.md` — one behavior per line, traced to FRs/SCs.
- [x] T8 RED (SC-6): scratch consumer pinned to published 6.2.1 —
      `dart pub get` + `dart compile exe` must FAIL with the issue's
      missing-file error naming `benchmark_contract.dart`; record
      verbatim as the artifact-level mutant the gate kills.
- [x] T9 GREEN (SC-5): `dart pub cache add zuraffa --version 6.2.2`;
      same scratch consumer on 6.2.2 — `dart compile exe` exits 0; run
      the scratch (imports `package:zuraffa/zuraffa.dart`, touches a
      benchmark-contract symbol) to prove the graph links end-to-end.
- [x] T10 GREEN: `dart test test/core/publish_set_exports_test.dart` —
      the master publish-set export guard stays green on this branch.

## 4. Implementation (non-behavioral / criterion 4)

- [x] T11 `.github/workflows/publish_drift.yml` — publish-drift guard:
      push-to-master + workflow_dispatch + daily schedule; compares
      `pubspec.yaml` version with pub.dev latest (curl + jq); exits 1
      with remedy message on drift; never on pull_request.
- [x] T12 SC-7 self-test: run the guard's check logic with a
      deliberately mismatched version → exit 1; against the live state →
      exit 0.

## 5. Hygiene + delivery

- [x] T13 format gate — CI scope (`dart format --set-exit-if-changed
      lib test`, the job the CI actually runs) exit 0 / 0 changed.
      `dart format .` flagged 3 PRE-EXISTING files outside that scope
      (corpus/** ×2, specs/1256 red_repro) — reverted untouched to avoid
      perturbing the generator-differential regression baselines;
      flagged for a future housekeeping task.
- [x] T14 SC-8: `git diff --name-only master -- lib/ bin/ tool/` empty;
      scratch apps + caches deleted; `df -h .` healthy.
- [x] T15 `tdd/verification.md` — red + green evidence verbatim
      (commands, exit codes, output excerpts), PROVED-vs-not statement
      per SC.
- [x] T16 Commit (Conventional Commits, `chore(1325):`), push branch,
      open PR closing #1325 with dry-run + tarball evidence in the body.

## Verification commands (per gate)

```
grep '^version:' pubspec.yaml
curl -s https://pub.dev/api/packages/zuraffa | jq -r .latest.version
dart pub publish --dry-run
tar -tzf zuraffa-6.2.2.tar.gz | grep benchmark_contract.dart
dart test test/core/publish_set_exports_test.dart
dart format .
git diff --name-only master -- lib/ bin/ tool/
```
