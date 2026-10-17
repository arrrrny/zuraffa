// Issue #1732 — `zfa build` refreshes the Hive registrar's import block.
//
// `hive_registrar.g.dart` is build_runner output driven by the entity
// source, so it picks up a newly referenced (or newly nested) entity type
// on its own. The host library's import block is only written by the
// adapter/migrate flow, so a hand-added entity left the part referencing a
// type the host library could not resolve — `'Pagination' isn't a type` —
// and the build's own analyze gate then failed on generated code it could
// not heal.
//
// These are in-process unit tests for `BuildCommand.refreshHiveRegistrar`,
// which runs BEFORE build_runner and keeps the two halves in step. No
// subprocess, no build_runner.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/commands/build_command.dart';

void main() {
  group('BuildCommand.refreshHiveRegistrar (#1732)', () {
    late Directory sandbox;
    late BuildCommand command;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('build_hive_refresh_');
      command = BuildCommand();
    });

    tearDown(() async {
      if (sandbox.existsSync()) {
        await sandbox.delete(recursive: true);
      }
    });

    Future<void> write(String rel, String content) async {
      final file = File(p.join(sandbox.path, rel));
      await file.create(recursive: true);
      await file.writeAsString(content);
    }

    String registrarPath() =>
        p.join(sandbox.path, 'lib', 'src', 'cache', 'hive_registrar.dart');

    /// The #1732 repro: an already-registered entity (`UrlEndpoint`) gains a
    /// field whose type is a hand-added entity (`Pagination`). The registrar
    /// host library only imports `UrlEndpoint`.
    Future<void> writeReproFixture() async {
      await write('lib/src/domain/entities/url_endpoint/url_endpoint.dart', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';
import 'pagination.dart';
part 'url_endpoint.zorphy.dart';

@Zorphy(generateJson: true)
abstract class \$UrlEndpoint {
  String get url;
  \$Pagination? get pagination;
}
''');
      await write('lib/src/domain/entities/pagination/pagination.dart', '''
import 'package:zorphy_annotation/zorphy_annotation.dart';
part 'pagination.zorphy.dart';

@Zorphy(generateJson: true)
abstract class \$Pagination {
  int get page;
}
''');
      await write('lib/src/cache/url_endpoint_cache.dart', '''
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/url_endpoint/url_endpoint.dart';

Future<void> initUrlEndpointCache() async {
  await Hive.openBox<UrlEndpoint>('url_endpoints');
}
''');
      await write('lib/src/cache/hive_registrar.dart', '''
// GENERATED - DO NOT EDIT
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/url_endpoint/url_endpoint.dart';
part 'hive_registrar.g.dart';

@GenerateAdapters([AdapterSpec<UrlEndpoint>()])
extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(UrlEndpointAdapter());
  }
}
// END GENERATED
''');
    }

    test('adds the import for a newly nested entity type', () async {
      await writeReproFixture();

      final refreshed = await command.refreshHiveRegistrar(
        projectRoot: sandbox.path,
      );

      expect(refreshed, isTrue);
      final content = File(registrarPath()).readAsStringSync();
      expect(
        content,
        contains("import '../domain/entities/pagination/pagination.dart';"),
        reason:
            'the registrar must import the entity its .g.dart part '
            'references (issue #1732)',
      );
      expect(
        content,
        contains('AdapterSpec<Pagination>()'),
        reason: 'the nested entity must also be registered',
      );
    });

    test('is a no-op when the project has no registrar', () async {
      await write(
        'lib/src/cache/url_endpoint_cache.dart',
        '// cache file without a registrar',
      );

      final refreshed = await command.refreshHiveRegistrar(
        projectRoot: sandbox.path,
      );

      expect(refreshed, isFalse);
      expect(
        File(registrarPath()).existsSync(),
        isFalse,
        reason: 'a project with no registrar must not gain one',
      );
    });

    test(
      'never deletes an orphaned registrar (no *_cache.dart source)',
      () async {
        await write(
          'lib/src/cache/hive_registrar.dart',
          '// hand-authored registrar, no cache source',
        );
        const before = '// hand-authored registrar, no cache source';

        final refreshed = await command.refreshHiveRegistrar(
          projectRoot: sandbox.path,
        );

        expect(refreshed, isFalse);
        expect(File(registrarPath()).readAsStringSync(), before);
      },
    );

    test('leaves an already-fresh registrar byte-identical', () async {
      await writeReproFixture();
      // First pass brings the registrar up to date.
      await command.refreshHiveRegistrar(projectRoot: sandbox.path);
      final fresh = File(registrarPath()).readAsStringSync();

      final refreshed = await command.refreshHiveRegistrar(
        projectRoot: sandbox.path,
      );

      expect(refreshed, isTrue);
      expect(File(registrarPath()).readAsStringSync(), fresh);
    });
  });
}
