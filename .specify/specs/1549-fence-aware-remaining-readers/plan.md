# Plan: 1549-fence-aware-remaining-readers

- **Spec ID**: 1549-fence-aware-remaining-readers
- **Created**: 2026-09-13

## Technical Context

- **Shared helper**: `splitCycleLogSections(String raw)` →
  `List<String>` (`lib/src/plugins/tdd/services/cycle_log_sections.dart`,
  issue #1467 / PR #1543). Fence-aware `## `-sectioning with the legacy
  `raw.split('\n## ')` byte contract: a section header is a column-0 `## `
  line outside a fenced code block; the first chunk keeps a byte-0 header's
  `## ` prefix (legacy split semantics); every later chunk starts AFTER its
  `## ` prefix. **Not on master yet** (PR #1543 open) — vendored into this
  branch byte-identical; add/add auto-resolves when either PR merges.
- **Affected readers** (all in `lib/src/plugins/tdd/services/`):
  - `provenance_scanner.dart` — `_collectRefactorAttributions`, line ~182:
    per-line state machine (`inRefactorSection` flipped by
    `trimmed.startsWith('## Cycle:')` + `endsWith('(refactor)')`;
    `currentCommand` updated by bare `command: \`` action lines — note the
    `- command:` ENTRY field does not match, only the actions block's
    indented `command:` lines do; `changed:` lists attributed under
    `inRefactorSection`).
  - `ci_referee/failure_artifacts.dart` — `_parseRedEntries`, line ~109:
    `## Cycle:` line calls `closeEntry()` (emits the pending artifact) and
    re-arms `inRed = trimmed.endsWith('(red)')`; within a red entry the bare
    ```` ``` ```` lines toggle `inOutput` and only in-output lines are kept.
  - `ci_referee/feature_provenance_reader.dart` — `_readGreenBehaviors`,
    line ~138: `## Cycle:` header sets `currentBehavior` (first token after
    the prefix); `- kind:` lines ending in `green` (sic — substring
    semantics preserved) add `currentBehavior` to the green set.
- **Entry grammar**: `CycleLogEntry.toMarkdown()` writes
  `## Cycle: <behavior> (<kind>)` with kind ∈ {red, green, refactor, error,
  refresh}; fields `- behavior:`, `- kind:`, … then `- output:` + fence
  (bare) or `- output: ``` ` (inline, committed 068 dialect); refactor
  entries carry an `actions:` block with `command:` / `changed:` lines.
- **Language/SDK**: Dart 3.13.3 (stable), pure-Dart; tests via `package:test`
  with `Directory.systemTemp` fixtures + `tearDown` deletion (the established
  pattern in all three reader test files).
- **Why an iterator, not three inline rewrites**: the byte-0-header nuance
  and the `Cycle:` header grammar would be duplicated three times; the issue
  explicitly allows "a shared 'entry sections' iterator built on it". The
  iterator lives in a NEW file so `cycle_log_sections.dart` stays
  byte-identical to PR #1543's (no fork, no conflict).

## Architecture

```
 tdd/cycle-log.md (raw bytes)
      │
      ▼
 splitCycleLogSections(raw)            [vendored, issue #1467]
      │  fence-aware ## sections (legacy byte contract)
      ▼
 parseCycleLogEntrySections(raw)       [NEW — this spec]
      │  • skips the preamble chunk and non-`Cycle:` sections
      │  • strips a byte-0 header's leading `## ` (chunk-0 only)
      │  • parses `Cycle: <behavior> (<kind>)` → header / behavior / kind
      │  • bodyLines = remaining lines, verbatim (fenced output included)
      ▼
 ┌────────────────────┬──────────────────────────┬──────────────────────────┐
 │ provenance_scanner │ ci_referee/              │ ci_referee/              │
 │ _collectRefacto-   │ failure_artifacts        │ feature_provenance_      │
 │ rAttributions      │ _parseRedEntries         │ reader._readGreenBehavio │
 │                    │                          │ rs                       │
 │ per entry:         │ per entry:               │ per entry:               │
 │  inRefactor =      │   kind != red → skip     │  behavior.isEmpty→skip   │
 │    kind ==         │   body scan: - test: /   │  body scan: - kind: …    │
 │    'refactor'      │     ``` toggle / output  │    endsWith('green') →   │
 │  body scan:        │  emit ≤20-line excerpt   │    greens.add(behavior)  │
 │   command:` → cmd  │                          │                          │
 │   changed: → attr  │                          │                          │
 │  (currentCommand   │                          │                          │
 │   hoisted across   │                          │                          │
 │   entries, as before)                         │                          │
 └────────────────────┴──────────────────────────┴──────────────────────────┘
```

The state machines are unchanged; only the SECTION SOURCE changes (fence-aware
iterator instead of fence-blind line matching). Body lines still scan
verbatim — including in-fence lines, exactly as before — so well-formed-log
output is untouched (SC-5) and the three reported symptoms (all driven by
in-fence `## Cycle:` lines starting phantom sections) are gone by
construction: an in-fence `## ` line can no longer start a section.

## Risks / trade-offs

- **Cross-section `currentCommand` persistence** (provenance_scanner): the
  original hoists `currentCommand` across the whole file; the conversion
  keeps that (declared outside the entry loop) so a well-formed actions
  block — `command:` immediately before its `changed:` — behaves
  identically.
- **Byte-0 header**: a log starting directly with `## Cycle: …` keeps the
  `## ` prefix on the splitter's first chunk (legacy byte contract); the
  iterator strips it for chunk 0 only. Covered by an iterator unit test.
- **Non-`Cycle:` `## ` sections**: previously their bodies were scanned with
  the preceding entry's stale state; now they are skipped entirely. No
  committed log has such sections between `Cycle:` entries (all `## ` headers
  in machine-written logs ARE `Cycle:` headers); the stale-state scan was
  itself part of the misattribution defect class.

## Test strategy

- Iterator: unit tests for header parsing, byte-0 prefix, preamble/
  non-Cycle skipping, verbatim body (in-fence `## Cycle:` stays in body).
- Readers: one fence-aware fixture per reader (SC-1/SC-2/SC-3), written
  FIRST and recorded red against the unconverted readers, then green.
- Regression: the three readers' existing suites (U25–U30, A11–A13, U1–U6)
  plus the vendored helper's 12-test suite must pass unmodified.
