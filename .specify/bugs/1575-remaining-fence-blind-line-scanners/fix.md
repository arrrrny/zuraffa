# Fix Report: Four `startsWith('## ')` line-scanners outside the cycle-log stay fence-blind

- **Slug**: 1575-remaining-fence-blind-line-scanners
- **Date**: 2026-09-13
- **Branch**: `fix/1575-remaining-fence-blind-line-scanners`
- **Assessment**: `.specify/bugs/1575-remaining-fence-blind-line-scanners/assessment.md`

## What Changed

The four `test_list_reader.dart` section-state scanners and
`proof_chain_checker.dart`'s `_behaviorIdsOf` now route their `## ` header
detection through the existing fence-aware primitive
`splitCycleLogSections()` (the #1467 splitter, already the section source
for the cycle-log readers via the #1553 entry-sections layer). The
per-reader state machines — kind selection, declarative-section flags, row
and bullet grammars — are byte-identical; only WHERE the `## ` boundaries
come from changed. The cycle-log readers are untouched (hard constraint).

### `lib/src/plugins/tdd/services/test_list_reader.dart`

1. **New private helper `TestListReader._fenceAwareLines(content)`** — the
   shared fence-aware line walk for every scanner in this file. It expands
   `splitCycleLogSections()`'s sections back into the original line
   sequence, yielding `(lineNo, raw, header?)` per line:
   - a section's first line is its header (the splitter consumed the
     `## ` prefix as the boundary separator; a byte-0 header keeps its
     prefix, mirroring the legacy `raw.split('\n## ')` byte contract);
   - the header text is the line's right-trimmed remainder — byte-equal
     to the legacy `trimmed.substring(3)` for every column-0 header;
   - a bare `## ` heading (empty remainder) is emitted as a body line —
     the legacy walk ignored those too (`'## '.trim()` does not start
     with `'## '`), so an empty heading never flipped a state and still
     must not;
   - absolute line numbers are reconstructed from the walk order (the
     legacy `\n## ` separators each consumed exactly one line), so the
     line-naming error contract (bug #984) stays byte-identical.
2. **`_parseRows` (site 346)** — walks `_fenceAwareLines`; an in-fence
   `## ` banner is body now and can no longer flip `kind` or the
   declarative-section flag. Header vocabulary and the row grammar are
   unchanged (`header` local renamed to `lowered` where the lowered text
   is matched — same comparisons as before).
3. **`readEntities` (site 485)** — same walk; an in-fence header can no
   longer close the Key entities section and drop the entity rows after it.
4. **`readDependencies` (site 533)** — same walk for External dependencies.
5. **`readLayerContracts` (site 571)** — same walk for Layer contracts
   (the `layer` reset semantics are unchanged for real headers).

### `lib/src/core/proof/proof_chain_checker.dart`

6. **New private top-level helper `_fenceAwareLines(source)`** — the same
   fence-aware expansion (no line numbers needed: `_behaviorIdsOf` never
   names lines).
7. **`_behaviorIdsOf` (site 1068)** — walks `_fenceAwareLines`; an
   in-fence `## ` banner can no longer flip `inBehaviorSection`:
   post-fence behavior ids no longer silently vanish from the coverage
   audit, and a fenced `## Behaviors` example fabricates no phantom ids.
   The behavior-section vocabulary, the id-shape filter and the
   lane-split source composition are unchanged.

### Deliberately unchanged

- The cycle-log readers (`provenance_scanner.dart`,
  `ci_referee/failure_artifacts.dart`,
  `ci_referee/feature_provenance_reader.dart`) and the splitter itself —
  already fence-aware via #1547/#1549/#1553 (hard constraint).
- `LaneSplitFiles.find`'s meta-index detection (a pointer-line matcher,
  not one of the five `startsWith('## ')` sites).
- In-fence `|`-prefixed lines stay parsed where the legacy walk parsed
  them: this fix's scope is the `## ` header detection only.

## Files Changed

```
lib/src/core/proof/proof_chain_checker.dart              | site 1068 + helper
lib/src/plugins/tdd/services/test_list_reader.dart       | sites 346/485/533/571 + helper
test/plugins/tdd/services/test_list_reader_1575_fence_test.dart   | new (8 tests)
test/core/proof_chain_checker_1575_fence_test.dart                | new (3 tests)
.specify/bugs/1575-remaining-fence-blind-line-scanners/* | assessment/issue/fix/test
tdd/test-list.md, tdd/verification.md                    | refreshed for this bug
```

## Tests Added / Updated

One fixture per reader (per the issue's remediation contract) plus
positive controls — all in two new files, TDD red → green:

- RED (pre-fix): 7 failing fixtures across the two files — the exact
  failure modes from the issue (mis-kind, silent vanish, phantom id) —
  recorded in `red-evidence.md`; the 4 positive controls were green
  pre-fix.
- GREEN (post-fix): 11/11 pass; the pre-existing reader/proof suites
  (76 tests across `test_list_reader*`, `bug_919_reader_test`,
  `bug_937_reader_sections_test`, `proof_chain_checker_test`) all pass
  unchanged.

## Constraints Check

- Only `test_list_reader.dart` and `proof_chain_checker.dart` touched in
  `lib/` (the two helpers are private to each file).
- Well-formed inputs: the byte-compat argument above plus the two
  no-fence positive controls and the committed-corpus control (the one
  real in-fence `## ` at `specs/004-fix-zuraffa-gen/tdd/test-list.md:83`
  is unrecognized either way — parse output identical).
- `dart analyze` (full project): 112 issues pre-change == 112 issues
  post-change, 0 errors / 0 warnings both sides.
