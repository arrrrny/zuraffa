// Issue #1418 (engine tier): the `--force`-regenerated pair — interface
// rewritten from the CHANGED --methods selection together with the mock —
// must pass a REAL scoped `dart analyze` with zero errors. The unit file
// (mock_builder_1418_force_interface_test.dart) pins the source-level
// contract; this file pins the compile bar the certification gate dies on
// (`Missing concrete implementation of '<Entity>DataSource.<old>'`).
//
// Sequence = the issue's exact reproduction, driven through MockPlugin
// inside a throwaway consumer package:
//   run 1: methods=[list]        → interface + mock for list(NoParams)
//   run 2: methods=[getList] + force → the pair must re-align on
//          getList(ListQueryParams<Deal>) and analyze clean.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

import '../../helpers/engine_tier_fixture.dart';

const String _entitySource = '''
class Deal {
  final String id;
  final String title;
  const Deal({required this.id, required this.title});
}

class DealPatch {
  final String? id;
  final String? title;
  const DealPatch({this.id, this.title});
}
''';

void main() {
  late EngineTierFixture fx;

  setUpAll(() async {
    fx = await EngineTierFixture.create(name: 'mock_1418_force_fixture');
    await fx.write(
      'lib/src/domain/entities/deal/deal.dart',
      _entitySource,
    );

    // Run 1 — the pair as first created (`mock create Deal --methods list`).
    final fs = FileSystem.create();
    await MockPlugin(
      outputDir: fx.libSrc,
      options: const GeneratorOptions(force: true),
      fileSystem: fs,
    ).generateWithContext(
      PluginContext(
        core: CoreConfig(
          name: 'Deal',
          projectRoot: fx.root.path,
          outputDir: fx.libSrc,
          force: true,
        ),
        data: <String, dynamic>{
          'mock': true,
          'data': true,
          'methods': const ['list'],
          'id-field': 'id',
          'id-field-type': 'String',
          'query-field': 'id',
        },
        discovery: DiscoveryEngine(
          projectRoot: fx.root.path,
          fileSystem: fs,
        ),
        fileSystem: fs,
      ),
    );
    expect(
      fx.read('lib/src/data/datasources/deal/deal_datasource.dart'),
      contains('list(NoParams'),
      reason: 'precondition: run 1 wrote the list-shaped interface',
    );

    // Run 2 — the issue's failing command: --methods getList --force.
    final fs2 = FileSystem.create();
    await MockPlugin(
      outputDir: fx.libSrc,
      options: const GeneratorOptions(force: true),
      fileSystem: fs2,
    ).generateWithContext(
      PluginContext(
        core: CoreConfig(
          name: 'Deal',
          projectRoot: fx.root.path,
          outputDir: fx.libSrc,
          force: true,
        ),
        data: <String, dynamic>{
          'mock': true,
          'data': true,
          'methods': const ['getList'],
          'id-field': 'id',
          'id-field-type': 'String',
          'query-field': 'id',
        },
        discovery: DiscoveryEngine(
          projectRoot: fx.root.path,
          fileSystem: fs2,
        ),
        fileSystem: fs2,
      ),
    );

    final interface = fx.read(
      'lib/src/data/datasources/deal/deal_datasource.dart',
    );
    expect(
      interface,
      contains('getList(ListQueryParams<Deal>'),
      reason: '#1418: --force regenerates the interface from the current '
          '--methods (out:\n$interface)',
    );

    await fx.pubGet();
  });

  tearDownAll(() async {
    await fx.dispose();
  });

  test('the --force-regenerated pair (methods changed list → getList) '
      'passes a real scoped dart analyze with zero errors', () async {
    final result = await fx.analyzeLib();
    expect(
      result.exitCode,
      0,
      reason:
          'the certification gate dead-ends on exactly this compile bar — '
          'a stale interface member against a regenerated mock is the '
          '"Missing concrete implementation" drift (out:\n'
          '${result.stdout}\n${result.stderr})',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
