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

    test('MCP server advertises zuraffa_register and invokes in-process', () {
      final content = readText('bin/zuraffa_mcp_server.dart');
      expect(content, contains("'name': 'zuraffa_register'"));
      expect(content, contains('RegisterCommand()'));
      expect(content, contains('RegisterCommand'));
    });

    test('MCP register tool uses in-process API not subprocess', () {
      final content = readText('bin/zuraffa_mcp_server.dart');
      // The register tool should call RegisterCommand directly,
      // NOT _runZuraffaProcess (which spawns external CLI)
      expect(content, contains('final cmd = RegisterCommand();'));
      expect(content, contains('await cmd.execute(registerArgs)'));
    });

    test('MCP register tool has required name parameter', () {
      final content = readText('bin/zuraffa_mcp_server.dart');
      expect(content, contains("'required': ['name']"));
      expect(
        content,
        contains(
          "'UseCase name in PascalCase (e.g., GetProduct, CreateOrder)'",
        ),
      );
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
