import 'package:test/test.dart';
import 'package:zuraffa/src/agent/shell/shell_protocol.dart';

void main() {
  group('ShellProtocol — NDJSON envelopes (#808)', () {
    test('encodes one JSON object per line', () {
      final line = ShellProtocol.encodeLine({
        'type': 'budget.tick',
        'missionId': 'm-1',
        'remainingCalls': 7,
      });
      expect(line, endsWith('\n'));
      expect(
        line.contains('\n') && line.trim().contains('\n'),
        isFalse,
        reason: 'a single envelope must be a single line',
      );
    });

    test('decodes a line back into the same message', () {
      final line = ShellProtocol.encodeLine({
        'type': 'lease.granted',
        'agentId': 'a',
        'scope': 'lib/src/features/cart/',
      });
      final msg = ShellProtocol.decodeLine(line);
      expect(msg['type'], 'lease.granted');
      expect(msg['agentId'], 'a');
    });

    test('encode/decode round-trip is stable', () {
      final msg = <String, Object?>{
        'type': 'mission.resumed',
        'agentId': 'b',
        'document': <String, Object?>{'missionId': 'm-9', 'cursor': 1},
      };
      final decoded = ShellProtocol.decodeLine(ShellProtocol.encodeLine(msg));
      expect(decoded['type'], msg['type']);
      expect((decoded['document'] as Map)['missionId'], 'm-9');
    });

    test('decodeLine throws FormatException on garbage', () {
      expect(
        () => ShellProtocol.decodeLine('not json at all'),
        throwsA(isA<FormatException>()),
      );
    });

    test('encode builds an envelope with type + payload', () {
      final msg = ShellProtocol.encode({
        'type': 'error',
        'message': 'bad request',
      });
      expect(msg['type'], 'error');
      expect(msg['message'], 'bad request');
    });
  });
}
