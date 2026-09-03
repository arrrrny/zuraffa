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
}
