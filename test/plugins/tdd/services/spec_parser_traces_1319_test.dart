// Issue #1319 — parseFrContractTraces only reads the single line after
// the FR header, so a multi-line FR (the common case: the zuraffa-1.0
// template wraps FR text at ~80 cols) silently drops its visually-
// attached `traces:` line, re-triggering the #1308 vacuous-green
// dead-end. The trace scanner must consume the entire FR block — the
// same block scope the FR walks share — and plan must warn loudly when
// a `traces:` line exists but binds nothing.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

void main() {
  group('block-continuation trace scan (issue #1319)', () {
    test('a traces: line after a wrapped continuation line binds (the '
        '#1319 repro)', () {
      const spec = '''
- **FR-001**: System MUST expose POST /conversation/stream that returns
  Content-Type: text/event-stream with structured JSON events.
          traces: RouteContentType
''';
      expect(SpecParser.parseFrContractTraces(spec)['U1'], [
        'RouteContentType',
      ]);
    });

    test('a traces: line after the next FR header binds to the SECOND '
        'FR only — blocks never leak across an FR header', () {
      const spec = '''
- **FR-001**: The system MUST validate the email before submitting.
  The validation runs on every submit attempt.
- **FR-002**: The system MUST persist the session.
          traces: SessionStore
''';
      final traces = SpecParser.parseFrContractTraces(spec);
      expect(
        traces.containsKey('U1'),
        isFalse,
        reason: 'FR-001 has no traces: line in ITS block',
      );
      expect(traces['U2'], ['SessionStore']);
    });

    test('a traces: line after a markdown heading binds to nothing', () {
      const spec = '''
- **FR-001**: The system MUST validate the email before submitting.

## Layer Contracts

- `RouteContentType`: `contentType() -> String`
          traces: RouteContentType
''';
      expect(
        SpecParser.parseFrContractTraces(spec),
        isEmpty,
        reason: 'the heading ends FR-001\'s block',
      );
    });

    test('a traces: line after an acceptance scenario header binds to '
        'nothing', () {
      const spec = '''
- **FR-001**: The system MUST validate the email before submitting.

1. **Given** a valid email **When** the user submits **Then** it passes.
          traces: RouteContentType
''';
      expect(SpecParser.parseFrContractTraces(spec), isEmpty);
    });

    test('a traces: line inside a fenced code example neither binds nor '
        'counts as unbound (documentation, not declarations)', () {
      const spec = '''
- **FR-001**: The system MUST validate the email.

  ```yaml
  example:
    traces: NotARealRow
  ```

  The validation runs on every submit attempt.
- **FR-002**: The system MUST persist the session.
          traces: SessionStore
''';
      final bound = SpecParser.parseFrContractTraces(spec);
      expect(
        bound.containsKey('U1'),
        isFalse,
        reason: 'the fenced example is documentation, not a declaration',
      );
      expect(bound['U2'], ['SessionStore']);
      expect(SpecParser.findUnboundFrTraces(spec, bound), isEmpty);
    });

    test('the FR-table form binds traces: after a variant continuation '
        'row (empty id cell)', () {
      const spec = '''
| FR-001 | The system MUST list rows. | — |
|        | variant: sorted by date. | — |
  traces: RowRepo.list
''';
      expect(SpecParser.parseFrContractTraces(spec)['U1'], ['RowRepo.list']);
    });

    test('multiple FRs each bind the first traces: line of their own '
        'block, in document order', () {
      const spec = '''
- **FR-001**: The system MUST expose POST /conversation/stream that
  returns text/event-stream.
          traces: RouteContentType, SessionStore
- **FR-002**: The system MUST flush the queue.
          traces: QueueFl
''';
      final traces = SpecParser.parseFrContractTraces(spec);
      expect(traces['U1'], ['RouteContentType', 'SessionStore']);
      expect(traces['U2'], ['QueueFl']);
    });
  });

  group('backward compatibility (issue #1319 acceptance 4)', () {
    test('a single-line FR with traces: on the immediately following '
        'line binds exactly as before', () {
      const spec = '''
- **FR-004**: The checkout totals the cart and returns the payable amount.
            traces: ProductRepository, `format(Template) -> String`
''';
      expect(SpecParser.parseFrContractTraces(spec)['U1'], [
        'ProductRepository',
      ], reason: 'the backticked signature is still not a row reference');
    });

    test('the first traces: line of a block wins over a later one', () {
      const spec = '''
- **FR-001**: The system MUST expose the stream endpoint.
          traces: RouteContentType
          traces: SessionStore
''';
      expect(SpecParser.parseFrContractTraces(spec)['U1'], [
        'RouteContentType',
      ]);
    });

    test('an FR block with no traces: line produces no binding', () {
      const spec = '''
- **FR-001**: The system MUST validate the email before submitting.
  The validation runs on every submit attempt.
- **FR-002**: The system MUST persist the session.
''';
      expect(SpecParser.parseFrContractTraces(spec), isEmpty);
    });
  });

  group('unbound traces detection (issue #1319 acceptance 2)', () {
    test('an FR whose traces: line yields no tokens is reported by FR id', () {
      const spec = '''
- **FR-001**: The system MUST format the template.
      traces: `format(Template) -> String`
''';
      final bound = SpecParser.parseFrContractTraces(spec);
      expect(
        bound['U1'],
        isEmpty,
        reason: 'the lone backticked signature is dropped by traceTokens',
      );
      expect(SpecParser.findUnboundFrTraces(spec, bound), ['FR-001']);
    });

    test('an FR whose traces: line bound a row is NOT reported', () {
      const spec = '''
- **FR-001**: The system MUST expose the stream endpoint.
          traces: RouteContentType
''';
      final bound = SpecParser.parseFrContractTraces(spec);
      expect(SpecParser.findUnboundFrTraces(spec, bound), isEmpty);
    });

    test('an ownerless traces: line (after a heading, before any FR) is '
        'not reported', () {
      const spec = '''
## Layer Contracts

- `RouteContentType`: `contentType() -> String`
          traces: RouteContentType

- **FR-001**: The system MUST expose the stream endpoint.
''';
      final bound = SpecParser.parseFrContractTraces(spec);
      expect(SpecParser.findUnboundFrTraces(spec, bound), isEmpty);
    });

    test('a traces: line separated from its FR by a heading is not '
        'attributed to that FR', () {
      const spec = '''
- **FR-001**: The system MUST expose the stream endpoint.

## Notes

          traces: RouteContentType
''';
      final bound = SpecParser.parseFrContractTraces(spec);
      expect(
        SpecParser.findUnboundFrTraces(spec, bound),
        isEmpty,
        reason: 'the heading breaks the visual attachment',
      );
    });
  });
}
