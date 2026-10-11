# Issue: tdd run stop message — the vacuous-green remedy prescribes editing 04-ENGINE.md, which does not exist for a legacy single-file feature

- **Issue**: #1483
- **URL**: https://github.com/arrrrny/zuraffa/issues/1483
- **State**: OPEN — labels `bug`, `documentation`, `tdd`, `track-tdd-loop`, opened by `arrrrny`
- **Slug**: 1483-vacuous-green-remedy-wrong-file
- **Assessment**: `.specify/bugs/1483-vacuous-green-remedy-wrong-file/assessment.md`

## Summary

The `vacuous-green` stop message's actionable remedy is written from the
**lane-split** perspective and names a file that does not exist for a legacy
single-file feature:

```
--> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd run
     — or hand-edit the lane plan (04-ENGINE.md) traces cell to FR-00N, Row.method and re-run zfa tdd gen
     (the designed hand-delta seam)
```

For a feature with no `## Lanes` in its spec — the shape `zfa tdd plan`
produces with no lane split — there is no `04-ENGINE.md` and there never will
be. The actual seam is the `test-list.md` traces cell. An author following the
printed advice looks for a file that isn't there, while the real one-file fix
sits in the artifact the same message told them to re-plan.

## Reproduction (from the issue)

```bash
zfa tdd run 001-todo-app --timeout 25
# -> run: feature=001-todo-app result=stopped ... stopped_at=U1:make
```

Verify the prescribed seam does not exist:

```bash
ls specs/001-todo-app/tdd/            # 04-engine-receipt.json, journal.json, test-list.md, ...
                                      # no 04-ENGINE.md, no 04-SKIN.md
grep -c '^## Lanes' specs/001-todo-app/spec.md   # 0
grep -c 'Lane split' specs/001-todo-app/tdd/test-list.md  # 0
```

And the real seam is right there:

```
specs/001-todo-app/tdd/test-list.md:46:
| U1 | Users MUST be able to create a task by supplying a title and confirming. | FR-001 | PENDING |
                                                                          ^^^^^^ -> FR-001, TaskStore.create
```

## Expected

The stop message names the seam that exists for the feature shape it is
talking to:

- legacy single-file feature: hand-edit the traces cell in
  `specs/<feature>/tdd/test-list.md`;
- lane-split feature: `04-ENGINE.md` / `04-SKIN.md`.

The full path of the file to edit is printed, not a bare filename.

## Hard constraints (from the issue)

- Fix ONLY the remedy text in `vacuous_guard.dart` / run driver — do NOT
  change the vacuous-green detection logic, the stop behaviour, or loop
  semantics.
- Branch the remedy by feature shape — the driver already knows which layout
  it read (lane split vs single file).
- Print the actual full path of the file to edit, not a bare filename.
- Related: #1308 (CLOSED), #1320 (CLOSED, introduced this wording), #1444
  (OPEN), #1259.
