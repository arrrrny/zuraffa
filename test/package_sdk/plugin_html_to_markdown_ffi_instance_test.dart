import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Behaviors B1–B4 (spec 064): the migration instance of the
/// `create-plugin` family for `html_to_markdown_ffi` (issue #687). Pins
/// the DELIVERED monorepo at `~/Developer/html_to_markdown_ffi` — family
/// layout, stamps, federated wiring, native artifact placement
/// (pre-migration parity), preserved public API surface, generated
/// zuraffa domain, and (macOS host only) the real-FFI proof tier driven
/// in the delivered app package. Offline fast tier; the FFI tier spawns
/// `dart test` in the delivered package.
@Timeout(Duration(minutes: 6))
void main() {
  final repoOverride = Platform.environment['HTM_MIGRATION_REPO'];
  final repo = repoOverride ??
      p.join(Platform.environment['HOME']!, 'Developer',
          'html_to_markdown_ffi');
  final app = p.join(repo, 'packages', 'html_to_markdown_ffi');

  const family = [
    'html_to_markdown_ffi',
    'html_to_markdown_ffi_platform',
    'html_to_markdown_ffi_android',
    'html_to_markdown_ffi_ios',
    'html_to_markdown_ffi_macos',
  ];
  const adapters = [
    'html_to_markdown_ffi_android',
    'html_to_markdown_ffi_ios',
    'html_to_markdown_ffi_macos',
  ];

  const description = 'Typed HTML to Markdown conversion for the Zuraffa '
      'ecosystem: a Rust FFI core behind a pure-Dart converter port with '
      'federated native adapters.';

  // Pre-migration native artifact sizes (baseline parity, spec 064 B1):
  // recorded from the clean clone before the migration moved them.
  const nativeArtifacts = <String, int>{
    'android/armeabi-v7a/libhtml_to_markdown_ffi.so': 2903004,
    'android/arm64-v8a/libhtml_to_markdown_ffi.so': 4478336,
    'android/x86_64/libhtml_to_markdown_ffi.so': 4953808,
    'ios/ios-arm64.a': 32746784,
    'ios/ios-sim-arm64.a': 32675128,
    'ios/ios-sim-x64.a': 32847136,
    'macos-arm64/libhtml_to_markdown_ffi.dylib': 3895968,
    'macos-x64/libhtml_to_markdown_ffi.dylib': 4136208,
  };

  /// The app package no longer bundles binaries; adapters carry them.
  const adapterNatives = {
    'html_to_markdown_ffi_android': [
      'android/armeabi-v7a/libhtml_to_markdown_ffi.so',
      'android/arm64-v8a/libhtml_to_markdown_ffi.so',
      'android/x86_64/libhtml_to_markdown_ffi.so',
    ],
    'html_to_markdown_ffi_ios': [
      'ios/ios-arm64.a',
      'ios/ios-sim-arm64.a',
      'ios/ios-sim-x64.a',
    ],
    'html_to_markdown_ffi_macos': [
      'macos-arm64/libhtml_to_markdown_ffi.dylib',
      'macos-x64/libhtml_to_markdown_ffi.dylib',
    ],
  };

  YamlMap pubspecOf(String packageName) {
    final file =
        File(p.join(repo, 'packages', packageName, 'pubspec.yaml'));
    expect(file.existsSync(), isTrue,
        reason: 'pubspec for $packageName must exist — is the migration '
            'delivered? Missing: ${file.path}');
    return loadYaml(file.readAsStringSync()) as YamlMap;
  }

  Set<String> declaredDeps(YamlMap pubspec) {
    final names = <String>{};
    for (final key in const ['dependencies', 'dev_dependencies']) {
      final section = pubspec[key];
      if (section is YamlMap) names.addAll(section.keys.cast<String>());
    }
    return names;
  }

  group('B1 — family layout + stamps (FR-001 / FR-002 / FR-003 / SC-005)', () {
    test('B1a: five packages, migration stamps, publishable, aligned '
        'version, LICENSE + CHANGELOG', () {
      final packagesDir = Directory(p.join(repo, 'packages'));
      expect(packagesDir.existsSync(), isTrue,
          reason: 'packages/ family missing — migration not delivered');
      expect(
        packagesDir
            .listSync()
            .whereType<Directory>()
            .map((d) => p.basename(d.path))
            .toList()
          ..sort(),
        [...family]..sort(),
      );

      final versions = <String>{};
      for (final pkg in family) {
        final spec = pubspecOf(pkg);
        expect(spec['description'], description,
            reason: '$pkg description must be the stamped migration one');
        expect(spec['repository'],
            'https://github.com/arrrrny/html_to_markdown_ffi',
            reason: '$pkg repository slug');
        expect(spec['issue_tracker'],
            'https://github.com/arrrrny/html_to_markdown_ffi/issues',
            reason: '$pkg issue tracker');
        final topics = (spec['topics'] as YamlList?)?.cast<String>() ?? const [];
        expect(topics, contains('zuraffa'),
            reason: '$pkg must carry the zuraffa topic');
        expect(spec['publish_to'], isNull,
            reason: '$pkg must be publishable');
        expect(File(p.join(repo, 'packages', pkg, 'LICENSE')).existsSync(),
            isTrue, reason: '$pkg LICENSE');
        final changelog = File(
            p.join(repo, 'packages', pkg, 'CHANGELOG.md'));
        expect(changelog.existsSync() && changelog.lengthSync() > 0, isTrue,
            reason: '$pkg non-empty CHANGELOG');
        versions.add(spec['version'] as String);
      }
      expect(versions.length, 1,
          reason: 'family versions must be aligned at publish: $versions');
    });

    test('B1b: federated dependency graph — nobody depends on an adapter',
        () {
      final appSpec = pubspecOf('html_to_markdown_ffi');
      final appDeps =
          (appSpec['dependencies'] as YamlMap).keys.cast<String>().toSet();
      expect(appDeps, contains('zuraffa'),
          reason: 'app package builds on hosted zuraffa');
      expect(appDeps.intersection(family.toSet()), isEmpty,
          reason: 'app package depends on no in-family package');

      final platformDeps =
          pubspecOf('html_to_markdown_ffi_platform')['dependencies']
              as YamlMap;
      expect(platformDeps.keys.cast<String>(), contains('html_to_markdown_ffi'),
          reason: 'core depends on the app package');

      for (final adapter in adapters) {
        final deps =
            (pubspecOf(adapter)['dependencies'] as YamlMap)
                .keys
                .cast<String>()
                .toSet();
        expect(deps, containsAll(['html_to_markdown_ffi',
            'html_to_markdown_ffi_platform']),
            reason: '$adapter depends on app + core');
        expect(
          deps.intersection(
              adapters.toSet()..remove(adapter)),
          isEmpty,
          reason: '$adapter must not depend on sibling adapters',
        );
      }

      for (final pkg in family) {
        final deps = declaredDeps(pubspecOf(pkg));
        for (final adapter in adapters) {
          expect(deps, isNot(contains(adapter)),
              reason: '$pkg must not depend on adapter $adapter');
        }
      }
    });

    test('B1c: native artifacts moved to adapters at pre-migration parity, '
        'app bundle retired (FR-003)', () {
      for (final entry in adapterNatives.entries) {
        for (final rel in entry.value) {
          final f = File(
              p.join(repo, 'packages', entry.key, 'native', rel));
          expect(f.existsSync(), isTrue, reason: 'missing $entry.key/$rel');
          expect(f.lengthSync(), greaterThan(0), reason: 'empty $rel');
        }
      }
      for (final entry in nativeArtifacts.entries) {
        final adapter = entry.key.startsWith('android')
            ? 'html_to_markdown_ffi_android'
            : entry.key.startsWith('ios')
                ? 'html_to_markdown_ffi_ios'
                : 'html_to_markdown_ffi_macos';
        final f = File(p.join(repo, 'packages', adapter, 'native', entry.key));
        expect(f.lengthSync(), entry.value,
            reason: '${entry.key} must be the pre-migration binary, '
                'byte-for-byte');
      }
      expect(
        Directory(p.join(app, 'native')).existsSync(),
        isFalse,
        reason: 'the app package must no longer bundle native binaries',
      );
    });
  });

  group('B2 — public API preservation (FR-005 / FR-006)', () {
    test('B2a: preserved barrels and loose lib entry points', () {
      const preservedLib = [
        'html_to_markdown.dart',
        'convert.dart',
        'exceptions.dart',
        'visitor.dart',
        'visitor_bridge.dart',
        'native_library.dart',
        'html_to_markdown_bindings.dart',
        'models/conversion_options.dart',
        'models/conversion_result.dart',
        'models/enums.dart',
      ];
      for (final rel in preservedLib) {
        expect(File(p.join(app, 'lib', rel)).existsSync(), isTrue,
            reason: 'public import path lib/$rel must survive (FR-006)');
      }
      final barrel = File(p.join(app, 'lib', 'html_to_markdown.dart'))
          .readAsStringSync();
      for (final symbol in [
        'convert.dart',
        'exceptions.dart',
        'models/conversion_options.dart',
        'models/conversion_result.dart',
        'models/enums.dart',
        'visitor.dart',
      ]) {
        expect(barrel, contains(symbol),
            reason: 'barrel must keep exporting $symbol');
      }
    });

    test('B2b: ported legacy suite present with unchanged file names',
        () {
      const ported = [
        'conversion_test.dart',
        'options_test.dart',
        'edge_case_test.dart',
        'structure_test.dart',
        'visitor_test.dart',
        'metadata_test.dart',
        'result_test.dart',
        'smoke_test.dart',
        'real_world_test.dart',
        'trendyol_test.dart',
      ];
      for (final rel in ported) {
        expect(File(p.join(app, 'test', rel)).existsSync(), isTrue,
            reason: 'ported legacy test test/$rel must exist (FR-005)');
      }
      expect(
          File(p.join(app, 'test', 'html_to_markdown_ffi_service_test.dart'))
              .existsSync(),
          isTrue,
          reason: 'the service contract test must exist');
    });
  });

  group('B3 — generated zuraffa domain (FR-001 / FR-002 / SC-005)', () {
    test('B3a: canonical domain layout with zorphy entity pair', () {
      final entitiesDir = Directory(p.join(app, 'lib', 'src', 'domain',
          'entities'));
      expect(entitiesDir.existsSync(), isTrue,
          reason: 'lib/src/domain/entities must exist (FR-001)');
      final entityDirs = entitiesDir
          .listSync()
          .whereType<Directory>()
          .map((d) => p.basename(d.path))
          .toList();
      expect(entityDirs, isNotEmpty,
          reason: 'at least one generated entity must exist');
      for (final dir in entityDirs) {
        expect(File(p.join(entitiesDir.path, dir, '$dir.dart')).existsSync(),
            isTrue, reason: 'entities/$dir/$dir.dart canonical path');
      }
      final anyZorphy = entitiesDir
          .listSync(recursive: true)
          .whereType<File>()
          .any((f) => f.path.endsWith('.zorphy.dart'));
      expect(anyZorphy, isTrue,
          reason: 'entity must be zorphy-generated (zfa entity create)');
    });

    test('B3b: generated repository/datasource/usecase artifacts exist',
        () {
      final domain = Directory(p.join(app, 'lib', 'src'));
      final files = domain
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.relative(f.path, from: domain.path))
          .toList();
      expect(files.any((f) => f.contains('repository')), isTrue,
          reason: 'generated repository artifact');
      expect(files.any((f) => f.contains('datasource')), isTrue,
          reason: 'generated datasource artifact (the FFI wrapper, FR-004)');
      expect(files.any((f) => f.contains('usecase') || f.contains('use_case')),
          isTrue, reason: 'generated usecase artifact');
    });

    test('B3c: service delegates through the generated stack', () {
      final serviceSrc = Directory(p.join(app, 'lib', 'src'))
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(serviceSrc, contains('UseCase'),
          reason: 'the stack must build on zuraffa usecase types');
    });
  });

  group('B4 — host FFI proof through the stack (FR-003 / FR-004 / SC-002)',
      () {
    test('B4: delivered app package host proof passes on macOS',
        timeout: Timeout(Duration(minutes: 5)), () async {
      if (!Platform.isMacOS) {
        markTestSkipped(
            'host FFI proof executes on macOS hosts only (pre-migration '
            'status-quo parity, research D7)');
        return;
      }
      final proof = File(p.join(app, 'test', 'host_ffi_proof_test.dart'));
      expect(proof.existsSync(), isTrue,
          reason: 'host_ffi_proof_test.dart must exist in the app package');
      final run = await Process.run('dart', const [
        'test',
        'test/host_ffi_proof_test.dart',
      ], workingDirectory: app);
      expect(run.exitCode, 0,
          reason: 'host FFI proof must pass through the migrated stack\n'
              '${run.stdout}\n${run.stderr}');
    });
  });
}
