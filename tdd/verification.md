# tdd.verify — Bug #1470 artifacts.json silently swallows corruption

- **Verified**: 2026-09-13, this session, on
  `fix/1470-artifacts-json-corruption-silent` (working tree, pre-push)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64
- **Scope**: `lib/src/plugins/tdd/services/artifact_registry.dart` (+28/−2)
  and the new
  `test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart`,
  then the chunked fast-suite sweep below.

## Verdict: PASS

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/services/artifact_registry.dart \
             test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart
→ No issues found!

dart analyze            (whole repo)
→ 112 issues found      (all `info`)
→ errors/warnings: 0    (baseline: 0 — no new warnings)
```

The whole-repo count is identical to the pre-change baseline measured on
this branch's parent state (112 info lints, 0 errors, 0 warnings).

## 2. The bug suite (REAL run in this session)

```
dart test test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart
→ 00:00 +5: All tests passed!
```

REQUIRED checks — the issue's expected behaviors are PROVED by real runs,
not inspection:

- **Corrupt file is loud (U-1470-a1/a3)**: `loadAll` and `findRecord` on a
  truncated/garbled `artifacts.json` throw `ArtifactRegistryCorruptException`
  — pre-fix they returned `[]`/`null` silently (probe RED-1).
- **No re-registration through corruption (U-1470-a2)**: `register` on a
  corrupt registry throws; the corrupt bytes are untouched on disk — pre-fix
  the call returned `Ownership.created` and the rewrite destroyed the prior
  records (probe RED-2/RED-3).
- **Actionable message (U-1470-a4)**: the thrown message contains
  `artifacts.json`, the full `registryPath`, and a recovery prescription.
- **Missing ≠ corrupt (U-1470-a5)**: absent registry still loads as `[]`
  (FR-012 unchanged).
- **RED honesty**: pre-fix probe output and the compile-level RED are
  preserved in `.specify/bugs/1470-artifacts-json-corruption-silent/red-evidence.md`.

## 3. Registry-adjacent suites (one command, real run)

```
dart test test/plugins/tdd/services/artifact_registry_test.dart \
          test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart \
          test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart \
          test/plugins/tdd/services/mutation_scope_test.dart \
          test/plugins/tdd/services/spec_fuzz_auditor_test.dart \
          test/plugins/tdd/services/behavior_kind_trace_test.dart \
          test/plugins/tdd/services/mutation_auditor_test.dart
→ 00:01 +68: All tests passed!
```

## 4. Chunked fast-suite sweep (repo policy, real runs)

`dart_test.yaml` on this repo: the default `dart test` suite is the FAST
tier; slow tiers are tag-excluded and a whole-tree single invocation
overflows small disks (kernel cache), so the sanctioned path is
`tools/run_tests_chunked.sh` semantics — per-folder chunks, kernel cache
cleared between chunks, flutter-tagged tests excluded. All runs below are
real `dart test <chunk> --exclude-tags flutter` invocations this session.

- **107 chunks PASSED, 6,946 tests passed, 0 genuine failures.**
- 5 folders correctly SKIP ("No tests ran"): every test in them carries a
  slow-tier tag (`slow` / `integration` / `benchmark`) which the fast tier
  excludes by design — the repo script treats this as SKIP, not failure
  (verified per-folder: `@Tags(['slow'])` etc. on every contained test).
- Highlight chunks (pass counts from the run log):

| chunk | result |
| ----- | ------ |
| test/plugins/tdd/commands | +546 passed |
| test/plugins/tdd/services (root files, incl. the new suite + artifact_registry_test) | +905 passed |
| test/plugins/tdd (root files, incl. bug_1357 reanchor) | +519 passed |
| test/plugins/tdd/models | +81 passed |
| test/plugins/tdd/theater | +15 passed |
| test/commands | +375 passed |
| test/simulation | +210 passed |
| test/core (root files) | +465 passed, 1 skipped |
| test/zap | +76 passed |

One runner artifact, not a test failure: my chunk list carried a trailing
blank line, producing one `dart test ""` → `Failed to load ""` entry. It is
the empty path, not a test; every real chunk passed. (The committed repo
runner `tools/run_tests_chunked.sh` builds its list differently and is not
affected; I did not modify it — the one-file lib/ constraint stands.)

## 5. Format + hygiene

```
dart format lib/.../artifact_registry.dart test/.../bug_1470_artifacts_json_corruption_test.dart
→ Formatted 2 files (1 changed)   # one file reformatted, then:
dart format --output=none --set-exit-if-changed <same two files>
→ exit 0 (clean)
→ bug suite re-run after formatting: +5: All tests passed!
```

- Kernel caches cleared before/after sweeps
  (`rm -rf .dart_tool/test/`, `rm -f $TMPDIR/dart_test.kernel.*`).
- Disk headroom after the sweep: 8.0G free (no leakage).
- `git status` vs origin/master: 1 lib file modified, 1 test file added,
  artifacts + tdd docs added. No stray files.

## 6. Environment caveats

- No Flutter SDK on this host: flutter-tagged tests are excluded by the
  repo's own chunked-runner policy; `example/` is not resolvable here and
  is untouched by this fix.
- Slow tiers (regression/integration/property/benchmark presets) not run —
  per `dart_test.yaml` header they fill several GB under /tmp on small
  agents; the fast tier is the sanctioned CI/cloud baseline.
