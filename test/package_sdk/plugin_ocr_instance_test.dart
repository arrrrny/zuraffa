import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../helpers/run_zfa_source.dart';

/// Behaviors B1–B2 (spec 1602): the OCR instance of the `create-plugin`
/// generator — the real CLI produces the five-package `zuraffa_ocr`
/// family with every OCR stamp, the federated wiring invariants, the
/// `Ocr`-shaped public surface, and harness integrity. Offline fast tier:
/// the CLI scaffold itself needs no network (`--no-gate`).
@Timeout(Duration(minutes: 6))
void main() {
  // One shared scaffold: the tests are read-only assertions over the same
  // generated family, and the helper's first spawn may compile the AOT
  // binary (its own 75s+ budget) — the file-level timeout above exceeds it.

  setUpAll(initZfaSourceBin);

  late Directory tempDir;
  late String monorepo;

  final ocrDescription =
      'Typed OCR support for the Zuraffa ecosystem: '
      'a pure-Dart port, recognition lifecycle, and typed failures behind '
      'an injected platform channel with federated adapters.';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_ocr_instance_');
    final scaffold = await runZfaSource(
      [
        'package',
        'create-plugin',
        'zuraffa_ocr',
        '--repo',
        'arrrrny/zuraffa_ocr',
        '--description',
        ocrDescription,
        '--no-gate',
      ],
      workingDirectory: tempDir.path,
      timeout: const Duration(seconds: 240),
    );
    expect(
      scaffold.exitCode,
      0,
      reason:
          'scaffold failed: ${scaffold.stdout}'
          '${scaffold.stderr}',
    );
    monorepo = p.join(tempDir.path, 'zuraffa_ocr');
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  const family = [
    'zuraffa_ocr',
    'zuraffa_ocr_platform',
    'zuraffa_ocr_android',
    'zuraffa_ocr_ios',
    'zuraffa_ocr_macos',
  ];

  YamlMap pubspecOf(String packageName) {
    final file = File(
      p.join(monorepo, 'packages', packageName, 'pubspec.yaml'),
    );
    expect(
      file.existsSync(),
      isTrue,
      reason: 'pubspec for $packageName must exist',
    );
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

  group('B1 — instance layout + stamps (FR-001 / FR-002 / FR-005 / SC-1)', () {
    test('B1: five packages, OCR description, repo slugs, ocr topic, '
        'LICENSE + CHANGELOG, publishable', () async {
      final packagesDir = Directory(p.join(monorepo, 'packages'));
      expect(
        packagesDir
            .listSync()
            .whereType<Directory>()
            .map((d) => p.basename(d.path))
            .toList()
          ..sort(),
        [...family]..sort(),
      );

      for (final pkg in family) {
        final spec = pubspecOf(pkg);
        expect(
          spec['description'],
          ocrDescription,
          reason: '$pkg description must be the stamped OCR one',
        );
        expect(
          spec['repository'],
          'https://github.com/arrrrny/zuraffa_ocr',
          reason: '$pkg repository slug',
        );
        expect(
          spec['issue_tracker'],
          'https://github.com/arrrrny/zuraffa_ocr/issues',
          reason: '$pkg issue tracker',
        );
        expect(
          (spec['topics'] as YamlList).contains('ocr'),
          isTrue,
          reason: '$pkg topics must include ocr',
        );
        expect(spec['version'], '0.1.0', reason: '$pkg version');
        expect(
          (spec['dependencies'] as YamlMap)['zuraffa'],
          '^6.2.2',
          reason: '$pkg must build on the published zuraffa v6 line',
        );
        expect(
          spec.containsKey('publish_to'),
          isFalse,
          reason: '$pkg must be publishable',
        );

        final license = File(p.join(monorepo, 'packages', pkg, 'LICENSE'));
        expect(
          license.existsSync() && license.readAsStringSync().contains('MIT'),
          isTrue,
          reason: '$pkg must ship a LICENSE',
        );
        final changelog = File(
          p.join(monorepo, 'packages', pkg, 'CHANGELOG.md'),
        );
        expect(
          changelog.existsSync() &&
              changelog.readAsStringSync().trim().isNotEmpty,
          isTrue,
          reason: '$pkg must ship a CHANGELOG',
        );
      }
    });
  });

  group('B2 — wiring, name shapes, harness integrity (FR-003 / FR-002)', () {
    test('B2: dependency invariants hold for the OCR instance', () async {
      const adapters = [
        'zuraffa_ocr_android',
        'zuraffa_ocr_ios',
        'zuraffa_ocr_macos',
      ];

      final appDeps = pubspecOf('zuraffa_ocr')['dependencies'] as YamlMap;
      expect(appDeps['zuraffa'], '^6.2.2');
      expect(
        declaredDeps(
          pubspecOf('zuraffa_ocr'),
        ).where((d) => d.startsWith('zuraffa_ocr')),
        isEmpty,
        reason: 'the app-facing package must not depend on family members',
      );

      final coreDeps =
          pubspecOf('zuraffa_ocr_platform')['dependencies'] as YamlMap;
      expect(coreDeps['zuraffa_ocr'], '^0.1.0');
      expect(
        declaredDeps(
          pubspecOf('zuraffa_ocr_platform'),
        ).where((d) => d.startsWith('zuraffa_ocr_') && d != 'zuraffa_ocr'),
        isEmpty,
        reason: 'the platform core must not depend on adapters',
      );

      for (final adapter in adapters) {
        final deps = pubspecOf(adapter)['dependencies'] as YamlMap;
        expect(deps['zuraffa_ocr'], '^0.1.0', reason: '$adapter → app');
        expect(
          deps['zuraffa_ocr_platform'],
          '^0.1.0',
          reason: '$adapter → core',
        );
      }

      for (final pkg in ['zuraffa_ocr', 'zuraffa_ocr_platform']) {
        final spec = pubspecOf(pkg);
        final all = declaredDeps(spec).toSet();
        final overrides = spec['dependency_overrides'];
        if (overrides is YamlMap) all.addAll(overrides.keys.cast<String>());
        expect(
          all.where(adapters.contains),
          isEmpty,
          reason: '$pkg must never depend on an adapter',
        );
      }
    });

    test('B2b: Ocr name shapes on the public surface', () async {
      final appBarrel = File(
        p.join(monorepo, 'packages', 'zuraffa_ocr', 'lib', 'zuraffa_ocr.dart'),
      ).readAsStringSync();
      expect(appBarrel, contains('OcrPort'), reason: 'app barrel exports');
      expect(appBarrel, contains('OcrService'), reason: 'app barrel exports');

      for (final adapter in const [
        'zuraffa_ocr_android',
        'zuraffa_ocr_ios',
        'zuraffa_ocr_macos',
      ]) {
        final srcDir = Directory(
          p.join(monorepo, 'packages', adapter, 'lib', 'src'),
        );
        final sources = srcDir
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.readAsStringSync())
            .join('\n');
        final prefix = adapter == 'zuraffa_ocr_android'
            ? 'AndroidOcr'
            : adapter == 'zuraffa_ocr_ios'
            ? 'IosOcr'
            : 'MacosOcr';
        expect(
          sources,
          contains(prefix),
          reason: '$adapter must carry the $prefix class prefix',
        );
      }
    });

    test('B2c: every harness imports its barrel over a test double', () async {
      for (final pkg in family) {
        final testDir = Directory(p.join(monorepo, 'packages', pkg, 'test'));
        final harness = testDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_test.dart'))
            .map((f) => f.readAsStringSync())
            .join('\n');
        expect(
          harness,
          contains('package:$pkg/$pkg.dart'),
          reason: '$pkg harness must import its barrel',
        );
        final hasDouble =
            harness.toLowerCase().contains('fake') ||
            RegExp(r'class _\w+', multiLine: true).hasMatch(harness);
        expect(
          hasDouble,
          isTrue,
          reason: '$pkg harness must exercise a test double',
        );
      }
    });
  });
}
