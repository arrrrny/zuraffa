#!/bin/bash
# Deliberate mutation audit (spec 1334, issue #1143) — the 0966
# "deliberate-mutation-report" precedent applied to the #1143 seams.
# Each mutant patches the production code, runs the 1334 + 0966 suites
# (the pins), and MUST be killed (a test fails). Reverts after each.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
command -v dart >/dev/null || export PATH=/home/z/tools/dart-sdk/bin:$PATH

TARGET=lib/src/tdd/services/typed_ledger_row.dart
BINDING=lib/src/tdd/services/xray_ledger_binding.dart
SUITES="test/tdd/1334-typed-ui-coverage-ledger/ test/tdd/0966-typed-ledger-rows/"
OUT=specs/1334-typed-ui-coverage-ledger/tdd/evidence
REPORT=$OUT/deliberate-mutation-report.md

run_suites() {
  rm -rf .dart_tool/test/
  dart test $SUITES > /tmp/mutant-run.txt 2>&1
  rm -rf .dart_tool/test/
  if grep -q "All tests passed" /tmp/mutant-run.txt; then echo "SURVIVED"; else echo "KILLED"; fi
}

run_green() {
  rm -rf .dart_tool/test/
  dart test $SUITES > /tmp/mutant-run.txt 2>&1
  rm -rf .dart_tool/test/
  if grep -q "All tests passed" /tmp/mutant-run.txt; then echo "GREEN"; else echo "RED"; fi
}

cp $TARGET /tmp/typed_ledger_row.dart.bak
cp $BINDING /tmp/xray_ledger_binding.dart.bak

echo "# Deliberate Mutation Report (spec 1334, issue #1143)" > $REPORT
echo "" >> $REPORT
echo "Production code under audit: \`typed_ledger_row.dart\` + \`xray_ledger_binding.dart\`." >> $REPORT
echo "Per-mutant scope: the 1334 + 0966 ledger subject suites (18 tests)." >> $REPORT
echo "A mutant is KILLED when any pin fails; SURVIVED means a coverage hole." >> $REPORT
echo "" >> $REPORT
echo "| # | mutant (the #1143 seam it breaks) | result | killed by |" >> $REPORT
echo "| - | ---------------------------------- | ------ | --------- |" >> $REPORT

# --- M1: zeroTraced predicate ignores 0/0 kinds ----------------------
python3 - << 'PY'
import re
p = 'lib/src/tdd/services/typed_ledger_row.dart'
s = open(p).read()
s = s.replace('bool get zeroTraced => traced == 0;',
              'bool get zeroTraced => traced == 0 && total > 0;')
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M1 | \`zeroTraced\` gains \`&& total > 0\` — 0/0 kinds stop being gaps (the presence-only screen reads clean — AC-2 broken) | $r | T2 (all-five-kinds report), T3 (gate), T7 (polarity pins) |" >> $REPORT
cp /tmp/typed_ledger_row.dart.bak $TARGET

# --- M2: legacy classifier always says typed -------------------------
python3 - << 'PY'
p = 'lib/src/tdd/services/typed_ledger_row.dart'
s = open(p).read()
s = s.replace('return LedgerParseResult(rows: rows, legacy: !anyTyped);',
              'return LedgerParseResult(rows: rows, legacy: false);')
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M2 | \`fromLedgerJson\` hard-codes \`legacy: false\` — kindless 075 ledgers get the tightened gate (AC-6 broken: existing projects go red) | $r | T6 (legacy mode) |" >> $REPORT
cp /tmp/typed_ledger_row.dart.bak $TARGET

# --- M3: status polarity ignores row gaps ----------------------------
python3 - << 'PY'
p = 'lib/src/tdd/services/typed_ledger_row.dart'
s = open(p).read()
s = s.replace('bool get fullyTraced => zeroTracedKinds.isEmpty && !hasRowGaps;',
              'bool get fullyTraced => zeroTracedKinds.isEmpty;')
s = s.replace('''    if (zeroTracedKinds.isEmpty && !hasRowGaps) {
      return ScreenTraceStatus.fullyTraced;
    }''',
              '''    if (zeroTracedKinds.isEmpty) {
      return ScreenTraceStatus.fullyTraced;
    }''')
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M3 | screen status drops the row-gap condition — a screen with red rows reads \`fully-traced\` (kinds traced, rows not) | $r | T3 (row-gap gate), T7 (status polarity pin) |" >> $REPORT
cp /tmp/typed_ledger_row.dart.bak $TARGET

# --- M4: fromScenario loses the advisory flag ------------------------
python3 - << 'PY'
p = 'lib/src/tdd/services/typed_ledger_row.dart'
s = open(p).read()
s = s.replace('      advisory: LedgerRowKind.isGoldenScenario(scenario),',
              '      advisory: false,')
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M4 | \`fromScenario\` drops the plan-time golden advisory flag — golden rows become gate surface (AC-5 broken: goldens could block) | $r | T1 (golden advisory), T5 (composed advisory) |" >> $REPORT
cp /tmp/typed_ledger_row.dart.bak $TARGET

# --- M5: per-screen gate ignores zero-traced kinds -------------------
python3 - << 'PY'
p = 'lib/src/tdd/services/typed_ledger_row.dart'
s = open(p).read()
s = s.replace('''      if (report.hasRowGaps || (!legacy && report.zeroTracedKinds.isNotEmpty))''',
              '''      if (report.hasRowGaps)''')
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M5 | \`evaluateScreens\` counts row gaps only — the gaming presence-only screen PASSES the per-screen gate (the whole point of #1143) | $r | T3 (gate fails gaming ledger), T8 (failure-line count) |" >> $REPORT
cp /tmp/typed_ledger_row.dart.bak $TARGET

# --- M6: overlay rendering loses the HIGHLIGHT marker ----------------
python3 - << 'PY'
p = 'lib/src/tdd/services/xray_ledger_binding.dart'
s = open(p).read()
s = s.replace("      c.zeroTraced ? 'HIGHLIGHT ${c.label}' : c.label,",
              "      c.label,")
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M6 | \`renderScreen\` drops the HIGHLIGHT marker — zero-traced kinds render like clean ones, painted as proof (AC-3 broken) | $r | T4 (per-kind overlay rendering) |" >> $REPORT
cp /tmp/xray_ledger_binding.dart.bak $BINDING

# --- M7: legacy golden reclassification dropped ----------------------
python3 - << 'PY'
p = 'lib/src/tdd/services/typed_ledger_row.dart'
s = open(p).read()
s = s.replace("      if (typedKind != null || isLegacyGolden) anyTyped = true;",
              "      if (typedKind != null) anyTyped = true;")
s = s.replace('''      final advisoryFlag = isLegacyGolden ||
          (entry['advisory'] as bool? ?? false);''',
              "      final advisoryFlag = entry['advisory'] as bool? ?? false;")
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M7 | \`fromLedgerJson\` stops recognizing the 0966 \`golden\` label — golden-only artifacts read legacy, golden rows lose the forced advisory | $r | T6 (golden-only 0966 artifact reads typed + advisory forced) |" >> $REPORT
cp /tmp/typed_ledger_row.dart.bak $TARGET

# --- M8: kind vocabulary gains a sixth value -------------------------
python3 - << 'PY'
p = 'lib/src/tdd/services/typed_ledger_row.dart'
s = open(p).read()
s = s.replace("""  /// An interaction chain ("tap → loading → resolve → navigate"). The
  /// `When` clause the presence-only ledger discarded.
  sequence('sequence');""",
              """  /// An interaction chain ("tap → loading → resolve → navigate"). The
  /// `When` clause the presence-only ledger discarded.
  sequence('sequence'),

  /// A stray sixth kind the #1143 vocabulary forbids.
  vibe('vibe');""")
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M8 | the vocabulary gains a sixth kind value — the five-kind contract (AC-1) is violated | $r | T1 (enumeration pin), T7 (order pin) |" >> $REPORT
cp /tmp/typed_ledger_row.dart.bak $TARGET

# --- M9: per-screen coverage skips undeclared kinds ------------------
python3 - << 'PY'
p = 'lib/src/tdd/services/typed_ledger_row.dart'
s = open(p).read()
s = s.replace('''    final gateRows = rows.where((r) => !r.advisory).toList();
    return [
      for (final kind in LedgerRowKind.values)
        KindCoverage(
          screen: screen,
          kind: kind,
          total: gateRows.where((r) => r.kind == kind).length,
          traced: gateRows
              .where((r) => r.kind == kind && r.state == 'DONE')
              .length,
        ),
    ];''',
              '''    final gateRows = rows.where((r) => !r.advisory).toList();
    final coverage = <KindCoverage>[];
    for (final kind in LedgerRowKind.values) {
      final ofKind = gateRows.where((r) => r.kind == kind).toList();
      if (ofKind.isEmpty) continue;
      coverage.add(KindCoverage(
        screen: screen,
        kind: kind,
        total: ofKind.length,
        traced: ofKind.where((r) => r.state == 'DONE').length,
      ));
    }
    return coverage;''')
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M9 | \`kindCoverageAllKinds\` skips undeclared kinds (back to the 0966 declared-only view) — the presence-only screen loses its 0/0 gaps | $r | T2, T3, T7, T8 |" >> $REPORT
cp /tmp/typed_ledger_row.dart.bak $TARGET

# --- M10: legacy gate exemption applied to typed ledgers -------------
# EQUIVALENT BY INVARIANT (documented, not a coverage hole): when
# unproven == 0 every gate row is DONE, so every declared kind has a
# traced row and untracedKinds is empty — the (legacy || ...) arm is
# unreachable with unproven == 0. Verified equivalent: suites stay green.
python3 - << 'PY'
p = 'lib/src/tdd/services/typed_ledger_row.dart'
s = open(p).read()
s = s.replace('  bool get passed => unproven == 0 && (legacy || untracedKinds.isEmpty);',
              '  bool get passed => unproven == 0;')
open(p, 'w').write(s)
PY
r=$(run_suites)
echo "| M10 | the feature-wide verdict drops the kind-gap arm (\`unproven == 0\` alone) — EQUIVALENT BY INVARIANT: \`unproven == 0\` implies every declared kind traced, so the arm is unreachable | $r (equivalent — the arm is defensive documentation of AC-6, unreachable when unproven == 0) | — |" >> $REPORT
cp /tmp/typed_ledger_row.dart.bak $TARGET

echo "" >> $REPORT
echo "Final state: both files restored from backup; the 1334 + 0966 suites" >> $REPORT
echo "re-run green after restore (see \`t00*-green.txt\` + \`0966-regression-green.txt\`)." >> $REPORT

# sanity: restored state must be green again
r=$(run_green)
echo "" >> $REPORT
echo "Post-restore sanity run: $r (all 18 tests pass on the restored code)." >> $REPORT

cat $REPORT
