**Template Version**: `zuraffa-1.0`

# Bug Spec: cycle-log.md section parsing breaks on test output containing '## '

Tracked as https://github.com/arrrrny/zuraffa/issues/1467.
Assessment: ./assessment.md

## Problem

Every cycle-log reader sections `tdd/cycle-log.md` with a plain-text
`split('\n## ')` (9 sites). The writer embeds captured test stdout verbatim
inside a fenced code block inside each `## Cycle:` section, so a captured
line starting with `## ` creates a phantom section: the real entry's
trailing fields (`- kind:`, `- hash:`, `- prev-hash:`) are stranded in the
phantom chunk, evidence is lost/misattributed, and the doctor's hash-chain
verification fails.

## Acceptance Criteria (fixed behavior)

1. **Given** a cycle-log whose red entry's fenced `- output:` block contains
   **Type**: acceptance
   lines starting with `## ` (e.g. `## Cycle: BOGUS (red)`), **When** the log
   is sectioned for parsing, **Then** the in-fence `## ` lines do NOT start
   new sections and the real entry's trailing fields (`- kind:`, `- hash:`)
   stay in the real section. (FR-001)
2. **Given** captured output containing backtick fence markers (including
   **Type**: acceptance
   info-string fences like ` ```dart `), **When** the splitter scans the log,
   **Then** fence state stays synchronized and no `## ` line inside any
   fence is treated as a section header. (FR-002)
3. **Given** a cycle-log with no `## ` inside captured output, **When** it is
   **Type**: acceptance
   parsed after the fix, **Then** the parsed sections are identical to what
   the legacy `split('\n## ')` produced (no format change, no migration).
   (FR-003)
4. **Given** all 9 reader call sites (cycle_evidence ×2, verify_red, make ×2,
   **Type**: acceptance
   compose ×2, era_tagged_log, theater_data, replay_history), **When** they
   read a cycle-log, **Then** each sections the file through the shared
   fence-aware splitter. (FR-003)
5. **Given** a red entry whose captured output contains `## Cycle: BOGUS
   **Type**: acceptance
   (red)` and `## Notes` lines, **When** `parseEntries` parses the log,
   **Then** it yields exactly one entry with the correct behavior id, kind,
   and hash. (FR-004)

## Reproduction Scenario (the failing test)

1. Build a cycle-log with a red entry whose fenced `- output:` contains
   lines starting with `## `.
2. Parse with `parseEntries` / `CycleEvidence`.
3. Before the fix: the entry loses its hash (or kind) to the phantom
   section; after the fix: one clean entry.

## Out of Scope (follow-up, recorded in assessment)

Writer-side hardening (fence-length adaptation or indenting captured
output) — a format change, separate decision.
