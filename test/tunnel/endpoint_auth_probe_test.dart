import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/tunnel/endpoint_auth_probe.dart';

void main() {
  late HttpServer server;
  late EndpointAuthProbe probe;

  setUp(() async {
    probe = const EndpointAuthProbe();
  });

  tearDown(() async {
    try {
      await server.close(force: true);
    } on StateError {
      // already closed
    }
  });

  /// Binds a one-response server answering [status] to every request.
  Future<Uri> serve(int status) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = status;
      await request.response.close();
    });
    return Uri.parse('http://127.0.0.1:${server.port}/');
  }

  group('EndpointAuthProbe', () {
    test('a 200 answer is NOT an authentication challenge', () async {
      final target = await serve(HttpStatus.ok);
      final result = await probe.probe(target);
      expect(result, EndpointProbeResult.unauthenticated);
    });

    test('a 401 answer IS an authentication challenge', () async {
      final target = await serve(HttpStatus.unauthorized);
      final result = await probe.probe(target);
      expect(result, EndpointProbeResult.authenticated);
    });

    test('a 403 answer IS an authentication challenge', () async {
      final target = await serve(HttpStatus.forbidden);
      final result = await probe.probe(target);
      expect(result, EndpointProbeResult.authenticated);
    });

    test('a dead endpoint is unreachable, not unauthenticated', () async {
      // Bind then release: the port is (near-certainly) free, so a connect
      // there is refused.
      final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = dead.port;
      await dead.close();
      final result = await probe.probe(
        Uri.parse('http://127.0.0.1:$port/'),
        timeout: const Duration(seconds: 2),
      );
      expect(result, EndpointProbeResult.unreachable);
    });
  });
}
