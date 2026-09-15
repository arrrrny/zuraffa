// Issue #1418 (secondary): the mock lane's generated files attach their
// `hide` combinator to the `package:zuraffa/mock.dart` import, but the
// names were verified against the `zuraffa.dart` surface
// (`EntityUtils.barrelHideNames` → `ZuraffaBarrelExports.filter`).
// Correctness rested on `src/mock/mock.dart` bare-re-exporting the full
// core surface — an accident of the current barrel layout. A mock barrel
// that diverges (a restricted re-export, a dropped re-export) would emit
// unverified hides again — the exact `undefined_hidden_name` warning
// class that fails `zfa build`'s analyze gate.
//
// The mock lane must verify against the library the import actually
// names: `EntityUtils.mockBarrelHideNames` → `ZuraffaBarrelExports.filterMock`,
// resolved from the resolved zuraffa package's `lib/mock.dart` export
// chain.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/utils/entity_utils.dart';
import 'package:zuraffa/src/utils/zuraffa_barrel_exports.dart';

/// Builds a fixture "target project" whose resolved `zuraffa` package
/// ships the given barrel files. [mockBarrel] is the `lib/mock.dart`
/// content (null = the package ships no mock barrel at all — the
/// unresolved case).
Future<Directory> seedFixturePackage({
  required String coreBarrel,
  String? mockBarrel,
  Map<String, String> extraFiles = const {},
}) async {
  final root = Directory.systemTemp.createTempSync('zfa_mock_surface_');
  final zuraffaRoot = p.join(root.path, 'zuraffa');
  Directory(p.join(zuraffaRoot, 'lib', 'src', 'mock')).createSync(
    recursive: true,
  );
  File(p.join(zuraffaRoot, 'lib', 'zuraffa.dart')).writeAsStringSync(
    coreBarrel,
  );
  if (mockBarrel != null) {
    File(p.join(zuraffaRoot, 'lib', 'mock.dart')).writeAsStringSync(
      mockBarrel,
    );
  }
  extraFiles.forEach((relative, content) {
    final file = File(p.join(zuraffaRoot, 'lib', relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  });
  final dotTool = Directory(p.join(root.path, '.dart_tool'));
  dotTool.createSync(recursive: true);
  File(p.join(dotTool.path, 'package_config.json')).writeAsStringSync(
    jsonEncode({
      'configVersion': 2,
      'packages': [
        {
          'name': 'zuraffa',
          'rootUri': Uri.file(zuraffaRoot).toString(),
          'packageUri': 'lib/',
        },
      ],
    }),
  );
  ZuraffaBarrelExports.seed(root.path);
  return root;
}

const _coreBarrel = "export 'src/core.dart';\n";
const _coreSource = 'class Credentials {}\nclass CredentialsPatch {}\n';

void main() {
  tearDown(() {
    ZuraffaBarrelExports.reset();
  });

  group('mock barrel surface resolution (#1418)', () {
    late Directory fixture;

    tearDown(() {
      if (fixture.existsSync()) fixture.deleteSync(recursive: true);
    });

    test('T6: a bare zuraffa re-export unions the core surface (the '
        'current lib/src/mock/mock.dart layout)', () async {
      fixture = await seedFixturePackage(
        coreBarrel: _coreBarrel,
        mockBarrel: "export 'src/mock/mock.dart';\n",
        extraFiles: {
          'src/core.dart': _coreSource,
          'src/mock/mock.dart': "export 'package:zuraffa/zuraffa.dart';\n",
        },
      );

      expect(
        EntityUtils.mockBarrelHideNames('Credentials'),
        ['Credentials', 'CredentialsPatch'],
        reason:
            'the #942 collision protection carries over through the mock '
            'barrel: the bare re-export unions the core surface',
      );
    });

    test('T7: a name the mock barrel does not export is dropped '
        '(show-restricted re-export)', () async {
      fixture = await seedFixturePackage(
        coreBarrel: _coreBarrel,
        mockBarrel: "export 'src/mock/mock.dart';\n",
        extraFiles: {
          'src/core.dart': _coreSource,
          // The mock barrel restricts its re-export: Credentials does not
          // come through the mock import — hiding it there is an
          // undefined_hidden_name warning.
          'src/mock/mock.dart':
              "export 'package:zuraffa/zuraffa.dart' show Unrelated;\n",
        },
      );

      expect(
        EntityUtils.mockBarrelHideNames('Credentials'),
        isEmpty,
        reason:
            'the hide is attached to package:zuraffa/mock.dart — a name '
            'that library does not export must never be emitted',
      );
    });

    test('T8: mock-barrel-local declarations along the relative export '
        'chain verify', () async {
      fixture = await seedFixturePackage(
        coreBarrel: _coreBarrel,
        mockBarrel: "export 'src/mock/mock.dart';\n",
        extraFiles: {
          'src/core.dart': _coreSource,
          'src/mock/mock.dart':
              "export 'package:zuraffa/zuraffa.dart';\n"
              'class MockSurfaceProbe {}\n',
        },
      );

      expect(
        EntityUtils.mockBarrelHideNames('MockSurfaceProbe'),
        ['MockSurfaceProbe'],
      );
    });

    test('T9: unresolved mock barrel (no lib/mock.dart) drops the hide '
        'entirely (#1530 FR-001 carryover)', () async {
      fixture = await seedFixturePackage(coreBarrel: _coreBarrel);

      expect(
        EntityUtils.mockBarrelHideNames('Credentials'),
        isEmpty,
        reason:
            'an unresolved surface yields an EMPTY list — no hide '
            'combinator at all, never an unverified name',
      );
    });

    test('T11: seedForTest seeds both surfaces (existing seeded pins '
        'keep their byte-exact behavior)', () async {
      ZuraffaBarrelExports.reset();
      ZuraffaBarrelExports.seedForTest({'Probe', 'ProbePatch'});

      expect(EntityUtils.barrelHideNames('Probe'), ['Probe', 'ProbePatch']);
      expect(
        EntityUtils.mockBarrelHideNames('Probe'),
        ['Probe', 'ProbePatch'],
        reason:
            'a test that pins a surface intends "these names are '
            'verified" for whichever library the emission site imports',
      );
    });
  });

  group('mock lane emission verifies the library it imports (#1418)', () {
    late Directory fixture;
    late Directory workspace;
    late String outputDir;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_mock_lane_');
      outputDir = p.join(workspace.path, 'lib', 'src');
      await Directory(
        p.join(outputDir, 'domain', 'entities', 'credentials'),
      ).create(recursive: true);
      await File(
        p.join(outputDir, 'domain', 'entities', 'credentials',
            'credentials.dart'),
      ).writeAsString('''
class Credentials {
  final String id;
  const Credentials({required this.id});
}

class CredentialsPatch {
  final String? id;
  const CredentialsPatch({this.id});
}
''');
    });

    tearDown(() {
      ZuraffaBarrelExports.reset();
      if (fixture.existsSync()) fixture.deleteSync(recursive: true);
      if (workspace.existsSync()) workspace.deleteSync(recursive: true);
    });

    test('T10: the mock datasource hides Credentials from '
        'package:zuraffa/mock.dart only when the MOCK barrel exports it',
        () async {
      // Diverged surface: the CORE barrel exports Credentials (so the
      // legacy core-surface check would emit the hide), but the MOCK
      // barrel restricts its re-export past it.
      fixture = await seedFixturePackage(
        coreBarrel: _coreBarrel,
        mockBarrel: "export 'src/mock/mock.dart';\n",
        extraFiles: {
          'src/core.dart': _coreSource,
          'src/mock/mock.dart':
              "export 'package:zuraffa/zuraffa.dart' show Unrelated;\n",
        },
      );

      final files = await MockPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
        fileSystem: FileSystem.create(root: workspace.path),
      ).generateWithContext(
        PluginContext(
          core: CoreConfig(
            name: 'Credentials',
            projectRoot: workspace.path,
            outputDir: outputDir,
            force: true,
          ),
          data: <String, dynamic>{
            'mock': true,
            'data': true,
            'methods': const ['get', 'update', 'toggle'],
            'id-field': 'id',
            'id-field-type': 'String',
            'query-field': 'id',
          },
          discovery: DiscoveryEngine(
            projectRoot: workspace.path,
            fileSystem: FileSystem.create(root: workspace.path),
          ),
          fileSystem: FileSystem.create(root: workspace.path),
        ),
      );

      final mockDs = files
          .map((f) => f.path)
          .firstWhere((path) => path.endsWith('mock_datasource.dart'));
      final content = File(
        p.isAbsolute(mockDs) ? mockDs : p.join(workspace.path, mockDs),
      ).readAsStringSync();

      expect(
        content,
        isNot(contains('hide Credentials')),
        reason:
            '#1418: the mock.dart import must not hide a name the mock '
            'barrel does not export — an unverified hide is the '
            'undefined_hidden_name warning that fails the analyze gate '
            '(out:\n$content)',
      );
    });
  });
}
