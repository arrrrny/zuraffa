// Spec 1653-trim-heavy-deps (issue #1661) — the plugin gate pins.
//
// U4: the catalog resolves the three optional capabilities to their
//     companion packages; an unknown id refuses naming the catalog
//     (FR-005/FR-006 vocabulary).
// U6: the gate refuses honestly — not-enabled names the enable command;
//     enabled-but-unresolvable names the package and `dart pub get`;
//     enabled-and-resolvable passes (null refusal). A refusal is a
//     MESSAGE, never a crash (FR-008).
// U7: issue #1690 §1 — `companionEntry` anchors a RELATIVE `rootUri` at
//     the package_config's own directory (where pub anchors it for
//     relative `path:` deps), NOT at the process CWD; absolute file://
//     rootUris keep resolving (no regression), and a companion whose bin
//     entry is missing still refuses with null.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/plugin_gate/plugin_catalog.dart';
import 'package:zuraffa/src/plugins/plugin_gate/plugin_gate.dart';

void main() {
  group('U4: the plugin catalog (FR-005/FR-006)', () {
    test('the three optional capabilities resolve to their companions', () {
      expect(PluginCatalog.find('graphql')?.package, 'zuraffa_graphql');
      expect(PluginCatalog.find('storage')?.package, 'zuraffa_storage');
      expect(
        PluginCatalog.find('observability')?.package,
        'zuraffa_observability',
      );
    });

    test('every catalog entry exposes name + package', () {
      expect(PluginCatalog.all, isNotEmpty);
      for (final entry in PluginCatalog.all) {
        expect(entry.name, isNotEmpty);
        expect(entry.package, isNotEmpty);
      }
    });

    test('an unknown id is not in the catalog (the command refuses '
        'naming the catalog)', () {
      expect(PluginCatalog.find('nope'), isNull);
      // The catalog names every valid id so the refusal can list them.
      expect(
        PluginCatalog.all.map((e) => e.name),
        containsAll(['graphql', 'storage', 'observability']),
      );
    });
  });

  group('U6: the gate refuses honestly (FR-008)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('plugin_gate_');
      addTearDown(() => tmp.deleteSync(recursive: true));
    });

    /// Writes a minimal package_config.json declaring [packages] present.
    void seedPackageConfig(List<String> packages) {
      final dotTool = Directory(p.join(tmp.path, '.dart_tool'))
        ..createSync(recursive: true);
      File(p.join(dotTool.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            for (final name in packages)
              {
                'name': name,
                'rootUri': 'file:///x/$name',
                'languageVersion': '3.11',
              },
          ],
        }),
      );
    }

    test('not enabled → refusal names the enable command and the package', () {
      seedPackageConfig([]);
      final refusal = PluginGate.refusalFor(
        'graphql',
        projectRoot: tmp.path,
        capabilities: const {},
      );
      expect(refusal, isNotNull);
      expect(refusal, contains('zfa plugin enable graphql'));
      expect(refusal, contains('zuraffa_graphql'));
    });

    test('enabled but package missing → refusal names the package and '
        'pub get', () {
      seedPackageConfig([]);
      final refusal = PluginGate.refusalFor(
        'graphql',
        projectRoot: tmp.path,
        capabilities: const {'graphql': true},
      );
      expect(refusal, isNotNull);
      expect(refusal, contains('zuraffa_graphql'));
      expect(refusal, contains('pub get'));
    });

    test('enabled and resolvable → usable (null refusal)', () {
      seedPackageConfig(['zuraffa_graphql']);
      final refusal = PluginGate.refusalFor(
        'graphql',
        projectRoot: tmp.path,
        capabilities: const {'graphql': true},
      );
      expect(refusal, isNull);
    });

    test('an unknown capability id refuses naming the catalog', () {
      final refusal = PluginGate.refusalFor(
        'nope',
        projectRoot: tmp.path,
        capabilities: const {},
      );
      expect(refusal, isNotNull);
      expect(refusal, contains('graphql'));
      expect(refusal, contains('observability'));
    });
  });

  group('U7: companionEntry resolves rootUris (#1690 §1)', () {
    late Directory project;
    late Directory companion;

    setUp(() {
      project = Directory.systemTemp.createTempSync('gate_u7_project_');
      companion = Directory.systemTemp.createTempSync('gate_u7_companion_');
      addTearDown(() => project.deleteSync(recursive: true));
      addTearDown(() => companion.deleteSync(recursive: true));
      // A real companion package: bin/zuraffa_graphql.dart exists.
      File(
        p.join(companion.path, 'bin', 'zuraffa_graphql.dart'),
      ).createSync(recursive: true);
    });

    /// Writes the project's package_config.json with a single
    /// zuraffa_graphql entry whose rootUri is [rootUri].
    void seedConfig(Map<String, dynamic> entry) {
      final dotTool = Directory(p.join(project.path, '.dart_tool'))
        ..createSync(recursive: true);
      File(p.join(dotTool.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [entry],
        }),
      );
    }

    test('a RELATIVE rootUri anchors at the package_config directory — '
        'with CWD at the project root (the documented path: install)', () {
      seedConfig({
        'name': 'zuraffa_graphql',
        'rootUri': p.relative(
          companion.path,
          from: p.join(project.path, '.dart_tool'),
        ),
        'languageVersion': '3.11',
      });
      // The bug fires when the CLI runs with CWD = the project root (the
      // user's terminal shape): Directory.current must NOT be consulted.
      final previousCwd = Directory.current.path;
      Directory.current = project.path;
      addTearDown(() => Directory.current = previousCwd);

      final entry = PluginGate.companionEntry(
        'graphql',
        projectRoot: project.path,
      );

      expect(
        entry,
        p.join(companion.path, 'bin', 'zuraffa_graphql.dart'),
        reason:
            'the relative rootUri resolves against .dart_tool/ (where pub '
            'anchors it), not against Directory.current — issue #1690 §1',
      );
      expect(File(entry!).existsSync(), isTrue);
    });

    test('a relative rootUri still resolves when CWD is unrelated to the '
        'project (no reliance on Directory.current)', () {
      seedConfig({
        'name': 'zuraffa_graphql',
        'rootUri': p.relative(
          companion.path,
          from: p.join(project.path, '.dart_tool'),
        ),
        'languageVersion': '3.11',
      });
      final previousCwd = Directory.current.path;
      Directory.current = Directory.systemTemp.path;
      addTearDown(() => Directory.current = previousCwd);

      final entry = PluginGate.companionEntry(
        'graphql',
        projectRoot: project.path,
      );

      expect(entry, p.join(companion.path, 'bin', 'zuraffa_graphql.dart'));
    });

    test('an absolute file:// rootUri keeps resolving (no regression)', () {
      seedConfig({
        'name': 'zuraffa_graphql',
        'rootUri': Uri.file(companion.path).toString(),
        'languageVersion': '3.11',
      });
      final previousCwd = Directory.current.path;
      Directory.current = Directory.systemTemp.path;
      addTearDown(() => Directory.current = previousCwd);

      final entry = PluginGate.companionEntry(
        'graphql',
        projectRoot: project.path,
      );

      expect(entry, p.join(companion.path, 'bin', 'zuraffa_graphql.dart'));
    });

    test('a resolvable companion whose bin entry is missing still returns '
        'null', () {
      File(p.join(companion.path, 'bin', 'zuraffa_graphql.dart')).deleteSync();
      seedConfig({
        'name': 'zuraffa_graphql',
        'rootUri': p.relative(
          companion.path,
          from: p.join(project.path, '.dart_tool'),
        ),
        'languageVersion': '3.11',
      });

      final entry = PluginGate.companionEntry(
        'graphql',
        projectRoot: project.path,
      );

      expect(entry, isNull);
    });
  });
}
