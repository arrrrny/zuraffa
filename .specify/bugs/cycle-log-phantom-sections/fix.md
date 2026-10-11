# Bug Fix: cycle-log.md section parsing breaks on test output containing '## '

- **Slug**: cycle-log-phantom-sections
- **Fixed**: 2026-09-10 (plan) / 2026-09-11 (applied)
- **Assessment**: ./assessment.md
- **Verification**: ./test.md
- **Status**: applied (verified — see ./test.md)
- **TDD artifacts**: ./tdd/test-list.md (plan), ./tdd/cycle-log.md (run engine)

## Summary

Every cycle-log reader sectioned `tdd/cycle-log.md` with a naive
`raw.split('\n## ')`. Because the writer embeds captured test stdout verbatim
inside a fenced code block in each `## Cycle:` section, a captured line starting
with `## ` started a **phantom section**: the real entry's trailing fields
(`- kind:`, `- schema:`, `- prev-hash:`, `- hash:`) were stranded in the fake
chunk, so evidence was lost or misattributed and the doctor's hash-chain
verification failed.

The remediation is a shared, fence-aware splitter adopted at all 9 reader sites.
It was authored as a hand delta rather than driven by `zfa tdd run` — see the
roadblock record below and `./test.md` for why the engine lane could not certify
it on this machine.

## Roadblock (STOP-ON-ROADBLOCK record — resolved)

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
6. **Resolved**: #1471 was fixed by PR #1475 (merge `94048e31`), which landed on
   `master` before this branch's final rebase. `zfa tdd doctor` and
   `zfa tdd verify` now resolve `.specify/bugs/<slug>` by both bare slug and
   explicit path — confirmed with the rebuilt binary.

## Blocks hit after the roadblock cleared

The engine lane (`zfa tdd run`) still could not certify this fix locally. All
behaviors reached `green` (A1–A5), but the run stops at A1's refactor re-proof:

- **`#1333` retry doom loop.** The refactor re-proof takes the full-suite
  fallback (this run's passes reported `changed: (none)`, so `libChanged` was
  empty and `refactor_command.dart:545` never scopes). A cold whole-tree
  `dart test` on this machine peaked at a **42 GB** kernel cache and 20+ minutes;
  each `#1333` retry calls `clearDartTestKernelCache`, deleting
  `.dart_tool/test` and forcing another cold compile — three retries can consume
  well over 100 GB. The run was aborted deliberately rather than fill the disk.
- **`zfa tdd verify` returns `NOT_ASSESSED` (exit 3)** at its proof preflight:
  the `zfa tdd gen` receipt records the generated *stub* digest, and implementing
  the subject by hand — the designed hand-delta seam — changes the bytes. There is
  no re-seal command (`zfa proof` offers only `chain` / `check` / `prune`), and the
  prescribed remedy (re-run the generating verbs) would revert the subjects to
  stubs and destroy the fix. Recorded in `./test.md` under Residual Risks.

Neither block is a defect in this fix; both are tooling/environment limits.

## What was completed

- Branch `fix/cycle-log-phantom-sections` created.
- `spec.md` synthesized from the assessment (Given/When/Then ACs, template
  version migrated via `--migrate-spec`).
- `zfa tdd plan` → `./tdd/test-list.md`: 5 acceptance behaviors (A1–A5),
  0 unit, 0 widget; `**Type**` markers emitted into the spec.
- `./tasks.md` written with mandatory test tasks T001–T005 before
  implementation tasks T006–T007 (splitter + 9-site adoption).
- The fence-aware splitter implemented and adopted at all 9 reader sites, with
  the A1–A5 acceptance subjects hand-implemented behind the generated tests.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/cycle_log_sections.dart` | **added** | `splitCycleLogSections()` — tracks CommonMark backtick fences (incl. info-string fences); identical to the legacy split on fence-free input |
| `lib/src/plugins/tdd/services/cycle_evidence.dart` | modified | 2 sites adopt the splitter |
| `lib/src/plugins/tdd/commands/make_command.dart` | modified | 2 sites |
| `lib/src/plugins/tdd/commands/compose_command.dart` | modified | 2 sites |
| `lib/src/plugins/tdd/commands/verify_red_command.dart` | modified | 1 site |
| `lib/src/plugins/tdd/services/era_tagged_log.dart` | modified | 1 site |
| `lib/src/plugins/tdd/services/theater_data.dart` | modified | 1 site |
| `lib/src/plugins/tdd/services/replay_history.dart` | modified | 1 site |
| `test/tdd/cycle-log-phantom-sections/a{1..5}_test.dart` | **added** | acceptance tests A1–A5 |
| `lib/tdd/cycle-log-phantom-sections/a{1..5}_subject.dart` | **added** | hand-implemented subjects (the designed hand-delta seam) |
| `test/plugins/tdd/theater/theater_data_test.dart` | modified | U3 edge fixture migrated to the fence-aware contract |
| `.specify/bugs/cycle-log-phantom-sections/spec.md` | added | synthesized from assessment.md; migrated to `zuraffa-1.0` template |
| `.specify/bugs/cycle-log-phantom-sections/tdd/test-list.md` | added | zfa tdd plan output, 5 acceptance behaviors |
| `.specify/bugs/cycle-log-phantom-sections/tasks.md` | added | test tasks mandatory, before implementation tasks |

Zero naive `raw.split('\n## ')` calls remain in `lib/src`.

## Deviations from Assessment

- The plan is unchanged: the shared fence-aware splitter at all 9 reader sites
  is what shipped. The remediation was authored by hand rather than through
  `zfa tdd run`, for the reasons recorded above.
- One pre-existing test had to be migrated rather than merely kept green:
  `test/plugins/tdd/theater/theater_data_test.dart` U3 encoded the *buggy*
  expectation (an unterminated fence producing a phantom fifth cycle). It now
  asserts the fence-aware contract. This is a contract correction, not a
  loosened assertion — the migrated test fails against pre-fix `master`.
- The A1–A5 test names are truncated mid-sentence ("each sections the file
  through the shared"), because the `**Type**: acceptance` markers that
  `zfa tdd plan` injects into `spec.md` split the acceptance criteria mid-clause.
  Cosmetic, and routing was unaffected, but worth a follow-up.

## Follow-ups

- Writer-side fence hardening (option 1/2 from issue #1467) remains a
  deliberate follow-up, not part of this fix.
- Proof receipts for hand-implemented subjects: the hand-delta seam invalidates
  the `zfa tdd gen` receipt and there is no re-seal, so `zfa tdd verify` cannot
  pass. Needs a design decision.
- `--baseline-scope` covers the baseline and `make` but not `refactor`, so the
  refactor re-proof still runs the whole suite — the main driver of the `#1333`
  doom loop on constrained machines.
