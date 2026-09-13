// Issue #1388 (PR #1597 review): the spec's DECLARED-ROUTING SURFACE —
// the Layer Contracts section a behavior's `traces:` cell resolves
// against. The gen reuse fingerprint hashes this, never the whole
// `spec.md`, so a documentation-only edit (prose, comments, acceptance
// wording) cannot read as a declared-routing change.
//
// Pins: the walk matches `parseLayerContracts` (a qualified heading and
// an entity-escaped one are the same section; any heading closes it),
// prose outside the section is excluded, CRLF specs normalize like every
// other parser walk, and a spec with no such section yields the empty
// string.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

void main() {
  group('SpecParser.layerContractsSection (issue #1388)', () {
    test('returns the section body and excludes prose before and after it', () {
      final section = const SpecParser().layerContractsSection('''
**Template Version**: `zuraffa-1.0`

# Spec: demo

Prose that declares no routing: the cart survives a restart.

### Layer Contracts

**Domain**:
- `CartRepo`: `save(c) -> void`

## Functional Requirements

- **FR-001**: MUST persist the cart
            traces: CartRepo
''');
      expect(section, contains('- `CartRepo`: `save(c) -> void`'));
      expect(
        section,
        isNot(contains('declares no routing')),
        reason: 'prose above the section is not part of it',
      );
      expect(
        section,
        isNot(contains('FR-001')),
        reason: 'the first heading after the section closes it',
      );
    });

    test('a qualified heading is the same section (issue #1196 walk)', () {
      final section = const SpecParser().layerContractsSection('''
## Layer Contracts — epic-level

**Domain**:
- `CartRepo`: `save(c) -> void`
''');
      expect(section, contains('CartRepo'));
    });

    test('an entity-escaped heading resolves like the parser walk', () {
      final section = const SpecParser().layerContractsSection('''
## Layer Contracts &amp; Surfaces

**Domain**:
- `CartRepo`: `save(c) -> void`
''');
      expect(section, contains('CartRepo'));
    });

    test('no Layer Contracts section → the empty string (fail-open)', () {
      expect(
        const SpecParser().layerContractsSection('''
# Spec: demo

## Functional Requirements

- **FR-001**: MUST persist the cart
'''),
        isEmpty,
      );
    });

    test('CRLF specs normalize like every other parser walk', () {
      final section = const SpecParser().layerContractsSection(
        '### Layer Contracts\r\n\r\n**Domain**:\r\n'
        '- `CartRepo`: `save(c) -> void`\r\n'
        '\r\n## Functional Requirements\r\n',
      );
      expect(section, contains('CartRepo'));
      expect(section, isNot(contains('Functional Requirements')));
    });
  });
}
