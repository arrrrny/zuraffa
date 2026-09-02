/// Bug #832 — the golden contract world: `SimulationWorld`.
///
/// Boots the five certified adapter families from committed fixtures
/// (`specs/<feature>/tdd/fixtures/`), installs the network-isolation
/// guard, binds the adapters into the SAME production DI container the
/// generated code resolves from (`ZuraffaContainer`), and replays the
/// golden contract deterministically. A generated-style data source
/// takes its adapter via DI and runs GREEN — same production interface,
/// different certified binding.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/di/zuraffa_container.dart';
import 'package:zuraffa/src/simulation/fixture_registry.dart';
import 'package:zuraffa/src/simulation/network_isolation_guard.dart';
import 'package:zuraffa/src/simulation/simulation_adapters.dart';
import 'package:zuraffa/src/simulation/simulation_world.dart';

/// A generated-style data source: takes its transport via DI. In
/// production it would be bound to a live HTTP binding; in the TDD
/// bootstrap it is bound to the certified simulation. The interface is
/// IDENTICAL — that is the bug's core requirement.
class PriceDataSource {
  PriceDataSource(this._rest);

  final RestContract _rest;

  Future<Map<String, dynamic>> fetchQuote(String symbol) =>
      _rest.get('/v1/quote/$symbol');
}

void main() {
  late Directory workspace;
  late String fixturesDir;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa-sim-world');
    fixturesDir = '${workspace.path}/tdd/fixtures';
    await SimulationFixtures.scaffold(
      fixturesDir,
      families: const [
        'firebase-auth',
        'vendure',
        'rest',
        'admob',
        'otel',
      ],
    );
  });

  tearDown(() async {
    NetworkIsolationGuard.uninstall();
    await workspace.delete(recursive: true);
  });

  group('fixture commitment', () {
    test('scaffold writes per-family fixture files plus a hashed manifest',
        () async {
      final manifestFile = File('$fixturesDir/manifest.json');
      expect(manifestFile.existsSync(), isTrue);
      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['schema'], 1);
      expect(
        (manifest['families'] as List).toSet(),
        {'firebase-auth', 'vendure', 'rest', 'admob', 'otel'},
      );
      final files = manifest['files'] as Map<String, dynamic>;
      expect(files.keys, containsAll(<String>[
        'auth-world.json',
        'vendure-golden.json',
        'rest-world.json',
        'admob-world.json',
        'otel-world.json',
      ]));
      // Every recorded hash is a real sha256 of the file bytes.
      for (final entry in files.entries) {
        final bytes =
            File('$fixturesDir/${entry.key}').readAsBytesSync();
        expect(
          FixtureRegistry.sha256Hex(bytes),
          (entry.value as Map<String, dynamic>)['sha256'],
          reason: 'fixture ${entry.key} must hash to its manifest sha256',
        );
      }
      expect(manifest['digest'], hasLength(64));
    });

    test('scaffold is deterministic: identical worlds hash identically',
        () async {
      final other = '${workspace.path}/other/tdd/fixtures';
      await SimulationFixtures.scaffold(
        other,
        families: const ['rest'],
      );
      final a = jsonDecode(
        File('$fixturesDir/rest-world.json').readAsStringSync(),
      );
      final b = jsonDecode(
        File('$other/rest-world.json').readAsStringSync(),
      );
      expect(jsonEncode(a), jsonEncode(b));
    });
  });

  group('SimulationWorld.load', () {
    test('boots all five families from the committed fixtures', () async {
      final world = await SimulationWorld.load(fixturesDir);
      expect(world.auth, isA<FirebaseAuthAdapter>());
      expect(world.vendure, isA<VendureAdapter>());
      expect(world.rest, isA<RestAdapter>());
      expect(world.admob, isA<AdMobAdapter>());
      expect(world.otel, isA<OtelAdapter>());
      world.dispose();
    });

    test('verifies every fixture against its manifest hash', () async {
      // Tamper with one fixture byte -> load must refuse.
      final restFile = File('$fixturesDir/rest-world.json');
      final original = restFile.readAsStringSync();
      restFile.writeAsStringSync(original.replaceFirst('"rest"', '"rost"'));
      await expectLater(
        SimulationWorld.load(fixturesDir),
        throwsA(isA<FixtureMismatch>()),
      );
      // Restore — the pristine world loads again.
      restFile.writeAsStringSync(original);
      final world = await SimulationWorld.load(fixturesDir);
      world.dispose();
    });
  });

  group('SimulationWorld.boot', () {
    test('installs the network-isolation guard', () async {
      expect(NetworkIsolationGuard.isActive, isFalse);
      final world = await SimulationWorld.boot(fixturesDir: fixturesDir);
      expect(NetworkIsolationGuard.isActive, isTrue);
      world.dispose();
    });
  });

  group('DI binding (same production interface, certified binding)', () {
    test('bindTo registers the certified adapters under the contracts',
        () async {
      final world = await SimulationWorld.boot(fixturesDir: fixturesDir);
      final container = ZuraffaContainer.instance;
      container.reset();
      world.bindTo(container);

      final resolvedRest = container.resolve<RestContract>();
      expect(identical(resolvedRest, world.rest), isTrue);
      expect(container.resolve<AuthContract>(), same(world.auth));
      expect(container.resolve<VendureContract>(), same(world.vendure));
      expect(container.resolve<AdContract>(), same(world.admob));
      world.dispose();
    });

    test('a generated-style data source runs GREEN through DI — no network',
        () async {
      final world = await SimulationWorld.boot(fixturesDir: fixturesDir);
      final container = ZuraffaContainer.instance;
      container.reset();
      world.bindTo(container);

      // The data source is constructed with whatever the container binds.
      final dataSource =
          PriceDataSource(container.resolve<RestContract>());
      final quote = await dataSource.fetchQuote('USD-TRY');
      expect(quote['symbol'], 'USD-TRY');
      // Deterministic: same answer twice.
      final again = await dataSource.fetchQuote('USD-TRY');
      expect(jsonEncode(again), jsonEncode(quote));
      world.dispose();
    });
  });

  group('golden replay', () {
    test('every recorded fixture replays GREEN', () async {
      final world = await SimulationWorld.load(fixturesDir);
      final results = await world.play();
      expect(results, isNotEmpty);
      for (final result in results) {
        expect(
          result.passed,
          isTrue,
          reason: 'golden play failed: ${result.name} — ${result.detail}',
        );
      }
      world.dispose();
    });

    test('replay filters by family', () async {
      final world = await SimulationWorld.load(fixturesDir);
      final results = await world.play(family: 'rest');
      expect(results, isNotEmpty);
      expect(results.every((r) => r.family == 'rest'), isTrue);
      world.dispose();
    });
  });
}
