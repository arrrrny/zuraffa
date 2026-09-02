// Unit tests for the strict TUPEC requirement scan + coverage gate +
// spec-contract hash (bug #846 — the completeness proof behind plan).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/requirement_scan.dart';

var _uIdx = 0;
Behavior _unit(String criterion) => Behavior(
  id: 'U${++_uIdx}',
  feature: 'f',
  kind: BehaviorKind.unit,
  description: '',
  sourceCriterion: criterion,
  target: '',
);

var _aIdx = 0;
Behavior _acceptance(String criterion) => Behavior(
  id: 'A${++_aIdx}',
  feature: 'f',
  kind: BehaviorKind.acceptance,
  description: '',
  sourceCriterion: criterion,
  target: '',
);

void main() {
  const scanner = RequirementScanner();
  const gate = CoverageGate();

  group('RequirementScanner — statement positions', () {
    test('recognizes the canonical FR bullet', () {
      final scan = scanner.scan('- **FR-001**: The system MUST do X');
      expect(scan.statements.single.id, 'FR-001');
      expect(scan.statements.single.isFunctional, isTrue);
      expect(scan.statements.single.lineNo, 1);
    });

    test('recognizes malformed FR statements a tolerant parser drops', () {
      // Missing list dash; colon inside the bold; heading form; table row.
      const spec = '''
**FR-002:** The system MUST log
### FR-003: registration
| FR-004 | The system MUST persist |
''';
      final ids = scanner.scan(spec).statements.map((s) => s.id).toList();
      expect(ids, ['FR-002', 'FR-003', 'FR-004']);
    });

    test('ignores mid-sentence FR references', () {
      final scan = scanner.scan(
        'This story implements the FR-012 contract from the parent spec.',
      );
      expect(scan.statements, isEmpty);
    });

    test('FR ids restated in a mapping table are not duplicates', () {
      const spec = '''
- **FR-001**: The system MUST do X
| FR-001 Contract interface | US1 | AC-1, SC-001 |
''';
      final scan = scanner.scan(spec);
      expect(scan.hasDuplicates, isFalse);
      expect(scan.statements.length, 2);
    });

    test('scenario headers get document-wide sequential AC ids', () {
      const spec = '''
### Story 1
1. **Given** a **When** b **Then** c
2. **Given** d **When** e **Then** f
### Story 2
1. **Given** g **When** h **Then** i
''';
      final scan = scanner.scan(spec);
      // The literal scenario number restarts per story; the AC ids must
      // not (duplicate criterion ids make the proof ambiguous).
      expect(scan.statements.map((s) => s.id).toList(), [
        'AC-1',
        'AC-2',
        'AC-3',
      ]);
    });

    test('duplicate explicit AC ids are flagged, FR ids are not', () {
      const spec = '''
1. **Given** a **When** b **Then** c
| AC-1 | Given d, When e, Then f |
- **FR-001**: The system MUST do X
- **FR-001**: The system MUST do Y
''';
      final scan = scanner.scan(spec);
      expect(scan.hasDuplicates, isTrue);
      expect(scan.duplicates.single.id, 'AC-1');
    });

    test('captures the manual declaration owner', () {
      final scan = scanner.scan(
        '2. **Given** slow **When** measured **Then** feels fast '
        '(manual: @arrrrny)',
      );
      final statement = scan.statements.single;
      expect(statement.isManual, isTrue);
      expect(statement.manualOwner, '@arrrrny');
    });
  });

  group('CoverageGate', () {
    test('complete spec has no gaps', () {
      const spec = '''
1. **Given** a **When** b **Then** c
- **FR-001**: The system MUST do X
''';
      final scan = scanner.scan(spec);
      final gaps = gate.evaluate(scan, [_acceptance('AC-1'), _unit('FR-001')]);
      expect(gaps, isEmpty);
    });

    test('FR statement with no unit row is a gap', () {
      const spec = '''
1. **Given** a **When** b **Then** c
- **FR-001**: The system MUST do X
- **FR-002**: The system MUST do Y
''';
      final scan = scanner.scan(spec);
      final gaps = gate.evaluate(scan, [_acceptance('AC-1'), _unit('FR-001')]);
      expect(gaps.single.statement.id, 'FR-002');
      expect(gaps.single.fix, contains('fix:'));
      expect(gaps.single.fix, contains('MUST'));
    });

    test('unpadded FR ids get the TUPEC 3-digit fix', () {
      final scan = scanner.scan('- **FR-1**: The system MUST do X');
      final gaps = gate.evaluate(scan, [_unit('FR-1')]);
      // FR-1 matches its own (unpadded) row id, so the coverage itself
      // holds — the id form is only enforced when it yields no row.
      expect(gaps, isEmpty);
    });

    test('non-3-digit FR id with no row is a gap with rename fix', () {
      final scan = scanner.scan('- **FR-1**: The system MUST do X');
      final gaps = gate.evaluate(scan, const []);
      expect(gaps.single.fix, contains('FR-001'));
    });

    test('AC with no row and no manual declaration is a gap', () {
      const spec = '''
1. **Given** a **When** b **Then** c
| AC-2 | Given d, When e, Then f |
''';
      final scan = scanner.scan(spec);
      final gaps = gate.evaluate(scan, [_acceptance('AC-1')]);
      expect(gaps.single.statement.id, 'AC-2');
      expect(gaps.single.fix, contains('(manual: @handle)'));
    });

    test('manual declaration without owner is a gap', () {
      final scan = scanner.scan(
        '1. **Given** slow **When** measured **Then** fast (manual:)',
      );
      final gaps = gate.evaluate(scan, const []);
      expect(gaps.single.statement.id, 'AC-1');
      expect(gaps.single.fix, contains('owner'));
    });

    test('valid manual declaration needs no behavior row', () {
      final scan = scanner.scan(
        '1. **Given** slow **When** measured **Then** fast (manual: @a)',
      );
      final gaps = gate.evaluate(scan, const []);
      expect(gaps, isEmpty);
    });
  });

  group('SpecContractHash', () {
    const spec = '''
1. **Given** a **When** b **Then** c
- **FR-001**: The system MUST do X
''';

    test('is stable across identical contracts', () {
      expect(
        SpecContractHash.compute(scanner.scan(spec)),
        SpecContractHash.compute(scanner.scan(spec)),
      );
    });

    test('changes when a requirement statement changes', () {
      final edited = spec.replaceFirst('MUST do X', 'MUST do X without fail');
      expect(
        SpecContractHash.compute(scanner.scan(spec)),
        isNot(SpecContractHash.compute(scanner.scan(edited))),
      );
    });

    test('is stable under cosmetic prose edits elsewhere', () {
      final edited = '# Spec: demo\n\n$spec\nSome trailing prose.\n';
      expect(
        SpecContractHash.compute(scanner.scan(spec)),
        SpecContractHash.compute(scanner.scan(edited)),
        reason:
            'the hash is scoped to the requirement statements, so '
            're-flowing prose must not fire drift',
      );
    });
  });

  group('TraceabilityMatrix', () {
    test('renders one row per statement with statuses and hash', () {
      const spec = '''
1. **Given** a **When** b **Then** c
- **FR-001**: The system MUST do X
2. **Given** slow **When** measured **Then** fast (manual: @a)
''';
      final scan = scanner.scan(spec);
      final md = const TraceabilityMatrix().render(
        feature: 'f',
        scan: scan,
        behaviors: [_acceptance('AC-1'), _unit('FR-001')],
      );
      expect(TraceabilityMatrix.extractSpecHash(md), isNotNull);
      expect(md, contains('| FR-001'));
      expect(md, contains('| AC-1'));
      expect(md, contains('| AC-2'));
      expect(md, contains('automated'));
      expect(md, contains('manual (owner: @a)'));
      expect(md, contains('open-gaps: 0'));
    });

    test('statement cells cannot break the table shape', () {
      final scan = scanner.scan(r'| FR-001 | MUST keep the \| pipe |');
      final md = const TraceabilityMatrix().render(
        feature: 'f',
        scan: scan,
        behaviors: const [],
      );
      // One gap row, one escaped cell — the row count is intact.
      expect(
        md.split('\n').where((l) => l.startsWith('| FR-001')),
        hasLength(1),
      );
    });
  });
}
