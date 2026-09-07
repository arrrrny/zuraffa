// Issue #1112 — the REAL vm_service driver proof: a live Dart VM
// service (spawned child), a library exposing the debugTapAnchorJson
// seam, and VmTapDriver evaluating through it. This is the same
// evaluate path the macOS success criterion exercises — proved on
// Linux, where the sandbox can run Dart but never cliclick.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/skin/driver/vm_tap_driver.dart';
import 'package:zuraffa/src/skin/tap_result.dart';

String _fixturePath() =>
    p.join(p.current, 'test', 'fixtures', 'vm_tap_driver', 'seam_app.dart');

/// Polls [buffer] until [pattern] matches (the VM prints its service
/// URI asynchronously); returns the first capture group or throws.
Future<String> _waitForMatch(StringBuffer buffer, RegExp pattern) async {
  for (var i = 0; i < 120; i++) {
    final m = pattern.firstMatch(buffer.toString());
    if (m != null) return m.group(1)!;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('pattern never matched: $pattern');
}

Future<bool> _waitForNeedle(StringBuffer buffer, String needle) async {
  for (var i = 0; i < 40; i++) {
    if (buffer.toString().contains(needle)) return true;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return buffer.toString().contains(needle);
}

void main() {
  group('issue #1112 — VmTapDriver (real vm_service evaluate)', () {
    late Process process;
    late String httpUri;
    final stdoutBuffer = StringBuffer();

    setUpAll(() async {
      process = await Process.start('dart', [
        '--enable-vm-service=0',
        _fixturePath(),
      ]);
      process.stdout.transform(utf8.decoder).listen(stdoutBuffer.write);
      process.stderr.transform(utf8.decoder).listen(stdoutBuffer.write);

      // The VM announces its service on the child's stdout:
      // "Dart VM Service listening on http://127.0.0.1:<port>/<token>/"
      httpUri = await _waitForMatch(
        stdoutBuffer,
        RegExp(r'listening on (http://\S+)'),
      );
      // The fixture prints SEAM_READY after the handlers are
      // registered — driving before that races the isolate boot.
      await _waitForNeedle(stdoutBuffer, 'SEAM_READY');
    });

    tearDownAll(() {
      process.kill();
    });

    test('connects over the plain http URI (scheme → ws handled)', () async {
      final result = await VmTapDriver.drive(
        dartUri: httpUri,
        anchor: 'zfa:signin-guest',
      );
      expect(result, const TapFound());
      expect(result.toJsonString(), '{"result":"found","tapped":true}');
    });

    test('the REAL handler ran (the genuine engine-flow proof)', () async {
      // The seam app's handler prints to its stdout when invoked — the
      // driver must have invoked the real callback, not a stub.
      final sawTap = await _waitForNeedle(stdoutBuffer, 'TAPPED:signin-guest');
      expect(sawTap, isTrue, reason: 'the real onPressed never ran');
    });

    test('an unknown anchor is notFound through the live VM', () async {
      final result = await VmTapDriver.drive(
        dartUri: httpUri,
        anchor: 'zfa:never-declared',
      );
      expect(result, const TapNotFound());
    });

    test('a disabled anchor is disabled through the live VM', () async {
      final result = await VmTapDriver.drive(
        dartUri: httpUri,
        anchor: 'log-out',
      );
      expect(result, const TapDisabled());
    });

    test('a dead VM service is an honest error (never a crash)', () async {
      final result = await VmTapDriver.drive(
        dartUri: 'http://127.0.0.1:1',
        anchor: 'zfa:signin-guest',
      );
      expect(result, isA<TapError>());
      expect((result as TapError).message, isNotEmpty);
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
