// Spec 893 — simulation flavor detection (T001).
//
// FR-001: a single build-time flag (`--dart-define=SIMULATION=true`)
// activates simulation mode. FR-012: conflicts with other build-time flags
// resolve explicitly — never a silent fall-through.
//
// The in-process asserts cover the default (no-define) compile of this test
// suite. The subprocess probes run the real Dart toolchain with and without
// the SIMULATION define (`dart run -DSIMULATION=true`, the VM-level form of
// the same define mechanism `flutter run --dart-define` feeds the frontend:
// both surface through `bool.fromEnvironment` at compile time).
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/simulation/simulation_flavor.dart';

void main() {
  group('kSimulationMode', () {
    test('defaults to false without the SIMULATION define', () {
      // This suite is compiled without any SIMULATION define, so the
      // compile-time constant must be false here.
      expect(kSimulationMode, isFalse);
      expect(SimulationFlavor.describe(), 'real');
    });

    test(
      'U1: SIMULATION define routes kSimulationMode to true',
      () async {
      final result = await _runProbe(const ['-DSIMULATION=true']);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('kSimulationMode=true'));
      expect(result.stdout, contains('flavor=simulation'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('default toolchain run keeps kSimulationMode false', () async {
      final result = await _runProbe(const []);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, contains('kSimulationMode=false'));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('probe reports the real flavor name without the define', () async {
      final result = await _runProbe(const []);
      expect(result.stdout, contains('flavor=real'));
      expect(result.stdout, contains('kRealBackendMode=false'));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('A5: SimulationFlavor.checkFlagConflicts', () {
    test('throws SimulationFlagConflict when both defines are set', () {
      expect(
        () => SimulationFlavor.checkFlagConflicts(
          simulation: true,
          realBackend: true,
        ),
        throwsA(isA<SimulationFlagConflict>()),
      );
    });

    test('allows the simulation flavor alone', () {
      expect(
        () => SimulationFlavor.checkFlagConflicts(
          simulation: true,
          realBackend: false,
        ),
        returnsNormally,
      );
    });

    test('allows the real backend alone (default toolchain)', () {
      expect(
        () => SimulationFlavor.checkFlagConflicts(
          simulation: false,
          realBackend: true,
        ),
        returnsNormally,
      );
    });

    test('conflict error names both flags and the resolution rule', () {
      try {
        SimulationFlavor.checkFlagConflicts(
          simulation: true,
          realBackend: true,
        );
        fail('expected SimulationFlagConflict');
      } on SimulationFlagConflict catch (e) {
        expect(e.message, contains('SIMULATION'));
        expect(e.message, contains('REAL_BACKEND'));
        expect(e.message, contains('conflict'));
      }
    });
  });
}

Future<ProcessResult> _runProbe(List<String> defines) {
  final probePath = File('test/simulation/helpers/simulation_flavor_probe.dart')
      .absolute
      .path;
  return Process.run(
    Platform.resolvedExecutable,
    ['run', ...defines, probePath],
    workingDirectory: Directory.current.path,
  );
}
