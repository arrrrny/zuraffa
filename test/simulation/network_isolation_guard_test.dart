/// Bug #832 — the network-isolation guard.
///
/// Soundness contract: while installed, ANY outbound socket attempt
/// (`Socket.connect`, `SecureSocket.connect`, `HttpClient` traffic)
/// throws `NetworkIsolationViolation` — without ever touching the
/// network itself (the override intercepts before dialing). Pure-Dart
/// test work (file I/O, compute) is untouched, so hosted TDD tests that
/// never open a socket keep passing: zero false positives. Uninstall
/// restores the real socket path.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/network_isolation_guard.dart';

void main() {
  tearDown(() {
    NetworkIsolationGuard.uninstall();
  });

  test(
    'install() makes outbound Socket.connect fail without dialing',
    () async {
      NetworkIsolationGuard.install();
      expect(NetworkIsolationGuard.isActive, isTrue);
      await expectLater(
        Socket.connect('simulation-blocked.invalid', 80),
        throwsA(isA<NetworkIsolationViolation>()),
      );
    },
  );

  test(
    'loopback connects are blocked too (any real socket is a violation)',
    () async {
      NetworkIsolationGuard.install();
      await expectLater(
        Socket.connect(InternetAddress.loopbackIPv4.address, 59999),
        throwsA(isA<NetworkIsolationViolation>()),
      );
    },
  );

  test('HttpClient traffic fails under the guard', () async {
    NetworkIsolationGuard.install();
    final client = HttpClient();
    // The guard's connectionFactory rejects before the request is even
    // opened — no bytes ever leave the process.
    await expectLater(
      client.getUrl(Uri.parse('http://simulation-blocked.invalid/certified')),
      throwsA(isA<NetworkIsolationViolation>()),
    );
  });

  test('no false positives: file I/O and pure compute keep working', () async {
    NetworkIsolationGuard.install();
    final dir = await Directory.systemTemp.createTemp('zfa-guard-check');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/probe.json');
    await file.writeAsString(jsonEncode({'certified': true}));
    expect(jsonDecode(await file.readAsString()), {'certified': true});
    // Pure compute runs fine while the guard is active.
    expect(List<int>.generate(100, (i) => i * 2).length, 100);
  });

  test(
    'install() is idempotent and uninstall() restores the socket path',
    () async {
      NetworkIsolationGuard.install();
      NetworkIsolationGuard.install(); // second install is a no-op
      expect(NetworkIsolationGuard.isActive, isTrue);

      NetworkIsolationGuard.uninstall();
      expect(NetworkIsolationGuard.isActive, isFalse);

      // The real socket path is restored: a loopback connect now surfaces a
      // genuine SocketException (connection refused), NOT a guard violation.
      await expectLater(
        Socket.connect(InternetAddress.loopbackIPv4.address, 1),
        throwsA(isA<SocketException>()),
      );
    },
  );

  test('uninstall() without install() is a safe no-op', () {
    expect(NetworkIsolationGuard.isActive, isFalse);
    NetworkIsolationGuard.uninstall();
    expect(NetworkIsolationGuard.isActive, isFalse);
  });
}
