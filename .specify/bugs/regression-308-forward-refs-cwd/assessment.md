# Bug Assessment: regression #308 forward-refs tests fail — zfa binary path resolved from polluted CWD

- **Slug**: regression-308-forward-refs-cwd
- **Created**: 2026-08-22
- **Source**: pasted text (regression suite run, `dart test --preset=regression`)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

All 6 assertions in `test/regression/issue_308_forward_refs_cyclic_test.dart`
fail in the regression run. The test invokes `zfa` as
`dart <zfaBin> <args>` and expects exit `0` (accept) or `1` (reject), but every
invocation returns **exit 254**. The smoke test fails harder:

```
ProcessException: No such file or directory
    Command: dart /tmp/zuraffa_issue336_UGYMFQ/bin/zfa.dart --help
  test/regression/issue_308_forward_refs_cyclic_test.dart 381:38
```

The other assertions show `Expected: <0>/<1>` but `Actual: <254>` (e.g. lines
103, 146, 205, 276, 333). 254 is what `dart` returns when the entrypoint script
cannot be located/run — i.e. `zfaBin` does not point at a real `bin/zfa.dart`.

Failing assertions: entity create WITH/without `--allow-forward-refs`; cyclic
batch `Customer(List<Order>)` / `Order(Customer?)`; add-field WITH/without
`--allow-forward-refs`; `zfa binary is runnable (smoke)`.

## Symptom

`issue_308` cannot execute `zfa` because it resolves the zfa executable from
the process working directory, which is polluted by other regression tests that
mutate the shared CWD. `zfaBin` ends up pointing at a non-existent
`<tempdir>/bin/zfa.dart`, so `dart` exits 254 / throws `ProcessException`. The
forward-refs feature behavior is therefore never actually exercised.

## Reproduction

1. Run the regression suite (parallel/sequential test files share one VM
   process and thus one OS CWD).
2. `issue_336_view_route_id_type_test.dart` (and `cli_command_test.dart`,
   `issue_348_preset_crud_datasource_di_test.dart`,
   `plugin_command_add_test.dart`) execute `Directory.current = tempDir.path`
   at some point.
3. `issue_308_forward_refs_cyclic_test.dart` evaluates, at module load:
   `final _zfaRoot = Directory.current.path;` then
   `zfaBin = p.join(_zfaRoot, 'bin', 'zfa.dart');` (lines 47 / 62).
4. If CWD is already polluted (or points at a deleted temp dir) when #308
   loads, `zfaBin` = `<pollutedTemp>/bin/zfa.dart` (the observed
   `/tmp/zuraffa_issue336_…/bin/zfa.dart`) — a path that does not exist.
5. Every `runZfa([...])` → `dart <missing script>` → exit 254.

## Suspected Code Paths

- `test/regression/issue_308_forward_refs_cyclic_test.dart:47` —
  `_zfaRoot = Directory.current.path;` captured at module load (unreliable).
- `test/regression/issue_308_forward_refs_cyclic_test.dart:62` —
  `zfaBin = p.join(_zfaRoot, 'bin', 'zfa.dart');` builds a wrong path when
  `_zfaRoot` is polluted.
- `test/regression/issue_308_forward_refs_cyclic_test.dart:381` — smoke test
  `Process.run('dart', [zfaBin, '--help'], workingDirectory: _zfaRoot)` shows
  the bad path in the error.
- `test/regression/issue_336_view_route_id_type_test.dart:43` —
  `Directory.current = tempDir.path;` (and similar in `cli_command_test.dart`,
  `issue_348_…`, `plugin_command_add_test.dart`) — the pollution source.
- `test/helpers/project_root.dart:26` — `Future<String> findProjectRoot()`,
  the robust helper sibling tests already use; it resolves the repo root via
  package URI, NOT `Directory.current`.

## Root Cause Hypothesis

`issue_308` is the only regression test that resolves the zfa binary from
`Directory.current` at module load. Because `dart test` runs all test files in
one VM process that shares a single OS working directory, any test that does
`Directory.current = tempDir` (and does not perfectly restore it, or runs
concurrently) leaves the CWD polluted. When #308 evaluates its module-level
`_zfaRoot`, it captures the polluted/deleted CWD, so `zfaBin` is a non-existent
path. The 6 forward-refs assertions then fail with exit 254 / ProcessException
before the feature is ever tested. This is the **test-side twin of #321** —
both stem from unsafe reliance on `Directory.current` in a shared-CWD test
process. Confidence: **high** for the mechanism and the fix.

## Proposed Remediation

**Preferred (fix the test)**: In `issue_308_forward_refs_cyclic_test.dart`,
stop using `Directory.current` for the binary path. Import
`test/helpers/project_root.dart` and set
`zfaBin = p.join(await findProjectRoot(), 'bin', 'zfa.dart');` — exactly as
`issue_306`/`issue_313`/`issue_321` already do. Resolve `zfaBin` inside
`setUp` (not at module load) so it is always correct.

**Systemic (stop the pollution — same root cause as #321)**: tests that do
`Directory.current = tempDir` should reliably save/restore CWD in
`addTearDown` (not just `tearDown`) and never leave it pointing at a deleted
dir; ideally they should avoid mutating the shared process CWD entirely and
instead pass `workingDirectory` to subprocesses and resolve paths explicitly
(via `findProjectRoot()`). This also prevents the `PathNotFoundException`
crash fixed in #321.

**Files likely to change**:
- `test/regression/issue_308_forward_refs_cyclic_test.dart` (primary fix)
- `test/regression/issue_336_view_route_id_type_test.dart`,
  `test/regression/cli_command_test.dart`,
  `test/regression/issue_348_preset_crud_datasource_di_test.dart`,
  `test/commands/plugin_command_add_test.dart` (harden CWD save/restore)

**Tests to add or update**:
- After the path fix, the 6 forward-refs assertions actually run; confirm
  `--allow-forward-refs` accept/reject behavior and re-baseline expectations.
- Add a guard asserting `File(zfaBin).existsSync()` before spawning, so a
  future CWD regression fails loudly instead of with exit 254.

## Risks & Considerations

- The forward-refs *feature* itself is currently **unverified** — the path bug
  masks whether `zfa entity create/add-field --allow-forward-refs` behaves as
  the assertions expect. Once the test runs, it may surface a real feature bug
  distinct from this one.
- Changing module-load `Directory.current` usage to `setUp`-scoped
  `findProjectRoot()` is low-risk and matches existing sibling tests.

## Open Questions

- [NEEDS CLARIFICATION]: After the path fix, do the 6 forward-refs assertions
  pass, or do they reveal a separate real `#308` feature defect? That would
  warrant its own assessment.
