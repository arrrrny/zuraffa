/// Simulation flavor detection (spec 893, T001).
///
/// The single build-time flag that activates simulation mode across the
/// entire application (FR-001). A Flutter app switches flavors with
///
/// ```sh
/// flutter run --dart-define=SIMULATION=true
/// ```
///
/// and a plain-Dart consumer with `dart run --dart-define=SIMULATION=true`.
/// The flavor is a compile-time constant (FR-013): switching requires a
/// rebuild, and AOT builds tree-shake the dead flavor branch entirely.
///
/// Conflicts with other build-time flags resolve explicitly (FR-012):
/// [SimulationFlavor.checkFlagConflicts] throws [SimulationFlagConflict]
/// when the simulation define is combined with a real-backend define —
/// simulation mode never silently falls through to real network access.
library;

/// Whether the application was compiled for the simulation flavor.
///
/// `true` only when the `SIMULATION` dart-define was set at compile time.
/// Every generated simulation binding (spec 893, T002) guards its
/// registration behind this constant, so the flavor switch is a single
/// `--dart-define` on the build command — never hand-wired code.
const bool kSimulationMode = bool.fromEnvironment(
  'SIMULATION',
  defaultValue: false,
);

/// Whether the application was compiled with an explicit real-backend
/// define. Used only to surface conflicts with [kSimulationMode] loudly
/// (FR-012); on its own it has no simulation semantics.
const bool kRealBackendMode = bool.fromEnvironment(
  'REAL_BACKEND',
  defaultValue: false,
);

/// The build-time configuration conflict for the simulation flavor.
///
/// Extends [Error] (not [Exception]) so generic `catch (e)` blocks in
/// composition roots do not silently swallow a mis-flagged build: the app
/// must fail to boot with a clear diagnostic instead of half-mocking.
final class SimulationFlagConflict extends Error {
  SimulationFlagConflict(this.message);

  /// Human-readable diagnostic naming both flags and the resolution rule.
  final String message;

  @override
  String toString() => 'SimulationFlagConflict: $message';
}

/// Compile-time flavor introspection for the simulation mode.
final class SimulationFlavor {
  SimulationFlavor._();

  /// The flavor name: `simulation` when compiled with
  /// `--dart-define=SIMULATION=true`, otherwise `real`.
  static String describe() => kSimulationMode ? 'simulation' : 'real';

  /// Whether the compile-time flag set is coherent.
  ///
  /// FR-012: a build that sets both `SIMULATION=true` and
  /// `REAL_BACKEND=true` is ambiguous — simulation mode must either take
  /// precedence or produce a conflict error, never silently fall through
  /// to real network calls. This gate produces the explicit conflict
  /// error, and every generated simulation binding and boot entry point
  /// ([SimulationBoot] and the generated `registerSimulationBindings`)
  /// runs it before any binding is registered.
  static void checkFlagConflicts({
    bool simulation = kSimulationMode,
    bool realBackend = kRealBackendMode,
  }) {
    if (simulation && realBackend) {
      throw SimulationFlagConflict(
        'Build-time flag conflict: --dart-define=SIMULATION=true and '
        '--dart-define=REAL_BACKEND=true were both set. The SIMULATION '
        'flavor boots exclusively on certified mocks and must not be '
        'combined with a real-backend flavor. Rebuild with a single '
        'flavor define.',
      );
    }
  }
}
