# Tasks: 1610-extract-canonicalize-missing-path

- **Spec ID**: 1610-extract-canonicalize-missing-path
- **Created**: 2026-09-16

Dependency order: T001 (RED — write the four direct walk-up pins against the
EXISTING helper; green-by-design is recorded honestly as characterization,
strength proven by deliberate mutants) → T001m (deliberate-mutant sampling —
the recorded red evidence) → T002 (GREEN — full targeted suites green, zero
code changes) → T003 (non-behavioral — precondition documentation in the
helper's doc comments) → T004 (verify + artifacts + format/analyze gates).

Baseline note: suite_baseline is green on this branch at planning time
(master's 994daeb1 state + the two artifact commits; the four command-pin
suites were green in PR #1611's verification and are re-run in T002).

## T001: Red-list — direct walk-up pins (new test file)

- [ ] T001 [P] [US2] Create `test/plugins/tdd/services/path_canonicalizer_test.dart`
      pinning the four behaviors (FR-004) against the CURRENT
      `canonicalizeMissingPath` — POSIX-safe `Directory.systemTemp` fixtures,
      `package:path` for expectation building, Windows symlink skip via the
      repo's `onPlatform` convention:
  - U1 (SC-2): nearest existing ancestor resolves through a SYMLINK —
    fixture root aliased by a symlink, missing subject passed as
    `<alias>/missing/subject.dart` → result starts with the RESOLVED root
    (`.../tdd_canon_root/...`), never the alias form; segments re-appended
  - U2 (SC-2, the tail-order assertion the command pins cannot make):
    `root/missing_a/missing_b/subject.dart` (root exists, both middle
    segments missing) → result equals
    `<resolvedRoot>/missing_a/missing_b/subject.dart` — ORIGINAL order,
    asserted with an exact-match expectation so dropping `.reversed`
    (→ `.../subject.dart/missing_b/missing_a`) FAILS
  - U3 (SC-2, one-segment boundary): direct parent exists and is a symlinked
    directory → parent's symlink resolved, basename re-appended
  - U4 (SC-2, root-boundary walk): missing path directly under the resolved
    root (`<root>/<missing>` form via the alias) → resolved root + basename;
    the doc-comment-documented no-ancestor fallback (input returned
    unchanged) is asserted as UNTESTABLE-BY-PUBLIC-SURFACE in a comment
    (defensive branch; POSIX root always resolves — no fake seam, per the
    hard constraint)
- Tests: `test/plugins/tdd/services/path_canonicalizer_test.dart`

## T001m: Mutation sampling — recorded red evidence (SC-3)

- [ ] T001m [US2] Deliberate-mutant runs against
      `lib/src/plugins/tdd/services/path_canonicalizer.dart`, each mutation
      applied → targeted test run → RESTORED byte-identical (`git checkout`
      between mutants; mutant states NEVER committed):
  - M1: drop `.reversed` (`...tail.reversed` → `...tail`) → U2 MUST go RED
    (exact-match failure showing the reordered path) → restore → GREEN
  - M2: skip the walk-up (return `path` on first FileSystemException) → U2
    MUST go RED (raw un-resolved path != resolved expectation); U1 MUST go
    RED on symlink fixtures → restore → GREEN
  - M3: drop the basename re-append (`joinAll([resolved])`) → U1/U2/U3 all
    RED (missing final segment) → restore → GREEN
  - RECORD every mutant's decisive failure line in
    `specs/1610-extract-canonicalize-missing-path/tdd/cycle-log.md` (the
    append-only evidence /speckit.tdd.verify audits)
- Tests: `test/plugins/tdd/services/path_canonicalizer_test.dart`

## T002: Green — targeted suites green with zero executable diffs

- [ ] T002 [US2] Run and record: new test file green;
      `view_command_test.dart` green (U-V3, U-V11/U-V12/U-V13, U-1603a/b
      pins intact); `wire_command_test.dart` green (U-W3, U-1603e intact);
      `func_command_test.dart` green (U-1603c, U-F5 — run-only, untouched);
      `git diff --stat` shows ONLY the new test file at this point
- Tests: `test/plugins/tdd/services/path_canonicalizer_test.dart`,
  `test/plugins/tdd/commands/view_command_test.dart`,
  `test/plugins/tdd/commands/wire_command_test.dart`,
  `test/plugins/tdd/commands/func_command_test.dart`

## T003: Non-behavioral — precondition documentation (config/docs)

- [ ] T003 [US1] `lib/src/plugins/tdd/services/path_canonicalizer.dart` —
      doc comments ONLY (FR-001, FR-002, SC-1):
  - Library doc: name the ABSOLUTE-input precondition and WHY (the walk-up
    resolves against the filesystem; a relative input silently joins the
    process CWD and the result becomes CWD-dependent — the silent-wrong-
    answer class the containment guard exists to prevent)
  - Function doc: the precondition ("[path] must be absolute — absolutize
    first, e.g. `p.normalize(p.absolute(...))` or join onto the absolute
    project root, as every call site does"), the fallback contract ("returns
    [path] UNCHANGED when no ancestor resolves" — defensive branch,
    POSIX-unreachable since the filesystem root always resolves), and keep
    the existing #1603/pull-1516 rationale intact
  - ZERO executable-line changes: `git diff` on the file touches comments
    only; no `assert`, no absolutization, no signature change
- Tests: re-run the new test file + the three command suites (docs cannot
  break behavior — the suites prove it)

## T004: Verify — analyze, format, verification artifact

- [ ] T004 `dart analyze` on the touched scope
      (`lib/src/plugins/tdd/ test/plugins/tdd/`) → No issues found;
      `dart format .` → zero remaining diffs (CI format gate);
      clean kernel/test caches pre-test per the repo's PRE-TEST ritual
- [ ] T004 Write
      `specs/1610-extract-canonicalize-missing-path/tdd/verification.md`
      from the REAL runs: pass/fail counts, per-mutant red/green evidence
      table, FR/SC coverage matrix, suite-baseline statement, honest
      not-proved items if any
- Tests: all of the above (recorded verbatim in verification.md)

## Dependencies

- T001 → T001m → T002 (the mutants mutate against the pins; the green gate
  runs after restoration)
- T003 independent of T001-T002 in CONTENT (comments) but sequenced after
  T002 so the green baseline precedes any source-file touch
- T004 last (gates + artifact over the final tree)

## Parallel execution examples

- T001's four pins are written as one file (same-file tasks run
  sequentially) — no parallel opportunity inside T001
- T003 (helper comments) and T001 (test file) touch disjoint files and COULD
  run in parallel; sequenced T001-first to keep the red-evidence-before-docs
  order honest to the TDD narrative

## Implementation strategy

MVP first: T001+T001m alone deliver the issue's gap 2 (direct test with
strength evidence); T003 delivers gap 1 (documented precondition); T002+T004
prove the acceptance criteria (SC-1..SC-4) and close the issue. Every task
leaves the tree committable; commits follow the repo's WIP convention during
the cycle and one behavior-named message at green.
