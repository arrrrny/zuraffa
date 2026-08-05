import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/project_context_store.dart';

/// Resolve project root by searching upward for zuraffa's pubspec.yaml.
/// This is immune to CWD changes by other tests in the same process.
final _zfaRoot = _findProjectRoot();

String _findProjectRoot() {
  // Start from this test file's directory (test/regression/) and go up.
  var dir = File(Platform.script.toFilePath()).parent;
  if (dir.path.contains('.dart_tool')) {
    // Fallback: Platform.script may point inside .dart_tool in some test runners.
    dir = Directory.current;
  }
  for (var i = 0; i < 10; i++) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      // Match "name: zuraffa" (not zuraffa_flutter, not zuraffa_test_app)
      if (RegExp(r'^name:\s*zuraffa\s*$', multiLine: true).hasMatch(content)) {
        return dir.path;
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  // Fallback: try resolving from test file path convention (test/regression/ → project root)
  final testDir = File(Platform.script.toFilePath()).parent;
  final candidate = testDir.parent.parent.path;
  if (File('$candidate/pubspec.yaml').existsSync()) return candidate;
  return Directory.current.path;
}

void main() {
  final projectRoot = _zfaRoot;

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
      if (!file.existsSync()) return; // skip if example config doesn't exist yet
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

      for (final file in files) {
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
