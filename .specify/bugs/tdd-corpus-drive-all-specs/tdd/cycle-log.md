# Cycle log — tdd-corpus-drive-all-specs (#836)

Session-driven bug TDD cycle (red → green → verify) on branch
`fix/836-tdd-corpus-drive-all-specs`, base `17a40434`.

## Cycle 0 — RED (the bug, observed)

- Command: `dart test test/plugins/tdd/commands/corpus_run_plan_test.dart`
- Outcome: **18 tests run, 3 passed / 15 failed** — the red evidence is the
  failing suite itself, saved verbatim at `tdd/red-evidence.log` (untracked:
  the repo's `*.log` gitignore policy; the counts and failing reasons below
  quote it).
- The failures are the bug, for the right reason:
  - `Could not find an option named "--plan"` — the plan input does not
    exist (remediation 1 impossible);
  - manifest-order driving with no topological ordering (B-001/B-003 red);
  - no `spec_hash` in progress, no drift exit (B-009/B-010 red);
  - no plan-gap ledger entries, no `order=` token (B-012/B-016 red);
  - B-018 (no-plan manifest order) passed pre-fix — the existing FR-001
    contract was already green and stayed green.

## Cycle 1 — GREEN (corpus plan driver)

- Command: same suite after implementing
  `models/corpus_plan.dart` (parse + stable Kahn order),
  `--plan` on `CorpusRunCommand`, `FeatureProgress.specHash`, the drift
  gate (exit 3), plan-gap reconciliation in the gap ledger, fixture
  helpers (`writePlan`/`writeSpec`/`writeTestList`).
- Outcome: **18 passed / 0 failed**.
- Middle-run findings fixed during the loop (observed red, then green):
  - a plan with no edges/criteria was wrongly rejected — made a valid
    no-op (B-002);
  - TUPEC dependency edges keyed by plan id were unresolved against the
    manifest name mapping (B-003);
  - the drift test's baseline counted run-1's legitimate drive of
    f2-next as a violation — test corrected to diff the call log across
    runs (evidence integrity: the fix went into the TEST, not the gate).

## Regression evidence

- All pre-existing corpus suites re-run:
  - `corpus_run_command_test.dart` (slow tag, `--preset=all` selection):
    **23 passed / 0 failed**;
  - `corpus_status_command_test.dart`, `corpus_audit_command_test.dart`,
    `corpus_manifest_store_test.dart`, `corpus_progress_store_test.dart`,
    `corpus_step_runner_test.dart`, `corpus_command_test.dart`:
    **54 passed / 0 failed** combined.
- Full fast suite: `tools/run_tests_chunked.sh` (chunked per directory,
  kernel caches cleared between chunks) — see verification.md for counts.
- `dart analyze` on the touched files: no issues.
