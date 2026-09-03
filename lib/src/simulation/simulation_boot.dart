/// Simulation boot: the end-to-end demo entry point (spec 893, T005).
///
/// [SimulationBoot.runApp] is the runtime half of the mock-first demo
/// dividend: it installs the network-isolation guard FIRST (FR-005), so
/// not even fixture loading can leak into a socket; validates the
/// committed per-entity fixtures (FR-009, naming the entity on any
/// problem); verifies the #832 manifest when one is present; binds the
/// certified simulation adapters to the container; and warns when the
/// app has zero `complete(mocked)` features to demo (FR-010).
///
/// The gate is the compile-time [kSimulationMode] flavor (FR-001/FR-013):
/// outside the simulation flavor the boot is a harmless no-op (FR-008).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../simulation.dart';
import '../core/di/zuraffa_container.dart';
import 'fixture_registry.dart';
import 'simulation_world.dart';

/// The result of a simulation boot.
final class SimulationBootReport {
  const SimulationBootReport({
    required this.guardActive,
    required this.warnings,
    required this.entities,
    required this.fixtures,
    this.world,
  });

  /// Whether the network-isolation guard is active for this session.
  final bool guardActive;

  /// Human-readable warnings (zero mocked features, no certified
  /// families, no-op outside the flavor).
  final List<String> warnings;

  /// The `complete(mocked)` entities the boot validated.
  final Set<String> entities;

  /// Committed fixture records per entity, ready for the mock
  /// datasources to serve.
  final Map<String, List<Map<String, dynamic>>> fixtures;

  /// The certified simulation world bound to the container, when the
  /// feature fixtures directory carried certified families (#832).
  final SimulationWorld? world;
}

/// Boots the app end-to-end on certified mocks.
final class SimulationBoot {
  SimulationBoot._();

  /// Runs the simulation boot sequence for the app rooted at [container].
  ///
  /// - [featureDir]: the feature directory whose `tdd/fixtures/` holds
  ///   the committed fixtures (spec 893 T003 layout).
  /// - [entities]: the `complete(mocked)` entities to validate and load.
  /// - [whitelist]: explicitly approved network lanes for the guard.
  /// - [simulation]: the flavor gate, defaulting to [kSimulationMode].
  static Future<SimulationBootReport> runApp({
    required ZuraffaContainer container,
    required String featureDir,
    Set<String> entities = const {},
    List<SocketLane> whitelist = const [],
    bool simulation = kSimulationMode,
  }) async {
    final warnings = <String>[];

    // FR-008/FR-012: outside the simulation flavor the boot is a no-op —
    // and an incoherent build-time flag set fails loudly either way.
    SimulationFlavor.checkFlagConflicts();
    if (!simulation) {
      warnings.add(
        'Simulation boot skipped: the app was not compiled with '
        '--dart-define=SIMULATION=true, so no mock bindings or isolation '
        'guard are active.',
      );
      return SimulationBootReport(
        guardActive: false,
        warnings: warnings,
        entities: entities,
        fixtures: const {},
      );
    }

    // FR-005: the guard goes up before anything else in the demo session.
    NetworkIsolationGuard.install(whitelist: whitelist);

    final fixturesDir = p.join(featureDir, 'tdd', 'fixtures');

    // FR-009/SC-005: fail fast naming the entity on missing/corrupt
    // fixtures — never a silent crash or blank screens mid-demo.
    final fixtures = EntityFixtures.loadAll(
      fixturesDir: fixturesDir,
      entities: entities,
    );

    // #832 integrity: when the fixtures directory carries a certified
    // manifest, the bytes on disk must still match it.
    SimulationWorld? world;
    final manifestFile = File(
      p.join(fixturesDir, FixtureRegistry.manifestFileName),
    );
    if (manifestFile.existsSync()) {
      await FixtureRegistry(fixturesDir).verifyManifest();
      world = await SimulationWorld.load(fixturesDir);
      world.bindTo(container);
    } else if (entities.isEmpty) {
      warnings.add(
        'No certified simulation families and no complete(mocked) '
        'features found under $fixturesDir — the demo will show only '
        'scaffolded/placeholder screens.',
      );
    }

    // FR-010: zero complete(mocked) features must warn the developer.
    if (entities.isEmpty) {
      warnings.add(
        'Simulation mode booted with zero complete(mocked) features — '
        'no mocked features are available for demo yet.',
      );
    }

    return SimulationBootReport(
      guardActive: NetworkIsolationGuard.isActive,
      warnings: warnings,
      entities: entities,
      fixtures: Map.unmodifiable(fixtures),
      world: world,
    );
  }
}
