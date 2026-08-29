// Spec 035 — Track 4.4: XrayCapability.triggerMock POSTs to
// `/xray/control-deck` per the spec (FR-003), not the legacy
// `/xray/mock`.
//
// We stand up a tiny in-process HTTP server, point the capability at it,
// invoke `triggerMock`, and assert on the *actually captured* request path
// — so the test fails if the client ever regresses to `/xray/mock`.
//
// Behavior B22.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/mcp/capabilities/xray_capability.dart';

void main() {
  group('XrayCapability.triggerMock URL contract (spec 035 / FR-003)', () {
    test('B22 — POSTs to /xray/control-deck (not /xray/mock)', () async {
      final server = await HttpServer.bind('127.0.0.1', 0);
      String? capturedPath;
      final done = Completer<void>();

      server.listen((req) async {
        capturedPath = req.uri.path;
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'success': true}));
        await req.response.close();
        done.complete();
      });

      try {
        await XrayCapability(
          host: '127.0.0.1',
          port: server.port,
        ).triggerMock(mockName: 'A');
        await done.future.timeout(const Duration(seconds: 5));

        expect(capturedPath, isNotNull);
        expect(
          capturedPath,
          '/xray/control-deck',
          reason:
              'triggerMock MUST POST to /xray/control-deck per '
              'spec FR-003',
        );
        expect(
          capturedPath,
          isNot(contains('/xray/mock')),
          reason: 'legacy /xray/mock path MUST NOT be used',
        );
      } finally {
        await server.close(force: true);
      }
    });
  });
}
