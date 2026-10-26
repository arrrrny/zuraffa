// Issue #2021 — the `zfa tdd run` project-wiring preflight.
//
//   U-2021-1/2/3 (service) — `ProjectWiring.check` walks up from the
//              project root and answers ok ONLY when the root or an
//              ancestor carries a zuraffa/Dart wiring marker
//              (.zfa.json, pubspec.yaml, dart_test.yaml): no marker
//              anywhere up the tree = not ok (the TypeScript-repo
//              shape), an ancestor marker = ok (the monorepo-worktree
//              fail-open).
//
//   U-2021-4 (wiring) — on a non-Dart project the run refuses BEFORE
//              the first side effect: the structured refusal block
//              (header + the `--> fix:` line + the issue reference), the
//              all-zero `result=setup-error` summary line as the final
//              stdout line, exit 1, ZERO step spawns, NO cycle-marker
//              pid file (the #1507 kernel sweep never ran), NO Dart
//              scaffolding, and the preflight_red journal entry.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/project_wiring.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  // -------------------------------------------------------------------
  // The service contract (U-2021-1..3).
  // -------------------------------------------------------------------
  group('ProjectWiring (U-2021-1..3)', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('zfa_wiring_');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test(
      'U-2021-1: no marker at the root or any ancestor → not wired',
      () async {
        // The walk starts IN the temp dir; the stop boundary pins it to
        // the temp root (a marker AT the boundary would still count), so
        // the verdict cannot be flipped by ambient wiring markers ABOVE
        // the temp root (a stray pubspec.yaml in /tmp or above — the
        // review's U-2021-1 robustness note). A TS repo's shape — the
        // #2021 raptorr repro had package.json, no .zfa.json / pubspec /
        // dart_test.yaml.
        final report = await ProjectWiring(
          projectRoot: temp.path,
          stopBoundary: temp.path,
        ).check();

        expect(report.ok, isFalse, reason: 'no marker inside the boundary');
        expect(report.marker, isNull);
        expect(report.markerDir, isNull);
      },
    );

    test('U-2021-2: a marker at the project root → wired', () async {
      File(
        p.join(temp.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: wired\n');

      final report = await ProjectWiring(projectRoot: temp.path).check();

      expect(report.ok, isTrue);
      expect(report.marker, 'pubspec.yaml');
      expect(report.markerDir, p.normalize(temp.path));
    });

    test(
      'U-2021-3: a marker on an ANCESTOR → wired (the monorepo fail-open)',
      () async {
        // A worktree/subdir project whose Dart workspace parent carries
        // the marker — every marker flavor, since the walk accepts the
        // whole kProjectWiringMarkers set.
        for (final marker in kProjectWiringMarkers) {
          final root = Directory.systemTemp.createTempSync('zfa_wiring_anc_');
          addTearDown(() {
            if (root.existsSync()) root.deleteSync(recursive: true);
          });
          File(p.join(root.path, marker)).writeAsStringSync('');
          final nested = Directory(p.join(root.path, 'apps', 'feature'))
            ..createSync(recursive: true);

          final report = await ProjectWiring(projectRoot: nested.path).check();

          expect(report.ok, isTrue, reason: 'ancestor marker $marker');
          expect(report.marker, marker);
          expect(report.markerDir, p.normalize(root.path));
        }
      },
    );
  });

  // -------------------------------------------------------------------
  // The CLI wiring (U-2021-4) — the refusal fires before ANY side
  // effect on the TS-shaped fixture.
  // -------------------------------------------------------------------
  test(
    'U-2021-4: `tdd run` refuses a non-wired project before any side effect',
    () async {
      const feature = '2021-not-wired';
      final fx = await TddFixture.create(featureName: feature);
      addTearDown(fx.dispose);

      // The #2021 raptorr shape: TypeScript repo — package.json present,
      // and NO wiring marker anywhere. The fixture's pubspec.yaml (its
      // only marker) is deleted; the Dart-shaped profile and the seeded
      // test list stand in for the speckit plan artifacts the repro had.
      File(p.join(fx.root.path, 'pubspec.yaml')).deleteSync();
      await File(
        p.join(fx.root.path, 'package.json'),
      ).writeAsString('{"name": "raptorr-repro"}\n');
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'A1',
          description: 'renders the category lexicon',
          traces: 'FR-010',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // The structured refusal: header, the machine-actionable fix line,
      // and the issue reference.
      expect(out, contains('not zuraffa-wired'), reason: out);
      expect(
        out,
        contains('no .zfa.json, pubspec.yaml, dart_test.yaml'),
        reason: out,
      );
      expect(out, contains('--> fix:'), reason: out);
      expect(out, contains('issue #2021'), reason: out);
      // The summary machine contract (FR-009/FR-010) with the setup class:
      // the all-zero setup-error line is the run's final stdout line.
      expect(
        out,
        contains(
          'run: feature=$feature result=setup-error '
          'pending=0 red=0 green=0 done=0',
        ),
        reason: out,
      );
      expect(
        out.trim().split('\n').where((l) => l.trim().isNotEmpty).last,
        contains('result=setup-error'),
        reason: out,
      );
      // Exit 1 (the stopped/setup class).
      expect(CliRunner.lastDispatchedExitCode, 1, reason: out);
      // ZERO step spawns: no gen, no verify-red, no make — so no Dart
      // scaffolding can exist (the #2021 pollution).
      expect(fx.stepInvocations(), isEmpty, reason: out);
      expect(fx.stepArgvLog(), isEmpty, reason: out);
      expect(
        Directory(p.join(fx.root.path, 'test', 'tdd')).existsSync(),
        isFalse,
        reason: 'gen never ran — no test/tdd/ scaffolding',
      );
      expect(
        Directory(p.join(fx.root.path, 'lib', 'tdd')).existsSync(),
        isFalse,
        reason: 'gen never ran — no lib/tdd/ scaffolding',
      );
      // The #1507 kernel sweep never ran, so its project cycle marker
      // (the third artifact of the #2021 repro) was never written.
      expect(
        File(
          p.join(fx.root.path, '.dart_tool', 'zfa_tdd_cycle.pid'),
        ).existsSync(),
        isFalse,
        reason: 'the gate precedes the kernel sweep — no cycle pid file',
      );
      // The refusal is journaled preflight_red at the gate phase with the
      // wiring violation.
      final journalFile = File(p.join(fx.featureDir, 'tdd', 'journal.json'));
      expect(journalFile.existsSync(), isTrue, reason: out);
      final journal =
          jsonDecode(journalFile.readAsStringSync()) as Map<String, dynamic>;
      final entries = (journal['entries'] as List).cast<Map<String, dynamic>>();
      expect(entries, hasLength(1), reason: entries.toString());
      final entry = entries.single;
      expect(entry['gate_state'], 'preflight_red');
      expect(entry['phase'], 'gate');
      expect(entry['result'], 'setup-error');
      final violations = (entry['violations'] as List<dynamic>).cast<String>();
      expect(violations, hasLength(1), reason: violations.join('\n'));
      expect(violations.single, contains('project wiring'));
      expect(violations.single, contains('issue #2021'));
    },
  );
}
