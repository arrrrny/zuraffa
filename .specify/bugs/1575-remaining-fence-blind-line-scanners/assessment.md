# Bug Assessment: Four `startsWith('## ')` line-scanners outside the cycle-log surface stay fence-blind

- **Slug**: 1575-remaining-fence-blind-line-scanners
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1575
- **Verdict**: valid (same defect class as #1467/#1549, different input files)
- **Severity**: latent fragility (0 of 400 spec.md files reachable today; 1 benign test-list hit)

## Report (verbatim or summarized)

Issue #1575: four `startsWith('## ')` line-scanners outside the cycle-log
surface stay fence-blind. Same defect class as #1467 and #1549, different
input files (`tdd/test-list.md`, `spec.md`-shaped section sources).

### Affected sites

| File | Lines | Input |
|---|---|---|
| `lib/src/plugins/tdd/services/test_list_reader.dart` | 346, 485, 533, 571 | `tdd/test-list.md` (+ lane plans via `_sectionsSource()`) |
| `lib/src/core/proof/proof_chain_checker.dart` | 1068 (`_behaviorIdsOf`) | `tdd/test-list.md` + lane plans |

### Pattern (same as #1467/#1549)

```dart
final trimmed = line.trim();
if (trimmed.startsWith('## ')) {
  final header = trimmed.substring(3).toLowerCase();
  ...  // flips section state — no fence tracking
}
```

A `## ` line inside a fenced block is treated as a real header.

### Current reachability

- `spec.md`-section readers: **0 of 400 files** contain an in-fence `## `
  line — not reachable today.
- `test-list.md`: **1 file** does
  (`specs/004-fix-zuraffa-gen/tdd/test-list.md:83`, an in-fence
  `## Baseline (2026-08-26, commit 614e648)`) — benign today: the marker
  is unrecognized and the section state is already off. Latent fragility.

## Symptom (failure mode, if reached)

A `## <recognised-marker>` line inside a fenced example toggles section
state exactly like a real header:

- an in-fence `## Inner loop:` mis-kinds every subsequent row;
- an in-fence `## Key entities` (or any declarative marker) switches the
  declarative-section state on → every real table row after the fence is
  silently dropped — "entries vanish with no error" (same as #1467);
- in `_behaviorIdsOf`, an in-fence non-marker header flips
  `inBehaviorSection` off → behavior ids silently vanish from the
  coverage audit (false negatives, no error).

## Reproduction

1. Seed `specs/<feature>/tdd/test-list.md` with a behavior section, a
   fenced code example containing `## Key entities` (or a loop marker),
   and a real table row after the fence.
2. `TestListReader(dir).read()` → the post-fence row is missing (or its
   kind is wrong for a loop-marker fence).
3. `ProofChainChecker.check()` → the post-fence behavior id produces no
   `behavior_coverage` gap although it has no green evidence.

## Suspected Code Paths

- `test_list_reader.dart` — `TestListReader._parseRows` (346),
  `readEntities` (485), `readDependencies` (533), `readLayerContracts`
  (571): four line-walks whose section state is driven by
  `trimmed.startsWith('## ')`.
- `proof_chain_checker.dart` — `_behaviorIdsOf` (1068): same walk for
  the behavior-section vocabulary.

## Root Cause (confirmed by reading the code)

The four `test_list_reader.dart` scanners and `_behaviorIdsOf` scan the
file LINE-BY-LINE with their own state machines instead of going through
the shared fence-aware splitter (`splitCycleLogSections()`, #1467), so a
`## ` line inside a fenced code block — a markdown banner inside a fenced
example, exactly the cycle-log's phantom-section defect (#1467, #1549) —
flips their section state as if a real header had started.

## Proposed Remediation

Route all five scanners through the existing fence-aware primitive
`splitCycleLogSections()` (the #1467 splitter already used by the
cycle-log readers via `parseCycleLogEntrySections`, #1549/#1553):

- each scanner walks the splitter's sections; a section's first line is
  its header (the splitter consumed the `## ` prefix as the boundary
  separator; a byte-0 header keeps it, mirroring the legacy
  `raw.split('\n## ')` byte contract), the remaining lines are the
  section body — verbatim, with absolute line numbers preserved so the
  reader's line-naming error messages are byte-identical;
- header semantics unchanged for column-0 headers (header text is the
  right-trimmed remainder — byte-equal to the legacy
  `trimmed.substring(3)`); an empty-header boundary line is emitted as a
  body no-op, exactly like the legacy reader ignored `## ` with no text;
- per-reader state machines (kind selection, declarative-section flags,
  row grammars) are unchanged — only WHERE the `## ` boundaries come
  from changes;
- one fixture per reader with an in-fence `## ` line asserting the
  fence-aware result; positive controls for well-formed inputs.

## Risks & Considerations

- Column-0 header semantics: the splitter cuts at column-0 `## ` only,
  so a 1–3-space-indented `## ` line outside a fence is no longer a
  section boundary. Corpus audit: 160 committed test-lists, zero
  indented headings — not reachable in the repo today.
- The splitter's cycle-log `- output:` fence anchoring is inert on
  test-list input (no `- output:` fields); its recovery pass only fires
  on malformed (unclosed-fence) input and requires `- behavior: `
  sections to prefer the anchored reading — none exist in test lists.
- Must not break the committed corpus: the one real in-fence `## `
  (004:83) is unrecognized either way — parse output stays identical.
- Do NOT touch the cycle-log readers (already fixed in #1547/#1549).

## Open Questions

- None — remediation follows the #1549 treatment exactly.
