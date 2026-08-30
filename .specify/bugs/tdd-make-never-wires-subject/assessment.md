# Bug Assessment: `zfa tdd make` never wires the gen'd subject — cannot reach green with the real pipeline

- **Slug**: tdd-make-never-wires-subject
- **Created**: 2026-08-30
- **Source**: pasted text (live demo reproduction, `/tmp/zfa-make-demo/run-b`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Even with the `-n` flag worked around and a fully successful real pipeline
(`zfa entity create -n User` + `zfa build`, zorphy + json codegen complete),
`zfa tdd make` reports:

```
zfa tdd make: target test still fails after generation (exit 1).
make: behavior=B-001 outcome=generation-error feature=001-demo-feature
```

because nothing connects the generated entity to the behavior subject stub.
Green was only reachable by wrapping the pipeline (`--zfa-bin`) with a script
that ALSO implements the subject after `build`; with the wrapper, the same
run certifies `outcome=green` and appends correct green evidence.

## Symptom

The pipeline plan for an entity-bearing behavior is
`entity create` + `build` only. The `gen`-produced subject
(`lib/tdd/<id>_subject.dart`, a standalone stub throwing
`UnimplementedError`) is never implemented or wired to the generated
entity, so the target test stays red after generation and `make` honestly
stops with `generation-error` — for every behavior, always.

## Reproduction

1. Same setup as the `tdd-make-planner-omits-name-flag` demo
   (`/tmp/zfa-make-demo/run-b`).
2. `gen B-001` → `verify-red B-001` (certified red).
3. `make B-001 --project . --zfa-bin ../zfa-green-wrapper.sh` where the
   wrapper runs the REAL `entity create -n User` and REAL `zfa build`, then
   writes `int subject_b_001() => 42;` into the subject →
   `outcome=green`, exit 0, green evidence with both real pipeline commands.
4. Remove only the subject-writing part of the wrapper →
   `target test still fails after generation`, `outcome=generation-error`.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/generation_planner.dart:92-107` — the
  entity plan has exactly two steps (`entity create`, `build`); no step
  produces or wires the behavior subject.
- `lib/src/plugins/tdd/commands/make_command.dart:345-364` — post-pipeline
  target-test run requires a pass; nothing between the pipeline and this
  check touches the subject.
- `lib/src/plugins/tdd/services/subject_writer.dart` — gen writes the
  standalone `UnimplementedError` stub the test asserts against.
- `lib/src/plugins/tdd/services/behavior_test_writer.dart:137-139` — the
  test's success condition is "subject no longer throws
  UnimplementedError".

## Root Cause Hypothesis

A design gap in 047's minimal-planner scope: "minimal generation that
satisfies the behavior's test" (FR-005) was implemented as
entity-scaffold-only; the step that turns the generated entity into an
implementation of the behavior subject does not exist anywhere in the
pipeline, so FR-007/US1.AC1 (green certification) is unreachable in
production. The merged tests pass because fake zfa scripts perform the
wiring themselves. High confidence — demonstrated live both ways.

## Proposed Remediation

**Preferred**: Give the pipeline a subject-implementation step owned by a
real generator surface — e.g. the planner emits
`zfa make <Entity> --with=tdd-subject --behavior <id>` (or a dedicated
`zfa tdd wire <id>` subcommand) that generates the subject's implementation
from the generated entity and is recorded as a normal `GenerationStep` in
the green evidence. Tracker: this is exactly the "complete pipeline" the
epic's harness spec (045 precondition 5) + corpus run are designed to force
out; fix belongs on that critical path with its own spec/tasks.

**Alternatives**:
- Have `gen` emit subjects that import the future entity — rejected: breaks
  044 FR-004 (gen requires no pre-existing entity) and honest-red.
- Keep requiring wrappers — rejected: violates the epic's generation-only
  contract (045 FR-004).

**Files likely to change**:
- `lib/src/plugins/tdd/services/generation_planner.dart`
- a new subject-implementation generator surface (owner: harness spec)
- `lib/src/plugins/tdd/commands/make_command.dart` (no change expected)

**Tests to add or update**:
- Slow-tier green-path test against the REAL pipeline (no fake zfa) for one
  entity-bearing behavior — currently impossible; must become the anchor
  test of the fix.

## Risks & Considerations

- Scope: this is a generator-capability gap, not a one-liner; sizing should
  happen in the harness/corpus planning (epic 045).
- Related provisioning gap (same demo): a bare project needs
  `zorphy`, `zorphy_annotation`, `json_annotation`, `json_serializable`,
  `build_runner`, and a `build.yaml` before `zfa build` succeeds —
  `zfa tdd init` provisions none of them. Likely its own small issue.

## Open Questions

- [NEEDS CLARIFICATION: should subject wiring be a `zfa make` preset flag,
  a `zfa tdd wire` subcommand, or part of `entity create`? Decide in the
  harness spec (045 precondition 5) before implementing.]
