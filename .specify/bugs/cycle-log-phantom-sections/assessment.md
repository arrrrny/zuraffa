# Bug Assessment: cycle-log.md section parsing breaks on test output containing '## '

- **Slug**: cycle-log-phantom-sections
- **Created**: 2026-09-10
- **Source**: https://github.com/arrrrny/zuraffa/issues/1467 (pasted via `assess 1467`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

From issue #1467 (arrrrny/zuraffa, OPEN, labels: bug, tdd, P0):

> `cycle_evidence.dart` L183 splits cycle-log sections using plain-text
> `split('\n## ')`, which is NOT markdown-aware. If a test's captured stdout
> contains a line starting with `## ` (e.g., Flutter framework banners,
> markdown-printing tests), it creates a **phantom section** that corrupts
> evidence parsing.
>
> Impact: lost or misattributed evidence entries; `doctor` hash-chain
> verification fails; driver may skip behaviors or repeat steps.
>
> Suggested fix: either indent captured output (breaking change) or use a
> fence-aware section splitter that tracks whether the cursor is inside
> ``` markers.

Related: hash chain integrity (bug #828); assessment from an internal TDD I/O audit.

## Symptom

Every cycle-log reader splits the log on the raw byte sequence `'\n## '`.
The cycle-log *writer* embeds captured test stdout verbatim inside a fenced
code block inside each `## Cycle: <id> (<kind>)` section. When captured
output contains a line starting with `## `, readers split mid-section:
trailing fields of the real entry (`- kind:`, `- hash:`, `- prev-hash:`,
`- subject-hash:`) land in a phantom section. The real entry loses its
hash-chain link (becomes legacy/unverifiable) or is misattributed, and the
doctor's chain verification fails on the next hashed entry.

## Reproduction

1. Author/run a behavior whose failing (or passing) test prints a line
   beginning with `## ` to stdout/stderr — e.g. a markdown-rendering test,
   or output copied from a cycle-log itself (this repo's own suites print
   `## Cycle:` / `##[group]` lines constantly).
2. `zfa tdd run <feature>` records the red/green entry; the captured output
   lands inside the entry's `- output:` fence in `tdd/cycle-log.md`.
3. Re-read the log: `CycleEvidence.entries()` / `doctor` /
   `verify-red` parse it. The section is split at the in-fence `## ` line.
4. Observed: the entry's `- hash:`/`- prev-hash:` are parsed as part of the
   phantom section (or not at all) → `ParsedCycleEntry.isHashed == false`,
   `lastHashFor()` returns a stale/null chain head, doctor reports
   chain drift, and red/green evidence sets can be lost or misattributed.

Minimal synthetic repro (parse level):

```dart
final raw = '## Cycle: A1 (red)\n- behavior: A1\n- kind: red\n- output:\n```\nsome banner\n## not a section\nmore\n```\n- hash: <64-hex>\n';
final entries = parseEntries(raw);
// entries.single.hash == null  <-- hash stranded in the phantom chunk
```

## Suspected Code Paths

Readers using the naive split (9 sites — the issue cited only one):

- `lib/src/plugins/tdd/services/cycle_evidence.dart:183` — `_evidence()` red/green/refactor sets (the cited line)
- `lib/src/plugins/tdd/services/cycle_evidence.dart:202` — `parseEntries()`, the structured parse feeding doctor, journal replay, hash-chain verification, orphaned-evidence checks, and the make skip transition
- `lib/src/plugins/tdd/commands/verify_red_command.dart:762` — verify-red's own section scan
- `lib/src/plugins/tdd/commands/make_command.dart:2570,2589` — make skip-transition evidence scan
- `lib/src/plugins/tdd/commands/compose_command.dart:536,663` — compose evidence scan
- `lib/src/plugins/tdd/services/era_tagged_log.dart:133` — era log scan
- `lib/src/plugins/tdd/services/theater_data.dart:602` — theater data scan
- `lib/src/plugins/tdd/services/replay_history.dart:127` — replay history scan

Writer that creates the hazard:

- `lib/src/plugins/tdd/models/cycle_entry.dart:173-177` — `toMarkdown()` writes `- output:` then a bare ``` fence with `capturedOutput.trim()` verbatim (no escaping, no indentation, no fence-length adaptation if the output itself contains ``` lines — a second, compounding hazard)

Downstream consumers that fail because of it:

- `lib/src/plugins/tdd/commands/doctor_command.dart` — hash-chain verification (bug #828 machinery) reads `CycleEvidence.entries()`
- run driver / make skip transition (`lastEntryFor`, `lastHashFor`, `isHashed`) — `cycle_evidence.dart:74,150,165`

## Root Cause Hypothesis

High confidence, verified by reading both sides of the format: the cycle-log
format places raw captured output inside fenced code blocks within
`## `-delimited sections, but every reader sections the file with a plain
text `split('\n## ')` that knows nothing about markdown fences. The format
and its parser disagree; any captured line starting with `## ` (or, worse,
a line starting with ``` that prematurely closes the fence and lets a later
`## ` line parse as a header) corrupts the parse. This is not hypothetical —
this repository's own tests and CI logs print `## Cycle:`, `##[group]`,
and `## Baseline` style lines routinely, so any behavior testing
markdown/log output trips it.

## Proposed Remediation

**Preferred**: add a single shared fence-aware section splitter and use it
at all 9 reader sites. Shape:

- New helper, e.g. `List<String> splitCycleLogSections(String raw)` in
  `cycle_evidence.dart` (or a small `cycle_log_sections.dart` next to it),
  exported for the command/services readers.
- It scans line-by-line, tracking fence state: a line whose trimmed content
  starts with ``` toggles inFence (track the fence marker length/char so
  ```` closes ``` and an info-string fence like ```dart opens). Only when
  NOT inside a fence does a line starting with `## ` begin a new section.
- Pure function, trivially unit-testable; existing logs with no `## ` inside
  output parse byte-identically (zero migration: old logs stay valid, and
  logs already corrupted by this bug parse the same way they do today —
  the fix prevents new corruption).
- Replace the 9 `raw.split('\n## ')` call sites with the helper. The
  per-site regex parsing of each section body stays unchanged.
- Optionally harden the writer in a follow-up (not this fix): fence-length
  adaptation (`capturedOutput` containing ```) or indenting captured
  output — both are format changes and should be a separate decision, since
  issue #1467's option 1 is explicitly flagged breaking.

**Alternatives**:
- Writer-side indentation of captured output (issue's option 1): fixes the
  problem at the source but is a breaking format change for every existing
  cycle-log and every reader's `- output:` handling — rejected for a
  surgical fix; keep as a separate format-rev proposal.
- Escape `## ` lines in captured output at write time: also a format change
  and lossy (changes the certified evidence payload); the hash chain covers
  certified facts, but tooling that diffs output would see escaped text.
  Reader-side fence awareness is strictly safer.

**Files likely to change**:
- `lib/src/plugins/tdd/services/cycle_evidence.dart` (new helper + adopt in
  `_evidence` / `parseEntries`)
- `lib/src/plugins/tdd/commands/verify_red_command.dart`
- `lib/src/plugins/tdd/commands/make_command.dart` (2 sites)
- `lib/src/plugins/tdd/commands/compose_command.dart` (2 sites)
- `lib/src/plugins/tdd/services/era_tagged_log.dart`
- `lib/src/plugins/tdd/services/theater_data.dart`
- `lib/src/plugins/tdd/services/replay_history.dart`

**Tests to add or update**:
- New unit tests for the splitter: `## ` inside a fence does not split;
  fence with info string; longer fence closing a shorter one; `## ` at
  line start outside a fence still splits; text before the first header.
- Regression test on `parseEntries` / `CycleEvidence` with a red entry whose
  captured output contains `## Cycle: BOGUS (red)` and a `## Notes` line —
  assert exactly one entry, correct behavior id, kind, and hash parsed.
- A test pinning the real end-to-end shape: run the verify-red path (or
  `CycleLogEntry.toMarkdown()` → `parseEntries()` round-trip) with captured
  output containing `## ` lines — cheap round-trip, no subprocess.

Natural homes: `test/plugins/tdd/services/cycle_evidence_test.dart` (splitter
+ parseEntries regression) and `test/plugins/tdd/services/cycle_log_test.dart`
(writer→reader round-trip). Note `tdd_enabled: true` in bug-config.yml, so
bug.fix will drive this through the TDD loop — the above tests are exactly
the red specs.

## Risks & Considerations

- **Behavior change for already-corrupted logs**: logs corrupted by this bug
  will parse differently (better) after the fix — doctor may newly report
  drift on historical entries. That is honest repair, but users should
  expect new doctor findings on affected features.
- **All 9 sites must move together**: fixing only `cycle_evidence.dart`
  leaves verify-red/make/compose/era/theater/replay disagreeing with the
  doctor — partial fixes make the stores inconsistent (the exact failure
  mode of bug #828).
- **Second writer hazard unaddressed**: output containing ``` lines can
  prematurely close the fence (the splitter fix assumes well-formed fences
  from `toMarkdown`). A cheap belt-and-braces option: since `toMarkdown`
  always emits a bare ``` fence, treat a ``` line inside a section's output
  as fence-close only when the parser itself opened it — i.e. the splitter
  toggles on lines that are exactly a fence marker; document the residual
  risk and defer format hardening.
- **No format/version bump needed**: the reader-side fix keeps the byte
  format unchanged, so schema v1 hash payloads are untouched.

## Open Questions

- [NEEDS CLARIFICATION: none blocking] Should the writer also be hardened in
  the same PR (fence-length adaptation) or strictly as a follow-up? The
  assessment recommends follow-up to keep the diff surgical.
- [NEEDS CLARIFICATION: none blocking] The issue labels this P0; assessment
  sets severity high rather than critical because it requires captured
  output containing `## ` lines (common in this repo's own test domains,
  but not in typical entity CRUD flows) and corrupts evidence rather than
  crashing or losing user data. Maintainer may upgrade to critical given
  the "certified evidence" contract.
