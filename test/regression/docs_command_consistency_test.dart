import 'dart:io';

import 'package:test/test.dart';

/// CWD-safe project root resolution.
/// Tries Platform.script (immune to CWD), then CWD walk (with temp guard),
/// then git rev-parse. Throws [StateError] if the root cannot be found.
String _findProjectRoot() {
  // Strategy 1: Walk up from Platform.script (immune to CWD changes).
  try {
    var dir = File(Platform.script.toFilePath()).parent;
    for (var i = 0; i < 10; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final c = pubspec.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
          return dir.path;
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {
    // Platform.script.toFilePath() may fail if CWD was deleted.
    // Recover CWD to a known-good location and retry.
    try { Directory.current = Directory.systemTemp.path; } catch (_) {}
    try {
      var dir = File(Platform.script.toFilePath()).parent;
      for (var i = 0; i < 10; i++) {
        final pubspec = File('${dir.path}/pubspec.yaml');
        if (pubspec.existsSync()) {
          final c = pubspec.readAsStringSync();
          if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
            return dir.path;
          }
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    } catch (_) {}
  }

  // Strategy 2: Walk up from CWD (may be poisoned, so guard against temp dirs).
  try {
    var dir = Directory.current;
    for (var i = 0; i < 15; i++) {
      final pubspec = File('${dir.path}/pubspec.yaml');
      if (pubspec.existsSync()) {
        final c = pubspec.readAsStringSync();
        if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
          final candidate = dir.path;
          if (!_isTempPath(candidate)) {
            return candidate;
          }
        }
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  } catch (_) {}

  // Strategy 3: git rev-parse as last resort.
  try {
    final result = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    if (result.exitCode == 0) {
      final gitRoot = (result.stdout as String).trim();
      if (!_isTempPath(gitRoot)) {
        final pubspec = File('$gitRoot/pubspec.yaml');
        if (pubspec.existsSync()) {
          final c = pubspec.readAsStringSync();
          if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(c)) {
            return gitRoot;
          }
        }
      }
    }
  } catch (_) {}

  throw StateError(
    'Cannot determine zuraffa project root. '
    'CWD=${Directory.current.path}',
  );
}

/// Returns true if [path] looks like it is inside a temp directory.
bool _isTempPath(String p) {
  final lower = p.toLowerCase();
  return lower.contains('/tmp') ||
      lower.contains(RegExp(r'/temp[/"]')) ||
      lower.contains('/var/folders/') ||
      lower.contains('/noSuchFile') ||
      lower == Directory.systemTemp.path;
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
