// Feature 1484 (FR manual exemption) — the FR-side escape hatch.
//
// Every FR unconditionally derived a unit behaviour row (_extractUnit),
// so inherently non-unit FRs (UI appearance, non-functional constraints,
// whole-app properties) manufactured unit rows that could never pass
// `make`, permanently blocking `zfa tdd run` with no opt-out. #846 gave
// ACCEPTANCE criteria the `(manual:)` hatch; 1484 extends the same
// concept to FRs with a `**Type**: manual` continuation line that
// mirrors the scenario-side `**Type**` marker pattern, and flips the
// default: an FR with no `traces:` binding and no marker routes to a
// manual declaration instead of a unit row (the fallback-routing
// dead-end class collapses).
//
// Pins:
//   - parseFrRoutings reports per-FR routing facts (id, unit id, spec
//     line, marker flag, trace tokens) for the bullet AND FR-table
//     grammars, with document-wide unit-id alignment.
//   - Manual FRs (explicit marker OR defaulted) consume their unit id
//     but emit no row (#846 id-alignment precedent).
//   - The explicit declaration outranks a trace (marker + traces ->
//     manual).
//   - A `**Type**: manual` line inside a fenced example is
//     documentation, never a declaration.
//   - The coverage gate counts manual FR ids as covered; the
//     traceability matrix renders the `## manual:` section and the
//     machine-block counts.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/requirement_scan.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

const _spec = '''
# Spec: 1484-probe

## Layer Contracts

**Function**:
- `Formatter`: `format(Template) -> String`

## Functional Requirements

- **FR-001**: The system MUST compute the total when totals are requested.
  traces: Formatter
- **FR-002**: The system MUST visually distinguish completed tasks.
  **Type**: manual
- **FR-003**: The system MUST NOT transmit task data anywhere.

## Acceptance Scenarios

1. **Given** the app **When** it starts **Then** the total equals 42.
''';

void main() {
  group('parseFrRoutings (feature 1484)', () {
    test('reports the routing facts per FR in document order', () {
      final routings = SpecParser.parseFrRoutings(_spec);
      expect(routings, hasLength(3));

      expect(routings[0].frId, 'FR-001');
      expect(routings[0].unitId, 'U1');
      expect(routings[0].traced, isTrue);
      expect(routings[0].traceTokens, ['Formatter']);
      expect(routings[0].manualMarker, isFalse);
      expect(routings[0].routesManual, isFalse);
      expect(routings[0].rawText, contains('MUST compute the total'));

      expect(routings[1].frId, 'FR-002');
      expect(routings[1].unitId, 'U2');
      expect(routings[1].manualMarker, isTrue);
      expect(routings[1].routesManual, isTrue);
      // The marker line's 1-based spec position: FR-002's bullet is
      // line 13 of the fixture, the marker line follows it.
      expect(routings[1].specLine, lessThan(routings[1].markerLine!));

      expect(routings[2].frId, 'FR-003');
      expect(routings[2].unitId, 'U3');
      expect(routings[2].manualMarker, isFalse);
      expect(routings[2].traced, isFalse);
      // The 1484 default: no binding, no marker -> manual declaration.
      expect(routings[2].routesManual, isTrue);
    });

    test('spec lines are 1-based and name the FR header', () {
      final routings = SpecParser.parseFrRoutings(_spec);
      final lines = _spec.split('\n');
      for (final r in routings) {
        expect(lines[r.specLine - 1], contains(r.frId));
      }
    });

    test('the explicit declaration outranks a trace', () {
      const both = '''
## Acceptance Scenarios

1. **Given** the cart **When** it computes **Then** the total equals 42.

## Functional Requirements

- **FR-001**: The system MUST compute the total.
  traces: Formatter
  **Type**: manual
''';
      final r = SpecParser.parseFrRoutings(both).single;
      expect(r.manualMarker, isTrue);
      expect(r.traced, isTrue);
      expect(r.routesManual, isTrue);
      expect(
        const SpecParser()
            .parse('1484-probe', both)
            .where((b) => b.kind == BehaviorKind.unit),
        isEmpty,
      );
    });

    test('a marker inside a fenced example is documentation', () {
      const fenced = '''
- **FR-001**: The system MUST compute the total.

```markdown
- **FR-002**: example FR
  **Type**: manual
```

- **FR-003**: The system MUST sync when online.
  traces: Formatter
''';
      final routings = SpecParser.parseFrRoutings(fenced);
      expect(routings, hasLength(2));
      expect(
        routings[0].manualMarker,
        isFalse,
        reason:
            'fenced markers '
            'are documentation, not declarations',
      );
      expect(
        routings[0].routesManual,
        isTrue,
        reason:
            'unbound FR defaults '
            'to manual even when the only marker it "carries" is fenced',
      );
      expect(routings[1].routesManual, isFalse);
    });

    test('FR-table grammar routes identically', () {
      const table = '''
| FR-001 | The system MUST visually distinguish completed tasks |
  **Type**: manual
| FR-002 | The system MUST compute the total |
  traces: Formatter
''';
      final routings = SpecParser.parseFrRoutings(table);
      expect(routings, hasLength(2));
      expect(routings[0].frId, 'FR-001');
      expect(routings[0].manualMarker, isTrue);
      expect(routings[0].routesManual, isTrue);
      expect(routings[1].routesManual, isFalse);
    });
  });

  group('unit derivation (feature 1484 routing)', () {
    test('a marker FR consumes its unit id but derives no row', () {
      final behaviors = const SpecParser().parse('1484-probe', _spec);
      expect(
        behaviors.where((b) => b.sourceCriterion == 'FR-002'),
        isEmpty,
        reason: 'the manual exemption routes FR-002 out of the unit lane',
      );
      // The traced sibling keeps its document-wide id (U1) — manual FRs
      // consume ids but never shift the traced ones (#846 alignment).
      final unitIds = behaviors
          .where((b) => b.kind == BehaviorKind.unit)
          .map((b) => b.id)
          .toList();
      expect(unitIds, ['U1']);
    });

    test('an unbound unmarked FR defaults to manual, not a unit row', () {
      final behaviors = const SpecParser().parse('1484-probe', _spec);
      expect(
        behaviors.where((b) => b.sourceCriterion == 'FR-003'),
        isEmpty,
        reason:
            'the fallback-routing dead-end class is collapsed: an FR '
            'with no declared contract binding is a manual declaration',
      );
    });

    test('traced FRs still derive rows with the persistence tag intact', () {
      const traced = '''
1. **Given** the app **When** it saves **Then** the draft persists.

- **FR-001**: The system MUST persist the draft.
  traces: DraftStore
- **FR-002**: The system MUST compute the total.
  traces: Formatter
''';
      final behaviors = const SpecParser().parse('1484-probe', traced);
      final units = behaviors
          .where((b) => b.kind == BehaviorKind.unit)
          .map((b) => b.id)
          .toList();
      expect(units, ['U1', 'U2']);
      final first = behaviors
          .where((b) => b.sourceCriterion == 'FR-001')
          .single;
      expect(
        first.persistence,
        isFalse,
        reason:
            'no [persistent] tag on '
            'this fixture — traces to a storage row would declare it',
      );
    });

    test('a [persistent]-tagged traced FR keeps the tag stripping', () {
      const tagged = '''
1. **Given** the app **When** it saves **Then** the draft persists.

- **FR-001**: **[persistent]** The system MUST persist the draft.
  traces: DraftStore
''';
      final behaviors = const SpecParser().parse('1484-probe', tagged);
      final unit = behaviors.where((b) => b.kind == BehaviorKind.unit).single;
      expect(unit.id, 'U1');
      expect(unit.description, isNot(contains('[persistent]')));
    });
  });

  group('coverage gate (feature 1484 accounting)', () {
    test('manual FR ids count as covered, never gaps', () {
      final scan = const RequirementScanner().scan(_spec);
      final behaviors = const SpecParser().parse('1484-probe', _spec);
      // Legacy contract preserved: without the manual set, untraced FRs
      // with no rows are gaps.
      expect(const CoverageGate().evaluate(scan, behaviors), isNotEmpty);
      // With the manual set, the manual FRs are covered declarations.
      final gaps = const CoverageGate().evaluate(
        scan,
        behaviors,
        manualFrIds: const {'FR-002', 'FR-003'},
      );
      expect(gaps, isEmpty);
    });
  });

  group('traceability matrix (feature 1484 manual section)', () {
    test('renders the manual section, statuses and machine counts', () {
      final scan = const RequirementScanner().scan(_spec);
      final behaviors = const SpecParser().parse('1484-probe', _spec);
      final md = const TraceabilityMatrix().render(
        feature: '1484-probe',
        scan: scan,
        behaviors: behaviors,
        frManualTags: const {
          'FR-002': '**Type**: manual',
          'FR-003': 'defaulted: no `traces:` binding',
        },
      );

      // The dedicated manual: section — tracked, not hidden.
      expect(md, contains('## manual:'));
      expect(md, contains('manual (**Type**: manual)'));
      expect(md, contains('manual (defaulted: no `traces:` binding)'));
      expect(md, contains('FR-002'));
      expect(md, contains('FR-003'));
      expect(
        md,
        contains('The system MUST visually distinguish completed tasks.'),
        reason: 'full FR text is carried',
      );

      // The main table marks the manual FRs manual, not GAP.
      final fr2Row = md
          .split('\n')
          .firstWhere((l) => l.startsWith('| FR-002 '));
      expect(fr2Row, contains('manual'));
      expect(fr2Row, isNot(contains('GAP')));

      // The machine block counts the FR manual declarations.
      expect(md, contains('fr-manual: 2'));
      expect(md, contains('manual: 2'));
      expect(md, contains('open-gaps: 0'));
      expect(md, contains('automated: 2'));
    });

    test('no manual FRs renders exactly the legacy shape', () {
      final scan = const RequirementScanner().scan(_spec);
      final behaviors = const SpecParser().parse('1484-probe', _spec);
      final md = const TraceabilityMatrix().render(
        feature: '1484-probe',
        scan: scan,
        behaviors: behaviors,
      );
      expect(md, isNot(contains('## manual:')));
      expect(md, contains('fr-manual: 0'));
    });
  });
}
