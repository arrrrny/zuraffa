import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final projectRoot = Directory.current.path;

  String readDoc(String relativePath) {
    final file = File('$projectRoot/$relativePath');
    if (!file.existsSync()) {
      throw StateError('Doc file not found: ${file.path}');
    }
    return file.readAsStringSync();
  }

  List<String> readWebsiteDocs() {
    final docsDir = Directory('$projectRoot/website/docs');
    if (!docsDir.existsSync()) return [];
    return docsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md') || f.path.endsWith('.mdx'))
        .map((f) => f.readAsStringSync())
        .toList();
  }

  group('Docs command consistency', () {
    test('README.md does NOT contain "zfa generate"', () {
      final content = readDoc('README.md');
      expect(
        content,
        isNot(contains('zfa generate')),
        reason:
            'README.md should not reference the removed "zfa generate" command',
      );
    });

    test('CLI_GUIDE.md does NOT contain "zfa generate"', () {
      final content = readDoc('CLI_GUIDE.md');
      expect(
        content,
        isNot(contains('zfa generate')),
        reason:
            'CLI_GUIDE.md should not reference the removed "zfa generate" command',
      );
    });

    test('SKILL.md does NOT contain "zfa generate"', () {
      final content = readDoc('SKILL.md');
      expect(
        content,
        isNot(contains('zfa generate')),
        reason:
            'SKILL.md should not reference the removed "zfa generate" command',
      );
    });

    test('README.md DOES contain "zfa make"', () {
      final content = readDoc('README.md');
      expect(
        content,
        contains('zfa make'),
        reason: 'README.md should reference the canonical "zfa make" command',
      );
    });

    test('CLI_GUIDE.md DOES contain "zfa make"', () {
      final content = readDoc('CLI_GUIDE.md');
      expect(
        content,
        contains('zfa make'),
        reason:
            'CLI_GUIDE.md should reference the canonical "zfa make" command',
      );
    });

    test('AGENTS.md DOES contain "zfa entity create" AND "zfa make"', () {
      final content = readDoc('AGENTS.md');
      expect(
        content,
        contains('zfa entity create'),
        reason: 'AGENTS.md should reference "zfa entity create"',
      );
      expect(
        content,
        contains('zfa make'),
        reason: 'AGENTS.md should reference "zfa make"',
      );
    });

    test('README.md DOES contain "zfa build"', () {
      final content = readDoc('README.md');
      expect(
        content,
        contains('zfa build'),
        reason: 'README.md should reference "zfa build"',
      );
    });

    test('website/docs does NOT contain "zfa generate"', () {
      final docs = readWebsiteDocs();
      if (docs.isEmpty) {
        // No website docs to check; pass by default.
        return;
      }
      for (var i = 0; i < docs.length; i++) {
        expect(
          docs[i],
          isNot(contains('zfa generate')),
          reason: 'A website/docs file should not reference "zfa generate"',
        );
      }
    });
  });
}
