/// GYM warmup rep #2 — build the host package under load.
///
/// A warmup rep proves the operator can build the package itself. This rep
/// runs the pure-Dart example app at `examples/pure_dart_server/` end to
/// end. The example exercises zuraffa's core (DI, UseCase, Result, hooks,
/// signals, FailureHandler) without any Flutter SDK dependency — so a clean
/// exit proves the package compiles and runs as a library.
///
/// Run: `dart run .gym/warmup/02-build.dart`
///
/// A mis-fire (unexpected outcome, not a clean failure) is a DROP CARD —
/// see github.com/arrrrny/drop-card.
library;

import 'dart:io';

/// Marker the example server prints on a clean run.
const _successMarker = 'Pure Dart zuraffa example completed successfully.';

/// Entry point for warmup rep #2.
Future<void> main() async {
  final exampleDir = Directory('examples/pure_dart_server');
  if (!exampleDir.existsSync()) {
    stderr.writeln(
      'REP FAIL: 02-build — examples/pure_dart_server not found in cwd='
      '${Directory.current.path}',
    );
    exit(1);
  }

  // Resolve the example's deps first (it path-depends on the parent zuraffa
  // package, so this also re-validates the parent package_config).
  final pubGet = await Process.run(
    'dart',
    ['pub', 'get'],
    workingDirectory: exampleDir.path,
  );
  if (pubGet.exitCode != 0) {
    stderr.writeln(
      'REP FAIL: 02-build — `dart pub get` in examples/pure_dart_server '
      'exited ${pubGet.exitCode}',
    );
    stderr.writeln(pubGet.stdout);
    stderr.writeln(pubGet.stderr);
    exit(pubGet.exitCode);
  }

  // Build + run the example. The example prints the success marker on a
  // clean run; anything else is a build failure.
  final run = await Process.run(
    'dart',
    ['run', 'bin/server.dart'],
    workingDirectory: exampleDir.path,
  );

  final combined = '${run.stdout}\n${run.stderr}';
  if (run.exitCode != 0 || !combined.contains(_successMarker)) {
    stderr.writeln(
      'REP FAIL: 02-build — example did not reach the success marker. '
      'exit=${run.exitCode}',
    );
    stderr.writeln(combined);
    exit(run.exitCode == 0 ? 1 : run.exitCode);
  }

  stdout.writeln('REP OK: 02-build — example app built and ran cleanly.');
}
