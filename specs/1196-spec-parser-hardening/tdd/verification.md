# TDD Verification — feature `1196-spec-parser-hardening`

Written from the ACTUAL runs performed on this branch (every command
below was executed; outputs are quoted from the transcripts, not
asserted). Toolchain: Dart 3.13.3 (stable) on linux_x64
(`dart --version`) with Flutter 3.47.0 on PATH (the pure-Dart CLI
lanes and the fast suite run without invoking it).

## Gate

- gate: `passed`
- analyze: `dart analyze lib test tool` → **0 errors, 0 warnings**
  (104 info-level lints; the pre-change tree reports 105 — no new
  lint was introduced, one stale one left with the code it pinned)
- fast suite (chunked): `tools/run_chunks_range.sh` (the ranged driver
  of `tools/run_tests_chunked.sh`; this environment reaps detached
  processes, so the run was driven in six foreground ranges 1–15,
  16–30, 31–45, 46–60, 61–75, 76–90) → **90/90 chunks, 0 failed**
  (every range ended `RANGE DONE …: failed_chunks=0`; the SKIP lines
  are the runner's no-fast-tier folders, not failures)
- property tier: `dart test --preset=property
  test/property/spec_corpus_fuzz_1196_test.dart` → **4/4 passed**
- format: `dart format .` → **Formatted 2379 files (0 changed)**

## Red → green evidence (the loop, honestly)

### RED (reproduced on the pre-change tree — commit caf52b66)

The corpus was generated first (`dart run
tool/generate_zikzak_corpus.dart` → "zikzak corpus: wrote 120 specs"),
then swept through the pre-fix parser:

```
$ dart run tool/sweep_zikzak_corpus.dart
zikzak sweep: specs=120 parse-clean=97 parse-refused(line)=3 crashed=20
inline-prose: n=8 clean=0 refused=0 crashed=8
    091-privacy-dashboard: crashed — lineless StateError: spec.md …
    contains no acceptance scenarios …
nested-ac: n=8 clean=0 refused=0 crashed=8
pathological: n=10 clean=3 refused=3 crashed=4
    106-geofence-deals: crashed — lineless StateError: duplicate …
```

Silent misroutes (facts, pre-fix — `--facts`):

```
051-dark-mode (crlf): behaviors=3 A=3 U=0 … version=null
      ^ 5 behaviors exist in the spec; the 2 FR bullets and the treaty
        pin were silently dropped (the `(.+)$` capture cannot cross \r)
059-delta-sync (html-entities): … deps=0 …
      ^ the `&amp;` heading hid the External Dependencies section
099-updates-check (epic-contracts): layerContracts=0 …
      ^ the `— epic-level` heading qualifier hid the Layer Contracts
075-battery-saver (fr-table): behaviors=1 A=1 U=0 …
      ^ the 2 FR-table rows produced no unit behaviors
```

The three new fast suites also failed on the pre-change tree (the
`spec_corpus_sweep_1196_test.dart` RED run: P1 `crashed=20`, P3
`crlf behaviors silently dropped` — full transcript in the spec's
`plan.md` narrative above).

### GREEN (this branch, same commands)

```
$ dart run tool/sweep_zikzak_corpus.dart --plan
zikzak sweep: specs=120 parse-clean=113 parse-refused(line)=7 crashed=0
crlf: n=8 clean=8 refused=0 crashed=0
epic-contracts: n=6 clean=6 refused=0 crashed=0
fr-table: n=8 clean=8 refused=0 crashed=0
html-entities: n=8 clean=8 refused=0 crashed=0
inline-prose: n=8 clean=8 refused=0 crashed=0
legacy-002: n=10 clean=10 refused=0 crashed=0
manual: n=6 clean=6 refused=0 crashed=0
modern: n=16 clean=16 refused=0 crashed=0
modern-no-lanes: n=12 clean=12 refused=0 crashed=0
modern-undeclared: n=12 clean=12 refused=0 crashed=0
nested-ac: n=8 clean=8 refused=0 crashed=0
non-english: n=8 clean=8 refused=0 crashed=0
pathological: n=10 clean=3 refused=7 crashed=0
    105-reminders: refused — spec line 8 declares an unknown scenario type …
    106-geofence-deals: refused — duplicate `**Type**` markers … (first at line 8, duplicate at line 9)
    107-location-history: refused — spec line 7 carries a `**Type**` marker outside any numbered scenario block.
zikzak plan sweep: specs=120 plan-clean=98 plan-refused=22 | routing: declared=410 fallback=199 (#1186 window)
  exit0: 98
  exit3: 14
  exit1: 4
  exit2: 4
wrote corpus/zik_zak/sweep.json
```

Every number above is the ACTUAL output. The 7 parse refusals are the
pathological class refusing honestly (each names its line); the 22
plan refusals are: 10 legacy drift (exit 3 — no treaty pin, the
#919/#990 contract), 4 pathological drift/derivation refusals, 4
"cannot derive behaviors" + 1 declaration refusal, 3 manual
empty-owner coverage-gate refusals (exit 2, offending line printed).

## The coverage tracker (issue #1196's X and Y)

- **X = 98 of 120 specs plan cleanly** (exit 0, test list written).
- **Y = 199 behaviors route via the labeled legacy fallback** (the
  #1186 window: `route: <id> -> <lane> [fallback: legacy description
  classifier matched — …]`); **410 route declared.** The fallback
  concentration is exactly the undeclared corpus shapes (60) plus
  specs whose FRs carry no `traces:` (136) plus html-entities (16) and
  manual (3) — the tracker exists so this number can only shrink
  honestly, toward zero. Committed evidence:
  `corpus/zik_zak/sweep.json` (schema `zikzak-sweep.v1`), guarded
  against drift by `spec_sweep_evidence_1196_test.dart` (4/4 passed).

## Mutation-checked test strength (the TDD extension's discipline)

Fuzz/property tier (130 deterministic mutants = 10 operators × the
first spec of every shape class): P1 no crash — 0 crashed; P2 form
invariance — 0 moved behavior sets; P3 honest content mutations —
all landed in line-addressed refusals or honest pin-absence; the
non-vacuity oracle — every operator provably mutates its input.
**4/4 passed.**

Parser mutant spot-checks (edit → run the two fast 1196 suites →
restore; transcripts condensed to the runner's summary lines):

```
MUTANT A (entity decode removed from _matchesSectionHeading):
  00:00 +29 -2: Some tests failed.          → KILLED (2 failures)
MUTANT B (CR normalization removed from normalizeSpecText):
  00:00 +28 -3: Some tests failed.          → KILLED (3 failures)
MUTANT C (scenario header grammar reverted to flat-bold-only):
  00:00 +26 -5: Some tests failed.          → KILLED (5 failures)
RESTORED:
  00:00 +31: All tests passed!
```

## New tests (counts from the actual runs)

- `test/plugins/tdd/services/spec_parser_hardening_1196_test.dart` —
  **24 passed** (per-fix unit evidence: CRLF ×5, entities ×3, epic
  qualifiers ×2, nested ×3, inline prose ×3, FR tables ×4, honest
  refusals ×2, lenient contracts ×2)
- `test/plugins/tdd/services/spec_corpus_sweep_1196_test.dart` —
  **7 passed** (P1/P2/P3 over the committed 120-spec corpus + BOM +
  unknown-version + tracker headline)
- `test/plugins/tdd/services/spec_sweep_evidence_1196_test.dart` —
  **4 passed** (evidence schema, parse-half drift guard, plan-half
  consistency, headline)
- `test/property/spec_corpus_fuzz_1196_test.dart` — **4 passed**
  (property tier, slow-tagged)

## Superseded contract (documented, not hidden)

`test/plugins/tdd/bug_846_coverage_gate_test.dart` case
"table-format MUST requirement": the #846-era expectation (exit 2 on a
table-FR) is superseded by #1196 — the corpus really contains FR
tables, and the parser now routes them. The case was rewritten
("GREEN since #1196: table-format MUST requirement routes") proving
the table FR lands on the test list with exit 0; the coverage gate
itself is untouched (its remaining 7 cases in that file pass
unchanged, proving the gate still refuses every requirement that
produces no behavior row).

## Honest limitations

- The 10 legacy-002 specs and 2 pathological specs plan-refuse as
  contract drift (no treaty pin). That is the #919 gate doing its job
  — `--migrate-spec` (issue #990) is the migration path; this PR does
  not silently re-pin unpinned specs.
- The 199-behavior fallback window is REPORTED, not fixed: emitting
  the `**Type**`/`traces:` markers back into authored specs is #1186's
  suggested follow-up and is deliberately out of this PR's scope.
- Flutter-tagged tiers were not run (the fast suite's
  `--exclude-tags flutter` contract, as on every spec branch in this
  repo); no flutter-tagged test was touched by this change.
