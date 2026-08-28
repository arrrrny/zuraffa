@Tags(['regression'])
library;

import 'dart:io';

import 'package:test/test.dart';

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

  group('issue 495 - core CLI commands are Flutter-free', () {
    test(
      'create_command.dart and module_command.dart have no Flutter import',
      () {
        for (final relative in const [
          'lib/src/commands/create_command.dart',
          'lib/src/commands/module_command.dart',
        ]) {
          final file = File(relative);
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
          final directory = Directory(dir);
          if (!directory.existsSync()) continue;
          for (final entity in directory.listSync(recursive: true)) {
            if (entity is! File || !entity.path.endsWith('.dart')) continue;
            if (flutterImportLine.hasMatch(entity.readAsStringSync())) {
              offenders.add(entity.path);
            }
          }
        }
        expect(offenders, isEmpty, reason: 'Flutter imports found in core');
      },
    );
  });
}
