**Template Version**: `zuraffa-1.0`

# Spec: 1357-registry-path-reanchor

GitHub issue: arrrrny/zuraffa#1357 (labels: verify-misfire, spec-drift)
Epic: #1136 Phase A sub-issue 2 (spec-mutation arena, close #967)

## Summary

The epic's fuzz exit criterion invokes `zfa spec fuzz 004-login-ui`; the
gate honestly refused with `notAssessed`. Two stacked causes: (1) the
fixture `specs/004-login-ui` was missing from the tree (resolved on
master by cba9be0f), and (2) — still live — the fixture's committed
`tdd/artifacts.json` records SANDBOX-ABSOLUTE paths
(`/home/z/my-project/zuraffa/test/tdd/...`), so the fuzz preflight spawns
`dart test` against paths that exist in no other environment →
`preflight load failure (issue #1045): the tests never ran` → the exit
criterion can never be assessed outside the original sandbox. The same
poisoned records feed every registry consumer (`tdd run`, `tdd verify`,
doctor).

## Problem

ArtifactRegistry stores and loads paths verbatim. A registry written in
sandbox A is unrunnable in every environment B≠A — the committed fixture
is permanently unfuzzable, and the gate reports notAssessed forever
(the issue's exact signature).

## Locked decisions

1. Fix at the READ boundary: `ArtifactRegistry._loadRecords` re-anchors
   each record's `test_path`, `subject_path`, and the path prefix of
   `runnable_test_name` — one point, healing every consumer. Write
   semantics are UNCHANGED (path-form policy at write time is issue
   #1397's lane).
2. Re-anchor rule (per path): leave it untouched when it is relative,
   or when the absolute path exists on disk as-is; otherwise, when the
   longest suffix starting at the last `/test/` or `/lib/` lane marker
   exists under the project root, adopt that repo-relative suffix;
   otherwise return the stored value verbatim (honest passthrough —
   never invent a path, never fabricate existence).
3. Project root = the parent of the registry feature's `specs/` segment
   (`dirname(dirname(featureDir))`, absolute-normalized). Works for
   nested project roots (e.g. `example/specs/<f>` → `example`).
4. No gate semantics change: fuzz preflight, verdicts, exit codes are
   untouched — only the paths it is handed become runnable.

## Functional requirements

- **FR-1 (re-anchor on load)**: a record whose stored absolute paths
  carry a portable suffix (`test/...`, `lib/...` under the project
  root) loads with repo-relative paths; the `runnable_test_name`'s
  path prefix is re-anchored the same way, preserving the
  `<path>::<id>::<name>` grammar.
- **FR-2 (verbatim passes)**: a relative path passes through; an
  absolute path that exists on disk stays absolute (a real checkout
  there must keep working); an absolute path with no matching suffix
  passes through unchanged.
- **FR-3 (scope consumer heals)**: `MutationScope.derive` over the
  healed registry yields test paths that exist on disk — the fuzz
  preflight's "the tests never ran" root cause is gone.

## Acceptance scenarios (measurable)

1. **Given** a registry whose records carry `/home/z/my-project/zuraffa/`
   absolute paths and a temp project root where the suffixes exist,
   **when** `loadAll` runs, **then** `testPath`/`subjectPath` come back
   repo-relative (`test/tdd/<f>/a1_test.dart`, ...) and
   `runnableTestName` starts with the relative test path.
2. **Given** a record whose absolute path exists on disk, **when**
   loaded, **then** the path is unchanged.
3. **Given** a record whose absolute path has no resolvable suffix,
   **when** loaded, **then** the path is returned verbatim.
4. **Given** a record with relative paths, **when** loaded, **then**
   they pass through untouched.
5. **Given** the healed registry, **when** `MutationScope.derive` runs,
   **then** every test path exists on disk.

## Success criteria

- **SC-001**: `zfa spec fuzz 004-login-ui --budget 5` passes its
  preflight on a fresh checkout (fixture suite green) and assesses
  mutations — the epic exit criterion becomes assessable outside the
  original sandbox.
- **SC-002**: The tdd plugin suites stay green.

## Assumptions

- The committed fixtures' `/home/z/...` records are the only poison;
  the suffix heuristic (`test/`|`lib/` under the project root) covers
  the artifact layouts the tdd engine writes.
