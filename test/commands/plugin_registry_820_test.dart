import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/registry/plugin_manifest.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('plugin_reg_test_');
    addTearDown(() => tmp.deleteSync(recursive: true));
  });

  Future<String> drive(List<String> args) async {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([...args, '--root', tmp.path]);
  }

  String signManifest(Map<String, dynamic> m) {
    // Build a PluginManifest from the map's capabilities, sign, inject.
    final caps = m['capabilities'] as Map<String, dynamic>;
    final pm = PluginManifest(
      id: m['id'] as String,
      name: m['name'] as String,
      version: m['version'] as String,
      description: (m['description'] ?? '') as String,
      writePaths: (caps['write_paths'] as List).cast<String>(),
      commands: (caps['commands'] as List).cast<String>(),
      tools: (caps['tools'] as List).cast<String>(),
    );
    final sig = PluginManifest.sign(pm.canonical());
    m['signature'] = sig;
    return jsonEncode(m);
  }

  test('install --dry-run prints capability diff', () async {
    // Create a plugin dir with a manifest.
    final pluginDir = Directory(p.join(tmp.path, 'myplugin'))..createSync();
    final manifest = {
      'id': 'my-plugin',
      'name': 'My Plugin',
      'version': '1.0.0',
      'description': 'demo',
      'capabilities': {
        'write_paths': ['lib/src/foo/'],
        'commands': ['zfa foo'],
        'tools': ['app.foo.bar'],
      },
    };
    File(
      p.join(pluginDir.path, 'manifest.json'),
    ).writeAsStringSync(signManifest(manifest));

    final out = await drive(['plugin', 'install', pluginDir.path, '--dry-run']);
    expect(out, contains('Capability diff'));
    expect(out, contains('Write paths'));
    expect(out, contains('lib/src/foo/'));
    expect(out, contains('zfa foo'));
    expect(out, contains('app.foo.bar'));
    expect(out, contains('dry run'));
  });

  test('install with undeclared write paths fails loudly', () async {
    final pluginDir = Directory(p.join(tmp.path, 'badplugin'))..createSync();
    File(p.join(pluginDir.path, 'sneaky.txt')).writeAsStringSync('x');
    final manifest = {
      'id': 'bad-plugin',
      'name': 'Bad Plugin',
      'version': '1.0.0',
      'description': 'demo',
      'capabilities': {
        'write_paths': ['lib/src/foo/'],
        'commands': ['zfa foo'],
        'tools': [],
      },
    };
    File(
      p.join(pluginDir.path, 'manifest.json'),
    ).writeAsStringSync(signManifest(manifest));

    final out = await drive(['plugin', 'install', pluginDir.path]);
    expect(out.toLowerCase(), contains('undeclared'));
    expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
  });

  test('two plugins with overlapping commands conflict', () async {
    // First install a plugin.
    final p1 = Directory(p.join(tmp.path, 'p1'))..createSync();
    final m1 = {
      'id': 'p1',
      'name': 'P1',
      'version': '1.0.0',
      'description': 'd',
      'capabilities': {
        'write_paths': ['lib/src/a/'],
        'commands': ['zfa shared'],
        'tools': [],
      },
    };
    File(p.join(p1.path, 'manifest.json')).writeAsStringSync(signManifest(m1));
    await drive(['plugin', 'install', p1.path]);

    // Second plugin with overlapping command.
    final p2 = Directory(p.join(tmp.path, 'p2'))..createSync();
    final m2 = {
      'id': 'p2',
      'name': 'P2',
      'version': '1.0.0',
      'description': 'd',
      'capabilities': {
        'write_paths': ['lib/src/b/'],
        'commands': ['zfa shared'],
        'tools': [],
      },
    };
    File(p.join(p2.path, 'manifest.json')).writeAsStringSync(signManifest(m2));
    final out = await drive(['plugin', 'install', p2.path]);
    expect(out.toLowerCase(), contains('conflict'));
    expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
  });

  test('verify passes for signed manifest', () async {
    final pluginDir = Directory(p.join(tmp.path, 'vplugin'))..createSync();
    final manifest = {
      'id': 'v-plugin',
      'name': 'V',
      'version': '1.0.0',
      'description': 'd',
      'capabilities': {'write_paths': [], 'commands': [], 'tools': []},
    };
    File(
      p.join(pluginDir.path, 'manifest.json'),
    ).writeAsStringSync(signManifest(manifest));
    final out = await drive(['plugin', 'verify', pluginDir.path]);
    expect(out, contains('Verification passed'));
  });

  test(
    'undeclared sibling-prefix file is not masked by loose prefix',
    () async {
      final pluginDir = Directory(p.join(tmp.path, 'sibplugin'))..createSync();
      final sub = Directory(p.join(pluginDir.path, 'lib', 'src', 'foobar'))
        ..createSync(recursive: true);
      File(p.join(sub.path, 'x.txt')).writeAsStringSync('x');
      final manifest = {
        'id': 'sib-plugin',
        'name': 'Sib Plugin',
        'version': '1.0.0',
        'description': 'demo',
        'capabilities': {
          'write_paths': ['lib/src/foo'],
          'commands': [],
          'tools': [],
        },
      };
      File(
        p.join(pluginDir.path, 'manifest.json'),
      ).writeAsStringSync(signManifest(manifest));

      final out = await drive(['plugin', 'install', pluginDir.path]);
      expect(out.toLowerCase(), contains('undeclared'));
      expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
    },
  );

  test('dry-run surfaces undeclared write paths', () async {
    final pluginDir = Directory(p.join(tmp.path, 'drybad'))..createSync();
    File(p.join(pluginDir.path, 'sneaky.txt')).writeAsStringSync('x');
    final manifest = {
      'id': 'dry-bad',
      'name': 'Dry Bad',
      'version': '1.0.0',
      'description': 'demo',
      'capabilities': {
        'write_paths': ['lib/src/foo/'],
        'commands': [],
        'tools': [],
      },
    };
    File(
      p.join(pluginDir.path, 'manifest.json'),
    ).writeAsStringSync(signManifest(manifest));

    final out = await drive(['plugin', 'install', pluginDir.path, '--dry-run']);
    expect(out.toLowerCase(), contains('undeclared'));
    expect(CliRunner.lastDispatchedExitCode, isNot(0), reason: out);
  });
}
