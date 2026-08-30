@Tags(['slow'])
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';

// #360 xray default resolution in MakeCommand (see make_command.dart):
//
//   if (xrayFlag || !context.data.containsKey('xray')) { ... config fallback ... }
//
// - An explicit `false` already present in context.data (e.g. via
//   --from-json) must be preserved — the config fallback only fires when
//   the key is absent.
// - An absent key falls back to `.zfa.json`'s `plugins.defaults.xray`.
// - The `--xray` CLI flag always wins.
void main() {
  late Directory workspace;

  setUpAll(() async {
    await initZfaSourceBin();
  });

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_make_xray_');
    await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_make_xray_test
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''');
    final entityDir = Directory(
      path.join(workspace.path, 'lib', 'src', 'domain', 'entities', 'product'),
    );
    await entityDir.create(recursive: true);
    await File(path.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  Future<void> writeConfig({required bool xrayByDefault}) async {
    await File(path.join(workspace.path, '.zfa.json')).writeAsString(
      jsonEncode({
        'plugins': {
          'defaults': {'xray': xrayByDefault},
        },
      }),
    );
  }

  Future<ProcessResult> runZfa(List<String> args) {
    return runZfaSource(args, workingDirectory: workspace.path);
  }

  // Finds every generated `*_view.dart` under the temp project.
  List<File> findViewFiles() {
    final dir = Directory(workspace.path);
    if (!dir.existsSync()) return const [];
    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_view.dart'))
        .toList();
  }

  test(
    'explicit xray:false in --from-json is preserved over the config default',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      // Config says xray defaults ON — but the caller explicitly opts out.
      await writeConfig(xrayByDefault: true);

      final configFile = File(path.join(workspace.path, 'make_config.json'));
      await configFile.writeAsString(
        jsonEncode({
          'name': 'Product',
          'preset': 'crud',
          'with': ['view'],
          'methods': ['get'],
          'xray': false,
        }),
      );

      final result = await runZfa(['make', '--from-json', configFile.path]);
      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );

      final views = findViewFiles();
      expect(views, isNotEmpty, reason: 'expected a generated view file');
      for (final view in views) {
        final content = view.readAsStringSync();
        expect(
          content,
          isNot(contains('XRayScope')),
          reason: '${view.path} must not contain XRayScope when xray=false',
        );
      }
    },
  );

  test(
    'absent xray key falls back to .zfa.json xrayByDefault:true',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      await writeConfig(xrayByDefault: true);

      final result = await runZfa([
        'make',
        'Product',
        '--preset=crud',
        '--with=view',
        '--methods=get',
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );

      final views = findViewFiles();
      expect(views, isNotEmpty, reason: 'expected a generated view file');
      expect(
        views.any((f) => f.readAsStringSync().contains('XRayScope(')),
        isTrue,
        reason: 'expected XRayScope when config xrayByDefault is true',
      );
    },
  );

  test(
    '--xray CLI flag wins over xrayByDefault:false',
    timeout: const Timeout(Duration(minutes: 2)),
    () async {
      await writeConfig(xrayByDefault: false);

      final result = await runZfa([
        'make',
        'Product',
        '--preset=crud',
        '--with=view',
        '--methods=get',
        '--xray',
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );

      final views = findViewFiles();
      expect(views, isNotEmpty, reason: 'expected a generated view file');
      expect(
        views.any((f) => f.readAsStringSync().contains('XRayScope(')),
        isTrue,
        reason: 'expected XRayScope when --xray is passed',
      );
    },
  );
}
