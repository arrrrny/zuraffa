// Spec 893 — isolation guard whitelist lanes (T004, extends #832).
//
// FR-005: no real sockets in simulation mode. FR-006: explicitly
// whitelisted lanes (e.g. analytics) are permitted. FR-007: every
// non-whitelisted attempt is blocked with a clear diagnostic. The empty
// whitelist stays the safest default (#832 behavior is unchanged).
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/network_isolation_guard.dart';
import 'package:zuraffa/src/simulation/simulation_whitelist.dart';

void main() {
  setUp(() {
    NetworkIsolationGuard.uninstall();
  });

  tearDown(() {
    NetworkIsolationGuard.uninstall();
  });

  group('U7: SocketLane matching', () {
    test('matches exact hosts', () {
      const lane = SocketLane(host: 'analytics.example.com');
      expect(lane.matches('analytics.example.com', 443), isTrue);
      expect(lane.matches('other.example.com', 443), isFalse);
    });

    test('wildcard subdomains via leading dot', () {
      const lane = SocketLane(host: '.example.com');
      expect(lane.matches('api.example.com', 443), isTrue);
      expect(lane.matches('deep.api.example.com', 443), isTrue);
      expect(
        lane.matches('example.com', 443),
        isTrue,
        reason: 'the apex domain is part of the lane',
      );
      expect(lane.matches('notexample.com', 443), isFalse);
    });

    test('optional port constraint', () {
      const lane = SocketLane(host: 'analytics.example.com', port: 443);
      expect(lane.matches('analytics.example.com', 443), isTrue);
      expect(lane.matches('analytics.example.com', 80), isFalse);
      expect(
        SocketLane(
          host: 'analytics.example.com',
        ).matches('analytics.example.com', 9999),
        isTrue,
        reason: 'no port means any port on the lane host',
      );
    });

    test('parses lanes from string and object config forms', () {
      expect(
        SocketLane.parse('analytics.example.com').host,
        'analytics.example.com',
      );
      final object = SocketLane.parse({
        'host': '.crashlytics.com',
        'port': 443,
      });
      expect(object.host, '.crashlytics.com');
      expect(object.port, 443);
      expect(() => SocketLane.parse(42), throwsArgumentError);
    });
  });

  group('A4: guard permits whitelisted lanes and blocks every other socket', () {
    test(
      'U8: whitelisted connects delegate to the pre-install overrides and are recorded as approved exceptions',
      () async {
        NetworkIsolationGuard.install(
          whitelist: const [SocketLane(host: 'analytics.example.com')],
        );

        // Non-whitelisted attempt: blocked before any dial/DNS with a
        // diagnostic identifying the source.
        await expectLater(
          Socket.connect('api.real-backend.invalid', 443),
          throwsA(isA<NetworkIsolationViolation>()),
        );

        // Whitelisted lane: the host does not resolve (invalid TLD), so
        // the delegated connect fails with a SocketException — proving
        // the attempt REACHED the real socket path instead of being
        // blocked by the guard.
        await expectLater(
          Socket.connect('analytics.example.com', 443),
          throwsA(isA<SocketException>()),
        );
        expect(
          NetworkIsolationGuard.approvedAttempts,
          contains((
            host: 'analytics.example.com',
            port: 443,
            operation: 'Socket.connect',
          )),
        );

        // HttpClient through a whitelisted host is also permitted (the
        // per-request connection factory consults the same lanes).
        final client = HttpClient();
        await expectLater(
          client.getUrl(Uri.parse('https://api.real-backend.invalid/x')),
          throwsA(isA<NetworkIsolationViolation>()),
        );
        client.close(force: true);
      },
    );

    test(
      'U9: default install keeps blocking everything (empty whitelist is the safest default)',
      () async {
        NetworkIsolationGuard.install();
        await expectLater(
          Socket.connect('analytics.example.com', 443),
          throwsA(isA<NetworkIsolationViolation>()),
        );
        expect(NetworkIsolationGuard.approvedAttempts, isEmpty);
      },
    );

    test(
      'uninstall restores the real socket path (FR-008 inertness)',
      () async {
        NetworkIsolationGuard.install(
          whitelist: const [SocketLane(host: 'analytics.example.com')],
        );
        NetworkIsolationGuard.uninstall();

        // Outside simulation mode the guard is inactive: the connect
        // attempt reaches the OS network stack (unresolvable host →
        // SocketException, not NetworkIsolationViolation).
        await expectLater(
          Socket.connect('api.real-backend.invalid', 443),
          throwsA(isA<SocketException>()),
        );
        expect(NetworkIsolationGuard.isActive, isFalse);
      },
    );
  });

  group('U10: whitelist config file', () {
    test('parses lanes from the project-level config file', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'zuraffa_893_whitelist_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final config = File('${tempDir.path}/.zfa.json');
      await config.writeAsString(
        jsonEncode({
          'simulation': {
            'whitelist': [
              'analytics.example.com',
              {'.crashlytics.com': 443},
              {'host': 'otel collector.internal', 'port': 4317},
            ],
          },
        }),
      );

      final lanes = SimulationWhitelistConfig.load(config.path);
      expect(lanes, hasLength(3));
      expect(lanes[0].host, 'analytics.example.com');
      expect(lanes[0].port, isNull);
      expect(lanes[1].host, '.crashlytics.com');
      expect(lanes[1].port, 443);
      expect(lanes[2].host, 'otel collector.internal');
      expect(lanes[2].port, 4317);
    });

    test(
      'missing file or missing key yields the empty (safe) whitelist',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'zuraffa_893_whitelist_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        expect(
          SimulationWhitelistConfig.load('${tempDir.path}/none.json'),
          isEmpty,
        );

        final config = File('${tempDir.path}/.zfa.json');
        await config.writeAsString('{"name": "app"}');
        expect(SimulationWhitelistConfig.load(config.path), isEmpty);
      },
    );

    test(
      'Malformed whitelist entries fail loudly (never silently open lanes)',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'zuraffa_893_whitelist_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final config = File('${tempDir.path}/.zfa.json');
        await config.writeAsString(
          jsonEncode({
            'simulation': {
              'whitelist': [
                {'port': 443},
              ],
            },
          }),
        );

        expect(
          () => SimulationWhitelistConfig.load(config.path),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
