# Bug Assessment — #1503

**Issue:** `zfa tdd plan`'s entity pipeline emits `mock create --name <E>`
without `--certify`; the engine's own preflight (spec 1001) then refuses the
uncertified mock it just produced — the pipeline contradicts itself.
**Severity:** high — every interrupted first run poisons all subsequent
runs of the same feature until a human intervenes.
**Source:** https://github.com/arrrrny/zuraffa/issues/1503
**Related:** #1001 (mock certification capability origin)

## Root cause — one semantic split across two pipeline halves

1. **The planner emits pre-#1001 args.** `generation_planner.dart` has two
   entity-pipeline arms, both emitting the uncertified variant:
   - the traced-entity arm (bug-#829 unit-behavior lane,
     `!summary.stub`, `entityTraced` non-empty) emits
     `args: ['mock', 'create', '--name', traced]`;
   - the declared-contract arm (`_declaredPlan`,
     `GenerationSurface.entityPipeline`) emits
     `args: ['mock', 'create', '--name', name]`.
   The planner was written when "a mock exists" was the whole contract.

2. **The gate enforces post-#1001 semantics.** `run_command.dart`'s
   pre-start preflight (spec 1001: "mocks the framework certifies, not the
   agent") refuses any CORE entity wired into the engine tree whose mock
   lacks a `mock-cert.<Entity>.json` receipt. `--certify` (the receipt
   writer) shipped as an explicit opt-in capability in #1001 — the planner
   was never reconciled with it.

3. **The timing hid the contradiction.** The gate runs BEFORE the plan. On
   a clean project the mock does not exist yet, so the preflight skips it.
   Run #1 creates the uncertified mock; any interruption (stop, Ctrl-C, a
   later-phase failure) leaves it on disk; run #2 then refuses at preflight
   forever — a permanent dead end that only a manual `zfa mock certify`
   unlocks.

## Remediation (hard constraints)

Fix ONLY the mock step in `generation_planner.dart`, both arms:
- traced-entity arm: `['mock', 'create', '--name', traced, '--certify']`
- declared entityPipeline arm: `['mock', 'create', '--name', name, '--certify']`

Do NOT change: the spec-1001 gate semantics, the preflight logic, or the
`mock create` command implementation. Standalone `mock create` (outside the
TDD pipeline) stays opt-in as before — the engine pipeline is the framework's
own loop, so the framework must request certification itself.

## Repro (from issue)

```
zfa tdd plan 001-todo-app        # spec has ## Key Entities with Task
zfa tdd run 001-todo-app         # run #1 creates uncertified Task mock
<Ctrl-C or later failure>
zfa tdd run 001-todo-app         # run #2: preflight refuses — spec 1001
#   CORE entity "Task" has a mock on disk that is NOT certified ...
#   --> fix: zfa mock certify Task (or zfa mock create Task --certify)
```

## Red→Green plan

RED: pin the emitted argv in a new test
(`bug_1503_mock_create_certify_pipeline_test.dart`): the traced-entity plan's
mock step MUST carry `--certify`. Existing planner tests (lines pinning
`['mock', 'create', '--name', <E>]`) are the pre-fix contract and must move
to the post-fix contract in the same change (they pin the buggy argv).

GREEN: add `'--certify'` to both arms in `generation_planner.dart` — two
literal list edits, no other production change.
