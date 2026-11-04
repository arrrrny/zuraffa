import 'package:test/test.dart';
import 'package:zuraffa/src/tunnel/tunnel_url_parser.dart';

void main() {
  const parser = TunnelUrlParser();

  group('TunnelUrlParser', () {
    test('parses the trycloudflare URL from a decorated output line', () {
      final url = parser.parse(
        '|  https://funny-words-here.trycloudflare.com                       |',
      );
      expect(url, isNotNull);
      expect(url.toString(), 'https://funny-words-here.trycloudflare.com');
    });

    test('parses a URL embedded in a log line with surrounding text', () {
      final url = parser.parse(
        '2026-11-04T10:00:00Z INF +--------------------------------------------------------------------------------------------+',
      );
      expect(url, isNull);
      final line =
          '2026-11-04T10:00:00Z INF |  https://red-terms-act.trycloudflare.com  |';
      expect(
        parser.parse(line).toString(),
        'https://red-terms-act.trycloudflare.com',
      );
    });

    test('rejects non-trycloudflare hosts', () {
      expect(parser.parse('visit https://example.com for details'), isNull);
      expect(
        parser.parse('https://team.cloudflareaccess.com is not a tunnel url'),
        isNull,
      );
    });

    test('rejects http (non-tls) scheme', () {
      expect(parser.parse('http://quick-words.trycloudflare.com'), isNull);
    });

    test('the quick-tunnel API endpoint is never mistaken for a tunnel', () {
      // A FAILED quick-tunnel request logs the control endpoint's URL —
      // reporting that as the tunnel address would surface a tunnel that
      // does not exist.
      expect(
        parser.parse(
          'failed to request quick Tunnel: https://api.trycloudflare.com/tunnel',
        ),
        isNull,
      );
    });

    test('returns null on empty and garbage lines', () {
      expect(parser.parse(''), isNull);
      expect(parser.parse('INF Registered tunnel connection'), isNull);
    });

    test('first URL wins when a line carries two', () {
      final url = parser.parse(
        'https://a-first.trycloudflare.com then https://b-second.trycloudflare.com',
      );
      expect(url.toString(), 'https://a-first.trycloudflare.com');
    });

    test('parses multi-segment quick-tunnel subdomains', () {
      final url = parser.parse('https://slugs-of-doom-9000.trycloudflare.com');
      expect(url.toString(), 'https://slugs-of-doom-9000.trycloudflare.com');
    });
  });
}
