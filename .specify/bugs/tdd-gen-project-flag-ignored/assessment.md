# Assessment: tdd-gen-project-flag-ignored (GitHub issue #1272)

## Severity: high (workflow-blocking)

`zfa tdd gen` is the entry step of every TDD loop pass. When the
test-list resolution escapes the `--project` root, the loop dies with a
parser error belonging to a FOREIGN test list (the monorepo's
`example/specs/`, `.worktrees/` and `corpus/` siblings carry
differently-shaped lists) — the operator's own list is never consulted
and the error names a file they never pointed at. The `--project` flag,
the documented way to pin the root, appears ignored.

## Root cause (verified on master d3679e0f)

gen resolves the feature's test list as `<root>/specs/<featureRef>/tdd/test-list.md`
with NO validation at resolution time:

- `GenCommand.run` computes `cwd` from `--project` (`p.absolute`) or
  `ProjectRoot.find(anchorDir: 'specs')` — the root itself resolves
  correctly (bug #890 remediation).
- `_resolveBehavior` / `_generateAll` then join the RAW `--feature`
  reference into `$cwd/specs/...` via string interpolation. A
  path-shaped reference (`../../../example/specs/004-login-ui`)
  normalizes OUTSIDE the project root and the parser reads whichever
  foreign test-list.md the escape hits first. Reproduced byte-for-byte
  against a monorepo fixture carrying the issue's decoys:

  ```
  ❌ Error: Bad state: zfa tdd gen: malformed test list —
  test-list.md line 7: expected 4 columns (id/behavior/traces/state),
  found 7: "| A1 | acceptance | US1, S1 | DONE | toggle method is
  generated across all layers | test/integration/toggle_method_test.dart | zzz |"
  ```

- gen's existing `_validateFeatureSegment` (bug #827) does NOT cover
  this: it guards the artifact-path namespace only and runs AFTER the
  row was found — after the foreign list was already read and parsed.
  Every other TDD command (verify, make, refactor, compose, verify-red,
  the run driver) validates the feature segment BEFORE using it; gen's
  test-list resolution is the one unguarded path.

What was NOT the problem (verified before fixing):

- `--project` itself IS honored — `p.absolute(projectFlag)` pins the
  root, and with a plain feature name the PROJECT's list resolves
  correctly even over decoy-laden monorepos (regression-guarded in the
  new test).
- The no-`--feature` scans list only direct children of
  `<root>/specs` — inside the root by construction.

## Remediation

1. Validate the `--feature` reference BEFORE any test-list read: a
   single plain spec-directory name (the same contract verify/make/
   refactor/compose/verify-red and the run driver already enforce —
   `validateFeatureSegment`).
2. Containment backstop: the reference's resolution must stay inside
   `<project>/specs` — the parser never walks above the project root
   and never reads a sibling directory. Pins the invariant against
   future reference-shape changes reopening the walk.
3. Default (no `--project`) resolution is unchanged; strict `--project`
   scoping over decoy-laden monorepos keeps resolving the project's own
   list.

## Hard constraints honored

- Fix ONLY the test-list.md resolution path in `zfa tdd gen` (one guard
  site in `GenCommand.run`, before the flow dispatch covers both the
  single and batch resolution call sites).
- No change to the test-list.md format; no change to gen/verify-red/
  make/refactor step semantics.
- One PR per bug.
