---
feature: 1549-fence-aware-remaining-readers
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 6
planned_at: local
updated_at: local
suite_baseline: green
---

# Test List: Fence-aware cycle-log splitting in the three remaining line-scanner readers

The shared fence-aware splitter (`splitCycleLogSections`, vendored from PR
#1543) exists; three line-scanner readers still section `tdd/cycle-log.md`
by matching `## Cycle:` on raw lines, so an in-fence `## Cycle:` line (a
markdown banner a test printed into its captured output) becomes a phantom
entry. The loop is inside-out: the shared iterator is a unit surface, each
reader gets one end-to-end fixture through its public API, every behavior
traces to a spec success criterion.

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/cycle_log_entry_sections.dart` (`parseCycleLogEntrySections`)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U1 | A `## Cycle: B-001 (red)` section parses to header `Cycle: B-001 (red)`, behavior `B-001`, kind `red` | SC-4 | example | DONE | `test/plugins/tdd/services/cycle_log_entry_sections_test.dart::parses the Cycle header grammar` |
| U2 | Preamble (`# Cycle Log` prose) and non-`Cycle:` `## ` sections are skipped | SC-4 | example | DONE | `test/plugins/tdd/services/cycle_log_entry_sections_test.dart::skips the preamble and non-Cycle sections` |
| U3 | Body lines are verbatim — an in-fence `## Cycle:` line stays a BODY line, never a section | SC-4 | example | DONE | `test/plugins/tdd/services/cycle_log_entry_sections_test.dart::keeps an in-fence Cycle line in the body` |
| U4 | A byte-0 `## Cycle:` header (legacy split keeps its `## ` prefix on chunk 0) still parses as an entry | SC-4 | example | DONE | `test/plugins/tdd/services/cycle_log_entry_sections_test.dart::parses a byte-0 header with its legacy ## prefix` |
| U5 | The inline `- output: ``` ` dialect (committed 068 form) fences correctly — later `## ` in-fence lines stay in the body | SC-4 | example | DONE | `test/plugins/tdd/services/cycle_log_entry_sections_test.dart::honors the inline output-fence dialect` |
| U6 | A header with no behavior token (`## Cycle:`) yields an empty behavior, never a crash | SC-4 | edge | DONE | `test/plugins/tdd/services/cycle_log_entry_sections_test.dart::tolerates a header with no behavior token` |

### `test/plugins/tdd/services/cycle_log_sections_test.dart` (vendored, PR #1543)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| V1 | The vendored splitter's 12-test suite passes byte-identical on this branch | SC-4 | characterization | DONE | `test/plugins/tdd/services/cycle_log_sections_test.dart` |

## Outer loop: reader fixtures (public API, one per reader)

### `lib/src/plugins/tdd/services/provenance_scanner.dart` (`_collectRefactorAttributions`)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| R1 | An in-fence `## Cycle: PHANTOM (refactor)` + `changed: lib/src/phantom.dart` in a RED entry attributes nothing; the real refactor entry's `changed: lib/src/real.dart` attributes to its action command | SC-1 | example | DONE | `test/plugins/tdd/services/provenance_scanner_test.dart::an in-fence Cycle line never flips refactor attribution (1549)` |
| R2 | A well-formed refactor log attributes exactly as before (existing U26 suite) | SC-5 | characterization | DONE | existing `U26 — cycle-log refactor changed lists attribute` |

### `lib/src/plugins/tdd/services/ci_referee/failure_artifacts.dart` (`_parseRedEntries`)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| R3 | A red entry with an in-fence `## Cycle:` line yields ONE artifact; the excerpt reaches the captured output's end; `failingLine` is the post-phantom frame; the in-fence line stays verbatim in the excerpt | SC-2 | example | DONE | `test/plugins/tdd/services/ci_referee/failure_artifacts_test.dart::an in-fence Cycle line never truncates the red excerpt (1549)` |
| R4 | Well-formed red entries keep their artifacts (existing A11 suite) | SC-5 | characterization | DONE | existing `A11` |

### `lib/src/plugins/tdd/services/ci_referee/feature_provenance_reader.dart` (`_readGreenBehaviors`)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| R5 | A red entry with in-fence `## Cycle: PHANTOM (green)` + `- kind: green` never greens PHANTOM; the real green sibling completes the feature → `complete(real)` | SC-3 | example | DONE | `test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart::an in-fence Cycle line never greens a phantom behavior (1549)` |
| R6 | Well-formed green evidence keeps driving state (existing U1/U3 suites) | SC-5 | characterization | DONE | existing `U1`, `U3` |

## Invariants and edge cases still to place

- None outstanding: in-fence field-shaped lines (`- kind:` / `changed:`)
  inside a section body keep their current (fence-blind) semantics by spec
  constraint — masking them is an out-of-scope behaviour change; the
  `## <timestamp>: <behavior> (kind)` dialect never matched `## Cycle:` and
  stays unmatched.
