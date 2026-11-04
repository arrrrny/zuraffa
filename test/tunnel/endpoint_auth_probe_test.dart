import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/tunnel/endpoint_auth_probe.dart';

void main() {
  // Nullable: tearDown runs after EVERY test in the file — including ones
  // that never called serve() — and a `late` field would throw a
  // LateInitializationError there (which is not a StateError, so the catch
  // does not cover it). Reset per test so no closed server leaks forward.
  HttpServer? server;
  late EndpointAuthProbe probe;

  setUp(() async {
    probe = const EndpointAuthProbe();
  });

  tearDown(() async {
    try {
      await server?.close(force: true);
    } on StateError {
      // already closed
    }
    server = null;
  });

  /// Binds a one-response server answering [status] to every request.
  Future<Uri> serve(int status) async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server = s;
    s.listen((request) async {
      request.response.statusCode = status;
      await request.response.close();
    });
    return Uri.parse('http://127.0.0.1:${s.port}/');
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

    test(
      'an endpoint that accepts but never answers is unresponsive',
      () async {
        // A POST-only MCP endpoint (or a very slow app) accepts the TCP
        // connection and never answers the GET — the honest diagnosis is
        // "something is listening", NOT "nothing is listening".
        final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final sub = silent.listen((socket) {
          socket.listen(null); // accepted; never answer, never close
        });
        try {
          final result = await probe.probe(
            Uri.parse('http://127.0.0.1:${silent.port}/'),
            timeout: const Duration(milliseconds: 400),
          );
          expect(result, EndpointProbeResult.unresponsive);
        } finally {
          await sub.cancel();
          await silent.close();
        }
      },
    );

    test('a long-lived response body cannot hold the classification', () async {
      // Headers arrive (401), the body never ends — an SSE-shaped endpoint.
      // The status is captured before the (bounded, non-fatal) drain, so
      // the probe still classifies and returns instead of hanging.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server!.listen((request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.add([0]);
        await request.response.flush(); // headers out, stream held open
        // never closed — tearDown force-closes it.
      });
      final result = await probe
          .probe(
            Uri.parse('http://127.0.0.1:${server!.port}/'),
            timeout: const Duration(milliseconds: 400),
          )
          .timeout(const Duration(seconds: 5));
      expect(result, EndpointProbeResult.authenticated);
    });
  });
}
