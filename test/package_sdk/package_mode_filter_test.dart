@Tags(['slow'])
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/app_shell_command.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_interface.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_manager.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

class _FakePlugin extends ZuraffaPlugin {
  _FakePlugin(this.id);

  @override
  final String id;

  @override
  String get name => id;

  @override
  String get version => '1.0.0';
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_pkg_filter_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Directory makeProject({required bool packageMode, String name = 'my_pkg'}) {
    final dir = Directory(p.join(tempDir.path, name))..createSync();
    File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: $name\n');
    File(p.join(dir.path, 'zfa.yaml')).writeAsStringSync(
      packageMode ? 'package_mode: true\n' : 'other_key: value\n',
    );
    return dir;
  }

  group('PluginManager package-mode filter (FR-003 — spec 025)', () {
    test(
      'U16: app-only plugins dropped in package mode; core plugins stay',
      () {
        final pkgDir = makeProject(packageMode: true);

        final registry = PluginRegistry()
          ..registerAll([
            _FakePlugin('datasource'),
            _FakePlugin('repository'),
            _FakePlugin('usecase'),
            _FakePlugin('di'),
            _FakePlugin('route'),
            _FakePlugin('view'),
            _FakePlugin('presenter'),
            _FakePlugin('controller'),
            _FakePlugin('app_shell'),
          ]);

        final manager = PluginManager(
          registry: registry,
          projectRoot: pkgDir.path,
        );

        final plan = manager.resolvePlan(
          name: 'Product',
          explicitPluginIds: [
            'datasource',
            'repository',
            'usecase',
            'di',
            'route',
            'view',
            'presenter',
            'controller',
            'app_shell',
          ],
        );

        final ids = plan.activePlugins.map((plugin) => plugin.id).toSet();
        expect(ids, containsAll(['datasource', 'repository', 'usecase', 'di']));
        expect(
          ids,
          isNot(contains('route')),
          reason: 'routes are app artifacts (FR-003)',
        );
        expect(
          ids,
          isNot(contains('view')),
          reason: 'presentation is app-side (FR-003)',
        );
        expect(ids, isNot(contains('presenter')));
        expect(ids, isNot(contains('controller')));
        expect(ids, isNot(contains('app_shell')));
      },
    );

    test('U16b: app mode keeps every requested plugin', () {
      final appDir = makeProject(packageMode: false, name: 'my_app');

      final registry = PluginRegistry()
        ..registerAll([
          _FakePlugin('datasource'),
          _FakePlugin('route'),
          _FakePlugin('view'),
        ]);

      final manager = PluginManager(
        registry: registry,
        projectRoot: appDir.path,
      );

      final plan = manager.resolvePlan(
        name: 'Product',
        explicitPluginIds: ['datasource', 'route', 'view'],
      );

      final ids = plan.activePlugins.map((plugin) => plugin.id).toSet();
      expect(ids, containsAll(['datasource', 'route', 'view']));
    });
  });

  group('zfa app shell package-mode guard (FR-003 — spec 025)', () {
    test('U17: app shell refuses in a package-mode project', () async {
      final pkgDir = makeProject(packageMode: true);

      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(AppCommand());
      await expectLater(
        runner.run(['app', 'shell', '--root', pkgDir.path]),
        throwsA(
          isA<AppShellException>().having(
            (e) => e.message,
            'message',
            contains('package'),
          ),
        ),
      );
    });
  });

  group('generation parity app vs package (SC-003 — spec 025)', () {
    test(
      'U18: domain/data files byte-identical; only DI emission differs',
      () async {
        final appDir = makeProject(packageMode: false, name: 'parity_app');
        final pkgDir = makeProject(packageMode: true, name: 'parity_pkg');

        Future<void> generateIn(Directory dir) async {
          final outputDir = p.join(dir.path, 'lib', 'src');
          await Directory(outputDir).create(recursive: true);
          final generator = CodeGenerator(
            config: GeneratorConfig(
              name: 'Product',
              methods: const ['get', 'getList', 'create', 'update', 'delete'],
              generateData: true,
              generateUseCase: true,
              generateDi: true,
              outputDir: outputDir,
              dryRun: false,
              force: true,
            ),
            outputDir: outputDir,
          );
          await generator.generate();
        }

        await generateIn(appDir);
        await generateIn(pkgDir);

        // 1. Domain + data layers are byte-identical between contexts.
        final appFiles = _collect(
          p.join(appDir.path, 'lib', 'src'),
          skipTopDirs: const {'di', 'presentation', 'routing'},
        );
        final pkgFiles = _collect(
          p.join(pkgDir.path, 'lib', 'src'),
          skipTopDirs: const {'di', 'presentation', 'routing'},
        );

        expect(
          appFiles.keys,
          isNotEmpty,
          reason: 'app context must generate domain/data files',
        );
        expect(
          pkgFiles.keys,
          equals(appFiles.keys),
          reason: 'package context must generate the same file set',
        );

        var identical = 0;
        appFiles.forEach((relPath, content) {
          final pkgContent = pkgFiles[relPath]!;
          if (pkgContent == content) identical++;
        });
        final overlap = identical / appFiles.length;
        expect(
          overlap,
          greaterThanOrEqualTo(0.9),
          reason:
              'SC-003: >=90% of domain/data must be identical '
              '(actual: $overlap)',
        );

        // 2. DI emission differs: package has registrar; app has locator.
        expect(
          File(
            p.join(
              pkgDir.path,
              'lib',
              'src',
              'di',
              'parity_pkg_package_registrar.dart',
            ),
          ).existsSync(),
          isTrue,
          reason: 'package context emits the package registrar',
        );
        expect(
          File(
            p.join(appDir.path, 'lib', 'src', 'di', 'service_locator.dart'),
          ).existsSync(),
          isTrue,
          reason: 'app context emits the service locator',
        );
        expect(
          File(
            p.join(pkgDir.path, 'lib', 'src', 'di', 'service_locator.dart'),
          ).existsSync(),
          isFalse,
        );
      },
    );
  });
}

/// Collects all files under [root], keyed by relative path, skipping files
/// whose top-level directory is in [skipTopDirs].
Map<String, String> _collect(String root, {required Set<String> skipTopDirs}) {
  final out = <String, String>{};
  final dir = Directory(root);
  if (!dir.existsSync()) return out;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: root);
    final segments = p.split(rel);
    if (segments.length > 1 && skipTopDirs.contains(segments.first)) continue;
    out[rel] = entity.readAsStringSync();
  }
  return out;
}
