/// Unit behavior U6 for spec 066-zfa-replay: the sandbox seeds, excludes,
/// and cleans (FR-006/FR-007).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/plugins/tdd/services/replay_sandbox.dart';

import '../helpers/replay_fixture.dart';

void main() {
  group('ReplaySandbox', () {
    test('U6: seeds the project contracts byte-identically', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      await fx.appendCycle('066-b1', marker: 'm1');
      await Directory(p.join(fx.root.path, '.specify')).create();
      await File(
        p.join(fx.root.path, '.specify', 'config.md'),
      ).writeAsString('specify config\n');
      await File(
        p.join(fx.root.path, 'analysis_options.yaml'),
      ).writeAsString('include: package:lints/recommended.yaml\n');

      final sandbox = await ReplaySandbox.create(
        projectRoot: fx.root.path,
        feature: fx.featureName,
      );
      addTearDown(sandbox.delete);

      expect(await Directory(sandbox.path).exists(), isTrue);
      expect(
        await File(p.join(sandbox.path, 'pubspec.yaml')).readAsString(),
        await File(p.join(fx.root.path, 'pubspec.yaml')).readAsString(),
      );
      expect(
        await File(
          p.join(sandbox.path, '.dart_tool', 'package_config.json'),
        ).exists(),
        isTrue,
      );
      expect(
        await File(
          p.join(sandbox.path, 'analysis_options.yaml'),
        ).exists(),
        isTrue,
      );
      expect(
        await File(p.join(sandbox.path, '.specify', 'config.md')).exists(),
        isTrue,
      );
      // The feature's spec directory — the cycle log must be there.
      expect(
        await File(
          p.join(sandbox.path, 'specs', fx.featureName, 'tdd', 'cycle-log.md'),
        ).exists(),
        isTrue,
      );
      // lib/ and test/ trees copy with their content.
      expect(
        await File(p.join(sandbox.path, 'lib', '066_b1_subject.dart'))
            .readAsString(),
        await File(fx.subjectPathOf('066-b1')).readAsString(),
      );
      expect(
        await File(p.join(sandbox.path, 'test', '066_b1_test.dart')).exists(),
        isTrue,
      );
    });

    test('U6: absent sources are skipped silently', () async {
      final fx = await ReplayFixture.create(withPackageConfig: false);
      addTearDown(() => fx.root.delete(recursive: true));

      final sandbox = await ReplaySandbox.create(
        projectRoot: fx.root.path,
        feature: fx.featureName,
      );
      addTearDown(sandbox.delete);

      expect(
        await File(
          p.join(sandbox.path, '.dart_tool', 'package_config.json'),
        ).exists(),
        isFalse,
      );
      expect(
        await File(p.join(sandbox.path, 'analysis_options.yaml')).exists(),
        isFalse,
      );
    });

    test('U6: .git, build/ and dart kernel caches are excluded', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      for (final name in ['.git', 'build']) {
        final d = Directory(p.join(fx.root.path, name));
        await d.create(recursive: true);
        await File(p.join(d.path, 'blob.txt')).writeAsString('heavy\n');
      }
      final kernel = Directory(p.join(fx.root.path, '.dart_tool', 'test'));
      await kernel.create(recursive: true);
      await File(
        p.join(kernel.path, 'incremental_kernel.dart'),
      ).writeAsString('kernel\n');

      final sandbox = await ReplaySandbox.create(
        projectRoot: fx.root.path,
        feature: fx.featureName,
      );
      addTearDown(sandbox.delete);

      expect(await Directory(p.join(sandbox.path, '.git')).exists(), isFalse);
      expect(
        await Directory(p.join(sandbox.path, 'build')).exists(),
        isFalse,
      );
      expect(
        await Directory(p.join(sandbox.path, '.dart_tool', 'test')).exists(),
        isFalse,
      );
    });

    test('U6: delete() removes the sandbox', () async {
      final fx = await ReplayFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));

      final sandbox = await ReplaySandbox.create(
        projectRoot: fx.root.path,
        feature: fx.featureName,
      );
      expect(await Directory(sandbox.path).exists(), isTrue);
      await sandbox.delete();
      expect(await Directory(sandbox.path).exists(), isFalse);
    });
  });
}
