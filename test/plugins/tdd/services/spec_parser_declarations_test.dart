// U2 (feature 071): scenario `**Type**` marker parsing — the rung-1
// lane declaration. Pins: markers parse into declarations keyed by the
// document-wide A-id with 1-based spec lines; duplicate markers and
// unknown kinds refuse naming the line; marker-less specs yield an
// empty map; manual scenarios consume an AC number but declare nothing
// (no row, no declaration). Issue #951;
// contracts/template-declarations.md §1.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

const _spec = '''
## User Scenarios

### User Story 1

1. **Given** the cart holds items, **When** checkout completes, **Then** the widget renders "Order placed".
   **Type**: widget
2. **Given** the totals FR, **When** computed, **Then** the total equals the sum.
3. **Given** the app is offline, **When** synced, **Then** the queue persists.
   **Type**: unit
''';

void main() {
  test('markers parse into declarations keyed by A-id with spec lines', () {
    final markers = SpecParser.parseScenarioTypeMarkers(_spec);
    expect(markers, hasLength(2));
    expect(markers['A1']?.declaredType, BehaviorKind.widget);
    expect(markers['A1']?.specLine, 6, reason: '1-based document line');
    expect(markers['A3']?.declaredType, BehaviorKind.unit);
    expect(markers['A3']?.specLine, 9);
  });

  test('scenarios without markers produce no declaration', () {
    final markers = SpecParser.parseScenarioTypeMarkers(_spec);
    expect(markers.containsKey('A2'), isFalse);
  });

  test('a spec without markers yields an empty map', () {
    expect(SpecParser.parseScenarioTypeMarkers('no scenarios here'), isEmpty);
  });

  test('a duplicate marker in one scenario is refused, naming the line', () {
    const dup = '''
1. **Given** x, **When** y, **Then** z.
   **Type**: widget
   **Type**: unit
''';
    expect(
      () => SpecParser.parseScenarioTypeMarkers(dup),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('duplicate'), contains('3')),
        ),
      ),
    );
  });

  test('an unknown kind is refused, naming the line and valid kinds', () {
    const bad = '''
1. **Given** x, **When** y, **Then** z.
   **Type**: shimmer
''';
    expect(
      () => SpecParser.parseScenarioTypeMarkers(bad),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('shimmer'), contains('line 2'), contains('widget')),
        ),
      ),
    );
  });

  test('a manual scenario consumes the AC number but declares nothing', () {
    const manual = '''
1. **Given** x, **When** y, **Then** z. (manual: verify on device)
2. **Given** a, **When** b, **Then** c.
   **Type**: widget
''';
    final markers = SpecParser.parseScenarioTypeMarkers(manual);
    expect(markers, hasLength(1));
    expect(markers.containsKey('A1'), isFalse);
    expect(markers['A2']?.declaredType, BehaviorKind.widget);
  });

  test('a marker inside a fenced code block declares nothing and spec '
      'lines stay accurate (round-2 fix 5)', () {
    const fenced = '''
## Examples

```markdown
1. **Given** x, **When** y, **Then** z.
   **Type**: widget
```

1. **Given** a, **When** b, **Then** c.
   **Type**: unit
''';
    final markers = SpecParser.parseScenarioTypeMarkers(fenced);
    expect(markers, hasLength(1), reason: 'the fenced example is docs');
    expect(markers['A1']?.declaredType, BehaviorKind.unit);
    expect(
      markers['A1']?.specLine,
      9,
      reason: 'blanking the fence preserves line numbering',
    );
  });

  test('a marker after a non-scenario heading belongs to no scenario '
      '(round-2 fix 5: heading resets the block)', () {
    const headingReset = '''
1. **Given** x, **When** y, **Then** z.

## Functional Requirements

   **Type**: widget
''';
    expect(
      () => SpecParser.parseScenarioTypeMarkers(headingReset),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('outside any'),
        ),
      ),
    );
  });

  group('FR contract traces (round-2 fix 2)', () {
    test('traceTokens keeps a backticked inline signature intact', () {
      final tokens = SpecParser.traceTokens(
        'ProductRepository, `format(Template) -> String`',
      );
      expect(
        tokens,
        contains('ProductRepository'),
        reason: 'the row reference survives',
      );
      expect(
        tokens.where((t) => t.contains(',')),
        isEmpty,
        reason: 'the signature span is never comma-split',
      );
    });

    test('a backticked inline signature is dropped: it neither resolves '
        'nor dangles', () {
      final tokens = SpecParser.traceTokens(
        'ProductRepository, `format(Template) -> String`',
      );
      expect(tokens, [
        'ProductRepository',
      ], reason: 'a `(`-carrying span is not a row reference');
    });

    test('parseFrContractTraces on the contract-doc example yields only '
        'the row name', () {
      const spec = '''
- **FR-004**: The checkout totals the cart and returns the payable amount.
            traces: ProductRepository, `format(Template) -> String`
''';
      expect(SpecParser.parseFrContractTraces(spec)['U1'], [
        'ProductRepository',
      ]);
    });
  });

  group('persistence declarations (round-2 fix 6)', () {
    test('a bold-wrapped `**[persistent]**` tag marks persistence AND '
        'keeps the description clean', () {
      const spec = '''
- **FR-001**: **[persistent]** The cart survives an app restart.
- **FR-002**: The totals equal the sum of the items.
''';
      final persistence = SpecParser.parsePersistenceDeclarations(spec);
      expect(persistence.containsKey('U1'), isTrue);
      expect(persistence['U1']?.fromTag, isTrue);
      expect(persistence.containsKey('U2'), isFalse);

      final behaviors = const SpecParser().parse('071-bold-tag', '''
**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** a cart **When** restarted **Then** the cart survives.

## Functional Requirements

$spec
''');
      final u1 = behaviors.where((b) => b.id == 'U1').single;
      expect(
        u1.description,
        'The cart survives an app restart.',
        reason: 'the tag (and its bold markers) never leak into prose',
      );
      expect(u1.description, isNot(contains('persistent')));
      expect(u1.description, isNot(contains('**')));
    });
  });
}
