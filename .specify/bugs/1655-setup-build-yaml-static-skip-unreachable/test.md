# Bug Test: #1641's static first-build skip is unreachable for zfa setup-created apps

- **Slug**: 1655-setup-build-yaml-static-skip-unreachable
- **Tested**: 2026-09-15 (this session)
- **Fix report**: ./fix.md
- **Verification**: ../tdd/verification.md (real runs), ./red-evidence.md (pre-fix)

## What was verified

The `tdd.verify` audit ran against the working tree on
`fix/1655-setup-build-yaml-static-skip-unreachable` with Dart 3.13.4
(stable, linux_x64). Static analysis, formatting, the targeted suites for
every modified file, and the fast-tier neighbor sweeps for the two touched
packages (`tdd/services`, `commands`) all executed for real in this session;
counts below are the runner's own output, not estimates.

## Acceptance criteria → evidence

1. **Fresh app's first refactor skips the build pass when no annotated files
   exist (even with build.yaml present)** — PROVED.
   `test/plugins/tdd/services/build_relevance_test.dart`:
   "a fresh app with the pristine zfa setup build.yaml skips the first build
   statically (issue #1655 — the reported bug)" was RED pre-fix
   (`Actual: <null>` — the gate ran the build; ./red-evidence.md) and GREEN
   post-fix (returns `staticFirstBuildSkippedNote`). The scratch fixture is
   the reported app shape: `zfa setup`'s exact build.yaml content + plain
   Dart under lib/test, no `.dart_tool/`, zero annotations.
2. **User-authored build.yaml still forces the build** — PROVED.
   Two shapes, both green: the pre-existing #1634 test (custom
   `targets:` content — user-authored) and the new "a MODIFIED
   setup-generated build.yaml runs the first build" test (the template plus
   a user edit — the exact-match contract catches a single-byte divergence).
3. **Entrypoint AOT compile eliminated or paid during setup** — PROVED for
   the static-skip half: on the reported shape the gate never spawns
   `zfa build`, so `dart compile aot-snapshot` of build.dart is not reached
   (the unit gate's note IS that decision; the compile subprocess itself was
   not exercised here — the fix removes it from the path rather than
   re-timing it).
4. **Incremental freshness logic unchanged** — PROVED by construction and by
   tests: the marker-mtime path (rules 2–6) has zero diff hunks
   (`git diff` touches only the static-path trigger, docs, note text, and
   the template string), and the entire pre-existing #1624/#1634 suite —
   including every `writeMarker()` incremental test — stayed green
   unchanged: `test/plugins/tdd/services/` → `01:40 +1151: All tests passed!`.

## Static analysis & formatting

```
dart analyze lib/src/plugins/tdd/services/build_relevance.dart \
             lib/src/core/dependencies/dependency_wirer.dart \
             test/plugins/tdd/services/build_relevance_test.dart \
             test/core/dependencies/dependency_wirer_test.dart
→ No issues found!

dart format --output=none --set-exit-if-changed .
→ Formatted 2866 files (0 changed)   (exit 0 — no remaining formatting diffs)
```

## Test runs (this session, real)

| Command | Result |
|---------|--------|
| `dart test test/plugins/tdd/services/build_relevance_test.dart` | `00:00 +31: All tests passed!` (4 new + 1 re-commented; RED pre-fix: `+30 -1`) |
| `dart test test/core/dependencies/dependency_wirer_test.dart test/commands/build_yaml_guard_test.dart test/commands/builder_dependency_preflight_test.dart test/plugins/tdd/services/refactor_passes_test.dart` | `00:05 +45: All tests passed!` |
| `dart test test/commands/build_command_unit_test.dart --preset=all` (slow-tagged, writes the template) | `00:19 +48: All tests passed!` |
| `dart test test/plugins/tdd/services/ test/core/dependencies/` | `01:40 +1151: All tests passed!` |
| `dart test test/commands/` | `06:11 +401: All tests passed!` |

## Unrelated pre-existing findings

- The whole-repo analyzer baseline carries ~106 info-level lints (style only,
  0 errors / 0 warnings) — the pre-existing drift #1626/#1636 verifications
  already recorded; none from the changed files.
- `example/analysis_options.yaml` cannot resolve `package:flutter_lints/`
  on this cloud agent (no Flutter SDK); unrelated to this fix and not part
  of the fast tier.

## Verdict

All four acceptance criteria proved at the gate level; no regressions in the
touched packages' fast tiers. PASS.
