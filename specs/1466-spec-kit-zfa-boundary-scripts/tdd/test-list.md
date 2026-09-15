# Test List: Spec-Kit ↔ ZFA Boundary Scripts — Acceptance Hardening

**Feature**: 1466-spec-kit-zfa-boundary-scripts
**Template**: zuraffa-1.0
**Generated**: 2026-09-15

This test list traces every testable behavior to its source criterion
(acceptance criteria from user stories or functional requirements in
`spec.md`). IDs are prefixed by the script under test: S = sync-behaviors,
P = read-tdd-profile, E = read-cycle-evidence, T = tick-behavior-task.

---

## Acceptance Behaviors (Outer Loop)

These behaviors trace to the Given/When/Then scenarios in the user stories.

### User Story 1 - Durable unit tests for every boundary script

**S1**: Sync script inserts behavior markers grouped by section
**Criterion**: US1-1 - Given tasks.md without markers and test-list.md defining A1/U1/C1, When sync runs, Then one [behavior: <id>] marker per behavior appears under Acceptance/Unit/Characterization Behaviors sections
**Status**: DONE
**Evidence**: RED @ Mutation M1 (marker_exists no-op: 4/6 failed incl. S1) - GREEN @ 24/24 ALL GREEN run: A1/U1/C1 markers grouped into the three sections

**S2**: Sync script is idempotent and preserves existing lines byte-identically
**Criterion**: US1-2 - Given tasks.md already contains markers, When sync runs twice, Then first run inserts only missing markers, existing lines stay byte-identical, second run reports behaviors_added 0
**Status**: DONE
**Evidence**: RED @ Mutation M1 - GREEN @ 24/24: first run added 2, existing lines byte-identical, second run behaviors_added=0

**S3**: Sync script rejects duplicate behavior IDs without mutating tasks.md
**Criterion**: US1-3 - Given test-list.md with a duplicate ID, When sync runs, Then exit non-zero with descriptive error and tasks.md unchanged
**Status**: DONE
**Evidence**: GREEN @ 24/24: duplicate A1 exits 2 with 'Duplicate behavior ID' on stderr, tasks.md md5 unchanged

**S4**: Sync script skips malformed behavior IDs with a warning but syncs valid ones
**Criterion**: US1-4 - Given a malformed ID in test-list.md, When sync runs, Then warning on stderr, malformed entry skipped, valid behaviors synced
**Status**: DONE
**Evidence**: RED @ Mutation M1 - GREEN @ 24/24: 'ab1' warned and skipped, A1 synced, no [behavior: ab1] marker

**S5**: Sync script fails loudly on missing input files
**Criterion**: FR-2 error tier - Given missing test-list.md or tasks.md, When sync runs, Then exit non-zero with error on stderr
**Status**: DONE
**Evidence**: GREEN @ 24/24: missing test-list and missing tasks each exit 1 with named error on stderr

**S6**: Sync script emits the documented JSON success shape
**Criterion**: FR-4 - Given --json, When sync succeeds, Then output has status=success, behaviors_added count, behaviors array (asserted via jq when present)
**Status**: DONE
**Evidence**: RED @ Mutation M1 - GREEN @ 24/24: status=success, behaviors_added=2, behaviors=[A1, U1] via jq

**P1**: Profile script emits dart engine JSON
**Criterion**: US1-5 - Given tdd-profile.md with engine dart, When read with --json, Then JSON carries engine and test_command
**Status**: DONE
**Evidence**: RED @ Mutation M2 (ENGINE emptied: 5/6 failed incl. P1) - GREEN @ 24/24: engine=dart, test_command=dart test via jq

**P2**: Profile script emits flutter engine JSON including optional commands
**Criterion**: US1-6 - Given engine flutter with verify_command and plan_command, When read with --json, Then all four fields carry the flutter values
**Status**: DONE
**Evidence**: RED @ Mutation M2 - GREEN @ 24/24 (after tier-agnostic fixture refactor): all four flutter fields round-trip

**P3**: Profile script emits null for absent optional fields
**Criterion**: US1-6 (second clause) + FR-2 edge tier - Given optional fields absent, When read with --json, Then verify_command and plan_command are JSON null; text mode shows (not configured)
**Status**: DONE
**Evidence**: RED @ Mutation M2 - GREEN @ 24/24: verify_command/plan_command JSON null; text '(not configured)'

**P4**: Profile script fails loudly on missing file or missing frontmatter
**Criterion**: FR-2 error tier - Given missing tdd-profile.md or file without frontmatter, When read runs, Then exit non-zero with error on stderr
**Status**: DONE
**Evidence**: GREEN @ 24/24: missing file and no-frontmatter both exit 1 with errors on stderr

**P5**: Profile script requires engine and test_command fields
**Criterion**: FR-2 error tier - Given frontmatter missing engine or missing test_command, When read runs, Then exit non-zero
**Status**: DONE
**Evidence**: RED @ Mutation M2 - GREEN @ 24/24: missing engine and missing test_command each exit 1

**P6**: Profile script text mode lists engine and commands
**Criterion**: FR-2 normal tier (text output) - Given valid profile, When read without --json, Then output lists Engine, Test Command lines
**Status**: DONE
**Evidence**: RED @ Mutation M2 - GREEN @ 24/24: text mode lists Engine and Test Command lines

**E1**: Evidence script parses RED/GREEN/REFACTOR entries into JSON
**Criterion**: US1-7 - Given cycle-log with RED, GREEN, REFACTOR entries, When read with --json, Then each entry returned with phase and behavior fields
**Status**: DONE
**Evidence**: RED @ Mutation M3 (GREEN phase dropped: 2/5 failed incl. E1) - GREEN @ 24/24: 4 entries, phases/ids/timestamps/evidence_text asserted via jq

**E2**: Evidence script skips malformed entries with a warning
**Criterion**: US1-7 (second clause) - Given a malformed entry, When read runs, Then warning on stderr, malformed skipped, valid entries kept
**Status**: DONE
**Evidence**: RED @ Mutation M3 - GREEN @ 24/24: malformed BROKEN-phase entry warned + skipped, 2 valid entries kept

**E3**: Evidence script returns zero entries for a log without evidence
**Criterion**: FR-2 edge tier - Given a cycle-log with no evidence entries, When read with --json, Then zero entries, exit 0
**Status**: DONE
**Evidence**: GREEN @ 24/24: narrative-only log yields zero-entry JSON, exit 0

**E4**: Evidence script fails loudly on missing file
**Criterion**: FR-2 error tier - Given missing cycle-log.md, When read runs, Then exit non-zero with error on stderr
**Status**: DONE
**Evidence**: GREEN @ 24/24: missing cycle-log exits 1 with named error

**E5**: Evidence script text mode summarizes entries; JSON is jq-parseable
**Criterion**: FR-4 + FR-2 normal tier - Given valid log, When read, Then text mode lists entries; --json parses via jq when present
**Status**: DONE
**Evidence**: GREEN @ 24/24: text 'Found 3 evidence entries:' with rendered entries; JSON parses via jq -e

**T1**: Tick script ticks exactly the requested behavior line
**Criterion**: US1-8 - Given unticked [behavior: U1] among other tasks, When tick --behavior U1 runs, Then only that checkbox becomes [x], all other lines byte-identical, JSON status success
**Status**: DONE
**Evidence**: RED @ Mutation M4 (marker literal broken: 5/7 failed incl. T1) - GREEN @ 24/24 (after diff-based assertion refactor): only U1 line changed, byte-exact

**T2**: Tick script reports already_done without rewriting the file
**Criterion**: US1-9 (first clause) - Given behavior already ticked, When tick re-runs, Then exit 0, already_done, file unchanged
**Status**: DONE
**Evidence**: RED @ Mutation M4 - GREEN @ 24/24: exit 0, already_done status, file md5 unchanged

**T3**: Tick script fails on unknown behavior without mutating the file
**Criterion**: US1-9 (second clause) - Given unknown behavior id, When tick runs, Then exit non-zero, file unchanged
**Status**: DONE
**Evidence**: GREEN @ 24/24: unknown Z9 exits 1, 'not found' error, file md5 unchanged

**T4**: Tick script ticks first occurrence and warns on duplicate markers
**Criterion**: FR-2 edge tier - Given two markers for one id, When tick runs, Then first ticked, warning on stderr, second marker line untouched
**Status**: DONE
**Evidence**: RED @ Mutation M4 - GREEN @ 24/24: first marker ticked, WARNING on stderr, second marker still unticked

**T5**: Tick script requires the --behavior flag
**Criterion**: FR-2 error tier - Given --behavior omitted or empty, When tick runs, Then exit non-zero with usage on stderr
**Status**: DONE
**Evidence**: GREEN @ 24/24: omitted and dangling --behavior both exit 1 with usage on stderr

**T6**: Tick script emits the documented JSON success shape
**Criterion**: FR-4 - Given --json, When tick succeeds, Then JSON has status=success and behavior_id (asserted via jq when present)
**Status**: DONE
**Evidence**: RED @ Mutation M4 - GREEN @ 24/24: status=success, behavior_id=U1 via jq

**T7**: Tick script preserves file permission bits across atomic replace
**Criterion**: FR-2 edge tier (regression guard) - Given tasks.md mode 0644, When tick runs, Then file mode still 0644 (mktemp-0600 hazard guarded)
**Status**: DONE
**Evidence**: RED @ Mutation M4 - GREEN @ 24/24: mode 644 preserved across atomic replace

## Unit Behaviors (Inner Loop)

**U1**: Harness provides case registration, assertions, fixture factory, and per-file reporting
**Criterion**: FR-1 - harness.sh supplies t_case, t_assert_eq, t_assert_contains, t_assert_exit, t_fixture_dir, t_report with zero external dependencies
**Status**: DONE
**Evidence**: GREEN @ 24/24 run: harness exercised by every case; SUITE line aggregated by runner

**U2**: Runner aggregates every test_*.sh and prints one aggregate line
**Criterion**: FR-5 - Given the four test files, When run_tests.sh executes, Then per-test PASS/FAIL lines, per-file summary, aggregate Passed: N/N, exit 0 when all pass
**Status**: DONE
**Evidence**: RED @ first full run (23/24, VERDICT: FAIL) - GREEN @ 24/24, VERDICT: ALL GREEN

**U3**: Runner exits non-zero and names the failing test when a case fails
**Criterion**: US2-2 - Given a forced-fail case, When runner executes, Then exit non-zero and the failing test id is printed
**Status**: DONE
**Evidence**: RED @ first full run (failing case T1 named, non-zero exit) - GREEN @ mutations M1-M4 all reported non-zero with named cases

**U4**: Runner runs shellcheck on the four boundary scripts and fails on warnings
**Criterion**: FR-6 + SC-2 - Given shellcheck installed, When runner executes, Then shellcheck -x -S warning runs on all four scripts and any warning fails the run
**Status**: DONE
**Evidence**: GREEN @ full-PATH run: 'shellcheck OK' printed for all four scripts; failure branch exits 1

**U5**: Runner skips the shellcheck gate with a loud notice when shellcheck is absent
**Criterion**: FR-6 honesty clause - Given shellcheck missing, When runner executes, Then SKIP notice printed (never silently green)
**Status**: DONE
**Evidence**: GREEN @ PATH=/usr/bin:/bin run: 'SKIP: shellcheck not installed' notice printed, suite still honest

## Verification Behaviors (documentation, non-behavioral where noted)

**V1**: README documents all four integration points with arguments and JSON shapes
**Criterion**: SC-4 + US3-1..3 - README.md names sync/read-profile/read-evidence/tick with skill-step mappings, argument tables, exit contracts
**Status**: PENDING
**Note**: non-behavioral (markdown) — verified by inspection + link-check against test suite coverage, not by a RED cycle.
