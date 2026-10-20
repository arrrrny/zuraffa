@Tags(['slow'])
// Issue #1923 compile tier: the synthesized paged-read body for a
// foreign-entity return (`getZikZaks(...) -> Future<ZikZakPage>`, where
// `ZikZakPage` wraps `List<ZikZak>`) must COMPILE against the interface the
// datasource writer emits for the same named-member shape — the bar the
// hand-written workaround had to meet, and the one the fast text assertions
// cannot prove. A real `dart analyze` runs over the generated pair inside an
// engine-tier fixture package.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/datasource/builders/interface_generator.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_datasource_builder.dart';

import '../../helpers/engine_tier_fixture.dart';

const _zikZakEntity = '''
class ZikZak {
  final String id;
  const ZikZak(this.id);

  ZikZak copyWithField(Object field, Object? value) => this;
}

class ZikZakPatch {}
''';

const _zikZakPageEntity = '''
import '../zik_zak/zik_zak.dart';

class ZikZakPage {
  final List<ZikZak> items;
  final bool hasMore;
  const ZikZakPage({required this.items, required this.hasMore});
}
''';

const _zikZakMockData = '''
import '../../domain/entities/zik_zak/zik_zak.dart';

class ZikZakMockData {
  static const zikZaks = <ZikZak>[ZikZak('1'), ZikZak('2'), ZikZak('3')];
}
''';

void main() {
  late EngineTierFixture fx;

  setUpAll(() async {
    fx = await EngineTierFixture.create(name: 'mock_1923_compile_fixture');
    await fx.write(
      'lib/src/domain/entities/zik_zak/zik_zak.dart',
      _zikZakEntity,
    );
    await fx.write(
      'lib/src/domain/entities/zik_zak_page/zik_zak_page.dart',
      _zikZakPageEntity,
    );
    await fx.write('lib/src/data/mock/zik_zak_mock_data.dart', _zikZakMockData);

    final config = GeneratorConfig(
      name: 'ZikZak',
      outputDir: fx.libSrc,
      methods: const [
        'getZikZaks:ListQueryParams<ZikZak>->ZikZakPage',
        'remove:String->void',
      ],
      generateMock: true,
      generateDataSource: false,
    );

    await DataSourceInterfaceBuilder(
      outputDir: fx.libSrc,
      fileSystem: FileSystem.create(),
    ).generate(config);

    await MockDataSourceBuilder(
      outputDir: fx.libSrc,
      fileSystem: FileSystem.create(),
    ).generateMockDataSource(config);

    await fx.pubGet();
  });

  tearDownAll(() async {
    await fx.dispose();
  });

  test('the generated foreign-entity paged mock passes a real scoped '
      'dart analyze with zero errors', () async {
    final result = await fx.analyzeLib();
    expect(
      result.exitCode,
      0,
      reason:
          'the synthesized paged body must compile against the interface.\n'
          '${result.stdout}\n${result.stderr}',
    );
  }, timeout: const Timeout(Duration(minutes: 4)));
}
