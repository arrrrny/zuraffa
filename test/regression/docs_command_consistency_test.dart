import 'dart:io';

import 'package:test/test.dart';

/// CWD-safe project root resolution using Platform.script.
String _findProjectRoot() {
  // Strategy 1: Walk up from this test file's location via Platform.script.
  try {
    var dir = File(Platform.script.toFilePath()).parent;
    for (var i = 0; i < 10; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(content)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}

  // Strategy 2: Walk up from Directory.current (fallback).
  try {
    var dir = Directory.current;
    for (var i = 0; i < 15; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final content = pubspec.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(content)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}

  return Directory.current.path;
}

void main() {
  final projectRoot = _findProjectRoot();

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
