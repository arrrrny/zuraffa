# TDD Verification — bug `1184-stale-binary-warning`

Generated fresh from the REAL runs of this branch (`fix/1184-stale-binary-warning`,
commit `05def06e`). Every command below was actually executed against this
checkout (Dart SDK 3.13.3 stable, linux_x64); outputs are quoted verbatim from
the run, not reconstructed.

## Gate

- gate: `passed`
- basis: the behavior suite `test/cli/binary_staleness_test.dart` was written
  BEFORE the implementation and has REAL red (`+0 -1`) and green (`+16`)
  evidence below; the touched-area suites are green (`+215`); the full
  chunked fast suite is green (90 chunks: 3506 passed / 0 failed /
  6 skipped-by-design); the fix was proven END-TO-END through a REAL compiled
  binary produced by `scripts/rebuild.sh` (fresh → silent; HEAD moved → the
  exact issue-spec'd warning on stderr, stdout and exit codes unchanged).

## Test-first evidence

- The suite `test/cli/binary_staleness_test.dart` (16 tests: U1–U15 plus
  sub-behaviors U4b, U10) was committed-in-intent BEFORE any implementation
  existed: `lib/src/cli/binary_staleness.dart` did not exist and
  `CliRunner`/`DoctorChecksRunner` had no injection seams.
- Red proof (before implementation):
  `dart test test/cli/binary_staleness_test.dart`
  → `00:00 +0 -1: Some tests failed.` — the suite fails to load with exactly
  the missing-surface compile errors:
  - `Error: Method not found: 'BinaryStaleness'`
  - `Error: No named parameter with the name 'staleness'` /
    `'onStalenessWarning'` (CliRunner constructor)
  - `Error: No named parameter with the name 'binaryDir'` (DoctorChecksRunner)
- Green proof (after implementation):
  `dart test test/cli/binary_staleness_test.dart` → `00:00 +16: All tests
  passed!` (re-verified after `dart format .` — still `+16`).

## Acceptance-criteria coverage (U-map)

- U1/U2 binary-dir derivation: null under the test VM (source run), explicit
  injection wins (simulates the installed binary).
- U3 marker read: trims; missing marker → null (never warn on unprovable
  input).
- U4/U4b/U5 checkout detection: walks up to the nearest pubspec with
  `name: zuraffa`; `name: zuraffa_example` does NOT match; null outside any
  zuraffa worktree.
- U6 no marker (pre-#1184 install) → silent. U7 marker == HEAD → silent.
- U8 marker != HEAD → EXACTLY ONE warning line containing `⚠️`,
  `installed zfa (<short-build-commit>)`, `this checkout (<short-head>)`,
  `run scripts/rebuild.sh`.
- U9 outside a zuraffa checkout → silent even with a marker. U10 zuraffa
  checkout with unresolvable git HEAD → silent.
- U11 `CliRunner.run()` emits the warning exactly once before dispatch
  (`--version` still prints; stdout unchanged). U12 `runCapturing()`
  (MCP-embedded protocol path) emits nothing.
- U13/U14/U15 `zfa doctor` `binary-staleness` check: WARN with
  `suggestedFix: scripts/rebuild.sh` when stale; PASS when fresh; SKIP when
  running from source.

## Real end-to-end proof (REAL compiled binary)

1. `ZURAFFA_BIN=<tmp-install> bash scripts/rebuild.sh` (commit `05def06e`):
   compiles both binaries and records the build commit —
   `✅ recorded build commit 05def06efc0d (zfa.build_commit)`.
2. Fresh binary run inside the checkout (`zfa --version`, marker == HEAD):
   stdout = `zfa v6.1.0` / `Zuraffa Code Generator`; stderr EMPTY; exit 0.
   No false alarm.
3. HEAD moved past the build point (temporary empty commit, since dropped):
   `zfa --version` → exit 0, stdout unchanged, and stderr shows the EXACT
   issue-spec'd line:
   `⚠️ installed zfa (05def06efc0d) is older than this checkout (d1bfce960945) — run scripts/rebuild.sh`
4. `zfa doctor --format json` in the same state:
   `{"id":"binary-staleness","status":"warn","detail":"installed zfa
   (05def06efc0d) is older than this checkout (d1bfce960945)",
   "suggested_fix":"scripts/rebuild.sh","fixed_items":[]}` — and doctor's
   exit contract is unchanged (warn is `ok`).
5. Temp commit reset; artifacts cleaned; tree back to `05def06e` clean.

## Regression gates

- Touched-area suites: `dart test test/commands/doctor_checks_test.dart
  test/cli/` → `00:23 +215: All tests passed!` (one honest intermediate
  failure during the cycle: U11 of doctor_checks_test pins the named-check
  id registry; the set gained `binary-staleness` by design and the pin was
  updated — that registry IS the contract under test).
- Full chunked fast suite (`tools/run_tests_chunked.sh` logic, chunked
  foreground because background processes are reaped between tool calls in
  this environment; identical per-chunk invocation `dart test <dir>
  --exclude-tags flutter < /dev/null` with kernel cleanup between chunks):
  90 chunks → **84 PASS / 6 SKIP / 0 FAIL**, cumulative **3506 tests passed,
  0 failed**. Skips are the runner's designed empty-fast-tier folders:
  `test/benchmark`, `test/core/dependencies`, `test/core/proof`,
  `test/integration`, `test/plugins/tdd/scenarios`,
  `test/tdd/077-make-engine-preset`.
- `dart analyze`: **134 issues at HEAD before the change == 134 issues after**
  (all pre-existing, in `examples/` and `lib/tdd/0966-*` fixtures); the five
  changed Dart files report `No issues found!`.
- `dart format .`: the five changed files are format-clean
  (`--output=none --set-exit-if-changed` → exit 0; "Formatted 5 files
  (0 changed)"). `git diff --stat` shows only the intended files. Note:
  HEAD has PRE-EXISTING drift in `examples/todo_tdd/test/tdd/{a1,u1,u3}_test.dart`
  under the current formatter; left untouched to keep the PR minimal.

## Mutation-style strength check

- A stub that warns on every invocation dies at U1/U6/U7/U9/U10/U12 (each
  silence rule is individually pinned).
- A stub that never warns dies at U8/U11/U13 (and the end-to-end proof).
- A multi-line or stdout-bound warning dies at U8 (one-line) and U11
  (stdout keeps the version line; warning arrives via the injected sink
  whose default writes to stderr).
- A wrong-commit display dies at U8's exact `contains` assertions on both
  short hashes (this caught a real test-helper bug during the cycle:
  `git commit` stdout is `[main abc…] message`, not the hash — the suite
  forced the helper to resolve hashes via `rev-parse`).
- A doctor check that FAILS on staleness dies at U13 (status `warn` pinned)
  and would flip the exit contract the U12/U13 doc pins.

## Known limitations (honest)

- Detection is COMMIT-based, per the issue's own telltale ("the snapshot was
  built from a commit that is NOT git rev-parse HEAD of the repo it is run
  inside"). Uncommitted working-tree changes are not detectable without
  mtime/content tracking, which would violate the minimal-warning
  constraint.
- Pre-#1184 installs have no marker and stay silent until the next
  `scripts/rebuild.sh` run (surfaced by `zfa doctor` as a SKIP with the
  exact remediation).
