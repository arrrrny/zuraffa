// Probe binary for the spec 893 flavor tests: prints the compile-time
// simulation flavor constants so the subprocess runs can assert the real
// `--dart-define` behavior of the Dart toolchain.
import 'dart:io';

import 'package:zuraffa/src/simulation/simulation_flavor.dart';

void main() {
  stdout.writeln('kSimulationMode=$kSimulationMode');
  stdout.writeln('kRealBackendMode=$kRealBackendMode');
  stdout.writeln('flavor=${SimulationFlavor.describe()}');
}
