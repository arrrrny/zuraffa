import 'package:test/test.dart';
import 'package:zuraffa/src/tunnel/tunnel_config.dart';

void main() {
  group('TunnelConfig', () {
    test('target is the loopback HTTP URL of the declared port', () {
      const config = TunnelConfig(mode: TunnelMode.quick, port: 8080);
      expect(config.target.scheme, 'http');
      expect(config.target.host, 'localhost');
      expect(config.target.port, 8080);
    });

    test('host is honored when the operator declares one', () {
      const config = TunnelConfig(
        mode: TunnelMode.quick,
        port: 8080,
        host: '127.0.0.1',
      );
      expect(config.target.host, '127.0.0.1');
    });

    test('quick mode is valid with no extra fields', () {
      const config = TunnelConfig(mode: TunnelMode.quick, port: 8080);
      expect(config.isValid, isTrue);
      expect(config.validationErrors(), isEmpty);
    });

    test('named mode requires tunnel name, hostname and credentials file', () {
      const config = TunnelConfig(mode: TunnelMode.named, port: 8080);
      final errors = config.validationErrors();
      expect(config.isValid, isFalse);
      expect(errors.join(' '), contains('tunnel-name'));
      expect(errors.join(' '), contains('hostname'));
      expect(errors.join(' '), contains('credentials-file'));
    });

    test('named mode is valid once every requirement is present', () {
      const config = TunnelConfig(
        mode: TunnelMode.named,
        port: 8080,
        tunnelName: 'dws-playground',
        hostname: 'dws.example.com',
        credentialsFile: '/home/op/.cloudflared/dws.json',
      );
      expect(config.isValid, isTrue);
    });

    test('token mode requires a token', () {
      const config = TunnelConfig(mode: TunnelMode.token, port: 8080);
      expect(config.isValid, isFalse);
      expect(config.validationErrors().join(' '), contains('token'));

      const withToken = TunnelConfig(
        mode: TunnelMode.token,
        port: 8080,
        token: 'eyJabc',
      );
      expect(withToken.isValid, isTrue);
    });

    test('port 0 and port 70000 are refused', () {
      const zero = TunnelConfig(mode: TunnelMode.quick, port: 0);
      const high = TunnelConfig(mode: TunnelMode.quick, port: 70000);
      expect(zero.isValid, isFalse);
      expect(high.isValid, isFalse);
      expect(zero.validationErrors().join(' '), contains('port'));
    });

    test('a non-loopback host is refused (FR-009)', () {
      // Wildcards, LAN addresses and hostnames must never pass: the tunnel
      // scope is always exactly one loopback port.
      for (final host in [
        '0.0.0.0',
        '10.0.0.5',
        '192.168.1.10',
        'intranet.corp',
        '::2',
        '127.999.1.1',
      ]) {
        final config = TunnelConfig(
          mode: TunnelMode.quick,
          port: 8080,
          host: host,
        );
        expect(config.isValid, isFalse, reason: host);
        expect(
          config.validationErrors().join(' '),
          contains('loopback'),
          reason: host,
        );
      }
    });

    test('every loopback spelling of --host is accepted', () {
      for (final host in [
        'localhost',
        'LOCALHOST',
        '127.0.0.1',
        '127.8.8.8',
        '::1',
        '[::1]',
      ]) {
        final config = TunnelConfig(
          mode: TunnelMode.quick,
          port: 8080,
          host: host,
        );
        expect(config.isValid, isTrue, reason: host);
      }
    });

    test('allowUnauthenticated override is carried on the config', () {
      const config = TunnelConfig(
        mode: TunnelMode.quick,
        port: 8080,
        allowUnauthenticated: true,
      );
      expect(config.allowUnauthenticated, isTrue);
    });
  });
}
