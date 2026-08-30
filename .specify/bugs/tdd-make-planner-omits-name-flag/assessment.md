# Bug Assessment: `zfa tdd make` planner omits required `-n` flag on `entity create`

- **Slug**: tdd-make-planner-omits-name-flag
- **Created**: 2026-08-30
- **Source**: pasted text (live demo reproduction, `/tmp/zfa-make-demo/run-a`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Live end-to-end demo of the merged 047 `zfa tdd make` (real pipeline, no
`--zfa-bin` override) failed at pipeline step 0:

```
zfa tdd make: generation step failed at index 0 (create entity User for behavior B-001):
   command: `/usr/local/share/flutter/bin/cache/dart-sdk/bin/dart /Users/ahmettok/Developer/zuraffa/bin/zfa.dart entity create User`
   exit: 1
   output (tail):
Error: Entity name is required. Use -n or --name to specify.
make: behavior=B-001 outcome=generation-error feature=001-demo-feature
```

## Symptom

For any entity-bearing behavior, `zfa tdd make` generates the pipeline step
`zfa entity create <Name>` without the `-n`/`--name` flag, which
`EntityCommand` requires — so the real pipeline always fails at its first
step and `make` can never certify green without a `--zfa-bin` wrapper.

## Reproduction

1. Fresh minimal Dart project with `zorphy_annotation`, `zorphy`,
   `json_annotation`, dev `build_runner`+`json_serializable`+`test`, a
   `build.yaml`, a quoted `tdd-profile.md` (`single`/`suite` keys), and
   `specs/001-demo-feature/tdd/test-list.md` with an entity-bearing behavior
   (`| B-001 | create entity User with id | FR-001 | unit | PENDING | subject_b_001 |`).
2. `zfa tdd gen B-001 --project .` then `zfa tdd verify-red B-001 --project .`
   (certifies red).
3. `dart run <repo>/bin/zfa.dart tdd make B-001 --project .`
   (entrypoint auto-resolves from source) → step 0 fails with
   `Error: Entity name is required. Use -n or --name to specify.`

Full working demo preserved at `/tmp/zfa-make-demo` (run-a).

## Suspected Code Paths

- `lib/src/plugins/tdd/services/generation_planner.dart:98` — the entity
  plan step is `args: ['entity', 'create', name]`; the flag is missing.
- `lib/src/commands/entity_command.dart` — argument parsing requires
  `-n/--name` for the entity name (error message quoted above).
- `lib/src/plugins/tdd/services/pipeline_runner.dart:93` — passes the spec
  args verbatim to the sub-process (correct behavior; the plan is wrong).
- `test/plugins/tdd/services/generation_planner_test.dart` — existing tests
  assert the current (broken) arg list, which is why the suite is green
  while production fails (the fake zfa ignores flags).

## Root Cause Hypothesis

The planner was written and tested against fake zfa scripts that accept
positional entity names, while the real `EntityCommand` CLI requires
`-n/--name`. High confidence — one line, verified live.

## Proposed Remediation

**Preferred**: Emit the flag in the plan step:
`args: ['entity', 'create', '-n', name]` in `generation_planner.dart`, and
update the planner tests to pin the exact argv. Add one integration-tier
(slow-tagged) test that executes the planner's emitted argv against the REAL
`bin/zfa.dart entity create` in a temp project so planner/CLI drift can never
pass CI silently again.

**Alternatives**: make `EntityCommand` accept a positional name — rejected:
changes a stable public CLI surface for an internal bug.

**Files likely to change**:
- `lib/src/plugins/tdd/services/generation_planner.dart`
- `test/plugins/tdd/services/generation_planner_test.dart`
- `test/plugins/tdd/make_command_test.dart` (fake zfa assertion tightening)

**Tests to add or update**:
- Planner emits `-n <Name>` for entity-bearing behaviors (unit, exact argv).
- Slow-tier test: planner argv runs successfully against the real CLI.

## Risks & Considerations

- None material; the fix narrows a plan to what the real CLI accepts.
- Related but separate: the CRUD branch `zfa make <slug>` uses the name
  positionally, which `MakeCommand` DOES accept positionally — verify while
  fixing.

## Open Questions

- None.
