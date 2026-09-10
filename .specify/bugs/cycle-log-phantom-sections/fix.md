# Bug Fix: cycle-log.md section parsing breaks on test output containing '## '

- **Slug**: cycle-log-phantom-sections
- **Fixed**: 2026-09-10
- **Assessment**: ./assessment.md
- **Status**: not-applied (blocked by zuraffa gap — see below)
- **TDD artifacts**: ./tdd/test-list.md (plan succeeded); no cycle-log — the run step never started

## Summary

The fix itself is fully specified and test-planned, but the TDD-mode fix
step stopped at an engine gap before any code changed: `zfa tdd plan`
accepts `.specify/bugs/<slug>` (issue #1182) and produced the test list,
while `zfa tdd run` only accepts `specs/<name>` — it ignores the
`.specify/feature.json` bug-dir pin and rejects paths. Per the
STOP-ON-ROADBLOCK rule in AGENTS.md, the run stops here and waits for the
gap to be merged.

## Roadblock (STOP-ON-ROADBLOCK record)

1. **Command**: `zfa tdd run cycle-log-phantom-sections --timeout 25`
   **Expected**: run engine drives the bug dir pinned in `.specify/feature.json`
   **Actual**: `no feature directory at specs/cycle-log-phantom-sections`,
   exit 2 (`result=runner-error`).
2. **Command**: `zfa tdd run .specify/bugs/cycle-log-phantom-sections --timeout 25`
   **Expected**: path form accepted (as `tdd plan` does)
   **Actual**: `invalid feature "...": expected a single spec directory name
   such as 049-tdd-run, not a path`, exit 2.
3. **Root cause** (traced in source): `lib/src/plugins/tdd/commands/run_command.dart`
   (~lines 195, 307, 329, 390, 438, 472, 479) hardcodes
   `featureDir: p.join(projectRoot, 'specs', feature)`; never consults
   `.specify/feature.json`. `doctor`/`verify` share the assumption.
4. **Filed**: https://github.com/arrrrny/zuraffa/issues/1471
5. **Resume condition**: issue #1471 merged, then re-run
   `/skill:speckit-bug-fix slug=cycle-log-phantom-sections --branch`
   (branch `fix/cycle-log-phantom-sections` already exists with the spec,
   assessment, issue record, and test list committed/intact).

## What was completed before the stop

- Branch `fix/cycle-log-phantom-sections` created.
- `spec.md` synthesized from the assessment (Given/When/Then ACs, template
  version migrated via `--migrate-spec`).
- `zfa tdd plan` → `./tdd/test-list.md`: 5 acceptance behaviors (A1–A5),
  0 unit, 0 widget; `**Type**` markers emitted into the spec.
- `./tasks.md` written with mandatory test tasks T001–T005 before
  implementation tasks T006–T007 (splitter + 9-site adoption).

## Changes

| File | Change | Notes |
|------|--------|-------|
| `.specify/bugs/cycle-log-phantom-sections/spec.md` | added | synthesized from assessment.md; migrated to `zuraffa-1.0` template |
| `.specify/bugs/cycle-log-phantom-sections/tdd/test-list.md` | added | zfa tdd plan output, 5 acceptance behaviors |
| `.specify/bugs/cycle-log-phantom-sections/tasks.md` | added | test tasks mandatory, before implementation tasks |

No source files were touched.

## Deviations from Assessment

None in the plan. The remediation itself (shared fence-aware splitter at
all 9 reader sites) is unchanged and ready to drive once the engine gap
clears.

## Follow-ups

- Merge https://github.com/arrrrny/zuraffa/issues/1471, then resume this fix.
- Writer-side fence hardening (option 1/2 from issue #1467) remains a
  deliberate follow-up, not part of this fix.
