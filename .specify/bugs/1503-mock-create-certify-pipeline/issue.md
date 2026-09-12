## Summary
`zfa tdd plan`'s entity pipeline emits `mock create --name <E>` **without**
`--certify`. The engine's own step produces an uncertified mock, then the
engine's own preflight refuses it — the pipeline contradicts itself.

## Reproduction

```bash
zfa tdd plan 001-todo-app          # spec has ## Key Entities with Task
zfa tdd run 001-todo-app           # run #1: phase 0 creates Task, plan
                                   # runs `mock create --name Task`
# (any interruption — stop, Ctrl-C, later failure — leaves uncertified mock)
zfa tdd run 001-todo-app           # run #2:
#   CORE entity "Task" has a mock on disk that is NOT certified —
#   the engine refuses to proceed (spec 1001)
```

Terminal verdict:

```
zfa tdd run: CORE entity "Task" has a mock on disk that is NOT certified —
the engine refuses to proceed (spec 1001: mocks the framework certifies, not the agent).
--> fix: zfa mock certify Task (or zfa mock create Task --certify), then re-run.
```

And `zfa tdd status`:

```
gate: entity=Task refused — CORE entity "Task" is wired into the engine tree
but has no mock-cert.Task.json receipt — the framework never certified its mock.
```

## Root cause
`generation_planner.dart` emits:

```dart
GenerationStepSpec(args: ['mock', 'create', '--name', name], ...)
```

`--certify` is opt-in (shipped as an explicit capability in #1001). The
planner was written against **pre-#1001 semantics** ("make a mock exist"),
while the gate was written against **post-#1001 semantics** ("the mock must
be certified"). The two halves of the pipeline were never reconciled.

## Why not caught earlier
The gate runs **before** the plan (`run_command.dart` preflight). On a clean
project the mock does not exist yet, so the gate skips it. The mock appears
only after the first run creates it — the failure surfaces on the second
run, which then refuses at preflight forever until a human runs
`zfa mock certify`.

## Expected
1. The planner's mock step requests the certified variant:
   `['mock', 'create', '--name', name, '--certify']`.
2. `mock create` without `--certify` should refuse or warn loudly when its
   target is a Key Entity wired into the TDD engine tree.

## Hard constraints
- Fix ONLY the mock step in `generation_planner.dart` (both the
  traced-entity arm and the `GenerationSurface.entityPipeline` arm). Do NOT
  change the gate semantics, preflight logic, or the `mock create` command
  implementation.
- The `--certify` flag must be added to both entity pipeline arms in the
  planner.
- Must not break `mock create` when used standalone (outside the TDD
  pipeline).
- Must pass `dart analyze` with no new warnings.

## Related
- #1001 (mock certification capability origin)
