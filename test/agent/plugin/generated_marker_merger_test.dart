import 'package:test/test.dart';
import 'package:zuraffa/src/agent/plugin/generated_marker_merger.dart';

void main() {
  group(
    'GeneratedMarkerMerger — SC-003 idempotency + manual-extension survival',
    () {
      test('mergeOrFresh returns wrapped content when no existing file', () {
        final merged = mergeOrFresh(
          existing: null,
          newGeneratedContent: 'class A {}',
          filePath: '/tmp/a.dart',
        );
        expect(merged, contains('// GENERATED - DO NOT EDIT'));
        expect(merged, contains('class A {}'));
        expect(merged, contains('// END GENERATED'));
      });

      test(
        'mergeOrFresh throws ManualFileConflictException on conflicting manual file',
        () {
          expect(
            () => mergeOrFresh(
              existing: '// manual\nimport "x.dart";\nclass A {}',
              newGeneratedContent: 'class B {}',
              filePath: '/tmp/a.dart',
            ),
            throwsA(isA<ManualFileConflictException>()),
          );
        },
      );

      test(
        'mergeOrFresh replaces ONLY the GENERATED block when markers present',
        () {
          const existing = '''// manual header line
final x = 1;
// GENERATED - DO NOT EDIT
class A {}
// END GENERATED
// manual footer line
final y = 2;
''';
          final merged = mergeOrFresh(
            existing: existing,
            newGeneratedContent: 'class B {}',
            filePath: '/tmp/a.dart',
          );
          expect(merged, contains('// manual header line'));
          expect(merged, contains('final x = 1;'));
          expect(merged, contains('// GENERATED - DO NOT EDIT'));
          expect(merged, contains('class B {}'));
          expect(merged, contains('// END GENERATED'));
          expect(merged, contains('// manual footer line'));
          expect(merged, contains('final y = 2;'));
          // The OLD generated content must be gone.
          expect(merged, isNot(contains('class A {}')));
        },
      );

      test(
        'mergeOrFresh is idempotent: regenerating twice yields identical bytes',
        () {
          const generated = 'class A {}';
          final first = mergeOrFresh(
            existing: null,
            newGeneratedContent: generated,
            filePath: '/tmp/a.dart',
          );
          final second = mergeOrFresh(
            existing: first,
            newGeneratedContent: generated,
            filePath: '/tmp/a.dart',
          );
          expect(second, first);
        },
      );

      test('manual edits above GENERATED marker survive regeneration', () {
        const initial = '''// GENERATED - DO NOT EDIT
class A {}
// END GENERATED
''';
        // Simulate a manual edit: add a line above the marker.
        const edited = '''// Hello from a developer
$initial''';
        final merged = mergeOrFresh(
          existing: edited,
          newGeneratedContent: 'class A {}',
          filePath: '/tmp/a.dart',
        );
        expect(merged, contains('// Hello from a developer'));
        expect(merged, contains('// GENERATED - DO NOT EDIT'));
        expect(merged, contains('class A {}'));
      });

      test('manual edits below GENERATED marker survive regeneration', () {
        const initial = '''// GENERATED - DO NOT EDIT
class A {}
// END GENERATED
''';
        const edited = '''$initial
// Hello below
final x = 42;
''';
        final merged = mergeOrFresh(
          existing: edited,
          newGeneratedContent: 'class A {}',
          filePath: '/tmp/a.dart',
        );
        expect(merged, contains('// Hello below'));
        expect(merged, contains('final x = 42;'));
      });

      test(
        'identical content without markers is treated as idempotent re-write',
        () {
          // Edge: an existing file without markers but with identical content.
          // Should not throw — treat as fresh wrap.
          const content = 'class A {}';
          final merged = mergeOrFresh(
            existing: content,
            newGeneratedContent: content,
            filePath: '/tmp/a.dart',
          );
          expect(merged, contains('// GENERATED - DO NOT EDIT'));
          expect(merged, contains(content));
        },
      );
    },
  );

  group('ManualFileConflictException — FR-009', () {
    test('toString mentions the path and the FR-009 contract', () {
      const ex = ManualFileConflictException('/tmp/a.dart');
      expect(ex.toString(), contains('/tmp/a.dart'));
      expect(ex.toString(), contains('FR-009'));
    });
  });
}
