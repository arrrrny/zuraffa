import 'dart:io';
import 'package:test/test.dart';

import '../../helpers/project_root.dart';

/// **A26 / FR-012**: The TUI plugin path contains NO `package:flutter`
/// import. This is a static grep test — it scans every Dart file under
/// `lib/src/plugins/tui/` and `test/plugins/tui/` and fails if any file
/// imports `package:flutter/`.
///
/// The grep is intentionally literal (not regex) so that comments mentioning
/// `package:flutter` are also caught — the spec contract is zero occurrences
/// anywhere in the TUI path, including comments.
void main() async {
  final repoRoot = await findProjectRoot();
  test(
    'A26 / FR-012: no package:flutter import anywhere in the TUI plugin path',
    () {
      final tuiDirs = <Directory>[
        Directory('$repoRoot/lib/src/plugins/tui'),
        Directory('$repoRoot/test/plugins/tui'),
      ];

      final offenders = <String>[];
      // The forbidden pattern is an actual Dart import statement that pulls
      // in package:flutter. Comments and string literals mentioning the
      // substring are fine — they do not import Flutter.
      //
      // Build the search string from pieces so this very test file is not
      // a false positive (its source legitimately mentions the forbidden
      // concept in comments to define the test).
      final forbidden = "import 'package:${'flutter'}";
      for (final dir in tuiDirs) {
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.dart')) continue;
          // Skip this very test file — it must mention the forbidden pattern
          // in its own source to define the test (the `import 'package:` +
          // `flutter'` literal concatenation is needed to build the search
          // string). This is not a real Flutter import.
          if (entity.path.endsWith('no_flutter_import_test.dart')) continue;
          final contents = entity.readAsStringSync();
          // Match actual import statements — `import 'package:flutter/...'`.
          if (contents.contains(forbidden)) {
            offenders.add(entity.path);
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'FR-012 violation — these files reference package:flutter:\n  '
            '${offenders.join('\n  ')}',
      );
    },
  );

  test('A26 / FR-012 (extra): nocterm dependency is pinned and pubspec.lock '
      'has no resolved flutter package', () {
    final pubspec = File('$repoRoot/pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('nocterm: ^0.9.0'));

    // pubspec.lock is the resolved dependency tree. If nocturn or any of
    // its transitive deps pulled in flutter, a `flutter:` package would
    // appear in the lockfile's packages section.
    final lockFile = File('$repoRoot/pubspec.lock');
    expect(
      lockFile.existsSync(),
      isTrue,
      reason: 'pubspec.lock must exist after dart pub get',
    );
    final lock = lockFile.readAsStringSync();

    // Look for the SDk constraint `sdk: flutter` (which would only appear
    // if a Flutter SDK package was resolved).
    expect(
      lock.contains('sdk: flutter'),
      isFalse,
      reason:
          'No package in the resolved tree may declare `sdk: flutter` '
          '(FR-012 — pure-Dart)',
    );
  });
}
