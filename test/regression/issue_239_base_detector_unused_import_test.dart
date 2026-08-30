@Tags(['regression', 'slow'])

// Regression test for issue #239.
//
// `lib/src/migration/detectors/base_detector.dart` previously had an unused
// `import 'package:path/path.dart';` at line 4 — flagged by `dart analyze`
// as `unused_import`. The import has been removed. This test asserts the
// import has not been re-introduced, so the `unused_import` warning cannot
// silently come back.
//
// See: https://github.com/arrrrny/zuraffa/issues/239

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/project_root.dart';

void main() {
  late String repoRoot;

  setUpAll(() async {
    repoRoot = await findProjectRoot();
  });

  test('base_detector.dart does not import package:path/path.dart (#239)', () {
    final baseDetector = File(
      p.join(
        repoRoot,
        'lib',
        'src',
        'migration',
        'detectors',
        'base_detector.dart',
      ),
    );

    expect(
      baseDetector.existsSync(),
      isTrue,
      reason: 'base_detector.dart should exist at $repoRoot',
    );
    final src = baseDetector.readAsStringSync();

    // The unused import must NOT be present anywhere in the file.
    expect(
      src.contains(
        RegExp(
          '^[ \\t]*import[ \\t]+["\']package:path/path\\.dart["\']',
          multiLine: true,
        ),
      ),
      isFalse,
      reason:
          'base_detector.dart must not import package:path/path.dart — '
          'it was unused per #239 and would re-introduce the unused_import '
          'warning. If you genuinely need path utilities here, use them so '
          'the import is no longer unused, or import the explicit symbol '
          'you need (e.g. p.join) instead of the whole library.',
    );
  });

  test('base_detector.dart imports set is the minimal expected set (#239)', () {
    final baseDetector = File(
      p.join(
        repoRoot,
        'lib',
        'src',
        'migration',
        'detectors',
        'base_detector.dart',
      ),
    );
    expect(baseDetector.existsSync(), isTrue);
    final src = baseDetector.readAsStringSync();

    // Collect every `import '...';` line.
    final imports =
        RegExp(
              '^[ \\t]*import[ \\t]+["\'][^"\']+["\']\\s*(?:as\\s+\\w+)?\\s*;',
              multiLine: true,
            )
            .allMatches(src)
            .map((m) => m.group(0)!.trim().replaceAll('"', "'"))
            .toList();

    // The current expected set: dart:io, package:meta/meta.dart,
    // package:glob/glob.dart. If you legitimately add a new import to
    // this file, update this set — but NEVER add `package:path/path.dart`
    // back (see the test above).
    expect(
      imports,
      containsAll(<String>[
        "import 'dart:io';",
        "import 'package:meta/meta.dart';",
        "import 'package:glob/glob.dart';",
      ]),
    );
    expect(
      imports.length,
      lessThanOrEqualTo(4),
      reason:
          'base_detector.dart should keep its import set minimal. '
          'If you added a new import, update this assertion.',
    );
  });
}
