// SPEC 1395 — `PubspecAppDependenciesPatcher` dry-run + additivity
// contract on the setup day-zero pass.
//
// The #1395 fix wires the SAME idempotent self-heal `zfa tdd init` runs
// (issue #1349) into `zfa setup`'s `_emitTddBaseline`, right after the
// `lib/app.dart` module write. To preview the day-zero baseline without
// touching disk (setup's `--dry-run`), the patcher's `ensure` gained a
// `dryRun` parameter mirroring `PubspecDevDependenciesPatcher.ensure`:
// report what WOULD be added, tolerate a missing pubspec (the project is
// being scaffolded), never write.
//
// The additivity pin is the setup-specific shape: a fresh `zfa setup` tree
// already has `zuraffa_flutter` declared by the DependencyWirer — the pass
// must add ONLY the still-missing `get_it`, never a duplicate.
//
// Compile-error red pre-fix is the honest first red for the new seam (the
// dryRun parameter did not exist), per the house convention recorded in
// `tdd/test-list.md` for #1664.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/writers/tdd/pubspec_app_dependencies_patcher.dart';

void main() {
  group('spec 1395: app-deps patcher dry-run + additivity', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('spec1395_patcher_');
    });

    tearDown(() {
      if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
    });

    test('dry-run on a scaffolded-from-scratch project reports both deps and '
        'writes nothing', () async {
      final missing = await const PubspecAppDependenciesPatcher().ensure(
        p.join(tmpDir.path, 'not_created_yet'),
        dryRun: true,
      );

      expect(
        missing,
        containsAll(['zuraffa_flutter: ^6.0.0', 'get_it: ^9.2.1']),
        reason:
            'the preview must report the app module\'s runtime deps when '
            'nothing is declared yet',
      );
      expect(
        File(
          p.join(tmpDir.path, 'not_created_yet', 'pubspec.yaml'),
        ).existsSync(),
        isFalse,
        reason: 'a dry-run must never touch disk',
      );
    });

    test('dry-run on an existing pubspec reports only the missing entries and '
        'leaves the file byte-identical', () async {
      // The DependencyWirer wires `zuraffa_flutter` during setup — the
      // preview must report ONLY the still-missing `get_it`.
      final pubspecFile = File(p.join(tmpDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: spec1395_dryrun_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa_flutter: ^6.0.0
''');
      final before = pubspecFile.readAsStringSync();

      final missing = await const PubspecAppDependenciesPatcher().ensure(
        tmpDir.path,
        dryRun: true,
      );

      expect(missing, ['get_it: ^9.2.1']);
      expect(
        pubspecFile.readAsStringSync(),
        before,
        reason: 'a dry-run must never touch disk',
      );
    });

    test('the self-heal is additive: an already-wired barrel gains ONLY the '
        'missing get_it, under dependencies:', () async {
      final pubspecFile = File(p.join(tmpDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: spec1395_additive_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  # wired by the DependencyWirer during setup — do not touch
  zuraffa_flutter: ^6.0.0
dev_dependencies:
  flutter_test:
    sdk: flutter
''');

      final added = await const PubspecAppDependenciesPatcher().ensure(
        tmpDir.path,
      );

      expect(added, ['get_it: ^9.2.1']);
      final pubspec = pubspecFile.readAsStringSync();
      expect(
        'zuraffa_flutter'.allMatches(pubspec).length,
        1,
        reason: 'the wirer-declared barrel must not be duplicated',
      );
      expect(pubspec, contains('get_it: ^9.2.1'));
      // Runtime dep — lands under `dependencies:`, never under
      // `dev_dependencies:` (lib/app.dart is runtime source).
      final depsMatch = RegExp(
        r'^dependencies:',
        multiLine: true,
      ).firstMatch(pubspec)!;
      final devMatch = RegExp(
        r'^dev_dependencies:',
        multiLine: true,
      ).firstMatch(pubspec)!;
      final getItIdx = pubspec.indexOf('get_it');
      expect(getItIdx, greaterThan(depsMatch.start));
      expect(getItIdx, lessThan(devMatch.start));
    });

    test(
      're-running the pass adds nothing (idempotent, cross-command)',
      () async {
        final pubspecFile = File(p.join(tmpDir.path, 'pubspec.yaml'));
        await pubspecFile.writeAsString('''
name: spec1395_idempotent_fixture
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
''');

        final patcher = const PubspecAppDependenciesPatcher();
        final first = await patcher.ensure(tmpDir.path);
        expect(
          first,
          hasLength(2),
          reason:
              'the fresh pubspec must gain both runtime deps, got: '
              '${first.join(', ')}',
        );
        final afterFirst = pubspecFile.readAsStringSync();

        // The second pass — e.g. `zfa tdd init` re-running its #1349
        // self-heal after setup already declared the pair — must be a
        // no-op.
        final second = await patcher.ensure(tmpDir.path);
        expect(second, isEmpty);
        expect(
          pubspecFile.readAsStringSync(),
          afterFirst,
          reason: 'a re-run must not rewrite a complete pubspec',
        );
      },
    );

    test('dry-run on a broken pubspec reports the SAME invalid-YAML '
        'FormatException the real pass throws (PR #1702 review)', () async {
      final pubspecFile = File(p.join(tmpDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString(
        'name: broken\n  bad: : :\n   bad indent',
      );

      await expectLater(
        const PubspecAppDependenciesPatcher().ensure(tmpDir.path, dryRun: true),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('is not valid YAML'),
          ),
        ),
        reason:
            'the preview must not escape a raw YamlException where the '
            'real path throws a readable FormatException',
      );
    });

    test('dry-run on a non-map dependencies value reports the SAME '
        'FormatException the real pass throws (PR #1702 review)', () async {
      final pubspecFile = File(p.join(tmpDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: spec1395_nonmap_fixture
environment:
  sdk: ^3.11.0
dependencies: true
''');

      await expectLater(
        const PubspecAppDependenciesPatcher().ensure(tmpDir.path, dryRun: true),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('has a non-map dependencies value'),
          ),
        ),
        reason:
            'the preview must not throw a bare TypeError where the real '
            'path throws a readable FormatException',
      );
    });

    test(
      'dry-run on a non-empty inline flow mapping previews the SAME '
      'UnsupportedError refusal the real pass throws (PR #1702 review)',
      () async {
        final pubspecFile = File(p.join(tmpDir.path, 'pubspec.yaml'));
        await pubspecFile.writeAsString('''
name: spec1395_inline_fixture
environment:
  sdk: ^3.11.0
dependencies: {flutter: {sdk: flutter}}
''');

        await expectLater(
          const PubspecAppDependenciesPatcher().ensure(
            tmpDir.path,
            dryRun: true,
          ),
          throwsA(isA<UnsupportedError>()),
          reason:
              'the preview must not promise "Would add" entries the real '
              'pass refuses (inline mappings unsupported)',
        );
      },
    );

    test('dry-run on an inline mapping with nothing missing stays silent '
        '(mirrors the real pass, which returns before the refusal)', () async {
      final pubspecFile = File(p.join(tmpDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString(
        'name: spec1395_inline_complete\n'
        'environment:\n'
        '  sdk: ^3.11.0\n'
        'dependencies: {zuraffa_flutter: ^6.0.0, get_it: ^9.2.1}\n',
      );

      final missing = await const PubspecAppDependenciesPatcher().ensure(
        tmpDir.path,
        dryRun: true,
      );

      expect(missing, isEmpty);
    });
  });
}
