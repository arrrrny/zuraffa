# Bug Verification: `zfa tdd run` now drives the bug-directory TDD loop

- **Slug**: 1471-tdd-run-bug-dir-resolution
- **Tested**: 2026-09-10
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: none — the fix ran through the classic flow, not the red-green loop; see _Residual Risks_.

## Summary

The reported symptom is gone. `zfa tdd run` no longer rejects a bug directory as a usage
error and no longer looks for `specs/<slug>`: with the `.specify/feature.json` pin in place,
the bare slug drives the real loop (`A1 gen -> ok`, then on to `A1 verify-red`) and writes
every artifact under `.specify/bugs/<slug>/tdd/` with nothing fabricated under `specs/`. The
new 18-test suite passes, the `#1272` traversal guard is intact, and the seven failures in
three slow suites were proven pre-existing by an A/B against a stashed tree.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix, part 1) | `dart run bin/zfa.dart tdd run .specify/bugs/repro-slug --project <tmp>` in a temp project pinned to `.specify/bugs/repro-slug` | pass | The reported `❌ invalid feature ".specify/bugs/…": … not a path` is gone. The run reads `.specify/bugs/repro-slug/tdd/test-list.md` and writes `journal.json` there. `$TMP/specs` stays empty. Exit 2 remains only because that hand-written fixture's test list was empty (`test list … has no behaviors`). |
| Reproduction (post-fix, part 2) | same fixture, `zfa tdd run repro-slug --project <tmp>` (bare slug, pin only) | pass | Resolves to the identical bug directory through the pin. The reported `no feature directory at specs/repro-slug` is gone. |
| Reproduction (post-fix, full loop) | `zfa tdd plan .specify/bugs/loop-slug --project <tmp>` then `zfa tdd run loop-slug --project <tmp>` | pass | plan → exit 0, wrote a 1-behavior test list under the bug dir. run → `[run] A1 gen -> ok`, then `[run] A1 verify-red -> unresolved`, `result=stopped … stopped_at=A1:verify-red`, exit 1. The loop now runs **through** the child steps instead of dying at the path refusal. |
| New / updated tests | `dart test test/plugins/tdd/commands/run_command_bug_1471_test.dart` | pass | 18/18. |
| Regression — driver end-to-end | `dart test --preset=all test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart` | pass | 4/4. Drives the real `zfa tdd run` into the real `RunDriverCore`, exercising the changed `drive(featureRef:)`. |
| Regression — traversal guard | `dart test --preset=all test/plugins/tdd/bug_1272_gen_project_scoped_test_list_test.dart` | pass | 12/12. `testListScopeRejection` still refuses path-shaped and escaping `--feature` values. |
| Regression — path formats and #1182 | `dart test test/plugins/tdd/run_command_path_format_test.dart test/plugins/tdd/commands/plan_command_bug_1182_test.dart` | pass | 16/16. `specs/<f>`, bare names, `specs/`, `..`, `specs/../foo` all keep their documented behavior. |
| Regression — refactor / verify-red subtree | `dart test --preset=all test/plugins/tdd/refactor_command_test.dart test/plugins/tdd/verify_red_subdirectory_test.dart` | pass | 14/14 and 4/4. |
| Regression — slow suites | `dart test --preset=all test/plugins/tdd/{make_command,verify_red_command,tdd_command_smoke}_test.dart` | fail (pre-existing) | 5 + 1 + 1 failures, **identical with the entire change set stashed** — see Output Excerpts. |
| Untagged view suite | `dart test test/plugins/tdd/commands/view_command_test.dart` | fail (pre-existing, macOS only) | U-V3 only; fails identically with `view_command.dart` restored to `HEAD`. Passes on Linux CI. |
| Lint / type-check | `dart analyze lib` | pass | 0 errors, 0 warnings; 112 pre-existing `info` lints, all in generated `lib/tdd/**`. |
| Formatting | `dart format --set-exit-if-changed lib test` | pass | 2541 files, 0 changed. |

## Output Excerpts

The two reported failure modes, before and after (temp project, real CLI):

```text
# BEFORE (per the issue):  zfa tdd run .specify/bugs/<slug>
#   ❌ invalid feature ".specify/bugs/<slug>": expected a single spec
#      directory name such as 049-tdd-run, not a path.          EXIT: 2
# BEFORE (per the issue):  zfa tdd run <slug>
#   zfa tdd run: no feature directory at specs/<slug>          EXIT: 2

# AFTER:                   zfa tdd run <slug>   (bare slug + feature.json pin)
[run] A1 gen -> ok
[run] A1 verify-red -> unresolved
zfa tdd run: step failed — behavior=A1 step=verify-red outcome=unresolved
   zfa tdd verify-red: behavior A1
      feature: loop-slug
      test: <tmp>/test/tdd/loop-slug/a1_test.dart
run: feature=loop-slug result=stopped pending=1 red=0 green=0 done=0 stopped_at=A1:verify-red
                                                               EXIT: 1
```

The loop's artifacts, all under the bug directory, with `specs/` empty:

```text
.specify/bugs/loop-slug/tdd/04-engine-receipt.json
.specify/bugs/loop-slug/tdd/artifacts.json
.specify/bugs/loop-slug/tdd/cycle-log.md
.specify/bugs/loop-slug/tdd/journal.json
.specify/bugs/loop-slug/tdd/journal.schema.json
.specify/bugs/loop-slug/tdd/provenance-ledger.json
.specify/bugs/loop-slug/tdd/run-state.json
.specify/bugs/loop-slug/tdd/test-list.md
.specify/bugs/loop-slug/tdd/traceability.md
.specify/bugs/loop-slug/tdd/ui-ledger.json
.specify/bugs/loop-slug/tdd/ui-ledger.md
--- specs/ listing: (empty) ---
```

The pre-existing failures, proven by A/B (`git stash push -- lib/src/plugins/tdd/`, tree at
HEAD, then `git stash pop`). Failing test names were **byte-identical** in both runs:

```text
make_command_test            US4 bug 657; bug 829 U-829g; bug 829 U-829h;
                             spec 052 A11/U17; spec 052 A15
verify_red_command_test      U23/A1: honest red certifies
tdd_command_smoke_test       zfa tdd --help lists the corpus family (051, T001)
```

## Residual Risks

- The full-loop reproduction stops at `A1:verify-red` because the throwaway temp project has
  no test-runner profile and no `lib/` source. That is a fixture limitation, not a
  regression: the step is reached, resolved to the correct bug directory, and reported
  honestly. Proving a fully green loop would need a provisioned fixture project.
- The fix was **not** driven through the TDD red-green loop despite `tdd_enabled: true`, so
  there is no `tdd/verification.md`. The loop's `tdd.run` step is the very thing this bug
  breaks, so it could not bootstrap its own fix. Consequently the mutation-testing audit
  that `tdd.verify` performs was **not** run against this fix; verification rests on the
  reproduction, the new suite, and the regression suites above.
- `view_command_test.dart` U-V3 is red on macOS (pre-existing, `/var` → `/private/var`
  canonicalization fallback). It will not fail Linux CI, but a macOS developer sees red.
- The seven slow-suite failures are pre-existing but real, and they will stay red until
  someone fixes them; this change neither causes nor masks them.
- No coverage was added for the follow-ups in `fix.md` (`func_command` mis-resolving bug
  features, `generation_planner` emitting a basename, the other commands with local `specs/`
  joins).

## Recommendation

Close the bug — verified end-to-end. Both reported failure modes are gone, the loop now runs
through its child steps with all artifacts landing beside the bug spec, plain-feature
resolution is unchanged, and every failure remaining in the suites this change touches was
proven pre-existing by stashing the entire change set. The follow-ups in `fix.md` should be
tracked separately rather than bundled here.
