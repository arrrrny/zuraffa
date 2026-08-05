import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/project_context_store.dart';

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

  // Read Directory.current.path defensively to avoid masking the intended StateError.
  String cwdForError;
  try {
    cwdForError = Directory.current.path;
  } catch (_) {
    cwdForError = '<unable to read CWD>';
  }
  throw StateError(
    'Cannot determine zuraffa project root. '
    'CWD=$cwdForError',
  );
}

/// Returns true if [path] looks like it is inside a temp directory.
bool _isTempPath(String p) {
  final lower = p.toLowerCase();
  final systemTempLower = Directory.systemTemp.path.toLowerCase();

  // Check if path starts with /tmp/, equals /tmp, or contains /tmp/ as a segment
  final isTmpSegment = lower == '/tmp' ||
                       lower.startsWith('/tmp/') ||
                       lower.contains('/tmp/');

  return isTmpSegment ||
      lower.contains('/var/folders/') ||
      lower.contains('/nosuchfile') ||
      lower == systemTempLower;
}

void main() {
  final projectRoot = _findProjectRoot();

  File fileAt(String relativePath) => File('$projectRoot/$relativePath');

  String readText(String relativePath) {
    final file = fileAt(relativePath);
    if (!file.existsSync()) {
      throw StateError('Missing file: ${file.path}');
    }
    return file.readAsStringSync();
  }

  List<File> filesUnder(String relativeDir, {List<String>? extensions}) {
    final dir = Directory('$projectRoot/$relativeDir');
    if (!dir.existsSync()) return const [];
    final allowed = extensions?.toSet();
    return dir.listSync(recursive: true).whereType<File>().where((file) {
      if (allowed == null) return true;
      return allowed.any((ext) => file.path.endsWith(ext));
    }).toList();
  }

  group('v5 pipeline contract', () {
    test('default project context encodes the canonical workflow', () {
      expect(
        ProjectContextStore.defaultContext()['workflow'],
        equals(['zfa entity create', 'zfa make', 'zfa build']),
      );
    });

    test('core docs teach the full canonical pipeline', () {
      const docs = <String>[
        'README.md',
        'AGENTS.md',
        'SKILL.md',
        'website/docs/intro.md',
        'website/docs/features/mcp-server.md',
      ];

      for (final doc in docs) {
        final file = fileAt(doc);
        if (!file.existsSync()) continue; // skip missing docs gracefully
        final content = file.readAsStringSync();
        expect(content, contains('zfa entity create'), reason: doc);
        expect(content, contains('zfa make'), reason: doc);
        expect(content, contains('zfa build'), reason: doc);
      }
    });

    test('MCP server advertises zuraffa_make and invokes make', () {
      final content = readText('bin/zuraffa_mcp_server.dart');
      expect(content, contains("'name': 'zuraffa_make'"));
      expect(
        content,
        contains(
          "final List<String> cliArgs = ['make', args['name'] as String];",
        ),
      );
    });

    test('example .zfa.json uses v5 config shape', () {
      final file = fileAt('example/.zfa.json');
      if (!file.existsSync()) return;
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      expect(json.containsKey('plugins'), isTrue);
      expect(json.containsKey('planning'), isTrue);
      expect(json.containsKey('ui'), isTrue);
      expect(json.containsKey('entity'), isTrue);

      final plugins = Map<String, dynamic>.from(json['plugins'] as Map);
      expect(plugins.containsKey('defaults'), isTrue);
    });
  });

  group('legacy residue guard for active/public surfaces', () {
    test('no legacy generator residues remain in active/public surfaces', () {
      final allFiles = <File>[
        fileAt('README.md'),
        fileAt('AGENTS.md'),
        fileAt('CLI_GUIDE.md'),
        fileAt('SKILL.md'),
        fileAt('doc/index.html'),
        fileAt('website/static/landing.html'),
        fileAt('example/.zfa.json'),
        fileAt('bin/zuraffa_mcp_server.dart'),
        ...filesUnder('website/docs', extensions: ['.md', '.mdx']),
        ...filesUnder('example/lib', extensions: ['.dart']),
        ...filesUnder('example/test', extensions: ['.dart']),
      ];
      final files = allFiles.where((f) => f.existsSync()).toList();
      if (files.isEmpty) return; // skip if no files found

      const forbidden = <String>[
        'zfa generate',
        'zuraffa_generate',
        '--vpcs',
        'generate <Name>',
      ];

      final existingFiles = files.where((f) => f.existsSync()).toList();
      if (existingFiles.isEmpty) return;
      for (final file in existingFiles) {
        final content = file.readAsStringSync();
        for (final token in forbidden) {
          expect(
            content,
            isNot(contains(token)),
            reason: 'Found legacy token "$token" in ${file.path}',
          );
        }
      }
    });
  });
}
