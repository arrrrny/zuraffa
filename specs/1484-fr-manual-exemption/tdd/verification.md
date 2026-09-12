# Verification: 1484-fr-manual-exemption

**Audit**: test-first evidence + suite health + format/analyze gates
**Date**: 2026-09-11 | **Verdict**: PASS

## 1. Test-first discipline (the loop was honest)

Every behavior in `tdd/test-list.md` was written RED before its
implementation:

- RED evidence: `spec_parser_fr_manual_1484_test.dart` failed to LOAD
  (`Member not found: 'SpecParser.parseFrRoutings'` — the 1484 API did not
  exist) and `plan_fr_manual_1484_test.dart` ran `+0 -5` (manual FRs still
  derived unit rows, no warning, no manual section). Recorded in
  `tdd/cycle-log.md` Cycles 1–2.
- GREEN evidence: both suites `+17: All tests passed!` after the
  implementation landed (Cycle 3). The legacy sweep (Cycle 4) updated
  fixtures that pinned the old fallback default — each edit preserves the
  test's original intent (documented per-file in the cycle log).

## 2. Mutation/test-strength spot evidence

The strongest structural mutant this feature could admit — "the default
flip is reverted (unbound FRs derive unit rows again)" — is killed by
`plan_fr_manual_1484_test.dart` (`defaulted FR warns naming the FR and
both remedies, routes manual` asserts `isNot(contains('FR-021'))` on the
test list) and by `spec_parser_fr_manual_1484_test.dart` (`an unbound
unmarked FR defaults to manual, not a unit row`).

The second mutant — "the marker is ignored when a trace exists" — is
killed by `the explicit declaration outranks a trace` (marker + binding →
no row).

The third mutant — "the manual section hides the FR text" — is killed by
the matrix test asserting the full FR prose appears under `## manual:` and
the machine block counts (`fr-manual: 2`, `manual: 2`, `open-gaps: 0`).

## 3. Success criteria (PROVED)

| Criterion | Proof |
| --- | --- |
| SC-001 explicit marker → zero unit rows, sibling keeps id | `plan_fr_manual_1484_test.dart::explicit marker routes manual end-to-end` (`isNot(contains('\| U2 \|'))`, `contains('\| U1 \|')`) |
| SC-002 defaulted FR → warning + both remedies + zero rows | `::defaulted FR warns naming the FR and both remedies, routes manual` |
| SC-003 manual section + machine counts | parser matrix test + `::traceability machine block counts the manual declarations` |
| SC-004 all-traced specs byte-identical | `::all-FR-traced specs plan byte-identically (backwards compat)` (+ the 816-test services suite, which re-derives every traced fixture exactly as before) |
| SC-005 legacy-default fixtures updated | Cycle 4 + the full repo sweep below |

## 4. Suite health

Chunked `dart test` runs (kernel caches cleaned between chunks per the
disk-housekeeping obligation; disk stayed ≥ 80% free after every chunk):

- `test/plugins/tdd/services` → **+816 green**
- `test/plugins/tdd/commands` → **+468 green**
- `test/tdd` +152, `test/cli` +230, `test/commands` +370,
  `test/plugins/mcp` +130, `test/agent` +240, core/state/skin/… batch
  +1074, integration/regression/… batch +255, misc batch +587,
  root + mock/slice/skeleton +413, plugin batches +347 / +262 / +813 —
  all green.

**Unrelated pre-existing failures (flagged, not caused by this diff)**:
the Flutter-SDK compile gates (`test/plugins/controller/controller_compile_test.dart`,
`test/plugins/presenter/presenter_compile_test.dart`,
`test/plugins/view/view_compile_test.dart`,
`test/templates/self_hosting/*_test.dart`) invoke `flutter pub get` —
the Flutter binary is absent from this environment
(`which flutter` → not found). These files are untouched by the change;
on a Flutter-equipped CI they gate the same way as before.

## 5. Gates

- `dart analyze` over every changed Dart file → `No issues found!`
- `dart format .` → idempotent (0 changed on re-run; two pre-existing
  drift files swept in the first pass are included in the diff).

## 6. Semantics preserved (hard constraints)

- `zfa tdd run` / `gen` / `make` / `verify` / `verify-red`: **zero source
  changes** (`git diff --name-only` shows none of them). Manual FRs never
  produce a row, so the loop never sees one.
- All-FR-traced specs: identical derivation (SC-004 suite).
- The scenario-side `**Type**` grammar is untouched; `parseScenarioTypeMarkers`
  only SKIPS `manual`-valued markers outside scenario blocks (they belong
  to the FR walk) — every other misplaced marker still refuses with the
  same message and spec line.
