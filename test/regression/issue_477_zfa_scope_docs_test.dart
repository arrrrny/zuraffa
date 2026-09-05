@Tags(['regression', 'slow'])
library;

// Regression test for issue #477.
//
// Misfire report: `zfa` cannot rewrite the zikzak_inappwebview Flutter plugin.
// The assessment for #477 classified this as a documentation/expectations
// issue, not a code bug: `zfa` is a clean-architecture generator for Zuraffa
// apps, has no command that rewrites arbitrary Flutter plugins, and `zfa
// doctor` reporting missing `.zfa.json` / `zuraffa` / `zorphy_annotation`
// inside a non-Zuraffa package is expected scope behavior. The fix is to set
// those expectations in the user-facing docs; this test pins that contract so
// the clarification cannot be silently dropped.
//
// See: https://github.com/arrrrny/zuraffa/issues/477
import 'dart:io';

import 'package:test/test.dart';

import '../helpers/project_root.dart';

Future<void> main() async {
  final projectRoot = await findProjectRoot();

  String readDoc(String relativePath) {
    final file = File('$projectRoot/$relativePath');
    if (!file.existsSync()) {
      throw StateError('Doc file not found: ${file.path}');
    }
    return file.readAsStringSync();
  }

  group('zfa scope docs (issue #477)', () {
    test('CLI_GUIDE.md scopes zfa to Zuraffa apps (#477)', () {
      final content = readDoc('CLI_GUIDE.md');
      expect(
        content,
        contains('Zuraffa apps'),
        reason:
            'CLI_GUIDE.md must state that zfa is a generator scoped to '
            'Zuraffa apps, so users do not expect a general-purpose rewriter '
            '(issue #477).',
      );
    });

    test('CLI_GUIDE.md states zfa does not rewrite non-Zuraffa packages '
        '(#477)', () {
      final content = readDoc('CLI_GUIDE.md');
      expect(
        content,
        contains('does not rewrite existing non-Zuraffa'),
        reason:
            'CLI_GUIDE.md must say zfa does not rewrite non-Zuraffa '
            'Flutter packages or plugins (issue #477).',
      );
    });

    test('CLI_GUIDE.md frames zfa doctor output in non-Zuraffa packages as '
        'expected (#477)', () {
      final content = readDoc('CLI_GUIDE.md');
      expect(
        content,
        contains('not a malfunction of the CLI'),
        reason:
            'CLI_GUIDE.md must set the expectation that zfa doctor '
            'reporting missing .zfa.json / zuraffa / zorphy_annotation inside '
            'a non-Zuraffa package is scope behavior, not a bug (issue #477).',
      );
    });

    test('CLI_GUIDE.md routes plugin-rewrite support to a feature request '
        '(#477)', () {
      final content = readDoc('CLI_GUIDE.md');
      expect(
        content,
        contains('file a feature request'),
        reason:
            'CLI_GUIDE.md must tell users who need zfa to operate on '
            'non-Zuraffa packages to file a feature request instead of '
            'hitting a silent misfire (issue #477).',
      );
    });

    test('README.md states the zfa scope for non-Zuraffa packages (#477)', () {
      final content = readDoc('README.md');
      expect(
        content,
        contains('Zuraffa apps'),
        reason:
            'README.md must state that zfa targets Zuraffa apps '
            '(issue #477).',
      );
      expect(
        content,
        contains('non-Zuraffa'),
        reason:
            'README.md must state that non-Zuraffa Flutter packages or '
            'plugins are outside zfa\'s rewrite scope (issue #477).',
      );
    });
  });
}
