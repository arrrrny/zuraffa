# Spec 1196 — [MOCK-FIRST] Spec-parser hardening: accept every spec format in the 120-spec corpus (P0)

**Issue:** [#1196](https://github.com/arrrrny/zuraffa/issues/1196) · **Part of:** #908 (P0 — "unblocks corpus start") · **References:** #1186 (fallback routing markers), #1017 (CORPUS-WALK — the 120 ZikZak specs), #846 (coverage gate), #919 (template treaty pin), #990 (drift migration path)

**Branch:** `spec/1196-spec-parser-hardening`

## Problem

`zfa tdd plan` (and the declaration parser behind it) must survive — and honestly route or refuse — every spec shape the 120 ZikZak specs will use. Before this spec, the parser failed that bar in four classes, PROVEN by sweeping a real 120-spec corpus (the RED run, below):

1. **Crashes of the honesty contract (20 of 120 specs).** Specs with inline-prose scenarios (`1. Given ...` unbolded) or nested AC numbering (`1.1. **Given**`) matched neither the parser's nor the scanner's scenario grammar — the scenarios were silently dropped and the parser died with a LINELESS "contains no acceptance scenarios" StateError. A refusal the author cannot act on is a crash, not a refusal.
2. **Silent misroutes.** CRLF specs lost every FR bullet (the `(.+)$` capture cannot cross a trailing `\r`) AND the treaty pin; `## External Dependencies &amp; Contracts` (HTML entities) and `## Layer Contracts — epic-level` (per-epic qualifier) hid their sections — declared dependencies and contracts silently vanished; FR-table rows (`| FR-001 | ... |`) produced no unit behaviors (the #846-era gap).
3. **No corpus.** The 120 specs the parser must harden against did not exist — the parser was hardened against imagination.
4. **No coverage tracker.** Nobody could answer "X of 120 specs plan cleanly, Y route via fallback" (#1186's window, which must shrink to zero).

## Method (the issue's, followed exactly)

1. **Corpus first.** `corpus/zik_zak/` — 120 committed spec files generated deterministically by `tool/generate_zikzak_corpus.dart` from a 13-class shape matrix derived from the repo's real spec eras plus the dimensions issue #1196 names: modern zuraffa-1.0 (×16), missing Lanes (×12), undeclared routing (×12), legacy-002-era (×10), CRLF (×8), HTML entities (×8), non-English headers (×8), FR tables with variants (×8), nested ACs (×8), inline prose (×8), per-epic contracts (×6), pathological (×10: empty, whitespace-only, BOM, FR-only, unknown/duplicate/outside Type markers, malformed FUNCTION signature, unknown version, CRLF+unpinned), manual declarations (×6). `corpus-shapes.txt` is the committed shape oracle.
2. **Sweep, fuzz, property.** `SpecCorpusSweeper` runs the full declaration-parse surface per spec and classifies: `clean` / `refused` (StateError naming `line N`) / `crashed` (anything else). The property tier (`test/property/spec_corpus_fuzz_1196_test.dart`) applies 10 deterministic mutation operators × the first spec of every shape class (130 mutants): no crash, form-only mutations must not move the derived behavior set (no silent misroute), content mutations must land in honest outcomes.
3. **Coverage tracker.** `tool/sweep_zikzak_corpus.dart --plan` drives the REAL `zfa tdd plan` over all 120 corpus specs in throwaway projects and writes the committed evidence `corpus/zik_zak/sweep.json` (schema `zikzak-sweep.v1`, deterministic — re-runs are byte-identical diffs). `test/plugins/tdd/services/spec_sweep_evidence_1196_test.dart` guards the evidence against parser/corpus drift.

## What was built (the fixes)

All in `lib/src/plugins/tdd/services/spec_parser.dart` unless noted:

1. **Line-ending + BOM normalization** (`normalizeSpecText`): CRLF and lone-CR become LF at every public entry point, line-for-line so every 1-based spec line number survives; a leading BOM is stripped. Fixes the CRLF FR-drop and pin-loss.
2. **HTML-entity decoding for heading recognition** (`_matchesSectionHeading` + `_decodeEntities`): `&amp;` `&quot;` `&#39;` `&apos;` `&lt;` `&gt;` `&nbsp;` decode before the section match — `## External Dependencies &amp; Contracts` is the section again. Content lines stay verbatim.
3. **Heading qualifier tolerance**: the four section headings (`Key Entities`, `External Dependencies &/and Contracts`, `Layer Contracts`, `Lanes`) accept a trailing qualifier (`## Layer Contracts — epic-level`) — per-epic contracts route exactly like per-feature ones.
4. **Scenario grammar widened, everywhere in lockstep**: flat (`1.`) or dotted (`1.1.`) numbering, bold (`**Given**`) or plain (`Given`) markers — one `_scenarioHeader` shared by the behavior walk, the marker walk, `RequirementScanner` (`requirement_scan.dart`), and `SpecMutator` (`spec_mutator.dart`) so document-wide AC ids stay aligned. `_extractScenarioText` matches `Then` bold-or-plain.
5. **FR tables with variants** (`_frLine`): FR declarations in bullet OR table form (`| FR-001 | The system MUST ... |`) produce unit behaviors in document order; variant continuation rows (empty id cell) are auxiliary detail, never behaviors. All three FR walks (unit derivation, contract traces, persistence declarations) route through the same helper so U-id numbering stays aligned. This SUPERSEDES the #846-era expectation that a table-FR exits 2 as a coverage gap — the updated `bug_846_coverage_gate_test.dart` case proves the table FR now lands on the test list (the gate itself is unchanged for every requirement that produces no row).
6. **Line-addressed refusals**: the no-acceptance-scenarios refusal names the first content line (`spec line N`) and carries a `--> fix:` line naming the accepted grammars (bold/plain, flat/dotted) and the `(manual: owner)` escape.
7. **The sweep infrastructure** (new): `spec_corpus_sweeper.dart` (pure sweep + honest classification), `tool/generate_zikzak_corpus.dart`, `tool/sweep_zikzak_corpus.dart`, the committed corpus + `corpus-shapes.txt` + `sweep.json`, and the three test suites (fast hardening ×24, fast sweep oracle ×7 + evidence guard ×4, property fuzz ×4).

## Honest results (the tracker, post-hardening)

- Parse surface: **120 specs — 113 clean, 7 refused (every refusal names a line), 0 crashed.** The 7 refusals are the pathological class doing its job (unknown type, duplicate marker, marker outside a block, malformed FUNCTION signature, empty/whitespace/FR-only specs → line-addressed "no acceptance scenarios").
- Plan surface: **98 of 120 plan cleanly; 22 refuse honestly** (10 legacy drift exit 3 — no treaty pin, the #919/#990 contract; 4 "cannot derive behaviors" exit 1 + 1 declaration refusal exit 2 + 4 more drift exit 3 from the pathological class; 3 manual-empty-owner coverage-gate exit 2 with the offending line).
- Routing (#1186 window): **declared=410, fallback=199** behaviors across the corpus. The fallback 199 is concentrated exactly where it should be: undeclared-routing shapes (60), nested-ac/inline-prose/fr-table/non-english specs whose FRs carry no `traces:` (120), html-entities (16), manual (3). The number is tracked so it can only shrink honestly, toward zero — emitting markers back into authored specs (#1186's suggestion) is follow-up work, deliberately out of scope here.

## Requirements

- **FR-001**: The parser never crashes on any corpus spec (a lineless StateError counts as a crash); every refusal names the offending spec line. PROVED by the sweep (crashed=0) and P1/P2 tests.
- **FR-002**: Form-only mutations of a spec (CRLF, entities, BOM, nested numbering, unbolded markers, translated headings, dropped Lanes) derive the IDENTICAL behavior set. PROVED by the property tier (130 mutants).
- **FR-003**: Content mutations (dropped pin, emptied spec, duplicated marker) land in honest outcomes — line-addressed refusals or drift the plan gate reports. PROVED by the property tier + plan sweep exit classes.
- **FR-004**: The corpus is committed, deterministic, and importable (`zfa corpus import corpus/zik_zak`); regeneration is byte-identical. PROVED by the generator + `--facts`/`--plan` sweep determinism.
- **FR-005**: The coverage tracker (`corpus/zik_zak/sweep.json`) reports X/120 plan-clean and the #1186 fallback count, and fails a test when it drifts from the parser. PROVED by `spec_sweep_evidence_1196_test.dart`.
- **FR-006**: Mutation-checked test strength: killing any of the hardening fixes (entity decode, CR normalization, scenario grammar) fails the suite — 3 spot-checked mutants each killed (2, 3, and 5 failures respectively). PROVED in `tdd/verification.md`.
- **FR-007**: One PR closes #1196; no `path:` dependency overrides introduced; existing strict-grammar contracts (#919 drift gate, #846 coverage gate, #1000 lane guards) remain green for their shapes.

## Non-Functional Requirements

- **Errors-are-an-API (VISION §4)**: every new refusal carries a `--> fix:` line and a line address.
- **Determinism (VISION §4)**: corpus, sweep, and evidence are pure functions of committed inputs — no clock, no RNG.
- **Honesty over claims**: the tracker reports the real 98/120 and the real 199-behavior fallback window; nothing is rounded to a nicer story.
