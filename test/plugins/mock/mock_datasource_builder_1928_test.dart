// Issue #1955: the #1923 merge rewrote the #1850 refusal sites around
// `_deriveForeignPageShape` and dropped the #1928 escape
// (`_isHonestArbitraryReturn` + `EntityAnalyzer.entityFileExists`). The
// surviving derivation normalizes only `?` and spaces, but a REAL Zorphy
// part-file entity declares its fields against the `$`-prefixed abstract
// supertype — `ZikZakPage.items` analyzes as `List<$ZikZak>`, not
// `List<ZikZak>` — so the derivation returned null and the honest paged
// read regressed to the `unknown return type` refusal. The normalizer must
// strip Zorphy's `$` prefix so `List<$ZikZak>` compares equal to
// `List<ZikZak>`; a future rewrite of the refusal path that drops this
// normalization fails these tests again.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_datasource_builder.dart';
import 'package:zuraffa/src/utils/entity_analyzer.dart';

const _zikZakEntity = '''
class ZikZak {
  final String id;
  const ZikZak(this.id);

  ZikZak copyWithField(Object field, Object? value) => this;
}

class ZikZakPatch {}
''';

/// The REAL #1928 shape: a Zorphy part-file entity. The source declares the
/// fields on the `$`-prefixed abstract class, so `analyzeEntity` sees
/// `List<$ZikZak>` — not the hand-written `List<ZikZak>` the 1923 fixture
/// used, which is why that fixture could not catch this regression.
const _zikZakPageZorphyEntity = r'''
import 'package:zorphy_annotation/zorphy_annotation.dart';

part 'zik_zak_page.zorphy.dart';

@Zorphy()
abstract class $ZikZakPage {
  List<$ZikZak> get items;
  bool get hasMore;
}
''';

const _zikZakMockData = '''
import '../../domain/entities/zik_zak/zik_zak.dart';

class ZikZakMockData {
  static const zikZaks = <ZikZak>[ZikZak('1'), ZikZak('2'), ZikZak('3')];
}
''';

Future<Directory> _seedTree() async {
  final root = await Directory.systemTemp.createTemp('zuraffa_1928_');
  final outputDir = Directory('${root.path}/lib/src');

  Future<void> write(String relative, String content) async {
    final file = File('${outputDir.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  await write('domain/entities/zik_zak/zik_zak.dart', _zikZakEntity);
  await write(
    'domain/entities/zik_zak_page/zik_zak_page.dart',
    _zikZakPageZorphyEntity,
  );
  await write('data/mock/zik_zak_mock_data.dart', _zikZakMockData);
  return root;
}

Future<String> _generate(
  Directory root, {
  required List<String> methods,
}) async {
  final outputDir = '${root.path}/lib/src';
  final file =
      await MockDataSourceBuilder(
        outputDir: outputDir,
        fileSystem: FileSystem.create(),
      ).generateMockDataSource(
        GeneratorConfig(
          name: 'ZikZak',
          outputDir: outputDir,
          methods: methods,
          generateMock: true,
          generateDataSource: false,
        ),
      );
  return file.content ?? '';
}

void main() {
  late Directory root;

  tearDown(() async {
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  test('a real Zorphy part-file page entity analyzes with the '
      r'$-prefixed List<$Subject> field type', () async {
    root = await _seedTree();

    final fields = EntityAnalyzer.analyzeEntity(
      'ZikZakPage',
      '${root.path}/lib/src',
      fileSystem: FileSystem.create(),
    );

    expect(fields, {
      'items': r'List<$ZikZak>',
      'hasMore': 'bool',
    }, reason: 'the fixture reproduces the real Zorphy field shape');
  });

  test('a Zorphy part-file page entity still gets the honest paged read '
      'instead of the #1850 refusal', () async {
    root = await _seedTree();

    final source = await _generate(
      root,
      methods: const [
        'getZikZaks:ListQueryParams<ZikZak>->ZikZakPage',
        'remove:String->void',
      ],
    );

    expect(
      source,
      contains('Future<ZikZakPage> getZikZaks(ListQueryParams<ZikZak> params)'),
      reason: 'the foreign-entity return keeps the seam signature',
    );
    expect(
      source,
      contains('final page = items.skip(offset).take(limit).toList();'),
      reason: 'the page is a real slice of the fixture list',
    );
    expect(
      source,
      contains('return ZikZakPage('),
      reason: 'the foreign entity is constructed, not thrown',
    );
    expect(
      source,
      contains('items: page'),
      reason: 'the wrapped list field receives the slice',
    );
    expect(
      source,
      contains('hasMore: offset + page.length < items.length'),
      reason: 'hasMore is computed from the slice, matching the issue shape',
    );
    expect(
      source,
      isNot(contains('throw UnimplementedError();')),
      reason: 'the generated body is honest — it returns real fixture data',
    );
  });
}
