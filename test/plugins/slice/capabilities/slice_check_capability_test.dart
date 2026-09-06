// Spec 1114 — slice compliance check tests.
//
// `zfa slice check <feature-id>` validates:
//   1. every file in the slice's engine/ is in the contract's entities;
//   2. every view in skin/ is in the contract's routes;
//   3. every layer is in xrayLayer (expanded: a layer's files may occupy
//      its layer or the layers beneath it);
//   4. files outside the slice (stray disk files the agent added) FAIL.
//
// Exit semantics: compliant => success (exit 0) with a report; any
// violation => failure (exit 1) with a "files outside slice" report.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/slice_check_capability.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/slice_worktree_capability.dart';

import '../helpers/feature_slice_fixture.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_slice_check_');
    buildLoginProbe(workspace.path);
    await gitInitWithCommit(workspace.path);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await Process.run('git', [
        'worktree',
        'prune',
      ], workingDirectory: workspace.path);
      try {
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            await workspace.delete(recursive: true);
            return;
          } on FileSystemException {
            if (attempt == 2) rethrow;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        }
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  String slicePath(String rel) =>
      p.join(workspace.path, '.zfa', 'slices', 'login', rel);

  Future<void> composeAndOpenWorktree() async {
    final result = await SliceWorktreeCapability().execute(
      projectRoot: workspace.path,
      featureId: 'login',
    );
    expect(result.success, isTrue, reason: result.message);
  }

  group('SliceCheckCapability (spec 1114: compliance)', () {
    test('a composed slice checks green (exit 0) with a report', () async {
      await composeAndOpenWorktree();

      final result = await SliceCheckCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );

      expect(result.success, isTrue, reason: result.violations.join('\n'));
      expect(result.violations, isEmpty);
      expect(result.reportPath, isNotNull);
      expect(File(result.reportPath!).existsSync(), isTrue);
      expect(result.checkedFiles, greaterThan(0));

      final report =
          jsonDecode(File(result.reportPath!).readAsStringSync())
              as Map<String, dynamic>;
      expect(report['feature'], 'login');
      expect(report['verdict'], 'compliant');
      expect(report['violations'], isEmpty);
    });

    test(
      'an engine file outside the contract entities FAILS (exit 1)',
      () async {
        await composeAndOpenWorktree();

        // The agent smuggled an unowned entity into the engine.
        writeFile(
          slicePath(''),
          'engine/entities/hacker/hacker.dart',
          'class Hacker {}\n',
        );

        final result = await SliceCheckCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(result.success, isFalse);
        expect(result.violations, isNotEmpty);
        expect(
          result.violations.map((v) => v.message).join('\n'),
          contains('hacker'),
        );
        expect(
          result.violations.any((v) => v.kind == 'engine-entity'),
          isTrue,
          reason: 'violation kind names the engine/entity rule',
        );
        final report =
            jsonDecode(File(result.reportPath!).readAsStringSync())
                as Map<String, dynamic>;
        expect(report['verdict'], isNot('compliant'));
      },
    );

    test('a view outside the contract routes FAILS (exit 1)', () async {
      await composeAndOpenWorktree();

      writeFile(
        slicePath(''),
        'skin/views/rogue_view.dart',
        'class RogueView {}\n',
      );

      final result = await SliceCheckCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );

      expect(result.success, isFalse);
      expect(
        result.violations.any((v) => v.kind == 'skin-route'),
        isTrue,
        reason: 'violation kind names the skin/route rule',
      );
      expect(
        result.violations.map((v) => v.message).join('\n'),
        contains('rogue_view.dart'),
      );
    });

    test(
      'a file outside the slice sections FAILS with the file named',
      () async {
        await composeAndOpenWorktree();

        // A stray file at the slice root — outside every declared section.
        writeFile(slicePath(''), 'exploit.dart', 'void main() {}\n');

        final result = await SliceCheckCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(result.success, isFalse);
        expect(
          result.violations.any((v) => v.kind == 'outside-slice'),
          isTrue,
          reason: 'files outside the slice must fail the check',
        );
        expect(
          result.violations.map((v) => v.message).join('\n'),
          contains('exploit.dart'),
        );
      },
    );

    test(
      'an agent EDIT inside the slice is allowed (work, not violation)',
      () async {
        await composeAndOpenWorktree();

        // The agent edited an owned engine file — that IS the point of the
        // slice; only out-of-contract FILES fail, not owned-file edits.
        final owned = File(slicePath('engine/entities/User/user.dart'));
        owned.writeAsStringSync('class User { final String id; }\n');

        final result = await SliceCheckCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );

        expect(result.success, isTrue, reason: result.violations.join('\n'));
      },
    );

    test('an uncomposed feature id fails honestly', () async {
      final result = await SliceCheckCapability().execute(
        projectRoot: workspace.path,
        featureId: 'checkout',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('checkout'));
    });

    test('corrupt contract JSON returns a typed user-facing failure', () async {
      await composeAndOpenWorktree();
      File(slicePath('contract/contract.json')).writeAsStringSync('{broken');

      final result = await SliceCheckCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('contract'));
      expect(result.message, contains('corrupt'));
      expect(result.message, isNot(contains('Stack trace')));
    });
  });
}
