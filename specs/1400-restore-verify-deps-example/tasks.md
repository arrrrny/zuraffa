# Tasks — Spec 1400 restore verify deps in example

Dependency-ordered; MVP (the certification evidence) first.

- [x] T001. [behavior: B1] The shipped baseline declares the
      writer-canonical TDD pair (`mutation_test: ^1.8.0`,
      `coverage: ^1.15.1`) — asserted by the existing structural pin
      `test/package_sdk/bug_1369_example_tdd_baseline_test.dart`
      (GREEN at HEAD; recorded red baseline: the issue's filing state,
      where the merge had dropped the pair and the audit died with
      `Could not find package 'mutation_test'`). Traces FR-1/AS-1.
- [x] T002. [behavior: B2] The shipped baseline declares NO plain
      `test` (unresolvable pin stays out of Flutter consumers) — same
      pin, GREEN at HEAD; the contrary state is proven unresolvable
      empirically (plan.md solver transcript). Traces FR-2/AS-1.
- [x] T003. [behavior: B3] The committed evidence's scoped mutation
      audit reproduces at HEAD against the restored tree
      (`mutation_was_run: true`, killed=48, survived=8, score=0.8571,
      subjects restored byte-identical). Traces FR-3/AS-3/SC-002.
- [x] T004. Append the #1400 certification to the baseline's
      issue-reference comment chain in `example/pubspec.yaml`
      (comment-only data change). Traces FR-4.
- [x] T005. Hygiene: `dart analyze` clean on the changed surface;
      `dart format .` with zero remaining diffs; kernel-cache cleanup
      before/after the audit run. Traces SC-003.
