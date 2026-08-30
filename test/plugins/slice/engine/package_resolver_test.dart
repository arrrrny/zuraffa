/// Tests for PackageResolver (U4, U5, U6, U7, U8).
///
/// Behaviors traced to specs/043-slice-plugin/tdd/test-list.md:
///   U4: Resolves `package:<self>/src/x.dart` to `<root>/lib/src/x.dart` via
///       `.dart_tool/package_config.json`
///   U5: Resolves a relative import (`../foo/bar.dart`) against the importing
///       file's directory
///   U6: Classifies `dart:*` and third-party `package:*` imports as
///       framework/external without filesystem resolution
///   U7: A missing `package_config.json` fails with an error telling the user
///       to run `dart pub get`
///   U8: A `package:` URI absent from the package config is treated as
///       external and never traversed
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/engine/package_resolver.dart';

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('slice_pkg_resolver_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<void> writePackageConfig(String root) async {
    final dir = await Directory('$root/.dart_tool').create(recursive: true);
    await File('${dir.path}/package_config.json').writeAsString('''
{
  "configVersion": 2,
  "packages": [
    {"name": "zik_zak", "rootUri": "../", "packageUri": "lib/"},
    {"name": "get_it", "rootUri": "../../cache/get_it", "packageUri": "lib/"}
  ]
}
''');
  }

  group('PackageResolver (FR-009)', () {
    test(
      'U4: resolves package:<self>/src/x.dart to <root>/lib/src/x.dart',
      () async {
        await writePackageConfig(tmpDir.path);
        final resolver = await PackageResolver.load(tmpDir.path);

        final resolved = resolver.resolve(
          'package:zik_zak/src/domain/entities/product/product.dart',
        );

        expect(
          resolved?.replaceAll('\\\\', '/'),
          equals(
            '${tmpDir.path}/lib/src/domain/entities/product/product.dart'
                .replaceAll('\\\\', '/'),
          ),
        );
      },
    );

    test('U5: resolves a relative import against the importing file', () async {
      await writePackageConfig(tmpDir.path);
      final resolver = await PackageResolver.load(tmpDir.path);

      final resolved = resolver.resolveRelative(
        '../entities/product/product.dart',
        '${tmpDir.path}/lib/src/domain/repositories/product_repository.dart',
      );

      expect(
        resolved.replaceAll('\\\\', '/'),
        equals(
          '${tmpDir.path}/lib/src/domain/entities/product/product.dart'
              .replaceAll('\\\\', '/'),
        ),
      );
    });

    test(
      'U6: classifies dart: and third-party package: imports as external',
      () async {
        await writePackageConfig(tmpDir.path);
        final resolver = await PackageResolver.load(tmpDir.path);

        expect(resolver.classify('dart:async'), equals(ImportKind.sdk));
        expect(resolver.classify('dart:io'), equals(ImportKind.sdk));
        expect(
          resolver.classify('package:flutter/material.dart'),
          equals(ImportKind.external),
        );
        // get_it IS in the package config but is not the self package: it is
        // a third-party dependency, framework from the slice's perspective.
        expect(
          resolver.classify('package:get_it/get_it.dart'),
          equals(ImportKind.external),
        );
        // And neither classification touches the filesystem: the referenced
        // paths do not exist under tmpDir.
        expect(resolver.resolve('dart:async'), isNull);
        expect(resolver.resolve('package:flutter/material.dart'), isNull);
      },
    );

    test(
      'U7: a missing package_config.json tells the user to run pub get',
      () async {
        await expectLater(
          () => PackageResolver.load(tmpDir.path),
          throwsA(
            isA<PackageResolverError>().having(
              (e) => e.message,
              'message',
              allOf(contains('package_config.json'), contains('dart pub get')),
            ),
          ),
        );
      },
    );

    test('U8: a package: URI absent from the config is external, never '
        'traversed', () async {
      await writePackageConfig(tmpDir.path);
      final resolver = await PackageResolver.load(tmpDir.path);

      expect(
        resolver.classify('package:unknown_pkg/thing.dart'),
        equals(ImportKind.external),
      );
      expect(resolver.resolve('package:unknown_pkg/thing.dart'), isNull);
    });

    test('self-package detection exposes the package name', () async {
      await writePackageConfig(tmpDir.path);
      final resolver = await PackageResolver.load(tmpDir.path);

      expect(resolver.packageName, equals('zik_zak'));
      expect(
        resolver.classify('package:zik_zak/src/main.dart'),
        equals(ImportKind.self),
      );
    });
  });
}
