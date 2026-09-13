# TDD Verification — 1574-tdd-gen-relative-paths

- **Feature**: `.specify/bugs/1574-tdd-gen-relative-paths`
- **Verified**: 2026-09-14, on branch `fix/1574-tdd-gen-relative-paths`
- **Engine**: `dart test` (Dart 3.13.3 stable), per `.specify/memory/tdd-profile.md`
- **Provenance**: REAL RUNS on this machine — no copied, stubbed or
  back-dated results. Every number below is from an actual command executed
  during this session (transcripts in the session log; raw evidence lines
  quoted verbatim).

## Test list outcomes (tdd/test-list.md → DONE)

| id | behavior | result |
|----|----------|--------|
| A1 | specs lane: fresh gen persists relative record paths | **pass** |
| A2 | bug lane: fresh gen persists relative record paths (the live leak) | **pass** |
| A3 | gen's emitted record carries relative paths (both lanes) | **pass** |
| A4 | re-gen of a relative prior record reuses without ownership conflict (bug lane) | **pass** |
| A5 | committed-registry census: zero absolute path fields after migration | **pass** |

## Red evidence (pre-fix, 2026-09-13)

Command: `dart test test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart`
Result: `00:00 +1 -5: Some tests failed.`

Verbatim refusal reproduced (bug-lane reuse, A4):

```
zfa tdd gen: ownership conflict — OwnershipConflict: the registry test path
"test/tdd/100-feature-one/a1_test.dart" does not match
"/tmp/bug_1574_gen_rel_test_XDJRPW/test/tdd/100-feature-one/a1_test.dart".
Refusing to overwrite non-owned content. Run `zfa tdd doctor <feature>` for
the deterministic diagnosis of the path disagreement.
```

(the issue's `ownership conflict: the registry test path "test/tdd/..." does
not match "/home/z/my-project/zuraffa/..."` — same defect, different machine
root)

Bug-lane fresh-gen persist (A2) stored
`/tmp/…/test/tdd/010-demo-bugfix/a1_test.dart` — the machine-absolute form,
reproducing the live writer behind the committed
`.specify/bugs/cycle-log-phantom-sections` drift.

## Green evidence (post-fix, 2026-09-14)

1. Guard suite:
   `dart test test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart`
   → `00:00 +6: All tests passed!`
2. Targeted regression battery (6 suites: #1574, #1397, #1573,
   artifact_registry, #1357 reanchor, #1470 corruption):
   → `00:02 +46: All tests passed!`
3. Full changed-scope chunk: `dart test test/plugins/tdd/commands/`
   → `05:34 +584: All tests passed!`
4. `dart analyze lib/src/plugins/tdd/commands/gen_command.dart
   lib/src/plugins/tdd/services/artifact_registry.dart
   test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart`
   → `No issues found!`
5. Format gate: `dart format --output=none --set-exit-if-changed lib/
   test/plugins/tdd/commands/` → `Formatted 1345 files (0 changed)`,
   exit 0.
6. Wider fast tier (repo's disk-safe `tools/run_tests_chunked.sh`, kernel
   cache cleared per chunk): all chunks pass except the pre-existing
   environment failures enumerated in test.md (Flutter-SDK-dependent suites;
   the honest-red 077 stub proven failing on pristine master 82b9ffe2; the
   slow-tier scenarios folder excluded by dart_test.yaml policy on cloud
   agents).

## Refactor notes

Post-green cleanup: the empirical probe scripts
(`tool/probe_registry.dart`, `tool/probe_gen_baseline.dart`) were removed
from the package; the migration tool lives outside the repo
(`scripts/migrate_1574_registries.py` in the agent workspace — it is a
one-shot data fix, not repo tooling, and its effect is pinned by the A5
census guard). Formatter pass applied; no logic changed after green.

## Verdict

GREEN. The corrupting writer is fixed, the drifted data is migrated, the
reuse path against the run driver's form is conflict-free, and the guard
suite keeps it that way.
