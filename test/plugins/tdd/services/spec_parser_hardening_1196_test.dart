// Issue #1196 (part of #908 P0) — spec-parser hardening, per-fix unit
// evidence. Each test pins ONE hardening dimension the 120-format
// sweep exposed on the pre-fix tree (RED evidence recorded in
// specs/1196-spec-parser-hardening/tdd/verification.md):
//
//  1. CRLF: FR bullets silently dropped (the `(.+)$` capture cannot
//     cross a trailing \r) and the treaty pin survived only because
//     the reader trims — now the parser normalizes line endings at
//     every entry point, line-for-line so spec line numbers survive.
//  2. HTML entities: `## External Dependencies &amp; Contracts` hid
//     the section — the declared dependencies were silently lost (a
//     silent misroute). Headings decode entities before matching.
//  3. Heading qualifiers: `## Layer Contracts — epic-level` (per-epic
//     contracts) hid the Layer Contracts section entirely.
//  4. Nested ACs: dotted numbering (`1.1. **Given**`) matched neither
//     the parser nor the scanner — scenarios silently dropped.
//  5. Inline prose: unbolded markers (`1. Given ... Then ...`) were
//     silently dropped the same way.
//  6. FR tables: `| FR-001 | The system MUST ... |` produced no unit
//     behavior (the #846-era gap) — now it routes like a bullet FR.
//  7. Honest refusals: the no-scenarios refusal names a spec line.
//
// The parser's lenient contracts (missing `## Lanes` = empty lanes)
// are pinned too: surviving a shape is not the same as requiring it.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/requirement_scan.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

const String pin = '**Template Version**: `zuraffa-1.0`';

void main() {
  group('CRLF line endings (issue #1196)', () {
    // Feature 1484: the FRs carry `traces:` bindings so they derive unit
    // rows — the CRLF continuation parsing they pin is exercised on the
    // traces lines too (an untraced FR would route manual, not unit).
    final crlfSpec =
        '$pin\r\n\r\n'
        '# Spec: crlf\r\n\r\n'
        '## Functional Requirements\r\n\r\n'
        '- **FR-001**: The system MUST save the state.\r\n'
        '  traces: Store\r\n'
        '- **FR-002**: The system MUST restore the state.\r\n'
        '  traces: Store\r\n\r\n'
        '## Acceptance Scenarios\r\n\r\n'
        '1. **Given** a user **When** they commit **Then** the state saves.\r\n'
        '   **Type**: acceptance\r\n';

    test('FR bullets parse (units are not silently dropped)', () {
      final behaviors = const SpecParser().parse('crlf', crlfSpec);
      expect(
        behaviors.where((b) => b.id.startsWith('U')).length,
        2,
        reason: 'pre-fix: the trailing CR killed the (.+)\$ capture',
      );
      expect(
        behaviors.map((b) => b.description),
        everyElement(isNot(contains('\r'))),
        reason: 'descriptions must not carry CR pollution',
      );
    });

    test('the treaty pin is found through CRLF', () {
      expect(const SpecParser().parseTemplateVersion(crlfSpec), 'zuraffa-1.0');
    });

    test('normalization is line-for-line (spec line numbers survive)', () {
      final lines = crlfSpec.split('\n');
      final normalized = SpecParser.normalizeSpecText(crlfSpec);
      expect(
        normalized.split('\n').length,
        lines.length,
        reason: '1 CRLF line in = 1 LF line out',
      );
    });

    test('lone-CR (classic Mac) endings normalize too', () {
      final crOnly =
          '${pin.replaceAll('\r\n', '\r')}'
          '\r# Spec: cr\r\r1. **Given** a **When** b **Then** c.\r';
      final behaviors = const SpecParser().parse('cr-only', crOnly);
      expect(behaviors, isNotEmpty);
    });

    test('the CRLF Type marker still declares its lane', () {
      final markers = SpecParser.parseScenarioTypeMarkers(crlfSpec);
      expect(markers['A1']?.declaredType?.name, 'acceptance');
      // Line 15 = the marker line (pin 1, blank 2, title 3, blank 4,
      // FR heading 5, blank 6, FR-001 7, traces 8, FR-002 9, traces
      // 10, blank 11, scenarios heading 12, blank 13, scenario 14,
      // marker 15).
      expect(markers['A1']?.specLine, 15);
    });
  });

  group('HTML entities in headings (issue #1196)', () {
    final entitySpec =
        '''
$pin

# Spec: entities

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| Thing | `id: String` | one thing |

## External Dependencies &amp; Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |

## Layer Contracts

**Domain**:
- `ThingRepo`: `get(String) -> Thing?`

## Functional Requirements

- **FR-001**: The system MUST escape the &quot;quoted&quot; label.

## Acceptance Scenarios

1. **Given** a label **When** the view renders **Then** the label renders.
   **Type**: widget
''';

    test('the &amp; heading still opens the dependencies section', () {
      final deps = const SpecParser().parseDependencies(entitySpec);
      expect(
        deps.map((d) => d.dependency),
        contains('Hive'),
        reason: 'pre-fix: the section was silently skipped',
      );
    });

    test('entity and contract sections survive entity-encoded prose', () {
      expect(const SpecParser().parseKeyEntities(entitySpec).length, 1);
      expect(const SpecParser().parseLayerContracts(entitySpec).length, 1);
    });

    test('entity-encoded section headings still open their sections', () {
      // `&nbsp;` between the canonical words decodes to a space before
      // the heading match, so `## Key&nbsp;Entities` is the Key
      // Entities section.
      final md =
          '''
$pin

## Key&nbsp;Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| Thing | `id: String` | one thing |

## Lanes&nbsp;—&nbsp;core

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
```

- **FR-001**: The system MUST hold the thing.

1. **Given** a thing **When** it renders **Then** the row shows.
''';
      expect(const SpecParser().parseKeyEntities(md).length, 1);
      expect(const SpecParser().parseLanes(md).length, 1);
    });
  });

  group('per-epic heading qualifiers (issue #1196)', () {
    final epicSpec =
        '''
$pin

# Spec: epic

## Layer Contracts — epic-level

**Function**:
- `Total`: `compute(List) -> num`

## Functional Requirements

- **FR-001**: The system MUST compute via the epic contract.
  traces: `Total.compute`

## Acceptance Scenarios

1. **Given** two items **When** the total computes **Then** the sum renders.
   **Type**: acceptance
''';

    test('the qualified Layer Contracts section is still the section', () {
      expect(const SpecParser().parseLayerContracts(epicSpec).length, 1);
      final rows = const SpecParser().parseContractRows(epicSpec);
      expect(rows.map((r) => r.name), contains('Total'));
    });

    test('qualified Key Entities and Lanes headings parse too', () {
      final md =
          '''
$pin

## Key Entities (commerce)

| Entity | Fields | Purpose |
| -- | -- | -- |
| Cart | `id: String` | the cart |

## Lanes — commerce epic

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
```

- **FR-001**: The system MUST hold the cart.

1. **Given** a cart **When** it opens **Then** items render.
''';
      expect(const SpecParser().parseKeyEntities(md).length, 1);
      expect(const SpecParser().parseLanes(md).length, 1);
      expect(
        const SpecParser().parseLanes(md).first.behaviorIds,
        contains('U1'),
      );
    });
  });

  group('nested ACs — dotted numbering (issue #1196)', () {
    final nestedSpec =
        '''
$pin

# Spec: nested

## Functional Requirements

- **FR-001**: The system MUST validate the form.
  traces: Validator

## Scenarios

### Story A

1.1. **Given** a valid form **When** the user submits **Then** the row saves.
1.2. **Given** a saved row **When** the user reopens **Then** the row renders.

### Story B

2.1. **Given** an invalid field **When** the user submits **Then** an error renders.
''';

    test('every dotted scenario becomes a behavior (none dropped)', () {
      final behaviors = const SpecParser().parse('nested', nestedSpec);
      expect(behaviors.map((b) => b.id), ['A1', 'A2', 'A3', 'U1']);
      expect(
        behaviors.first.description,
        'the row saves.',
        reason: 'the Then text of the first nested scenario',
      );
    });

    test('the requirement scanner counts the same scenarios (aligned ids)', () {
      final scan = const RequirementScanner().scan(nestedSpec);
      final acStatements = scan.statements
          .where((s) => s.id.startsWith('AC'))
          .toList();
      expect(acStatements.length, 3, reason: 'AC-1..AC-3 in document order');
      // Lines 14, 15, 19: the dotted scenario headers (pin 1, blank 2,
      // title 3, blank 4, FR heading 5, blank 6, FR-001 7, traces 8,
      // blank 9, Scenarios 10, blank 11, Story A 12, blank 13, then
      // the headers; Story B pushes 2.1 to 19).
      expect(acStatements.map((s) => s.lineNo), [14, 15, 19]);
    });

    test('a Type marker inside a dotted scenario declares its lane', () {
      final markers = SpecParser.parseScenarioTypeMarkers(
        nestedSpec.replaceFirst(
          '1.1. **Given** a valid form **When** the user submits '
              '**Then** the row saves.',
          '1.1. **Given** a valid form **When** the user submits '
              '**Then** the row saves.\n   **Type**: widget',
        ),
      );
      expect(markers['A1']?.declaredType?.name, 'widget');
    });
  });

  group('inline prose — unbolded markers (issue #1196)', () {
    final proseSpec =
        '''
$pin

# Spec: prose

## Functional Requirements

- **FR-001**: The system MUST compute the total.
  traces: Total

## Scenarios

1. Given a filled cart, When the user opens the list, Then the total renders.
2. Given an empty cart, When the user opens the list, Then the zero total renders.
''';

    test('unbolded scenarios become behaviors (none dropped)', () {
      final behaviors = const SpecParser().parse('prose', proseSpec);
      expect(behaviors.map((b) => b.id), ['A1', 'A2', 'U1']);
      expect(behaviors[0].description, 'the total renders.');
    });

    test('the scanner aligns with the parser on unbolded scenarios', () {
      final scan = const RequirementScanner().scan(proseSpec);
      expect(scan.statements.where((s) => !s.isFunctional).length, 2);
    });

    test('mixed bold and plain scenarios keep document-wide AC order', () {
      final mixed =
          '''
$pin

1. **Given** a **When** b **Then** bold-first.
2. Given c When d Then plain-second.
3. **Given** e **When** f **Then** bold-third.
''';
      final behaviors = const SpecParser().parse('mixed', mixed);
      expect(behaviors.map((b) => b.id), ['A1', 'A2', 'A3']);
      expect(behaviors[1].description, 'plain-second.');
    });
  });

  group('FR tables with variants (issue #1196)', () {
    final tableSpec =
        '''
$pin

# Spec: table

## Layer Contracts

**Domain**:
- `RowRepo`: `list(QueryParams) -> List<Row>`

## Functional Requirements

| ID | Requirement | Variants |
| -- | -- | -- |
| FR-001 | The system MUST list rows. | — |
  traces: RowRepo
|  | variant: offline — the cached list renders. | v1 |
|  | variant: empty — the placeholder renders. | v2 |
| FR-002 | The system MUST refresh on pull. | — |
  traces: RowRepo

## Acceptance Scenarios

1. **Given** cached rows **When** the list opens **Then** the cached list renders.
   **Type**: widget
''';

    test('table FR rows become unit behaviors, in document order', () {
      final behaviors = const SpecParser().parse('table', tableSpec);
      expect(behaviors.map((b) => b.id), ['A1', 'U1', 'U2']);
      expect(behaviors[1].sourceCriterion, 'FR-001');
      expect(behaviors[1].description, 'The system MUST list rows.');
      expect(behaviors[2].sourceCriterion, 'FR-002');
    });

    test('variant continuation rows are detail, never behaviors', () {
      final behaviors = const SpecParser().parse('table', tableSpec);
      expect(behaviors.where((b) => b.id.startsWith('U')).length, 2);
      expect(
        behaviors.map((b) => b.description),
        everyElement(isNot(contains('variant:'))),
      );
    });

    test('the scanner and the parser agree on table FR ids (no gate gap)', () {
      final scan = const RequirementScanner().scan(tableSpec);
      final frStatements = scan.statements
          .where((s) => s.isFunctional)
          .map((s) => s.id)
          .toList();
      expect(frStatements, ['FR-001', 'FR-002']);
      final behaviors = const SpecParser().parse('table', tableSpec);
      expect(
        behaviors
            .where((b) => b.id.startsWith('U'))
            .map((b) => b.sourceCriterion),
        frStatements,
        reason: 'every scanned FR must map to a unit behavior',
      );
    });

    test('a table FR with a traces: continuation resolves its traces', () {
      final withTraces = tableSpec.replaceFirst(
        '| FR-002 | The system MUST refresh on pull. | — |',
        '| FR-002 | The system MUST refresh on pull. | — |\n'
            '  traces: `RowRepo.list`',
      );
      final traces = SpecParser.parseFrContractTraces(withTraces);
      expect(traces['U2'], contains('RowRepo.list'));
    });
  });

  group('honest refusals name the line (issue #1196)', () {
    test('the empty spec refuses naming spec line 1', () {
      expect(
        () => const SpecParser().parse('empty', ''),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('spec line 1'))
              .having((e) => e.message, 'message', contains('--> fix:')),
        ),
      );
    });

    test('the FR-only spec refuses naming its first content line', () {
      const frOnly =
          '''
$pin

# Spec: fr-only

## Functional Requirements

- **FR-001**: The system MUST do the thing.
''';
      expect(
        () => const SpecParser().parse('fr-only', frOnly),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('spec line 1'),
          ),
        ),
      );
    });
  });

  group('lenient contracts stay lenient (surviving, not requiring)', () {
    test('a spec without a Lanes section plans with zero lanes', () {
      final md =
          '''
$pin

- **FR-001**: The system MUST work.

1. **Given** a **When** b **Then** c.
''';
      expect(const SpecParser().parseLanes(md), isEmpty);
    });

    test('non-English headers with English keywords still route', () {
      final md =
          '''
$pin

## Requisitos Funcionales

- **FR-001**: El sistema DEBE guardar.
  traces: Guardado

## Escenarios

1. **Given** un usuario **When** abre **Then** la lista guarda.
   **Type**: acceptance
''';
      final behaviors = const SpecParser().parse('es', md);
      expect(behaviors.map((b) => b.id), ['A1', 'U1']);
      expect(behaviors.first.kind.name, 'acceptance');
    });
  });
}
