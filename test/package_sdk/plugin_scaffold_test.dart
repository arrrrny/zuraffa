import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:zuraffa/src/package/package_scaffold.dart';
import 'package:zuraffa/src/package/plugin_scaffold.dart';

/// Behaviors B1–B11 (spec 1601): `PluginScaffold` generates a complete
/// federated plugin monorepo — app-facing package + platform core + one
/// adapter per platform — where every package analyzes, tests, and
/// publish-dry-runs clean with zero manual edits.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_plugin_scaffold_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<PluginScaffoldResult> scaffold({
    String name = 'my_plugin',
    List<PluginPlatform> platforms = const [
      PluginPlatform.android,
      PluginPlatform.ios,
      PluginPlatform.macos,
    ],
    String? description,
    String? repo,
    String? zuraffaPath,
    bool dryRun = false,
  }) {
    return PluginScaffold().create(
      name: name,
      outputParent: tempDir.path,
      platforms: platforms,
      description: description,
      repository: repo,
      zuraffaPath: zuraffaPath,
      dryRun: dryRun,
    );
  }

  bool existsAt(String path) =>
      File(path).existsSync() || Directory(path).existsSync();

  YamlMap pubspecOf(String monorepo, String packageName) {
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

  /// Every dependency name declared by [packageName] — regular, dev, AND
  /// overrides (overrides placement is asserted separately in B5).
  Set<String> declaredDeps(YamlMap pubspec) {
    final names = <String>{};
    for (final key in const ['dependencies', 'dev_dependencies']) {
      final section = pubspec[key];
      if (section is YamlMap) names.addAll(section.keys.cast<String>());
    }
    return names;
  }

  group('PluginScaffold — B1 full-family layout (FR-001 / FR-011 / SC-1)', () {
    test(
      'B1: five package dirs, per-package file set, root docs + scripts',
      () async {
        final result = await scaffold();
        final monorepo = result.rootPath;
        expect(monorepo, p.join(tempDir.path, 'my_plugin'));

        const family = [
          'my_plugin',
          'my_plugin_platform',
          'my_plugin_android',
          'my_plugin_ios',
          'my_plugin_macos',
        ];

        // Exactly five packages in packages/, publish order preserved.
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
        expect(
          result.packagePaths.map((path) => p.basename(path)),
          family,
          reason: 'packagePaths must list the family in publish order',
        );

        // Per-package file set (every role).
        for (final pkg in family) {
          final pkgDir = p.join(monorepo, 'packages', pkg);
          for (final rel in [
            'pubspec.yaml',
            'analysis_options.yaml',
            'README.md',
            'CHANGELOG.md',
            'LICENSE',
            p.join('lib', '$pkg.dart'),
            'test',
          ]) {
            expect(
              existsAt(p.join(pkgDir, rel)),
              isTrue,
              reason: '$pkg/$rel must exist in the scaffold',
            );
          }
          // At least one src/ source per package.
          final srcDir = Directory(p.join(pkgDir, 'lib', 'src'));
          expect(srcDir.existsSync(), isTrue, reason: '$pkg must have lib/src');
          expect(
            srcDir.listSync(recursive: true).whereType<File>().isNotEmpty,
            isTrue,
            reason: '$pkg/lib/src must contain at least one source file',
          );
          // A test harness per package.
          final testDir = Directory(p.join(pkgDir, 'test'));
          expect(
            testDir
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('_test.dart'))
                .isNotEmpty,
            isTrue,
            reason: '$pkg must ship a test harness',
          );
        }

        // Monorepo root docs + tooling.
        for (final rel in [
          'README.md',
          'PUBLISH.md',
          'LICENSE',
          'CHANGELOG.md',
          '.gitignore',
          p.join('scripts', 'prepare_for_publish.sh'),
          p.join('scripts', 'publish.sh'),
          p.join('scripts', 'push_to_master.sh'),
        ]) {
          expect(
            existsAt(p.join(monorepo, rel)),
            isTrue,
            reason: 'monorepo root $rel must exist',
          );
        }
      },
    );
  });

  group('PluginScaffold — B2 dependency-graph wiring (FR-004 / SC-1)', () {
    test(
      'B2: app→zuraffa only; core→app; adapters→app+core; nobody→adapter',
      () async {
        final result = await scaffold();
        final monorepo = result.rootPath;

        const adapters = [
          'my_plugin_android',
          'my_plugin_ios',
          'my_plugin_macos',
        ];
        const initialVersion = '0.1.0';

        // Versions aligned at the scaffold version.
        for (final pkg in ['my_plugin', 'my_plugin_platform', ...adapters]) {
          expect(
            pubspecOf(monorepo, pkg)['version'],
            initialVersion,
            reason: '$pkg must start at the scaffold version',
          );
        }

        final app = pubspecOf(monorepo, 'my_plugin');
        final core = pubspecOf(monorepo, 'my_plugin_platform');

        // App: zuraffa hosted, no in-family deps.
        final appDeps = app['dependencies'] as YamlMap;
        expect(
          appDeps['zuraffa'],
          isA<String>().having(
            (v) => v.toString(),
            'hosted constraint',
            startsWith('^'),
          ),
        );
        expect(
          declaredDeps(app).where((d) => d.startsWith('my_plugin')),
          isEmpty,
          reason: 'the app-facing package must not depend on family members',
        );

        // Core: app hosted, no other family members.
        final coreDeps = core['dependencies'] as YamlMap;
        expect(coreDeps['my_plugin'], '^$initialVersion');
        expect(
          declaredDeps(
            core,
          ).where((d) => d.startsWith('my_plugin_') && d != 'my_plugin'),
          isEmpty,
          reason: 'the platform core must not depend on adapters',
        );

        // Adapters: app + core, in-family constraints at the scaffold version.
        for (final adapter in adapters) {
          final deps = pubspecOf(monorepo, adapter)['dependencies'] as YamlMap;
          expect(
            deps['my_plugin'],
            '^$initialVersion',
            reason: '$adapter → app',
          );
          expect(
            deps['my_plugin_platform'],
            '^$initialVersion',
            reason: '$adapter → core',
          );
        }

        // Nobody depends on an adapter (any dependency section).
        for (final pkg in ['my_plugin', 'my_plugin_platform']) {
          final spec = pubspecOf(monorepo, pkg);
          final all = declaredDeps(spec).toSet();
          final overrides = spec['dependency_overrides'];
          if (overrides is YamlMap) all.addAll(overrides.keys.cast<String>());
          expect(
            all.where(adapters.contains),
            isEmpty,
            reason: '$pkg must never depend on an adapter',
          );
        }
      },
    );
  });

  group('PluginScaffold — B3 harness integrity (FR-008)', () {
    test(
      'B3: every generated test exercises its barrel through a fake',
      () async {
        final result = await scaffold();
        final monorepo = result.rootPath;

        for (final pkg in const [
          'my_plugin',
          'my_plugin_platform',
          'my_plugin_android',
          'my_plugin_ios',
          'my_plugin_macos',
        ]) {
          final testDir = Directory(p.join(monorepo, 'packages', pkg, 'test'));
          final harness = testDir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('_test.dart'))
              .map((f) => f.readAsStringSync())
              .join('\n');
          expect(
            harness.contains('package:$pkg/$pkg.dart'),
            isTrue,
            reason: '$pkg harness must import its own public barrel',
          );
          final hasTestDouble =
              harness.toLowerCase().contains('fake') ||
              RegExp(r'class _\w+', multiLine: true).hasMatch(harness);
          expect(
            hasTestDouble,
            isTrue,
            reason:
                '$pkg harness must exercise the surface through a test double',
          );
        }
      },
    );
  });

  group('PluginScaffold — B4 publish metadata (FR-003 / SC-2)', () {
    test(
      'B4: every package carries complete publish metadata + LICENSE + CHANGELOG',
      () async {
        final result = await scaffold(
          description: 'Typed testing plugin for the Zuraffa ecosystem.',
          repo: 'myorg/my_plugin',
        );
        final monorepo = result.rootPath;

        for (final pkg in const [
          'my_plugin',
          'my_plugin_platform',
          'my_plugin_android',
          'my_plugin_ios',
          'my_plugin_macos',
        ]) {
          final spec = pubspecOf(monorepo, pkg);
          expect(
            spec['description'],
            'Typed testing plugin for the Zuraffa ecosystem.',
            reason: '$pkg description must be the stamped one',
          );
          expect(spec['homepage'], 'https://zuraffa.com', reason: pkg);
          expect(
            spec['repository'],
            'https://github.com/myorg/my_plugin',
            reason: '$pkg repository must use the requested slug (FR-012)',
          );
          expect(
            spec['issue_tracker'],
            'https://github.com/myorg/my_plugin/issues',
            reason: pkg,
          );
          expect((spec['topics'] as YamlList).isNotEmpty, isTrue, reason: pkg);
          expect(
            spec.containsKey('publish_to'),
            isFalse,
            reason: '$pkg must be publishable (no publish_to: none)',
          );

          final license = File(p.join(monorepo, 'packages', pkg, 'LICENSE'));
          expect(
            license.existsSync() && license.readAsStringSync().contains('MIT'),
            isTrue,
            reason: '$pkg must ship a LICENSE (pub.dev hard requirement)',
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
      },
    );

    test('B4b: repository defaults to the house owner slug', () async {
      final result = await scaffold();
      final spec = pubspecOf(result.rootPath, 'my_plugin');
      expect(spec['repository'], 'https://github.com/arrrrny/my_plugin');
    });
  });

  group('PluginScaffold — B5 overrides placement (FR-006 / FR-013)', () {
    test(
      'B5: siblings override by path only; hosted constraints stay in dependencies',
      () async {
        final result = await scaffold();
        final monorepo = result.rootPath;

        final coreOverrides =
            pubspecOf(monorepo, 'my_plugin_platform')['dependency_overrides']
                as YamlMap?;
        expect(coreOverrides, isNotNull);
        expect(
          (coreOverrides!['my_plugin'] as YamlMap)['path'],
          '../my_plugin',
        );

        final adapterOverrides =
            pubspecOf(monorepo, 'my_plugin_android')['dependency_overrides']
                as YamlMap?;
        expect(adapterOverrides, isNotNull);
        expect(
          (adapterOverrides!['my_plugin'] as YamlMap)['path'],
          '../my_plugin',
        );
        expect(
          (adapterOverrides['my_plugin_platform'] as YamlMap)['path'],
          '../my_plugin_platform',
        );

        // Hosted in-family constraints still declared as dependencies (B2
        // asserts the values; here the placement pairing is what matters).
        final adapterDeps =
            pubspecOf(monorepo, 'my_plugin_android')['dependencies'] as YamlMap;
        expect(adapterDeps['my_plugin'], '^0.1.0');
        expect(adapterDeps['my_plugin_platform'], '^0.1.0');
      },
    );

    test(
      'B5b: --zuraffa-path pins the framework via overrides, hosted stays',
      () async {
        final repoRoot = Directory.current.path;
        final result = await scaffold(zuraffaPath: repoRoot);
        final monorepo = result.rootPath;

        for (final pkg in const [
          'my_plugin',
          'my_plugin_platform',
          'my_plugin_android',
        ]) {
          final spec = pubspecOf(monorepo, pkg);
          expect(
            (spec['dependencies'] as YamlMap)['zuraffa'],
            isA<String>(),
            reason: '$pkg keeps the hosted zuraffa constraint (FR-006)',
          );
          final overrides = spec['dependency_overrides'] as YamlMap?;
          expect(overrides, isNotNull, reason: '$pkg must override zuraffa');
          expect(
            (overrides!['zuraffa'] as YamlMap)['path'],
            repoRoot,
            reason: '$pkg framework override must point at the checkout',
          );
        }
      },
    );
  });

  group('PluginScaffold — B6 publish tooling (FR-007 / SC-2)', () {
    test(
      'B6: prepare_for_publish aligns versions/changelogs and commits; publish order app→core→adapters',
      () async {
        final result = await scaffold();
        final monorepo = result.rootPath;

        // publish.sh: all five packages, app first, core before adapters.
        final publishScript = File(
          p.join(monorepo, 'scripts', 'publish.sh'),
        ).readAsStringSync();
        final order = const [
          'my_plugin',
          'my_plugin_platform',
          'my_plugin_android',
          'my_plugin_ios',
          'my_plugin_macos',
        ].map((pkg) => publishScript.indexOf('"$pkg"')).toList();
        expect(
          order,
          everyElement(greaterThanOrEqualTo(0)),
          reason: 'publish.sh must list every package incl. the core',
        );
        expect(
          order,
          orderedEquals([...order]..sort()),
          reason: 'publish order must be app → core → adapters',
        );

        // prepare_for_publish.sh: run it for real in a git-init'ed scaffold.
        await _git(monorepo, ['init']);
        await _git(monorepo, ['config', 'user.email', 'scaffold@test']);
        await _git(monorepo, ['config', 'user.name', 'Scaffold Test']);
        await _git(monorepo, ['add', '-A']);
        await _git(monorepo, ['commit', '-m', 'scaffold', '--no-verify']);

        const version = '1.2.3';
        File(p.join(monorepo, 'CHANGELOG.md')).writeAsStringSync(
          '\n## $version\n\n- Released.\n',
          mode: FileMode.append,
        );
        // The release flow commits the release notes before the prep script
        // runs (its dirty-tree check gates the version bump).
        await _git(monorepo, ['add', '-A']);
        await _git(monorepo, ['commit', '-m', 'release notes', '--no-verify']);

        final prep = Process.runSync(
          'bash',
          [p.join('scripts', 'prepare_for_publish.sh'), version],
          workingDirectory: monorepo,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        expect(
          prep.exitCode,
          0,
          reason: 'prepare_for_publish failed: ${prep.stderr}${prep.stdout}',
        );

        for (final pkg in const [
          'my_plugin',
          'my_plugin_platform',
          'my_plugin_android',
          'my_plugin_ios',
          'my_plugin_macos',
        ]) {
          final spec = pubspecOf(monorepo, pkg);
          expect(
            spec['version'],
            version,
            reason: '$pkg must align to $version',
          );
          final changelog = File(
            p.join(monorepo, 'packages', pkg, 'CHANGELOG.md'),
          ).readAsStringSync();
          expect(
            changelog.contains('## $version'),
            isTrue,
            reason: '$pkg CHANGELOG must gain the $version entry',
          );
          if (pkg != 'my_plugin') {
            final deps = spec['dependencies'] as YamlMap;
            expect(
              deps['my_plugin'],
              '^$version',
              reason: '$pkg in-family constraint must follow $version',
            );
          }
        }
        // The prep script committed the bump.
        final log = await _git(monorepo, ['log', '--oneline', '-1']);
        expect(log, contains(version));
      },
    );
  });

  group('PluginScaffold — B7 platform subset (FR-005)', () {
    test('B7: android,ios yields exactly app/core/android/ios', () async {
      final result = await scaffold(
        platforms: const [PluginPlatform.android, PluginPlatform.ios],
      );
      final monorepo = result.rootPath;

      final packages =
          Directory(p.join(monorepo, 'packages'))
              .listSync()
              .whereType<Directory>()
              .map((d) => p.basename(d.path))
              .toList()
            ..sort();
      expect(packages, [
        'my_plugin',
        'my_plugin_android',
        'my_plugin_ios',
        'my_plugin_platform',
      ]);
      expect(
        existsAt(p.join(monorepo, 'packages', 'my_plugin_macos')),
        isFalse,
        reason: 'unselected platform must have no adapter',
      );

      // The README's wiring example must name a registration that exists
      // in the subset: an android-less family can't tell users to call
      // `registerAndroid…` (review of PR #1609 — the token used to be
      // overridden with a literal `Android`).
      final subset = await scaffold(
        name: 'picker',
        platforms: const [PluginPlatform.ios, PluginPlatform.macos],
      );
      final subsetReadme = File(
        p.join(subset.rootPath, 'packages', 'picker', 'README.md'),
      ).readAsStringSync();
      expect(
        subsetReadme,
        contains('registerIosPickerDependencies'),
        reason: 'the subset README must point at its first platform adapter',
      );
      expect(
        subsetReadme,
        isNot(contains('registerAndroid')),
        reason: 'no android adapter is scaffolded for an ios,macos subset',
      );
    });
  });

  group('PluginScaffold — B8 selection rejection (FR-005 / FR-010)', () {
    test('B8: empty platform set refused naming the supported set', () async {
      await expectLater(
        scaffold(platforms: const []),
        throwsA(
          isA<PackageScaffoldException>().having(
            (e) => e.message,
            'message',
            allOf(contains('android'), contains('ios'), contains('macos')),
          ),
        ),
      );
      // And nothing was written.
      expect(tempDir.listSync().whereType<Directory>(), isEmpty);
    });

    test('B8b: unknown platform name refused naming the supported set', () {
      expect(
        () => PluginScaffold.platformsFromCsv('android,dos'),
        throwsA(
          isA<PackageScaffoldException>().having(
            (e) => e.message,
            'message',
            allOf(contains('dos'), contains('android'), contains('macos')),
          ),
        ),
      );
      expect(
        () => PluginScaffold.platformsFromCsv(''),
        throwsA(isA<PackageScaffoldException>()),
      );
      expect(
        PluginScaffold.platformsFromCsv(' macos , android '),
        equals({PluginPlatform.macos, PluginPlatform.android}),
        reason: 'csv parsing must tolerate whitespace',
      );
    });
  });

  group('PluginScaffold — B10 validation rails (FR-010)', () {
    test('B10: invalid names refused with the snake_case rule', () async {
      for (final bad in const ['Bad-Name', '9lives', 'MyPlugin']) {
        await expectLater(
          scaffold(name: bad),
          throwsA(
            isA<PackageScaffoldException>().having(
              (e) => e.message,
              'message',
              allOf(contains(bad), contains('snake_case')),
            ),
          ),
          reason: '$bad must be refused',
        );
      }
      expect(tempDir.listSync().whereType<Directory>(), isEmpty);
    });

    test('B10b: existing target refused, tree untouched', () async {
      final existing = Directory(p.join(tempDir.path, 'my_plugin'))
        ..createSync();
      File(p.join(existing.path, 'keep.txt')).writeAsStringSync('precious');

      await expectLater(
        scaffold(),
        throwsA(
          isA<PackageScaffoldException>().having(
            (e) => e.message,
            'message',
            contains('already exists'),
          ),
        ),
      );
      expect(
        File(p.join(existing.path, 'keep.txt')).readAsStringSync(),
        'precious',
      );
      expect(existing.listSync().length, 1, reason: 'nothing may be added');
    });

    test('B10c: bad --zuraffa-path refused', () async {
      await expectLater(
        scaffold(zuraffaPath: p.join(tempDir.path, 'nope')),
        throwsA(
          isA<PackageScaffoldException>().having(
            (e) => e.message,
            'message',
            contains('--zuraffa-path'),
          ),
        ),
      );
    });
  });

  group('PluginScaffold — B11 dry-run purity (FR-009)', () {
    test(
      'B11: dry-run enumerates exactly the real run and writes nothing',
      () async {
        final dryDir = await Directory.systemTemp.createTemp('zfa_plugin_dry_');
        try {
          final dry = await PluginScaffold().create(
            name: 'my_plugin',
            outputParent: dryDir.path,
            platforms: const [
              PluginPlatform.android,
              PluginPlatform.ios,
              PluginPlatform.macos,
            ],
            dryRun: true,
          );
          expect(
            Directory(p.join(dryDir.path, 'my_plugin')).existsSync(),
            isFalse,
            reason: 'dry-run must not create the monorepo',
          );
          expect(dry.createdFiles, isNotEmpty);

          // A real run in a sibling dir creates exactly the same files.
          final realParent = await Directory.systemTemp.createTemp(
            'zfa_plugin_real_',
          );
          try {
            final real = await PluginScaffold().create(
              name: 'my_plugin',
              outputParent: realParent.path,
              platforms: const [
                PluginPlatform.android,
                PluginPlatform.ios,
                PluginPlatform.macos,
              ],
            );
            final realRoot = real.rootPath;
            final realFiles = Directory(realRoot)
                .listSync(recursive: true)
                .whereType<File>()
                .map((f) => p.relative(f.path, from: realRoot))
                .toSet();
            expect(
              dry.createdFiles.toSet(),
              realFiles,
              reason: 'dry-run must enumerate exactly what a real run writes',
            );
          } finally {
            realParent.delete(recursive: true);
          }
        } finally {
          dryDir.delete(recursive: true);
        }
      },
    );
  });
}

Future<String> _git(String cwd, List<String> args) async {
  final result = await Process.run(
    'git',
    args,
    workingDirectory: cwd,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  expect(
    result.exitCode,
    0,
    reason: 'git ${args.first} failed: ${result.stderr}',
  );
  return result.stdout as String;
}
