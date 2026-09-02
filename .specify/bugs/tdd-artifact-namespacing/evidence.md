# Bug #827 TDD Evidence — red → green → verify

This file is the per-bug cycle-log equivalent (the bug-triage extension stores
per-bug records under `.specify/bugs/<slug>/`; there is no
`specs/<feature>/tdd/cycle-log.md` for a bug branch). Every command below was
run in the fix session, against the working tree of branch
`fix/827-tdd-artifact-namespacing`, with Dart 3.13.3 (stable).

## RED (pre-fix)

Command:

```sh
dart test test/plugins/tdd/commands/gen_namespacing_827_test.dart --preset=all
```

Result: `00:00 +1 -9: Some tests failed.` — 1 passed (the pre-existing
flat-layout idempotency guard, which stays green by design), 9 failed.

The failure that IS the bug (feature-2 gen after feature-1 gen — flat paths
collide, the registry is per-feature):

```
  Expected: contains 'test/tdd/100-feature-one/a1_test.dart'
    Actual: 'behavior_id: A1\n'
            'source_criterion: FR-007\n'
            'test_path: /tmp/gen_namespacing_test_QAAYEE/test/tdd/a1_test.dart\n'
            'subject_path: /tmp/gen_namespacing_test_QAAYEE/lib/tdd/a1_subject.dart\n'
```

i.e. gen still wrote the feature-agnostic flat path; the second feature's gen
then hit `ownership conflict: ... exists on disk but the registry has no
recorded ownership` (FR-008 refusing a file feature-1 owns). The migration
family also failed red (`Could not find an option named "--project"` —
`zfa tdd migrate-paths` did not exist).

Full red output retained in session logs; the failing set:

- feature-1 then feature-2 with the same behavior id: both gens succeed and
  artifacts live under per-feature directories
- the generated test imports its namespaced sibling subject via a relative
  path that resolves on disk
- ownership guardrail still refuses a foreign file at a namespaced path
- migrate-paths ×6: move+rewrite, idempotent, refuse-taken-target,
  missing-file fail-honest, dry-run, already-namespaced untouched

## GREEN (post-fix)

Command (same file):

```sh
dart test test/plugins/tdd/commands/gen_namespacing_827_test.dart --preset=all
```

Result: `00:00 +10: All tests passed!`

Regression scopes re-run in the same session (all green unless noted):

| Scope | Command | Result |
| --- | --- | --- |
| gen suite (slow tier, incl. #683 staleness + #744 bounded flow) | `dart test test/plugins/tdd/commands/gen_command_test.dart --preset=all` | `+17: All tests passed!` |
| plan↔gen contract + compose + func + wire | `dart test test/plugins/tdd/commands/plan_gen_contract_test.dart test/plugins/tdd/commands/compose_command_test.dart test/plugins/tdd/commands/func_command_test.dart test/plugins/tdd/wire_command_test.dart` | `+38: All tests passed!` |
| artifact registry + composition services | `dart test test/plugins/tdd/services/artifact_registry_test.dart test/plugins/tdd/services/composition_planner_test.dart test/plugins/tdd/services/composition_targets_test.dart` | `+22: All tests passed!` |
| verify-red suite (slow) | `dart test test/plugins/tdd/verify_red_command_test.dart --preset=all` | `+19: All tests passed!` |
| verify suite (slow) | `dart test test/plugins/tdd/commands/verify_command_test.dart --preset=all` | `+1: All tests passed!` |
| fast tier, tdd plugin folder | `dart test test/plugins/tdd --exclude-tags slow,flutter` | `+405: All tests passed!` |
| make suite (slow) | `dart test test/plugins/tdd/make_command_test.dart --preset=all` | `+30 -2` (both failures reproduce on clean `HEAD` without this branch's changes — pre-existing) |
| run suite (slow) | `dart test test/plugins/tdd/run_command_test.dart --preset=all` | `+34 -1` (same — reproduces on clean `HEAD`) |
| SC-017 real-pipeline e2e | `dart test test/plugins/tdd/scenarios/sc_017_real_pipeline_wires_subject_test.dart --preset=all` | `+1: All tests passed!` |
| SC-018 plan→run loop e2e | `dart test test/plugins/tdd/scenarios/sc_018_plan_run_loop_e2e_test.dart --preset=all` | `+1: All tests passed!` |
| SC-021 acceptance composition e2e | `dart test .../sc_021_acceptance_composition_e2e_test.dart --preset=all` (A1, A2 run separately: 10-min agent wall-clock cap) | `+1` each: `All tests passed!` |
| fast suite, chunked (repo-wide) | `tools/run_tests_chunked.sh` (68 chunks; agent wall-clock cap split it into two windows, chunks 60–68 re-run with identical semantics) | 0 failing chunks (62 passed, 5 no-fast-tier skips) |
| format gate | `dart format .` then `git diff --stat` | zero remaining formatting diffs (`--set-exit-if-changed` exit 0) |
| analyzer | `dart analyze` | 47 issues, byte-identical to the pre-change baseline (all 22 errors confined to `examples/todo_tdd/`, a pre-existing broken example package) |
