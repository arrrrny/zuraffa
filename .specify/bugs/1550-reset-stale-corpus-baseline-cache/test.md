# Test — #1550: reset invalidates the corpus baseline cache; compose refuses stale green premises

- **Slug**: 1550-reset-stale-corpus-baseline-cache
- **Suite**: `test/plugins/tdd/bug_1550_reset_stale_corpus_baseline_test.dart`
  (tagged `slow`; run with `dart test --preset=all <file>`)

## Test map

| Test | Level | Pins |
| ---- | ----- | ---- |
| B1 — reset deletes the corpus-wide cache and the feature-local run-baseline.json, and announces the invalidation | integration (CliRunner) | fix 1: the third store leaves the restart contract with the registry + run-state; announcement precedes acting; verdict stays `reset`, exit 0 |
| B1b — reset with no baseline caches on disk still resets cleanly | integration | fix 1 is idempotent: a clean tree reset neither fails nor fabricates invalidations |
| B2 — the post-reset run does NOT reuse the corpus-wide baseline | integration (fake zfa driver + suite spy) | fix 1 end-to-end: run 1 captures live (spy ×1, cache written), reset, run 2 shows NO `corpus-wide reuse` and the spy fires again (live re-capture) — the exact failure signature from the issue, inverted |
| B3 — a green unit whose registry record is absent is stale-evidence, not runner-error | integration (CliRunner on the real compose command) | fix 2: post-reset registry shape (A-001 re-generated, U-001 dropped, U-001 green cycle-log evidence surviving) → exit 1, `outcome=stale-evidence`, message names U-001 and the re-derive path, and NEVER `outcome=runner-error` |

## Result — GREEN (fresh run, real execution)

```
$ dart test --preset=all test/plugins/tdd/bug_1550_reset_stale_corpus_baseline_test.dart
00:03 +4: All tests passed!
```

## Regression verification (all real runs)

| Scope | Result |
| ----- | ------ |
| `dart analyze` on the changed files | No issues found! |
| `composition_targets_test.dart` + `compose_command_test.dart` | +24 All tests passed! |
| `baseline_cache_test.dart` + `bug_1380_reset_namespace_guard_test.dart` | +11 All tests passed! |
| `bug_1264_reset_done_state_phantom_test.dart` + `bug_1331_reset_half_state_test.dart` + `bug_840_recovery_commands_test.dart` | +14, −5 — all 5 failures pre-existing on pristine master (bug_840 expects the pre-#969 raw-JSON verdict line; fails identically without this branch's changes) |
| `bug_1162_subject_shape_test.dart` + `bug_1345_placeholder_re_drive_test.dart` + `bug_1331_make_adopted_re_drive_test.dart` + `bug_1324_resume_stale_artifacts_wedge_test.dart` | +34, −1 — the 1345 failure is the sandbox OOM guard killing the spawned compose child (`resource-limit exit -6`), reproduced identically on pristine master |
| `make_command_test.dart` + `corpus_run_plan_test.dart` + `bug_1512_acceptance_vacuous_composition_test.dart` | +34 All tests passed! |
| `test/plugins/tdd/json_flag_test.dart` | +15 All tests passed! |

## Constraint check

- Corpus cache fingerprint logic: untouched (`baseline_cache_test` green).
- Run state machine: untouched (`bug_1264`, `bug_1331`, `bug_1324` green).
- Reset ownership rules: untouched (`bug_1380`, `bug_840` reset cases behave
  identically to pristine).
