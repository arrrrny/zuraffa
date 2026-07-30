import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zuraffa/src/core/project/project_context_store.dart';

void main() {
  final projectRoot = Directory.current.path;

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
        final content = readText(doc);
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

    test('MCP server never falls back to echoing commands', () {
      final content = readText('bin/zuraffa_mcp_server.dart');
      // The silent echo fallback made tools pretend to succeed (#150, #156).
      expect(content, isNot(contains("_cachedExecutable = 'echo'")));
      expect(content, contains('Never echo'));
    });

    test('MCP server advertises zuraffa_setup and adds deps via pub add', () {
      final content = readText('bin/zuraffa_mcp_server.dart');
      expect(content, contains("'name': 'zuraffa_setup'"));
      expect(content, contains("case 'zuraffa_setup':"));
      // Setup exists for the case where no zfa CLI is resolvable yet, so it
      // cannot delegate to the CLI — it must run `dart pub add` directly.
      expect(content, contains("'pub', 'add'"));
    });

    test('MCP config_init reports missing code-gen dependencies', () {
      final content = readText('bin/zuraffa_mcp_server.dart');
      expect(content, contains('_runConfigInitCommand'));
      expect(content, contains('Dependency check'));
    });

    test('example .zfa.json uses v5 config shape', () {
      final content = readText('example/.zfa.json');
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
      final files = <File>[
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
