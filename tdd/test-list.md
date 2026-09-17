# TDD test list — Bug #1664 first refactor after a master bump compiles the zfa CLI (~85s) even when the parent runs from a current installed binary

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1664-b1 | test/cli/zfa_executable_1664_installed_binary_reuse_test.dart | unit | a current installed binary (`zfa.build_commit` == checkout HEAD) is returned for the canonical `bin/zfa.dart` candidate — the ~85s compile never happens (the issue's bug) | issue #1664 criteria 1–2 | RED → GREEN |
| U-1664-b2 | test/cli/zfa_executable_1664_installed_binary_reuse_test.dart | unit | a marker that disagrees with the checkout HEAD forbids the reuse — the stale-install guard | criterion 3 | RED → GREEN |
| U-1664-b3 | test/cli/zfa_executable_1664_installed_binary_reuse_test.dart | unit | a Dart-VM running executable never reuses (source/test drivers keep the compile-cache contract); rejected before any git probe | criterion 4 (steady state) | RED → GREEN |
| U-1664-b4 | test/cli/zfa_executable_1664_installed_binary_reuse_test.dart | unit | no `zfa.build_commit` marker (pre-#1184 install, the `scripts/zfa` cache artifact) — reuse is unprovable, compile as today | fail-open soundness | RED → GREEN |
| U-1664-b5 | test/cli/zfa_executable_1664_installed_binary_reuse_test.dart | unit | an empty/whitespace marker — reuse is unprovable | fail-open soundness | RED → GREEN |
| U-1664-b6 | test/cli/zfa_executable_1664_installed_binary_reuse_test.dart | unit | a failed git probe (not a repo, exit 128) falls through to the compile path | fail-open soundness | RED → GREEN |
| U-1664-b7 | test/cli/zfa_executable_1664_installed_binary_reuse_test.dart | unit | a non-canonical candidate (a custom `--zfa-bin` fixture script) never reuses the zfa binary; rejected before any git probe | fix-scope guard | RED → GREEN |
| U-1664-b8 | test/cli/zfa_executable_1664_installed_binary_reuse_test.dart | unit | a missing running executable never reuses | fail-open soundness | RED → GREEN |
| U-1664-b9 | test/cli/zfa_executable_1664_installed_binary_reuse_test.dart | unit | a VM-driven cache miss still compiles through the injected runner; the compiler fake never sees a git argv (the probe rides its own runner) | wiring unchanged (U2 contract) | GREEN |

Guard pins (pre-existing, unchanged and green against the fix):

| id | suite | description |
| -- | ----- | ----------- |
| U2/U3/U4/U5 | test/cli/zfa_executable_test.dart | compile-on-miss argv, fresh-cache reuse (criterion 4's cache-wins-first), lib/ and pubspec staleness — the compile-cache contract the probe must not disturb |
| #1636 B1–B5 | test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart | the StepRunner running-binary tier order — untouched |
| #1645 | test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart | the PipelineRunner running-binary tier — untouched |
| #1184 | test/cli/binary_staleness_test.dart | the `zfa.build_commit` marker reader this fix imports (`zfaBuildCommitMarker`) — unchanged |

## Red evidence (pre-fix, this session)

Verbatim runs preserved in
`.specify/bugs/1664-first-refactor-cli-compile/red-evidence.md`:

- Suite 1 (new, pre-fix):
  `dart test test/cli/zfa_executable_1664_installed_binary_reuse_test.dart`
  → `00:00 +0 -1: Some tests failed.` — the file fails to LOAD:
  `Error: Member not found: 'ZfaExecutable.currentInstalledBinary'`. The
  compile-error red is the honest first red for a NEW seam: it proves the
  child binary resolution has NO installed-binary awareness — the issue's
  root cause. With the API's logic in place pre-fix, U-1664-b1 would have
  returned null (compile as today) instead of the running binary.

## Green evidence (post-fix, this session)

- `dart test test/cli/zfa_executable_1664_installed_binary_reuse_test.dart`
  → `00:00 +9: All tests passed!`
- `dart test test/cli/zfa_executable_test.dart
  test/cli/binary_staleness_test.dart
  test/plugins/tdd/services/step_runner_test.dart
  test/plugins/tdd/services/bug_1636_running_binary_tier_test.dart
  test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart
  test/plugins/tdd/services/refactor_passes_test.dart`
  → `00:16 +82: All tests passed!`
- `dart test test/cli/ test/core/ --exclude-tags "flutter || e2e"`
  → `00:57 +901 (1 skipped): All tests passed!`
- `dart test test/plugins/tdd/services/`
  → `01:44 +1135: All tests passed!`
