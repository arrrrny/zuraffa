# 1549-fence-aware-remaining-readers

- **Spec ID**: 1549-fence-aware-remaining-readers
- **Created**: 2026-09-13
- **Source**: GitHub issue #1549 (SPEC 1549 — adopt fence-aware cycle-log splitting in the three remaining line-scanner readers)
- **Type**: bug/feature (P2 — evidence misattribution under in-fence `## ` lines; provenance/CI-referee output corruption, no crash)
- **Branch**: feat/1549-fence-aware-remaining-readers
- **Related**: #1467 (original fence-aware fix), PR #1543 (unmerged — its `cycle_log_sections.dart` helper is vendored into this branch so this PR is self-contained against `master`)

## Problem

PR #1543's `splitCycleLogSections()` (`lib/src/plugins/tdd/services/cycle_log_sections.dart`)
made every `raw.split('\n## ')` cycle-log reader fence-aware. Three further
cycle-log readers scan `specs/<feature>/tdd/cycle-log.md` **line-by-line with
their own state machines** and remain fence-blind — the same defect class as
#1467, a different shape than `split`:

| File | Site | Symptom on an in-fence `## Cycle:` line |
|---|---|---|
| `lib/src/plugins/tdd/services/provenance_scanner.dart` | `_collectRefactorAttributions` (~line 182) | a phantom `(refactor)` header flips `inRefactorSection`, so in-fence `changed:` lines become file attributions |
| `lib/src/plugins/tdd/services/ci_referee/failure_artifacts.dart` | `_parseRedEntries` (~line 109) | an in-fence `## Cycle:` line calls `closeEntry()` early — the excerpt is truncated, the failing frame lost |
| `lib/src/plugins/tdd/services/ci_referee/feature_provenance_reader.dart` | `_readGreenBehaviors` (~line 138) | `currentBehavior` is set from the phantom header, so a following `- kind: green` line is attributed to the phantom instead of the entry's real behavior |

Concretely: cycle-log entries embed captured test stdout verbatim inside
fenced code blocks (`- output:` + fence, `CycleLogEntry.toMarkdown`). A test
that prints a markdown banner (`## Cycle: …`) — e.g. a meta-test rendering a
sample log — plants a phantom `## Cycle:` line inside a fence. The three
readers react to it as if a new entry had started, misattributing provenance,
truncating failure excerpts, and crediting green evidence to a behavior that
does not exist.

## Goal

Every cycle-log reader sections the log through the shared fence-aware
splitter: no in-fence `## ` line can start a section, flip scanner state,
close an excerpt early, or steal a behavior attribution — while output for
well-formed logs stays byte-identical.

## Success criteria (measurable)

- **SC-1** (provenance_scanner): a red entry whose captured output contains
  an in-fence `## Cycle: X (refactor)` line and an in-fence
  `changed: lib/src/phantom.dart` line attributes NO file named by the
  in-fence content; a real refactor entry's `changed:` list in the same log
  still attributes (`lib/src/real.dart` → `AttributionSource.refactor`,
  command = the action's recorded command).
- **SC-2** (failure_artifacts): a red entry whose captured output contains an
  in-fence `## Cycle:` line yields exactly ONE artifact whose excerpt runs to
  the end of the captured output — the failing frame after the phantom line
  (`.dart:<n>`) is the `failingLine`, and the in-fence `## Cycle:` line itself
  is retained verbatim inside the excerpt (captured output is evidence).
- **SC-3** (feature_provenance_reader): a red entry whose captured output
  contains an in-fence `## Cycle: PHANTOM (green)` + `- kind: green` pair
  never makes `PHANTOM` green; the line attributes (current contract) to the
  section's REAL behavior, and the feature's realization state reflects the
  real behaviors only (registered-and-really-green behaviors complete the
  feature; a phantom never completes it).
- **SC-4** (shared routing): each of the three readers routes through
  `splitCycleLogSections()` (via the shared entry-sections iterator
  `parseCycleLogEntrySections()` built on it); no reader keeps fence-blind
  `## Cycle:` line matching for sectioning.
- **SC-5** (no regression): for a well-formed cycle-log (headers at column 0,
  fences balanced, in-fence content free of field-shaped lines) all three
  readers produce the same output as before the change — the existing
  U25–U30, A11–A13, and U1–U6 suites pass untouched.
- **SC-6** (hygiene): `dart analyze` on the changed files reports no new
  warnings; `dart format` is clean on the changed files.

## Hard constraints

- Must not break existing provenance/CI-referee output for well-formed
  cycle-logs (SC-5).
- `lib/src/plugins/tdd/services/cycle_log_sections.dart` and its test stay
  BYTE-IDENTICAL to PR #1543's version (vendored, not forked) so whichever
  PR merges first, git auto-resolves the add/add.
- `cycle_evidence.dart`'s naive `raw.split('\n## ')` sites are PR #1543's
  scope — untouched here.
- The readers' body-level field semantics (`- kind:`/`changed:`/`- test:`
  matching on section body lines, `command:`/`changed:` state machine) are
  preserved as-is; the change is WHERE sections come from, not what a body
  line means.

## Out of scope

- Masking in-fence field-shaped lines (`- kind:`, `changed:`) inside a
  section body — a larger behaviour change to the readers' field grammar,
  not needed to fix the three reported symptoms.
- The `## <timestamp>: <behavior> (kind)` hand-written log dialect — those
  headers never matched `## Cycle:` and still do not.
