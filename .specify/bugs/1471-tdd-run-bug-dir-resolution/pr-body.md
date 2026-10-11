## Summary

`zfa tdd run` (and `run-engine` / `run-skin` / `doctor` / `verify`) could not operate on the
bug directory the speckit bug extension pins in `.specify/feature.json`. `tdd plan` could
(issue #1182), so the documented bug-workflow TDD loop (`bug.fix` → `tdd.plan` → `tdd.run` →
`tdd.verify`) stopped at the run step with exit 2.

The root cause was that `TddFeaturePaths`, introduced by #1182, had exactly one caller
(`plan_command.dart`); the rest of the family still hardcoded `<root>/specs/<feature>`. This
change completes that migration: every command resolves its `<feature>` reference through the
shared resolver, the parent hands its children the canonical `ResolvedFeatureDir.ref`, and
`RunDriverCore.drive` resolves the reference itself instead of joining `specs/<feature>`.
Plain-name resolution is byte-identical.

Both reported failure modes are gone, and artifacts now land beside the bug spec instead of
under a fabricated `specs/<slug>`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/feature_path_resolver.dart` | modified | `ResolvedFeatureDir` gains `ref`. New `isSupportedRef`, `pinned` (reads `.specify/feature.json` → `feature_directory`) and `resolveWithPin`. A trailing separator is refused on the raw reference (`p.normalize` would otherwise collapse `specs/` to `specs` and make the guard unreachable); the pin value is normalized before validation. |
| `lib/src/plugins/tdd/commands/run_command.dart` | modified | Resolves via `resolveWithPin`; carries `featureDir` + `featureRef` to the driver, journals and receipts instead of seven `specs/<feature>` joins. |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | modified | `drive` takes `featureRef` and resolves internally; hands `resolved.ref` to `StepRunner.run`. `_finish` gains `projectRoot`; `_recordStepFailure` takes `featureDir`; `_handStepViolationFor` takes an explicit `projectRoot`, replacing the walk that keyed on a parent literally named `specs`. |
| `lib/src/plugins/tdd/commands/run_engine_command.dart` | modified | Same resolve-and-thread treatment. |
| `lib/src/plugins/tdd/commands/run_skin_command.dart` | modified | Same. |
| `lib/src/plugins/tdd/commands/doctor_command.dart` | modified | Banners name the relative resolved directory; child hints use `resolved.ref`. |
| `lib/src/plugins/tdd/commands/verify_command.dart` | modified | Resolved dir from the resolver; validator relaxed to `isSupportedRef`. |
| `lib/src/plugins/tdd/commands/gen_command.dart` | modified | Resolves scope and threads `(dir, ref, name)`. `testListScopeRejection` exempts `.specify/bugs/<slug>` from the single-segment gate while keeping the containment boundary at the project root, so the #1272 traversal guard is unchanged. |
| `lib/src/plugins/tdd/commands/make_command.dart` | modified | Same pattern; the spawned `zfa tdd view --feature` receives the canonical ref; the registry scan uses `resolved.dir`. |
| `lib/src/plugins/tdd/commands/verify_red_command.dart` | modified | Registry scan and planned-in-test-list checks resolve through the shared resolver. |
| `lib/src/plugins/tdd/commands/refactor_command.dart` | modified | A `featureDir` local replaces every `specs/<featureName>` join; `CycleLog(featureDir)`. |
| `lib/src/plugins/tdd/commands/view_command.dart` | modified | `_RegistryEntry`/`_Resolved` carry the real feature directory; the `--feature` branch resolves through `TddFeaturePaths`. |
| `lib/src/plugins/tdd/services/declared_routing.dart` | modified | `declaredSignatureFor` accepts an optional `featureDir`. |
| `lib/src/plugins/tdd/services/cycle_log_terminal_receipt.dart` | modified | Takes a `required String featureDir`. |
| `lib/src/plugins/tdd/services/step_runner.dart` | modified | Docstring parameter renamed `feature` → `featureRef` (argv unchanged). |
| `test/plugins/tdd/commands/run_command_bug_1471_test.dart` | added | New regression suite, 18 tests. |

## Verification

Reproduction with the real CLI in a temp project pinned to `.specify/bugs/<slug>`:

```text
# BEFORE:  zfa tdd run .specify/bugs/<slug>
#   ❌ invalid feature ".specify/bugs/<slug>": expected a single spec
#      directory name such as 049-tdd-run, not a path.          EXIT: 2
# BEFORE:  zfa tdd run <slug>
#   zfa tdd run: no feature directory at specs/<slug>          EXIT: 2

# AFTER:   zfa tdd run <slug>   (bare slug + feature.json pin)
[run] A1 gen -> ok
[run] A1 verify-red -> unresolved
run: feature=loop-slug result=stopped pending=1 red=0 green=0 done=0 stopped_at=A1:verify-red
```

The loop now runs **through** its child steps. Eleven artifacts landed under
`.specify/bugs/loop-slug/tdd/` (journal, receipts, cycle log, traceability, provenance
ledger) and `specs/` stayed completely empty. The stop at `verify-red` is a fixture
limitation — the throwaway temp project has no test-runner profile.

- `dart analyze lib` → **0 errors, 0 warnings** (112 pre-existing `info` lints, all in generated `lib/tdd/**`).
- `dart format --set-exit-if-changed lib test` → clean.
- `run_command_bug_1471_test.dart` → **18/18**.
- `issue_1308_vacuous_guard_remedy_driver_test.dart` (`--preset=all`) → **4/4**. Drives the real `zfa tdd run` into the real `RunDriverCore`, so it exercises the changed `drive(featureRef:)`.
- `bug_1272_gen_project_scoped_test_list_test.dart` (`--preset=all`) → **12/12**; the traversal guard is intact.
- `run_command_path_format_test` + `plan_command_bug_1182_test` → **16/16**; `specs/<f>`, bare names, `specs/`, `..`, `specs/../foo` all keep their documented behavior.
- `refactor_command_test` → **14/14**; `verify_red_subdirectory_test` → **4/4**.

### Pre-existing failures (not caused by this change)

`make_command_test` (5), `verify_red_command_test` (1) and `tdd_command_smoke_test` (1) fail
**identically with the entire change set stashed** — the A/B was run by stashing all of
`lib/src/plugins/tdd/` and re-running, and the failing test names are byte-identical. They
fail on `master` too.

`view_command_test.dart` U-V3 fails on **macOS only** and does so at `HEAD`: when the recorded
subject file is absent, `resolveSymbolicLinks` throws and the code falls back to the
un-canonicalized path, so `/var/…` is compared against the canonical `/private/var/…` root and
reported as "outside the project root" instead of "missing subject file". It passes on Linux
CI. Not fixed here — see the follow-ups below.

## Deviations from the assessment

- The fix was applied directly rather than through `tdd.run`'s red-green loop, despite
  `tdd_enabled: true`: the loop's `tdd.run` step is precisely what this bug breaks, so it
  cannot bootstrap its own fix. `.specify/feature.json` was not repointed.
- Scope was expanded past the assessment's file list to the commands that receive
  `--feature <ref>` from their parents (`gen`, `make`, `verify-red`, `refactor`, `view`),
  because leaving them hardcoded would re-break the same loop one step later.

## Follow-ups (not in this PR)

- `func_command.dart` still builds `specs/<featureFlag>`; `zfa tdd func` mis-resolves a bug
  feature. It is not on the run loop's path.
- `generation_planner.dart` emits `--feature <basename>`; in the pinned bug flow this resolves
  via the pin, but a bug feature without a pin would still mis-resolve.
- Other commands with local `specs/` joins are deliberately untouched: `compose`, `realize`,
  `realize-mock`, `wire`, `spec-fuzz`, `status`, `prove`, `reset`, `diff-check`, `theater`,
  `dream`, `replay`, `corpus`, `migrate-paths`.

Assessment: `.specify/bugs/1471-tdd-run-bug-dir-resolution/assessment.md`
Fix report: `.specify/bugs/1471-tdd-run-bug-dir-resolution/fix.md`
Verification report: `.specify/bugs/1471-tdd-run-bug-dir-resolution/test.md`

Closes #1471.
