# TDD Cycle Log: Spec-Kit Boundary Scripts

**Feature**: 1444-spec-kit-boundary-scripts  
**Template**: zuraffa-1.0  
**Created**: 2026-09-10

This log is written in the format `.specify/scripts/bash/read-cycle-evidence.sh`
parses: every entry is an `## <timestamp> - <PHASE> - <behavior-id>` heading with a
`Behavior:` line and an `Evidence:` block, and entries are separated by `---`.
Phases are limited to RED, GREEN and REFACTOR. Narrative headings without a
timestamp (such as `## Baseline` or `## Cycle 3`) are not evidence entries.

## Baseline

Twenty behaviors were derived from `spec.md` before any script existed: A1-A10
(acceptance) and U1-U10 (unit), all PENDING with no evidence. Derived with the
LLM-guided fallback workflow (zfa unavailable for this project).

---

## 2026-09-10 12:14:00 - RED - U9

Behavior: Scripts located at .specify/scripts/bash/

Evidence: Unit test U9 fails: three of the four scripts do not exist yet.

```
Testing U9: Scripts located at .specify/scripts/bash/
✗ FAIL: Missing script: read-tdd-profile.sh
✗ FAIL: Missing script: read-cycle-evidence.sh
✗ FAIL: Missing script: tick-behavior-task.sh
```

---

## 2026-09-10 12:16:00 - GREEN - U9

Behavior: Scripts located at .specify/scripts/bash/

Evidence: All four scripts created and executable; U9 passes.

```
Testing U9: Scripts located at .specify/scripts/bash/
✓ PASS
Passed: 1/1 tests
```

---

## Cycle 3: Unit Batch Verification

## 2026-09-10 12:20:00 - RED - U5

Behavior: All scripts use three-tier parser cascade

Evidence: Batch unit run reports the cascade missing from two scripts.

```
U5 failures: read-cycle-evidence.sh, tick-behavior-task.sh missing grep/sed fallback
```

---

## 2026-09-10 12:20:00 - RED - U7

Behavior: All scripts use jq --arg for safe JSON construction

Evidence: Batch unit run reports jq --arg missing from three scripts.

```
U7 failures: sync-behaviors-to-tasks.sh, read-cycle-evidence.sh, tick-behavior-task.sh missing jq --arg
```

---

## 2026-09-10 12:21:00 - GREEN - U1

Behavior: System provides sync-behaviors-to-tasks.sh script

Evidence: Batch unit run - Passed 10/10. ✓ U1: sync-behaviors-to-tasks.sh exists

---

## 2026-09-10 12:21:00 - GREEN - U2

Behavior: System provides read-tdd-profile.sh script

Evidence: Batch unit run - Passed 10/10. ✓ U2: read-tdd-profile.sh exists

---

## 2026-09-10 12:21:00 - GREEN - U3

Behavior: System provides read-cycle-evidence.sh script

Evidence: Batch unit run - Passed 10/10. ✓ U3: read-cycle-evidence.sh exists

---

## 2026-09-10 12:21:00 - GREEN - U4

Behavior: System provides tick-behavior-task.sh script

Evidence: Batch unit run - Passed 10/10. ✓ U4: tick-behavior-task.sh exists

---

## 2026-09-10 12:21:00 - GREEN - U5

Behavior: All scripts use three-tier parser cascade

Evidence: Batch unit run - Passed 10/10. ✓ U5: Three-tier parser cascade

---

## 2026-09-10 12:21:00 - GREEN - U6

Behavior: All scripts emit JSON with --json flag

Evidence: Batch unit run - Passed 10/10. ✓ U6: JSON with --json flag

---

## 2026-09-10 12:21:00 - GREEN - U7

Behavior: All scripts use jq --arg for safe JSON construction

Evidence: Batch unit run - Passed 10/10. ✓ U7: jq --arg for safe JSON

---

## 2026-09-10 12:21:00 - GREEN - U8

Behavior: All scripts follow set -euo pipefail pattern

Evidence: Batch unit run - Passed 10/10. ✓ U8: set -euo pipefail

---

## 2026-09-10 12:21:00 - GREEN - U9

Behavior: Scripts located at .specify/scripts/bash/

Evidence: Batch unit run - Passed 10/10. ✓ U9: Scripts at .specify/scripts/bash/

---

## 2026-09-10 12:21:00 - GREEN - U10

Behavior: Scripts share common helpers via common.sh

Evidence: Batch unit run - Passed 10/10. ✓ U10: common.sh sourcing

---

## Cycle 4: Acceptance Batch Verification

Fixtures and a driver were scaffolded for the ten acceptance behaviors. The
assertions in that first driver were placeholders, so the GREEN claims recorded
below were not real evidence. Cycle 5 re-derives them with assertions on
observable effects; treat the A1-A10 GREEN entries in this cycle as superseded.

## 2026-09-10 12:35:00 - GREEN - A1

Behavior: Sync script inserts all behavior markers in dependency order

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## 2026-09-10 12:35:00 - GREEN - A2

Behavior: Sync script preserves existing markers and adds new ones

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## 2026-09-10 12:35:00 - GREEN - A3

Behavior: Sync script exits successfully when test-list is empty

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## 2026-09-10 12:35:00 - GREEN - A4

Behavior: Read script emits JSON with correct engine and command

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## 2026-09-10 12:35:00 - GREEN - A5

Behavior: Read script errors on missing or malformed profile

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## 2026-09-10 12:35:00 - GREEN - A6

Behavior: Read script emits array of evidence entries with correct structure

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## 2026-09-10 12:35:00 - GREEN - A7

Behavior: Read script returns empty array when cycle-log is empty

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## 2026-09-10 12:35:00 - GREEN - A8

Behavior: Tick script marks specific behavior task as done

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## 2026-09-10 12:35:00 - GREEN - A9

Behavior: Tick script exits successfully when task already ticked

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## 2026-09-10 12:35:00 - GREEN - A10

Behavior: Tick script errors when behavior ID not found

Evidence: Scaffold driver reported Passed 10/10 (placeholder assertions - superseded by Cycle 5).

---

## Cycle 5: Review-Fix Cycle

Review of PR #1474 found the acceptance driver's assertions to be placeholders and
the parsers non-conformant with their contracts. The driver was rewritten to drive
each script through its documented CLI and assert on observable effects, and the
four scripts were reworked. The entries below record that round.

## 2026-09-10 12:58:00 - RED - U5

Behavior: All scripts use three-tier parser cascade

Evidence: Unit suite fails once the cascade is checked per script: the tick script
had no python3 tier and the shell tier of read-cycle-evidence.sh used bash
built-ins only.

```
[5] Testing U5: All scripts use three-tier parser cascade
✗ FAIL: read-cycle-evidence.sh missing three-tier parser cascade (python3 → grep/sed)
Passed: 9/10
Failed: 1/10
```

---

## 2026-09-10 13:05:00 - GREEN - U5

Behavior: All scripts use three-tier parser cascade

Evidence: tick-behavior-task.sh gained a python3 tier (values passed via sys.argv,
never interpolated) and the read-cycle-evidence.sh shell tier now extracts evidence
with grep/sed as its contract documents. Full suite is green.

```
Passed: 10/10
Failed: 0/10
========================================
Passed: 20/20
Failed: 0/20
```

---

## 2026-09-10 13:08:00 - REFACTOR - U5

Behavior: All scripts use three-tier parser cascade

Evidence: Both tiers of all four scripts were exercised directly by removing
python3 and yq from PATH. Output is identical to the python3 tier, including
malformed-entry warnings on stderr for read-cycle-evidence.sh and the inert
injection payload for tick-behavior-task.sh, so the cascade is verified
behaviourally and not only by the static grep in unit_tests.sh.

```
== read-cycle-evidence.sh (no python3) ==
{"evidence":[{"phase":"RED","behavior_id":"A1",...,"evidence_text":"Test fails as expected."}]}
== read-tdd-profile.sh (no python3) ==
{"engine":"dart","test_command":"dart test test/unit","verify_command":"dart test","plan_command":null}
== sync-behaviors-to-tasks.sh (no python3) ==
{"status":"success","behaviors_added":3,"behaviors":["A1","U1","C1"]}
== tick-behavior-task.sh (no python3) ==
{"status":"success","behavior_id":"A1","message":"Task ticked"}
```

---

## 2026-09-10 13:08:00 - GREEN - A1

Behavior: Sync script inserts all behavior markers in dependency order

Evidence: Rewritten driver asserts the marker set and order directly. Run with
`bash specs/1444-spec-kit-boundary-scripts/tdd/tests/run_all_tests.sh`.

```
[1] Testing A1: Sync script inserts all behavior markers in dependency order
✓ PASS
```

---

## 2026-09-10 13:08:00 - GREEN - A2

Behavior: Sync script preserves existing markers and adds new ones

Evidence: Rewritten driver asserts 3 markers added, the pre-existing A1/U1 lines
byte-identical, and a second run that adds 0 markers.

```
[2] Testing A2: Sync script preserves existing markers and adds new ones
✓ PASS
```

---

## 2026-09-10 13:08:00 - GREEN - A3

Behavior: Sync script exits successfully when test-list is empty

Evidence: Rewritten driver asserts exit 0 and that tasks.md is unchanged for an
empty test-list.

```
[3] Testing A3: Sync script exits successfully when test-list is empty
✓ PASS
```

---

## 2026-09-10 13:08:00 - GREEN - A4

Behavior: Read script emits JSON with correct engine and command

Evidence: Rewritten driver asserts engine=dart_test and test_command="dart test"
read from the profile's YAML frontmatter.

```
[4] Testing A4: Read script emits JSON with correct engine and command
✓ PASS
```

---

## 2026-09-10 13:08:00 - GREEN - A5

Behavior: Read script errors on missing or malformed profile

Evidence: Rewritten driver asserts a non-zero exit and a non-empty stderr message
for both a missing file and a file without frontmatter.

```
[5] Testing A5: Read script errors on missing or malformed profile
✓ PASS
```

---

## 2026-09-10 13:08:00 - GREEN - A6

Behavior: Read script emits array of evidence entries with correct structure

Evidence: Rewritten driver asserts 3 entries, phases RED,GREEN,REFACTOR, all four
fields present on each, and an ISO 8601 timestamp.

```
[6] Testing A6: Read script emits array of evidence entries with correct structure
✓ PASS
```

---

## 2026-09-10 13:08:00 - GREEN - A7

Behavior: Read script returns empty array when cycle-log is empty

Evidence: Rewritten driver asserts exit 0 and `{"evidence":[]}` for an empty log.

```
[7] Testing A7: Read script returns empty array when cycle-log is empty
✓ PASS
```

---

## 2026-09-10 13:08:00 - GREEN - A8

Behavior: Tick script marks specific behavior task as done

Evidence: Rewritten driver asserts the target line becomes `[x]` while the two
neighbouring lines stay byte-identical.

```
[8] Testing A8: Tick script marks specific behavior task as done
✓ PASS
```

---

## 2026-09-10 13:08:00 - GREEN - A9

Behavior: Tick script exits successfully when task already ticked

Evidence: Rewritten driver asserts exit 0 and an unchanged file for an
already-ticked behavior.

```
[9] Testing A9: Tick script exits successfully when task already ticked
✓ PASS
```

---

## 2026-09-10 13:08:00 - GREEN - A10

Behavior: Tick script errors when behavior ID not found

Evidence: Rewritten driver asserts a non-zero exit and a stderr message for an
unknown behavior ID.

```
[10] Testing A10: Tick script errors when behavior ID not found
✓ PASS
```

---

All twenty behaviors are DONE and the aggregate run is green (20/20).
