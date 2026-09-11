# TDD Verification — BUG 1511 (unexpressible message drift, bug 657 assertion)

- **Date**: 2026-09-12
- **Branch**: `fix/1511-unexpressible-message-drift`
- **Baseline**: `master` @ `03cdf45b`
- **Toolchain**: Dart SDK 3.13.3 (stable) — satisfies `pubspec.yaml` `sdk: ^3.11.0`
- **Machine**: Linux x86_64 container, 9.9 GB disk (chunked runner used per
  `dart_test.yaml` guidance for small agents)

> FRESH from real runs — every result below was produced by the exact command shown,
> in the order shown, on the final state of the branch.

## 0. Environment preparation

```
git clone https://<token>@github.com/arrrrny/zuraffa.git zuraffa
git checkout -b fix/1511-unexpressible-message-drift
dart pub get                       # root package resolves; dependency_overrides absent (comment-only)
```

`specify init zuraffa --integration zed --ignore-agent-tools --force --non-interactive`
run from the workspace root; the CLI version-drift it introduced in
`.agents/skills/*` and `.specify/integrations/*` was reverted, and the single
clobbered template `.specify/templates/spec-template.md` was restored via
`git checkout --`. `specify extension add bug` / `add tdd`: both extensions were
already installed and enabled (tdd v1.1.2) — no force-overwrite performed.

## 1. RED (pre-fix reproduction, baseline test file)

```
$ dart test --preset=all test/plugins/tdd/make_command_test.dart -n "bug 657"
00:08 +0 -1: … bug 657: an unexpressible make names the verb and the stub path … [E]
  Expected: contains 'no generator for \'provision\''
  Actual: 'zfa tdd make: cannot plan a generation for behavior "B-042". behavior "B-042" requires an implementation the zuraffa generation pipeline cannot express: no generator surface maps the behavior description "provision bespoke DSL syntax with no generator surface" to a `zfa entity create` / `zfa make` / `zfa build` invocation. File a zuraffa gap per the STOP-ON-ROADBLOCK policy.'
  …
  Which: does not contain 'no generator for \'provision\''
00:18 +1 -1: Some tests failed.
Exit code: 1
```

Result: **RED confirmed** — exactly the reported drift (T1 fails, T2 passes).
Full verbatim capture: `.specify/bugs/1511-unexpressible-message-drift/red-evidence.md`.

## 2. GREEN (after test-only fix)

```
$ dart test --preset=all test/plugins/tdd/make_command_test.dart -n "bug 657"
00:00 +0: loading test/plugins/tdd/make_command_test.dart
00:00 +0: US4 — misfire-stop on unexpressible behaviors bug 657: an unexpressible make phrases the refusal in behavior terms — it names the behavior, quotes the full description, and cites the STOP-ON-ROADBLOCK policy
00:08 +1: US4 — misfire-stop on unexpressible behaviors bug 657: a render-type behavior plans the `tdd func` step through the pipeline (no longer unexpressible)
00:16 +2: All tests passed!
Exit code: 0
```

Result: **GREEN — 2/2 passed, exit 0.**

## 3. No new failures — full fast suite, chunked

Per `dart_test.yaml` ("Even the fast tier … compiles the whole tree's kernel into a
~6.5 GB cache … use the chunked runner"), the suite was run with the repo's own
chunked semantics (`tools/run_tests_chunked.sh` logic: one folder per chunk,
`--exclude-tags flutter`, kernel caches cleared between chunks, "No tests ran"
folders counted as SKIP):

```
chunks with verdict: 103
  PASSED : 98   (incl. test/plugins/tdd/commands — 518 tests, the changed file's chunk)
  SKIPPED: 15   (no fast-tier tests in folder: test/benchmark, test/integration, test/core/proof, test/plugins/tdd/scenarios, test/tdd/077-make-engine-preset, …)
  FAILED : 0
Final line: ALL CHUNKS PASSED
```

Result: **no new failures**; every chunk has exactly one verdict (programmatic
diff of the chunk list vs the results log).

## 4. Static analysis + format

```
$ dart analyze $(git diff --name-only HEAD -- '*.dart' | tr '\n' ' ')
Analyzing make_command_test.dart...
No issues found!

$ dart format --output=none --set-exit-if-changed test/plugins/tdd/make_command_test.dart
Formatted 1 file (0 changed) in 0.04 seconds.   # exit 0
```

`dart format .` on the whole tree would reformat exactly one PRE-EXISTING,
out-of-scope file (`tool/generate_openwiki_cli_docs.dart`) under the newer formatter;
it was intentionally left untouched to keep the fix scoped to the test file. The
changed file itself is format-clean.

## 5. Diff scope

```
$ git diff --stat
 test/plugins/tdd/make_command_test.dart | 27 +++++++++++++++++----------
 1 file changed, 17 insertions(+), 10 deletions(-)
```

Only the test file differs from baseline. No `lib/` change, no state-machine change.

## 6. Cache hygiene

`.dart_tool/test/` and `$TMPDIR/dart_test.kernel.*` were cleared before the analyze
run and again after the final verification run (disk stayed at ~16% used
throughout).

## Verdict

| Gate | Status |
| --- | --- |
| RED reproduced on baseline | PASS |
| GREEN after test-only fix | PASS |
| Chunked fast suite, no new failures | PASS (103 chunks, 0 failed) |
| `dart analyze` no new warnings | PASS |
| Format clean (changed file) | PASS |
| Diff scoped to `make_command_test.dart` | PASS |
