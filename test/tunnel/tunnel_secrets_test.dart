import 'package:test/test.dart';
import 'package:zuraffa/src/tunnel/tunnel_secrets.dart';

void main() {
  group('TunnelSecrets', () {
    test('redacts a token wherever it appears', () {
      final line = 'INF tunnel run --token eyJsupersecret started';
      final redacted = TunnelSecrets.redact(line, ['eyJsupersecret']);
      expect(redacted, isNot(contains('eyJsupersecret')));
      expect(redacted, contains('[redacted]'));
    });

    test('redacts a credentials-file path', () {
      final line = 'INF using credentials-file /home/op/.cloudflared/dws.json';
      final redacted = TunnelSecrets.redact(line, [
        '/home/op/.cloudflared/dws.json',
      ]);
      expect(redacted, isNot(contains('/home/op/.cloudflared')));
    });

    test('redacts every supplied secret', () {
      final redacted = TunnelSecrets.redact('token=A path=B', ['A', 'B']);
      expect(redacted, isNot(contains('A')));
      expect(redacted, isNot(contains('B')));
    });

    test('empty and whitespace-only secrets are ignored', () {
      final line = 'unchanged text';
      expect(TunnelSecrets.redact(line, ['', '  ']), line);
    });

    test('no secrets means the text is unchanged', () {
      expect(TunnelSecrets.redact('plain', const <String>[]), 'plain');
    });
  });
}
