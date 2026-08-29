// Tests for the SpecParser (spec 041-tdd-setup-plugin, U25-U26).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

void main() {
  group('SpecParser', () {
    test('extracts one acceptance behavior per Given/When/Then', () {
      const spec = '''
# Feature Spec

## User Scenarios

### User Story 1 - Foo (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a state, **When** an action, **Then** a result.
2. **Given** another state, **When** another action, **Then** another result.

## Requirements

### Functional Requirements

- **FR-001**: System MUST do X
- **FR-002**: System MUST do Y
- **FR-003**: System MUST do Z
''';
      final behaviors = const SpecParser().parse('041-tdd-setup-plugin', spec);
      final acceptance = behaviors
          .where((b) => b.kind == BehaviorKind.acceptance)
          .toList();
      final unit = behaviors.where((b) => b.kind == BehaviorKind.unit).toList();
      expect(acceptance.length, 2);
      expect(unit.length, 3);
      expect(acceptance[0].id, 'A1');
      expect(acceptance[1].id, 'A2');
      expect(unit[0].id, 'U1');
      expect(unit[1].id, 'U2');
      expect(unit[2].id, 'U3');
      expect(acceptance[0].sourceCriterion, 'AC-1');
      expect(acceptance[1].sourceCriterion, 'AC-2');
      expect(unit[0].sourceCriterion, 'FR-001');
      expect(unit[1].sourceCriterion, 'FR-002');
      expect(unit[2].sourceCriterion, 'FR-003');
    });

    test('exits non-zero on spec with no acceptance scenarios', () {
      const spec = '''
# Feature Spec

## Requirements

### Functional Requirements

- **FR-001**: System MUST do X
''';
      expect(
        () => const SpecParser().parse('041-tdd-setup-plugin', spec),
        throwsA(isA<StateError>()),
      );
    });

    test('handles spec with no FRs (acceptance-only)', () {
      const spec = '''
# Feature Spec

## User Scenarios

### User Story 1 - Foo (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a, **When** b, **Then** c.
''';
      final behaviors = const SpecParser().parse('041-tdd-setup-plugin', spec);
      expect(behaviors.length, 1);
      expect(behaviors.first.kind, BehaviorKind.acceptance);
    });

    test('parses multiline Given/When/Then scenarios', () {
      const spec = '''
## User Scenarios

**Acceptance Scenarios**:

1. **Given** a logged-out user
   **When** they tap sign in
   **Then** they see the home screen.

2. **Given** an empty cart
   **When** they checkout
   **Then** they are prompted to add items.
''';
      final behaviors = const SpecParser().parse('041-tdd-setup-plugin', spec);
      final acceptance = behaviors
          .where((b) => b.kind == BehaviorKind.acceptance)
          .toList();
      expect(acceptance.length, 2);
      expect(acceptance[0].sourceCriterion, 'AC-1');
      expect(acceptance[1].sourceCriterion, 'AC-2');
      expect(acceptance[0].description, 'they see the home screen.');
      expect(acceptance[1].description, 'they are prompted to add items.');
    });

    test('acceptance behaviors are listed before unit behaviors', () {
      const spec = '''
## User Scenarios

### Story 1

**Acceptance Scenarios**:

1. **Given** a, **When** b, **Then** c.

## Requirements

### Functional Requirements

- **FR-001**: System MUST do X
''';
      final behaviors = const SpecParser().parse('041', spec);
      expect(behaviors.first.kind, BehaviorKind.acceptance);
      expect(behaviors.last.kind, BehaviorKind.unit);
    });
  });
}
