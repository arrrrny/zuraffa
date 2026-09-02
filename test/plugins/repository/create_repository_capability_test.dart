import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/repository/capabilities/create_repository_capability.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;
  late CreateRepositoryCapability capability;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_repo_create_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    final plugin = RepositoryPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );
    capability = CreateRepositoryCapability(plugin);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.delete(recursive: true);
    }
  });

  // Issue #766: `zfa repository create --name X` is the documented minimal
  // invocation (the manifest requires only `name`), yet its schema defaults
  // (`data: false`, `datasource: false`, no `methods` default) diverged from
  // the positional `zfa repository <Entity>` path (`data: true`,
  // `datasource: true`, `methods: get,update`). With the schema defaults the
  // config was not entity-based, the plugin generated ZERO files, and the
  // command still reported success. The `create` subcommand must produce the
  // same compilable trio as the positional path by default.
  group('issue #766 — repository create default flags', () {
    test(
      'minimal invocation generates interface, implementation and datasource',
      () async {
        final result = await capability.execute({'name': 'Widget'});

        expect(result.success, isTrue);
        final paths = result.files;
        expect(
          paths.where(
            (p) => p.endsWith('domain/repositories/widget_repository.dart'),
          ),
          hasLength(1),
          reason: 'the abstract repository interface must be generated',
        );
        expect(
          paths.where(
            (p) => p.endsWith('data/repositories/data_widget_repository.dart'),
          ),
          hasLength(1),
          reason: 'the data repository implementation must be generated',
        );
        expect(
          paths.where(
            (p) => p.endsWith('data/datasources/widget/widget_datasource.dart'),
          ),
          hasLength(1),
          reason:
              'the datasource interface imported by the implementation must be generated',
        );
      },
    );

    test('generated trio is internally consistent (imports resolve)', () async {
      final result = await capability.execute({'name': 'Widget'});
      final generated = result.data?['generatedFiles'] as List<dynamic>;

      final interface = generated.firstWhere(
        (f) => f.path.endsWith('domain/repositories/widget_repository.dart'),
      );
      final impl = generated.firstWhere(
        (f) => f.path.endsWith('data/repositories/data_widget_repository.dart'),
      );
      final datasource = generated.firstWhere(
        (f) =>
            f.path.endsWith('data/datasources/widget/widget_datasource.dart'),
      );

      expect(interface.content, contains('abstract class WidgetRepository'));
      expect(impl.content, contains('class DataWidgetRepository'));
      expect(impl.content, contains('implements WidgetRepository'));
      expect(
        impl.content,
        contains('../datasources/widget/widget_datasource.dart'),
        reason: 'the implementation imports the emitted datasource interface',
      );
      expect(datasource.content, contains('WidgetDataSource'));

      // The files really land on disk (not just in-memory metadata).
      expect(
        File(interface.path).existsSync(),
        isTrue,
        reason: 'interface file is written',
      );
      expect(
        File(impl.path).existsSync(),
        isTrue,
        reason: 'implementation file is written',
      );
    });

    test('schema defaults match the positional CLI contract', () {
      final props =
          capability.inputSchema['properties'] as Map<String, dynamic>;
      expect(
        (props['data'] as Map<String, dynamic>)['default'],
        isTrue,
        reason: 'positional `zfa repository <Entity>` defaults data to true',
      );
      expect(
        (props['datasource'] as Map<String, dynamic>)['default'],
        isTrue,
        reason:
            'positional `zfa repository <Entity>` defaults datasource to true',
      );
      expect(
        (props['methods'] as Map<String, dynamic>)['default'],
        ['get', 'update'],
        reason:
            'positional `zfa repository <Entity>` defaults methods to get,update',
      );
    });

    test(
      'explicit opt-out (data:false, methods:[]) is still honored',
      () async {
        final result = await capability.execute({
          'name': 'Widget',
          'data': false,
          'datasource': false,
          'methods': <String>[],
        });

        // Custom-usecase request with nothing to generate: zero files. The
        // CLI-level zero-file guard (issue #769) reports this honestly.
        expect(result.files, isEmpty);
      },
    );
  });
}
