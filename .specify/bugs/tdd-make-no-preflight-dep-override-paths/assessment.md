# Assessment: tdd-make-no-preflight-dep-override-paths (bug 1303)

- **Assessed**: 2026-09-08 (this fix session)
- **Source**: GitHub issue #1303 + the triage brief; restored into
  `.specify/bugs/tdd-make-no-preflight-dep-override-paths/` because the
  records referenced by the brief were never committed to the repo (the
  directory did not exist on `master` or any branch — verified via
  `git log --all`).

## Triage verdict

REAL BUG, severity medium, fix class: **preflight validation + error
classification only**. Hard constraints from the brief:

- Fix ONLY the preflight validation and error classification.
- Do NOT change the `dependency_overrides` format.
- Do NOT change the build_runner retry logic for non-resolution errors.
- One PR per bug, `Closes #1303`.

## Root cause (code-confirmed)

1. **No path-override preflight.** `tdd make` (`make_command.dart`) and
   `tdd run` (`run_command.dart`) resolve the project root and immediately
   start registry/feature work and pipeline steps. Nothing anywhere in
   `lib/` parses `dependency_overrides` to validate that a `path:` value
   resolves to a directory containing a `pubspec.yaml` (only the migration
   detector and the dependency wirer read that section, for unrelated
   purposes). A stale path therefore reaches `build_runner`, whose implicit
   pub get dies with a raw version-solving dump; the pipeline runner
   classifies the step `generation-error`, burying the actionable line
   mid-log.
2. **Unclassifiable retry.** `BuildCommand.run()` (build_command.dart)
   runs `_runBuild()` with `ProcessStartMode.inheritStdio` — the child's
   output is never captured — so at the retry decision point the command
   cannot know WHY the build failed. The `Retrying with clean cache`
   fallback fires on EVERY non-zero exit without `--clean`, including pub
   resolution failures that no cache clean can fix: one wasted full
   rebuild per resolution failure, then the same dump again.

## Remediation (implemented)

1. New service `lib/src/plugins/tdd/services/dependency_override_preflight.dart`
   — parses `<projectRoot>/pubspec.yaml`, and for every
   `dependency_overrides[*].path` (pub's grammar: path overrides exist ONLY
   in the map form; a string override is a version constraint, never a
   path) verifies the normalized `<projectRoot>/<path>/pubspec.yaml`
   exists. Fail-open boundaries: no pubspec / unparseable pubspec → vacuous
   pass (pub get names that problem with the authoritative message).
2. `tdd make` + `tdd run` run the gate before ANY work. On findings:
   print the honest `❌ preflight:` line per finding + the
   `--> fix:` line, exit **3** (SPEC 917 drift class — a stale override is
   corrupt project state), summary `outcome=preflight-red` (make) /
   `result=corrupt-state` (run, journaled `preflight_red`, zero steps).
3. `BuildCommand` captures the streamed build output (still echoed live —
   the visible output contract is unchanged) and skips the clean-cache
   retry when the output carries a pub RESOLUTION signature
   (`version solving failed` / `No pubspec.yaml found for package`),
   printing the honest classification + remedy. Every other failure keeps
   the retry exactly as before.

## Exit-code rationale

The issue offers exit 2 (usage/grammar of the environment) or 3 (drift).
A stale override is not a usage error of the CLI — it is corrupt project
state discovered before the pipeline starts, which is exactly SPEC 917's
drift class, and `tdd run` already ships exit 3 = corrupt-state in its
machine contract. Exit 3 chosen for both commands.

## Test surface (TDD cycle)

- `test/plugins/tdd/services/dependency_override_preflight_test.dart` —
  8 unit tests (map-form stale path, the exact #1303 repro shape,
  version-constraint overrides NOT validated as paths, valid path passes,
  non-path overrides ignored, no section vacuous, missing pubspec fail-open,
  honest line rendering).
- `test/plugins/tdd/commands/bug_1303_dep_override_preflight_test.dart` —
  make refuses (exit 3, `--> fix:`, zero generation, negative control for a
  resolvable override) + run refuses (exit 3, `result=corrupt-state`,
  no `[run]` lines).
- `test/commands/bug_1303_build_retry_skip_test.dart` — classifier unit
  tests + the slow subprocess proof that a resolution failure prints no
  `Retrying with clean cache` and does print the `--> fix:` line.
