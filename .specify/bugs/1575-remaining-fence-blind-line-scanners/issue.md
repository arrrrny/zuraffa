# Bug Issue: Four `startsWith('## ')` line-scanners outside the cycle-log surface stay fence-blind

- **Slug**: 1575-remaining-fence-blind-line-scanners
- **Fetched**: 2026-09-13
- **Issue**: 1575
- **URL**: https://github.com/arrrrny/zuraffa/issues/1575
- **State**: open
- **Severity**: latent fragility
- **Author**: arrrrny
- **Labels**: bug

## Body

Four `startsWith('## ')` line-scanners outside the cycle-log surface stay
fence-blind. Same defect class as #1467 and #1549, different input files
(`tdd/test-list.md`, `spec.md`).

### Affected sites

| File | Lines | Input |
|---|---|---|
| `test_list_reader.dart` | 346, 485, 533, 571 | `tdd/test-list.md`, `spec.md` |
| `proof_chain_checker.dart` | 1068 (`_behaviorIdsOf`) | `tdd/test-list.md` + lane plans |

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

- `spec.md` readers: **0 of 400 files** contain in-fence `## ` — not
  reachable today.
- `test-list.md`: **1 file** does
  (`specs/004-fix-zuraffa-gen/tdd/test-list.md:83`) — benign case today
  (marker unrecognized, section already off). Latent fragility.

## Steps to Reproduce

1. Seed a `tdd/test-list.md` with a behavior section, a fenced code
   example containing `## Key entities` (or a loop marker), and a real
   table row after the fence.
2. Read it with `TestListReader` — the post-fence row vanishes (or its
   kind is wrong for a loop-marker fence).
3. Same shape in `ProofChainChecker._behaviorIdsOf` — the post-fence
   behavior id silently drops out of the coverage audit.

## Expected Behavior

1. Route the scanners through the existing fence-aware primitive
   (`splitCycleLogSections()` / the `cycle_log_entry_sections.dart`
   layer).
2. One fixture per reader with an in-fence `## ` line asserting the
   fence-aware result.
3. Same treatment as #1549 — line-scanner readers consuming different
   input files.

## Actual Behavior

`## <recognised-marker>` inside a fenced example toggles section state →
every real table row after the fence silently dropped — "entries vanish
with no error" (same as #1467).

## Hard Constraints

- Fix ONLY the fence-tracking in `test_list_reader.dart` and
  `proof_chain_checker.dart`. Do NOT change the cycle-log readers
  (already fixed in #1547/#1549).
- Must not break existing test-list/spec parsing for well-formed inputs.
- Must pass `dart analyze` with no new warnings.

## Related

- #1467 (cycle-log split fix), #1543, #1549 (cycle-log line-scanner fix),
  #1553 (entry sections helper).
