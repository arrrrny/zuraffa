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

  group('SpecParser — bug 829: Key Entities extraction', () {
    const parser = SpecParser();

    test('extracts entity names and backticked field pairs from the '
        'corpus-style section', () {
      const spec = '''
# Feature Spec

## Requirements

- **FR-001**: The system shall persist a User with a name and an email.

### Key Entities

- **User**: The domain entity for stored users. Contains `name: String`, `email: String`.
- **Role**: The role assigned to a user.
''';
      final entities = parser.parseKeyEntities(spec);
      expect(entities.length, 2);
      expect(entities[0].name, 'User');
      expect(entities[0].fields.map((f) => '${f.name}:${f.type}').toList(), [
        'name:String',
        'email:String',
      ]);
      expect(entities[1].name, 'Role');
      expect(entities[1].fields, isEmpty);
    });

    test('strips a generic suffix from the entity name', () {
      const spec = '''
### Key Entities

- **ToggleParams<I, F>**: Parameter class for toggle operations. Contains `id: I`, `value: bool`.
''';
      final entities = parser.parseKeyEntities(spec);
      expect(entities.single.name, 'ToggleParams');
      expect(entities.single.fields.map((f) => f.name).toList(), [
        'id',
        'value',
      ]);
    });

    test('returns empty when the spec declares no Key Entities', () {
      const spec = '''
# Feature Spec

- **FR-001**: System MUST do X
''';
      expect(parser.parseKeyEntities(spec), isEmpty);
    });

    test('stops the section at the next heading', () {
      const spec = '''
### Key Entities

- **User**: The user entity. Contains `name: String`.

## Success Criteria

- **SC-1**: works
''';
      final entities = parser.parseKeyEntities(spec);
      expect(entities.single.name, 'User');
    });

    test('skips bullets whose name is not a valid Dart identifier', () {
      const spec = '''
### Key Entities

- **User & Role**: not a single identifier.
- **User**: the valid one.
''';
      final entities = parser.parseKeyEntities(spec);
      expect(entities.single.name, 'User');
    });
  });
}
