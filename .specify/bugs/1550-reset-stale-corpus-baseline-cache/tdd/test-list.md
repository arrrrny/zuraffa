# Test List — bug-1550-reset-stale-corpus-baseline-cache

Driven by the bug TDD cycle (red → green → verify). Suite:
`test/plugins/tdd/bug_1550_reset_stale_corpus_baseline_test.dart`
(tagged `slow` — spawns real driver runs against the fake zfa binary).

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| B1 | `tdd reset` invalidates the corpus-wide baseline cache (`.zfa/corpus/run-baseline.json`, spec 069 T004) and the feature-local `specs/<feature>/tdd/run-baseline.json`, announced before acting and reported in the verdict (`invalidated_caches`) | #1550 fix 1 | GREEN |
| B1b | `tdd reset` with no baseline caches on disk still resets cleanly (the invalidation is idempotent, no phantom failures) | #1550 fix 1 | GREEN |
| B2 | The run after a reset does NOT reuse the corpus-wide baseline: the live suite re-captures (no `corpus-wide reuse` line, suite spy invoked again) | #1550 fix 1 | GREEN |
| B3 | Compose refuses a green unit whose registry record is absent with `outcome=stale-evidence` (actionable: re-derive the artifacts), never `outcome=runner-error` | #1550 fix 2 | GREEN |

## Regression scopes exercised (all green after the fix)

- `test/plugins/tdd/services/composition_targets_test.dart` — U3 pins the
  sibling case: record PRESENT but subject file missing stays
  `missing-anchor-subject` (unchanged).
- `test/plugins/tdd/commands/compose_command_test.dart` — compose outcome
  matrix incl. `no-green-units` and `runner-error` paths (unchanged).
- `test/plugins/tdd/corpus_economics/baseline_cache_test.dart` — corpus
  cache write/read/reuse/fingerprint-miss mechanics (fingerprint logic
  untouched).
- `test/plugins/tdd/commands/bug_1380_reset_namespace_guard_test.dart`,
  `bug_1264_reset_done_state_phantom_test.dart`,
  `bug_1331_reset_half_state_test.dart`,
  `bug_1331_make_adopted_re_drive_test.dart`,
  `bug_1324_resume_stale_artifacts_wedge_test.dart`,
  `bug_1162_subject_shape_test.dart` — reset ownership/tombstone
  contracts (unchanged).
- `test/plugins/tdd/json_flag_test.dart` — `--json` registration +
  envelope shape (new `invalidated_caches` detail is additive).
