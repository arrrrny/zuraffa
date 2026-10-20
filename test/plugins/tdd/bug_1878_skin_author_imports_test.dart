// Bug #1878 — the skin-authoring import channel. A shad skin could not name
// `LucideIcons` / `Shad*` (which live in `package:zuraffa_ui/shad.dart`)
// from the author finders because the patched test body had no import
// channel. `// import:`-marked header lines are now hoisted into the test's
// import section; these are the pure-transform contract tests for that
// mechanism (the original patch shipped none).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/skin_authoring.dart';
import 'package:zuraffa/src/plugins/tdd/services/widget_scaffold.dart';

/// A scaffolded widget test in the shape `BehaviorTestWriter` emits for a
/// no-derivable-finder scenario.
String scaffoldedTest() =>
    '''
import 'package:test/test.dart';

void main() {
  test('scenario', () {
      $widgetScaffoldComment
      $skinPlaceholderStatement
  });
}
''';

void main() {
  group('SkinAuthoring import markers (#1878)', () {
    test('inline quoted marker hoists the import and is not spliced', () {
      final patched = SkinAuthoring.patchedContent(
        testContent: scaffoldedTest(),
        authorFinders:
            "// import: 'package:zuraffa_ui/shad.dart'\n"
            'expect(find.byType(ShadButton), findsOneWidget);',
      );
      expect(patched, contains("import 'package:zuraffa_ui/shad.dart';"));
      expect(
        RegExp(r'^\s+//\s*import:', multiLine: true).hasMatch(patched),
        isFalse,
        reason: 'marker lines must never be indented into the test body',
      );
      expect(
        patched,
        contains(
          'expect(find.byType(ShadButton), '
          'findsOneWidget);',
        ),
      );
      expect(patched, isNot(contains(skinPlaceholderStatement)));
    });

    test('inline bare-token marker hoists every URI', () {
      final patched = SkinAuthoring.patchedContent(
        testContent: scaffoldedTest(),
        authorFinders:
            '// import: package:a/a.dart package:b/b.dart\n'
            "expect(find.text('Hi'), findsOneWidget);",
      );
      expect(patched, contains("import 'package:a/a.dart';"));
      expect(patched, contains("import 'package:b/b.dart';"));
    });

    test('inline multi-quoted marker hoists every URI', () {
      final patched = SkinAuthoring.patchedContent(
        testContent: scaffoldedTest(),
        authorFinders:
            "// import: 'package:a/a.dart' 'package:b/b.dart'\n"
            "expect(find.text('Hi'), findsOneWidget);",
      );
      expect(patched, contains("import 'package:a/a.dart';"));
      expect(patched, contains("import 'package:b/b.dart';"));
    });

    test('bare header continuation is hoisted', () {
      final patched = SkinAuthoring.patchedContent(
        testContent: scaffoldedTest(),
        authorFinders:
            '// import:\n'
            '// package:zuraffa_ui/shad.dart\n'
            'expect(find.byType(ShadButton), findsOneWidget);',
      );
      expect(patched, contains("import 'package:zuraffa_ui/shad.dart';"));
    });

    test(
      'quoted header continuation is hoisted, not indented into the body',
      () {
        final patched = SkinAuthoring.patchedContent(
          testContent: scaffoldedTest(),
          authorFinders:
              '// import:\n'
              "// 'package:zuraffa_ui/shad.dart'\n"
              'expect(find.byType(ShadButton), findsOneWidget);',
        );
        expect(patched, contains("import 'package:zuraffa_ui/shad.dart';"));
        expect(
          patched,
          isNot(contains("// 'package:zuraffa_ui/shad.dart'")),
          reason: 'the quoted header line must be consumed, not spliced',
        );
      },
    );

    test('a continuation line may carry several quoted URIs', () {
      final patched = SkinAuthoring.patchedContent(
        testContent: scaffoldedTest(),
        authorFinders:
            '// import:\n'
            "// 'package:a/a.dart' 'package:b/b.dart'\n"
            "expect(find.text('Hi'), findsOneWidget);",
      );
      expect(patched, contains("import 'package:a/a.dart';"));
      expect(patched, contains("import 'package:b/b.dart';"));
    });

    test('hoisting de-duplicates against imports already present', () {
      final content =
          '''
import 'package:zuraffa_ui/shad.dart';
import 'package:test/test.dart';

void main() {
  test('scenario', () {
      $widgetScaffoldComment
      $skinPlaceholderStatement
  });
}
''';
      final patched = SkinAuthoring.patchedContent(
        testContent: content,
        authorFinders:
            "// import: 'package:zuraffa_ui/shad.dart'\n"
            'expect(1, 1);',
      );
      expect(
        RegExp(
          "import 'package:zuraffa_ui/shad.dart';",
        ).allMatches(patched).length,
        1,
      );
    });

    test('a URI-looking comment outside a header block is not hoisted', () {
      final patched = SkinAuthoring.patchedContent(
        testContent: scaffoldedTest(),
        authorFinders:
            '// package:fake/not_an_import.dart\n'
            "expect(find.text('Hi'), findsOneWidget);",
      );
      expect(
        patched,
        isNot(contains("import 'package:fake/not_an_import.dart';")),
        reason: 'a stray doc comment must stay a comment',
      );
      expect(patched, contains('// package:fake/not_an_import.dart'));
    });

    test('with no import and no main anchor the import precedes code', () {
      final content =
          '''
// subject comment
library;

int value() => 0;

    $widgetScaffoldComment
    $skinPlaceholderStatement
''';
      final patched = SkinAuthoring.patchedContent(
        testContent: content,
        authorFinders:
            '// import: package:foo/bar.dart\n'
            'expect(1, 1);',
      );
      expect(patched, contains("import 'package:foo/bar.dart';"));
      expect(
        patched.indexOf("import 'package:foo/bar.dart';"),
        lessThan(patched.indexOf('int value() => 0;')),
        reason: 'an import appended at EOF does not compile',
      );
      expect(
        patched.trimRight().endsWith("import 'package:foo/bar.dart';"),
        isFalse,
      );
    });
  });

  group('SkinAuthoring validation against the spliced body (#1878)', () {
    test('an assertion that lives only in a line comment is refused', () {
      expect(
        () => SkinAuthoring.patchedContent(
          testContent: scaffoldedTest(),
          authorFinders:
              '// import: package:zuraffa_ui/shad.dart\n'
              '// expect(1, 1);\n',
        ),
        throwsA(isA<SkinAuthoringException>()),
      );
    });

    test('an assertion that lives only in a block comment is refused', () {
      expect(
        () => SkinAuthoring.validateAuthorFinders('/* expect(1, 1); */'),
        throwsA(isA<SkinAuthoringException>()),
      );
    });

    test('import markers alone are not an assertion', () {
      expect(
        () => SkinAuthoring.patchedContent(
          testContent: scaffoldedTest(),
          authorFinders: '// import: package:zuraffa_ui/shad.dart',
        ),
        throwsA(isA<SkinAuthoringException>()),
      );
    });

    test('a comment token inside a string literal is not a comment', () {
      expect(
        () => SkinAuthoring.validateAuthorFinders(
          "expect(find.text('https://example.com'), findsOneWidget);",
        ),
        returnsNormally,
      );
    });
  });
}
