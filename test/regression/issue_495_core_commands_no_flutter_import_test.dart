@Tags(['regression', 'slow'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// CWD-safe resolution of the `zuraffa` package root.
///
/// Other suites change `Directory.current`, so relative paths are unreliable
/// (see the cli-tests-cwd-contamination bug). Walk up from `Platform.script`
/// first (immune to CWD), then fall back to a CWD walk.
String _findPackageRoot() {
  bool isZuraffaRoot(Directory dir) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    return RegExp(
      r'^name:\s*zuraffa\s*$',
      multiLine: true,
    ).hasMatch(pubspec.readAsStringSync());
  }

  String? walkUp(Directory start) {
    var dir = start;
    for (var i = 0; i < 15; i++) {
      if (isZuraffaRoot(dir)) return dir.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  try {
    final fromScript = walkUp(File(Platform.script.toFilePath()).parent);
    if (fromScript != null) return fromScript;
  } catch (_) {
    // Platform.script may be unusable if the CWD was deleted.
  }

  final fromCwd = walkUp(Directory.current);
  if (fromCwd != null) return fromCwd;

  throw StateError('Could not locate the zuraffa package root');
}

/// #495 regression: the pure-Dart core package must not contain any
/// `package:flutter/` import directive in `lib/` or `bin/`.
///
/// Acceptance criterion A2 of feature `014-pure-dart-core-split` is checked
/// with a grep for lines starting with `import 'package:flutter`. The CLI
/// commands that *generate* Flutter code used to trip that check because
/// their multi-line string templates started a line with the literal import.
/// Generated Flutter imports must therefore be emitted via string constants.
void main() {
  final flutterImportLine = RegExp(
    '''^\\s*import\\s+['"]package:flutter/''',
    multiLine: true,
  );
  final root = _findPackageRoot();

  group('issue 495 - core CLI commands are Flutter-free', () {
    test(
      'create_command.dart and module_command.dart have no Flutter import',
      () {
        for (final relative in const [
          'lib/src/commands/create_command.dart',
          'lib/src/commands/module_command.dart',
        ]) {
          final file = File(p.join(root, relative));
          expect(file.existsSync(), isTrue, reason: 'missing $relative');
          expect(
            flutterImportLine.hasMatch(file.readAsStringSync()),
            isFalse,
            reason:
                '$relative must not contain a line beginning with '
                "import 'package:flutter/ (use a string constant for "
                'generated code templates)',
          );
        }
      },
    );

    test(
      'no core lib/ or bin/ dart file starts a line with a Flutter import',
      () {
        final offenders = <String>[];
        for (final dir in const ['lib', 'bin']) {
          final directory = Directory(p.join(root, dir));
          if (!directory.existsSync()) continue;
          for (final entity in directory.listSync(recursive: true)) {
            if (entity is! File || !entity.path.endsWith('.dart')) continue;
            if (flutterImportLine.hasMatch(entity.readAsStringSync())) {
              offenders.add(p.relative(entity.path, from: root));
            }
          }
        }
        expect(offenders, isEmpty, reason: 'Flutter imports found in core');
      },
    );
  });
}
