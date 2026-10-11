---
feature: 1412-refactor-console-excerpt-tail
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 6
planned_at: 2ac6b9d
updated_at: 2ac6b9d
suite_baseline: green
---

# Test List: Refactor failure console excerpt tail (issue #1412)

The behavior under test is the run driver's failed-step CONSOLE excerpt —
which slice of a failed step's transcript the operator sees in `zfa tdd
run` output — plus the build analyze gate's ownership-aware refusal remedy
(secondary nit). The loop is outside-in at the driver's console seam: the
primary behaviors are driver-tier (TddFixture + fake zfa + CliRunner
runCapturing, the bug_1329 harness), because the contract is "what the
operator sees", and the secondary remedy behaviors are unit-tier pure
statics. The recorded-evidence tail (#1329) is pinned as a regression
constraint, never re-derived.

## Outer loop: console excerpt semantics

### The diagnostic tail (SC-1, SC-2)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| R1 | A failed refactor step whose transcript opens with the passing preflight block and ends with the failing-pass block shows the FAILING-PASS lines (`pass: build`, `exit: 1`, `pass "build" failed — misfire-stop.`) in the run's console excerpt — never the preflight head (`preflight exit: 0` absent from the captured stdout) | SC-1 | example | DONE | `test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart::U-1412-1` |
| R2 | A failed-step transcript deeper than the excerpt depth carries the honest truncation marker wording (`truncated`, `last 10 of`) in the console excerpt — the `_outputTail`-reuse proof (no second tail implementation) | SC-2 | example | DONE | `...bug_1412_refactor_excerpt_tail_test.dart::U-1412-2` |

### The short-transcript and recorded-path contracts (SC-3, SC-4)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| R3 | A failed-step transcript at or below the excerpt depth prints every non-empty line and NO truncation marker (the common small-failure case is content-unchanged) | SC-3 | example | DONE | `...bug_1412_refactor_excerpt_tail_test.dart::U-1412-3` |
| R4 | The same failing step's cycle-log error section still truncates at the LAST 200 lines with the #1329 marker (`200 of 251`) and carries the final diagnostic line — the recorded-evidence path is byte-identical (hard constraint) | SC-4 | characterization | DONE | `...bug_1412_refactor_excerpt_tail_test.dart::U-1412-4` |

## Secondary loop: build-gate ownership remedy (SC-5)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| R5 | `analyzerOffendingPaths` extracts the deduped, first-seen-ordered `path:line:col` fields of error/warning severity lines ONLY — info lines and summary counts never fabricate offenders | SC-5 | example | DONE | `test/commands/build_command_unit_test.dart::analyzerOffendingPaths (issue #1412)` |
| R6 | `analyzeGateRemedyLines` — hand-authored-only offenders → ownership-naming remedy lines and NO "Fix the generator"; generated-only offenders → the existing "Fix the generator" remedy; >3 hand-authored files cap with a `+N more` remainder | SC-5 | example | DONE | `...build_command_unit_test.dart::analyzeGateRemedyLines (issue #1412)` |

## Characterization pins (green-before-write by design)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| P1 | The #1329 journal/cycle-log tail for a >200-line failed gen step is unchanged (pre-existing suite) | SC-4 | characterization | DONE | `test/plugins/tdd/bug_1329_step_failure_diagnostics_test.dart::U-1329-5` (existing, unchanged) |
| P2 | The #1472 warnings-only gate readers still parse the verdict pattern (pre-existing suite) | SC-5 | characterization | DONE | `test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart` (existing, unchanged) |

## Invariants and edge cases still to place

- The excerpt is compact (empty lines never consume slots) — folded into
  R1/R3's fixture transcripts, which carry interior blank padding in the
  flood tail; a dedicated row would duplicate R3's assertion surface.
- Empty output prints nothing — structurally guaranteed by the compact-join
  guard; not independently observable through the driver harness (no failed
  step produces zero output — every spawn failure carries a message), so it
  is covered by the guard's presence, not a test row.
- The marker's `of M` count reflects the compacted line count — R2 asserts
  the stable `last 10 of` prefix, not a brittle full-line match.
