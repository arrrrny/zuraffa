// Bug #1303 — the dependency_overrides path preflight (service unit tests).
//
// `tdd make` / `tdd run` spend minutes compiling before a stale
// `dependency_overrides` path entry (e.g. `path: ../../zuraffa_flutter`
// pointing at a directory that does not exist) surfaces as a raw
// exit-255 version-solving dump buried mid-log — and the "retry with
// clean cache" fallback then burns a full rebuild on a failure no cache
// clean can fix (issue #1303).
//
// Fix contract (issue #1303, remediation 1): the preflight parses the
// project's `dependency_overrides`, and for EVERY `path:` value verifies
// `<projectRoot>/<path>/pubspec.yaml` exists. A stale path is a FINDING;
// findings refuse the pipeline up front with an honest, machine-actionable
// verdict instead of a mid-pipeline dump.
//
// Fail-open boundaries (the preflight's single contract is stale PATH
// overrides — anything else fails honestly downstream):
//   - no pubspec.yaml at the project root → vacuous pass (nothing to
//     validate; the pipeline's own pub get names the real problem);
//   - an unparseable pubspec → vacuous pass (same reasoning);
//   - non-path overrides (version strings, sdk maps) → ignored.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/dependency_override_preflight.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug1303_preflight_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedPubspec(String content) async {
    await File(p.join(tmpDir.path, 'pubspec.yaml')).writeAsString(content);
  }

  group('bug1303: DependencyOverridePreflight path resolution', () {
    test(
      'map-form stale path override is a finding naming package+path',
      () async {
        await seedPubspec('''
name: login_demo
dependency_overrides:
  zuraffa:
    path: ../..
  zuraffa_flutter:
    path: ../zuraffa_flutter_missing
''');

        final report = await DependencyOverridePreflight(
          projectRoot: tmpDir.path,
        ).check();

        expect(report.ok, isFalse, reason: 'a stale path must fail the gate');
        // The `zuraffa: {path: ../..}` entry resolves to the temp parent —
        // a real directory that carries no pubspec.yaml, so BOTH path
        // overrides are findings. The contract under test: the STALE
        // zuraffa_flutter one is named.
        expect(
          report.findings,
          anyElement(
            isA<OverridePathFinding>()
                .having((f) => f.package, 'package', 'zuraffa_flutter')
                .having((f) => f.path, 'path', '../zuraffa_flutter_missing'),
          ),
        );
        expect(
          report.findings,
          everyElement(
            isA<OverridePathFinding>()
                .having((f) => f.detail, 'detail', contains('no pubspec.yaml'))
                .having(
                  (f) => f.resolved,
                  'resolved',
                  predicate<String>(p.isAbsolute, 'is absolute'),
                ),
          ),
          reason:
              'every finding must name WHY the path does not resolve and '
              'the absolute location the gate checked',
        );
      },
    );

    test(
      'the bug #1303 repro shape: .. segments resolve against the root',
      () async {
        // The issue's exact override: ../../zuraffa_flutter from an app
        // scaffolded INSIDE the zuraffa checkout — one depth off from the
        // real sibling checkout. The resolved location must normalize the
        // .. segments against the project root, not lexicographically.
        await seedPubspec('''
name: login_demo
dependency_overrides:
  zuraffa:
    path: ../..
  zuraffa_flutter:
    path: ../../zuraffa_flutter
''');

        final report = await DependencyOverridePreflight(
          projectRoot: tmpDir.path,
        ).check();

        expect(report.ok, isFalse);
        expect(
          report.findings,
          anyElement(
            isA<OverridePathFinding>()
                .having((f) => f.package, 'package', 'zuraffa_flutter')
                .having((f) => f.path, 'path', '../../zuraffa_flutter'),
          ),
          reason:
              'the stale zuraffa_flutter override must be among the '
              'findings (the ../.. one resolves to a real directory that '
              'may or may not carry a pubspec — either way, the STALE one '
              'is named)',
        );
      },
    );

    test('a string override is a VERSION constraint, never a path — '
        'ignored', () async {
      // `analyzer: 14.1.0` pins a version; it is NOT a path override in
      // pub's grammar. Validating it as a path would false-positive
      // every version pin and refuse healthy projects (issue #1303
      // constraint: validate path targets ONLY).
      await seedPubspec('''
name: login_demo
dependency_overrides:
  analyzer: 14.1.0
''');

      final report = await DependencyOverridePreflight(
        projectRoot: tmpDir.path,
      ).check();

      expect(report.ok, isTrue);
      expect(report.findings, isEmpty);
      expect(report.overridesChecked, 0);
    });

    test('a path override whose target HAS pubspec.yaml passes', () async {
      // The sibling checkout the override names — INSIDE the project
      // root, carrying a pubspec.yaml, so the gate must pass it.
      final target = Directory(p.join(tmpDir.path, 'the_real_checkout'));
      await target.create(recursive: true);
      await File(
        p.join(target.path, 'pubspec.yaml'),
      ).writeAsString('name: x\n');
      await seedPubspec('''
name: login_demo
dependency_overrides:
  zuraffa:
    path: the_real_checkout
''');

      final report = await DependencyOverridePreflight(
        projectRoot: tmpDir.path,
      ).check();

      expect(report.ok, isTrue, reason: 'a resolvable path must pass');
      expect(report.findings, isEmpty);
      expect(report.overridesChecked, 1);
    });

    test(
      'non-path overrides (version strings, sdk maps) are ignored',
      () async {
        await seedPubspec('''
name: login_demo
dependency_overrides:
  analyzer: 14.1.0
  flutter:
    sdk: flutter
  intl: ^0.19.0
''');

        final report = await DependencyOverridePreflight(
          projectRoot: tmpDir.path,
        ).check();

        expect(
          report.ok,
          isTrue,
          reason: 'no path overrides — nothing to check',
        );
        expect(report.findings, isEmpty);
      },
    );

    test('no dependency_overrides section at all is a vacuous pass', () async {
      await seedPubspec('''
name: login_demo
dependencies:
  path: ^1.9.0
''');

      final report = await DependencyOverridePreflight(
        projectRoot: tmpDir.path,
      ).check();

      expect(report.ok, isTrue);
      expect(report.findings, isEmpty);
      expect(report.overridesChecked, 0);
    });

    test('missing pubspec.yaml is a vacuous pass (fail-open)', () async {
      final report = await DependencyOverridePreflight(
        projectRoot: tmpDir.path,
      ).check();

      expect(
        report.ok,
        isTrue,
        reason:
            'the preflight validates override paths, not the pubspec itself '
            '— a pubspec-less project fails honestly at pub get',
      );
      expect(report.findings, isEmpty);
    });

    test('unreadable pubspec.yaml is a vacuous pass (fail-open on the '
        'exists()/read() permission race)', () async {
      // A path override pointing at a REAL target, so the verdict can
      // only come from the read failing — not from a finding.
      final target = Directory(p.join(tmpDir.path, 'real_target'))
        ..createSync();
      File(
        p.join(target.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: real_target\n');
      final pubspec = File(p.join(tmpDir.path, 'pubspec.yaml'));
      await pubspec.writeAsString('''
name: login_demo
dependency_overrides:
  real_target:
    path: real_target
''');

      await Process.run('chmod', ['000', pubspec.path]);
      try {
        final report = await DependencyOverridePreflight(
          projectRoot: tmpDir.path,
        ).check();

        expect(
          report.ok,
          isTrue,
          reason:
              'an unreadable pubspec fails honestly at pub itself; the '
              'preflight must not crash with an unhandled '
              'FileSystemException',
        );
        expect(report.findings, isEmpty);
      } finally {
        await Process.run('chmod', ['644', pubspec.path]);
      }
    });

    test('every finding renders the honest single-line verdict', () async {
      await seedPubspec('''
name: login_demo
dependency_overrides:
  zuraffa_flutter:
    path: ../../zuraffa_flutter
''');

      final report = await DependencyOverridePreflight(
        projectRoot: tmpDir.path,
      ).check();

      final line = DependencyOverridePreflight.findingLine(
        report.findings.single,
      );
      expect(line, startsWith('❌ preflight:'));
      expect(line, contains('dependency_overrides["zuraffa_flutter"]'));
      expect(line, contains('path "../../zuraffa_flutter"'));
      expect(
        line,
        contains('does not resolve to a package'),
        reason: 'the issue #1303 verdict wording',
      );
      expect(line, contains('(no pubspec.yaml'));
    });
  });
}
