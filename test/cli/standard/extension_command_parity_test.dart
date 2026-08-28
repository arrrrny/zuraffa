// Parity test: every `zfa manifest` command must be registered in the speckit
// zuraffa extension (extension.yml `provides:`), and each command .md must follow
// the template shape. Drives the CLI via a subprocess so it tracks the real
// command surface, not a snapshot.
//
// Traces to spec.md AC1 (registry coverage), AC2 (doc shape), AC3 (0 missing).
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const String extensionYml = '.specify/extensions/zuraffa/extension.yml';
const String extensionRoot = '.specify/extensions/zuraffa';

/// Map a manifest (plugin, name) pair to the `zfa` alias the extension is
/// expected to register. The mapping is irregular by design; the known
/// exceptions are encoded here rather than worked around in the extension.
String expectedAlias(String plugin, String name) {
  if (plugin == 'method_append') {
    return name == 'append' ? 'zfa.method-append' : 'zfa.method';
  }
  if (plugin == 'feature' && name == 'scaffold') {
    return 'zfa.scaffold';
  }
  if (name == 'private-method') {
    return 'zfa.$plugin.private';
  }
  if (name == 'create') {
    return 'zfa.$plugin';
  }
  return 'zfa.$plugin.$name';
}

Future<List<Map<String, String>>> loadManifest() async {
  final result = await Process.run('dart', ['run', 'bin/zfa.dart', 'manifest']);
  if (result.exitCode != 0) {
    throw StateError(
      'zfa manifest failed (${result.exitCode}):\n${result.stderr}',
    );
  }
  final List<dynamic> raw = jsonDecode(result.stdout as String) as List<dynamic>;
  return raw
      .map((e) => {
            'plugin': (e as Map)['plugin'] as String,
            'name': e['name'] as String,
          })
      .toList();
}

({Map<String, String> aliasesToFile, Set<String> aliases})
    parseExtensionProvides() {
  final doc = loadYaml(File(extensionYml).readAsStringSync()) as Map;
  final commands = (doc['provides'] as Map)['commands'] as List;
  final aliasesToFile = <String, String>{};
  final aliases = <String>{};
  for (final c in commands) {
    final entry = c as Map;
    final file = entry['file'] as String;
    final aliasList = (entry['aliases'] as List?) ?? const [];
    for (final a in aliasList) {
      aliases.add(a as String);
      aliasesToFile[a as String] = file;
    }
  }
  return (aliasesToFile: aliasesToFile, aliases: aliases);
}

void main() {
  test('every zfa manifest command is registered in the speckit extension',
      () async {
    final manifest = await loadManifest();
    final (:aliasesToFile, :aliases) = parseExtensionProvides();

    final missing = <String>[];
    final missingFiles = <String>[];
    for (final cmd in manifest) {
      final alias = expectedAlias(cmd['plugin']!, cmd['name']!);
      if (!aliases.contains(alias)) {
        missing.add('${cmd['plugin']}/${cmd['name']} -> $alias');
        continue;
      }
      final file = aliasesToFile[alias]!;
      if (!File('$extensionRoot/$file').existsSync()) {
        missingFiles.add('$alias -> $file (file missing)');
      }
    }

    expect(missing, isEmpty,
        reason: 'manifest commands with no extension provides entry:\n'
            '${missing.join('\n')}');
    expect(missingFiles, isEmpty,
        reason: 'provides entries referencing missing files:\n'
            '${missingFiles.join('\n')}');
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('each command .md follows the template shape', () {
    final (:aliasesToFile, :aliases) = parseExtensionProvides();
    final requiredSections = [
      '## Usage',
      '## When to Use',
    ];
    final bad = <String>[];
    for (final alias in aliases) {
      final file = aliasesToFile[alias]!;
      final path = '$extensionRoot/$file';
      if (!File(path).existsSync()) {
        bad.add('$alias -> $file (missing)');
        continue;
      }
      final content = File(path).readAsStringSync();
      if (!content.startsWith('---') || !content.contains('name:')) {
        bad.add('$alias -> $file (no frontmatter)');
      }
      for (final section in requiredSections) {
        if (!content.contains(section)) {
          bad.add('$alias -> $file (missing "$section")');
        }
      }
    }
    expect(bad, isEmpty,
        reason: 'command .md files not matching the template:\n${bad.join('\n')}');
  });
}
