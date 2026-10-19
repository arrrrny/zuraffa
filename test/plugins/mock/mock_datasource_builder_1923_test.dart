// Issue #1923: after #1850 the honest-body guard refused EVERY
// foreign-entity return, so a cross-entity seam (e.g. a paged read
// `getZikZaks(...) -> Future<ZikZakPage>` where `ZikZakPage` wraps
// `List<ZikZak>`) could never be generated and had to be hand-written —
// leaving the mock uncertified. When the foreign entity's source declares a
// `List<$Subject>` field, the paged body IS derivable from the subject's
// fixture list, so the builder must synthesize it instead of refusing.
// Shapes that are not derivable keep today's refusal.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_datasource_builder.dart';

const _zikZakEntity = '''
class ZikZak {
  final String id;
  const ZikZak(this.id);

  ZikZak copyWithField(Object field, Object? value) => this;
}

class ZikZakPatch {}
''';

const _zikZakPageEntity = '''
class ZikZakPage {
  final List<ZikZak> items;
  final bool hasMore;
  const ZikZakPage({required this.items, required this.hasMore});
}
''';

/// A foreign entity with no `List<ZikZak>` field — nothing the fixture set
/// can feed, so the honest refusal stays in force.
const _zikZakStatsEntity = '''
class ZikZakStats {
  final int total;
  final bool hasMore;
  const ZikZakStats({required this.total, required this.hasMore});
}
''';

const _zikZakMockData = '''
import '../../domain/entities/zik_zak/zik_zak.dart';

class ZikZakMockData {
  static const zikZaks = <ZikZak>[ZikZak('1'), ZikZak('2'), ZikZak('3')];
}
''';

Future<Directory> _seedTree({
  bool withPageEntity = true,
  bool withStatsEntity = false,
}) async {
  final root = await Directory.systemTemp.createTemp('zuraffa_1923_');
  final outputDir = Directory('${root.path}/lib/src');

  Future<void> write(String relative, String content) async {
    final file = File('${outputDir.path}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  await write('domain/entities/zik_zak/zik_zak.dart', _zikZakEntity);
  await write('data/mock/zik_zak_mock_data.dart', _zikZakMockData);
  if (withPageEntity) {
    await write(
      'domain/entities/zik_zak_page/zik_zak_page.dart',
      _zikZakPageEntity,
    );
  }
  if (withStatsEntity) {
    await write(
      'domain/entities/zik_zak_stats/zik_zak_stats.dart',
      _zikZakStatsEntity,
    );
  }
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

  test('a foreign entity wrapping List<Subject> gets a real paged read over '
      'the subject fixture instead of the #1850 refusal', () async {
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
      contains('final items = ZikZakMockData.zikZaks;'),
      reason: 'the body reads the subject fixture list',
    );
    expect(
      source,
      contains('params.offset'),
      reason: 'the paged read honors the offset parameter',
    );
    expect(
      source,
      contains('params.limit'),
      reason: 'the paged read honors the limit parameter',
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
    expect(
      source,
      contains(
        "import '../../../domain/entities/zik_zak_page/zik_zak_page.dart';",
      ),
      reason: 'the foreign entity return type is imported',
    );
  });

  test('an unknown foreign return type keeps the #1850 refusal', () async {
    root = await _seedTree(withPageEntity: false);

    await expectLater(
      _generate(
        root,
        methods: const ['getZikZaks:ListQueryParams<ZikZak>->ZikZakPage'],
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'unknown return type ZikZakPage for member getZikZaks',
        ),
      ),
    );
  });

  test(
    'a foreign entity with no List<Subject> field keeps the refusal',
    () async {
      root = await _seedTree(withStatsEntity: true);

      await expectLater(
        _generate(root, methods: const ['getStats:NoParams->ZikZakStats']),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'unknown return type ZikZakStats for member getStats',
          ),
        ),
      );
    },
  );

  test(
    'a derivable wrapper with non-paging params keeps the refusal',
    () async {
      root = await _seedTree();

      await expectLater(
        _generate(root, methods: const ['getZikZaks:String->ZikZakPage']),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'unknown return type ZikZakPage for member getZikZaks',
          ),
        ),
      );
    },
  );

  test('the shape-drift repair uses the same honest paged read for a '
      'missing foreign-entity member', () async {
    root = await _seedTree();
    final outputDir = '${root.path}/lib/src';
    final datasourceDir = Directory('$outputDir/data/datasources/zik_zak')
      ..createSync(recursive: true);
    File(
      '${datasourceDir.path}/zik_zak_datasource.dart',
    ).writeAsStringSync(_interfaceWithForeignMember);
    File(
      '${datasourceDir.path}/zik_zak_mock_datasource.dart',
    ).writeAsStringSync(_staleMock);

    final file =
        await MockDataSourceBuilder(
          outputDir: outputDir,
          fileSystem: FileSystem.create(),
        ).generateMockDataSource(
          GeneratorConfig(
            name: 'ZikZak',
            outputDir: outputDir,
            methods: const [],
            generateMock: true,
            generateDataSource: false,
          ),
        );
    final source = file.content ?? '';

    expect(
      source,
      contains('Future<ZikZakPage> getZikZaks(ListQueryParams<ZikZak> params)'),
    );
    expect(source, contains('ZikZakMockData.zikZaks'));
    expect(source, contains('return ZikZakPage('));
    expect(source, contains('hasMore: offset + page.length < items.length'));
    expect(
      source,
      isNot(contains('ZikZakMockData.sampleZikZak')),
      reason:
          'the repair must not return the subject entity for a foreign '
          'return type',
    );
  });
}

// --- shape-drift repair path (issue #1570) -------------------------------
//
// The same cross-entity seam can reach the builder as a member the
// interface declares but an existing mock predates. The repair must use the
// paged-read body too — the single-entity sample is a wrong-type body.

const _interfaceWithForeignMember = '''
// GENERATED by zfa datasource — DO NOT EDIT BY HAND.
import 'package:zuraffa/zuraffa.dart';

import '../../../domain/entities/zik_zak/zik_zak.dart';
import '../../../domain/entities/zik_zak_page/zik_zak_page.dart';

abstract class ZikZakDataSource with Loggable, FailureHandler {
  Future<ZikZakPage> getZikZaks(ListQueryParams<ZikZak> params);
}
''';

const _staleMock = '''
// Generated by zfa for: ZikZak
import 'dart:async';

import 'package:zuraffa/mock.dart';
import '../../../domain/entities/zik_zak/zik_zak.dart';
import '../../mock/zik_zak_mock_data.dart';
import 'zik_zak_datasource.dart';

class ZikZakMockDataSource
    with Loggable, FailureHandler
    implements ZikZakDataSource {
  ZikZakMockDataSource({Duration? delay})
      : _delay = delay ?? const Duration(milliseconds: 100);

  final Duration _delay;
}
''';
