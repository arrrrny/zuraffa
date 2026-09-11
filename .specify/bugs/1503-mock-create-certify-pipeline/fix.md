# Bug Fix — #1503 (the entity pipeline now produces certified mocks)

## Root cause

A semantic split across the two halves of the TDD pipeline:

1. The planner emitted pre-#1001 args. Both entity-pipeline arms in
   `generation_planner.dart` — the traced-entity arm (bug-#829 unit lane)
   and the declared `GenerationSurface.entityPipeline` arm
   (`_declaredPlan`) — emitted `['mock', 'create', '--name', <E>]`,
   written when "a mock exists" was the whole contract.
2. The gate enforces post-#1001 semantics. `run_command.dart`'s pre-start
   preflight refuses any CORE entity wired into the engine tree whose mock
   lacks a `mock-cert.<Entity>.json` receipt; `--certify` (the receipt
   writer) shipped as an explicit opt-in in #1001 and the planner was
   never reconciled with it.
3. The timing hid the contradiction. The gate runs BEFORE the plan: on a
   clean project the mock does not exist yet, so preflight skips it; run
   #1 creates the uncertified mock; any interruption leaves it on disk;
   run #2 refuses at preflight forever until a human runs
   `zfa mock certify`.

## Changes

- `generation_planner.dart` — both entity pipeline arms now include
  `'--certify'` in the mock step args:
  - traced-entity arm: `['mock', 'create', '--name', traced, '--certify']`
  - declared entityPipeline arm: `['mock', 'create', '--name', name,
    '--certify']`
  (plus purpose-string updates naming the certified contract, spec 1001 —
  bug #1503, inside the same two constructors).
- `generation_planner_test.dart` — the two argv pins encoding the pre-fix
  contract (U-829a, U-909) moved to the certified contract.
- NEW `bug_1503_mock_create_certify_pipeline_test.dart` — 4 behaviors:
  both arms carry `--certify` (exact argv pins), every planner-emitted
  `mock create` is certified, and the stub arm still plans no mock step.

Standalone `mock create` is unchanged (opt-in as before); no gate, no
preflight, no mock-command change.

## Review-fix round (PR #1514 findings)

- Finding 1: both arms now emit
  `['entity', 'create', '-n', <E>, '--build']` — the certify step's
  sandbox needs the entity's build_runner outputs on disk (a missing
  `part` target fails the import-closure copy), and `entity create` does
  not build by default.
- Finding 3: U-1503c became a table-driven invariant over the planner's
  arm shapes instead of a third copy of the two literal plans.
- Finding 4: the TDD records moved from the new root `tdd/` into
  `./tdd/`, and the broken cross-reference was fixed.
- Finding 2 (per-behaviour certification cost): not applied — it requires
  a digest-keyed short-circuit in the spec-1001 certification path, a
  behaviour change the review itself scoped out of this PR.

## Verification (actual run — see ./tdd/verification.md)

- RED: 3 failed / 1 passed, failing on the missing `--certify` verbatim.
- GREEN: new suite 4/4; chunked related suites 35 + 18 + 13 + 17 = 83
  passed, 0 failed, 0 new failures.
- `dart analyze` on all changed files: No issues found.
- `dart format`: applied, re-verified green.
