@Tags(['slow', 'integration'])
// Drift guard for bug #609 (tdd-make-planner-omits-name-flag).
//
// The unit suite (generation_planner_test.dart) pins the planner's argv
// against expectations written by the same author — which is exactly how
// the missing `-n` flag drifted: fake zfa scripts accepted a bare
// positional name, the real `EntityCommand` requires `-n/--name`, and CI
// stayed green while production failed at pipeline step 0.
//
// This slow-tier test closes that class of bug: it takes the planner's
// EMITTED argv for an entity-bearing behavior and runs it, verbatim,
// against the REAL `bin/zfa.dart entity create` CLI in a throwaway temp
// project. If the planner ever drifts from the real CLI contract again,
// the real CLI rejects the plan and this test goes red.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';

/// Walk up from [start] to the directory whose pubspec.yaml declares
/// `name: zuraffa` — the repo root where the REAL bin/zfa.dart lives.
Directory? _findZuraffaRoot(Directory start) {
  var dir = start;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zuraffa')) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

void main() {
  group('GenerationPlanner ⇄ real zfa CLI (bug #609 drift guard)', () {
    test('the planner-emitted entity argv is accepted by the REAL '
        '`zfa entity create` CLI — fake-zfa drift can no longer hide '
        'a malformed plan', () async {
      // 1. The planner plans an entity-bearing behavior.
      const planner = GenerationPlanner();
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-001',
          feature: '090-planner-real-cli',
          sourceCriterion: 'FR-005',
          description: 'create entity User with email',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: 'entity behavior must plan');
      expect(plan.steps, isNotEmpty);
      final argv = plan.steps.first.args;

      // 2. A minimal temp project the real CLI accepts (EntityCommand's
      //    dependency gate reads the pubspec for zorphy_annotation and
      //    build_runner before it will create anything).
      final tmp = await Directory.systemTemp.createTemp('planner_real_cli_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      await File(p.join(tmp.path, 'pubspec.yaml')).writeAsString('''
name: planner_real_cli_fixture
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');

      // 3. Run the planner's emitted argv VERBATIM against the REAL zfa
      //    CLI (bin/zfa.dart), exactly as PipelineRunner would.
      final repoRoot =
          _findZuraffaRoot(Directory.current) ??
          _findZuraffaRoot(File(Platform.script.toFilePath()).parent);
      expect(repoRoot, isNotNull, reason: 'cannot locate zuraffa repo root');
      final result = await Process.run(Platform.resolvedExecutable, [
        p.join(repoRoot!.path, 'bin', 'zfa.dart'),
        ...argv,
      ], workingDirectory: tmp.path);

      // 4. The real pipeline consumes exactly this argv — it must succeed.
      //    The pre-#609 plan (`entity create User`, no flag) fails here
      //    with "Error: Entity name is required. Use -n or --name to
      //    specify." and exit 1.
      final output = '${result.stdout}${result.stderr}';
      expect(
        result.exitCode,
        0,
        reason:
            'the real zfa CLI rejected the planner-emitted argv '
            '($argv) — planner/CLI drift:\n$output',
      );
      expect(
        output,
        isNot(contains('Entity name is required')),
        reason:
            'the planner must emit the `-n/--name` flag the real '
            'EntityCommand requires; a bare positional name is drift',
      );
    });
  });

  group('GenerationPlanner ⇄ real zfa CLI (bug #696 drift guard)', () {
    test('the planner-emitted `make <slug> --no-entity` argv is accepted '
        'by the REAL `zfa make` CLI, and the bare slug without the flag '
        'is rejected with the issue #696 failure', () async {
      // 1. The planner plans a unit CRUD behavior whose description
      //    names no entity: the slugified behavior id is the only name.
      const planner = GenerationPlanner();
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'U-6',
          feature: '090-planner-real-cli',
          sourceCriterion: 'FR-006',
          description: 'service exposes the count of pending items',
        ),
      );
      expect(plan.isExpressible, isTrue, reason: plan.unexpressibleReason);
      final argv = plan.steps.first.args;
      expect(argv.first, 'make');

      // 2. A minimal temp project for the real CLI.
      final tmp = await Directory.systemTemp.createTemp('planner_real_cli_');
      addTearDown(() {
        if (tmp.existsSync()) tmp.deleteSync(recursive: true);
      });
      await File(p.join(tmp.path, 'pubspec.yaml')).writeAsString('''
name: planner_real_cli_fixture
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');

      // 3. The bare slug (pre-#696 behavior) is REJECTED by the real
      //    CLI's #496 fail-fast: no entity source file was found.
      final repoRoot =
          _findZuraffaRoot(Directory.current) ??
          _findZuraffaRoot(File(Platform.script.toFilePath()).parent);
      expect(repoRoot, isNotNull, reason: 'cannot locate zuraffa repo root');
      final bare = await Process.run(Platform.resolvedExecutable, [
        p.join(repoRoot!.path, 'bin', 'zfa.dart'),
        'make',
        'u_6',
      ], workingDirectory: tmp.path);
      final bareOutput = '${bare.stdout}${bare.stderr}';
      expect(
        bareOutput,
        contains('no entity source file was found'),
        reason:
            'the pre-fix argv (bare slugified behavior id) must '
            'reproduce the issue #696 failure against the real CLI:\n'
            '$bareOutput',
      );

      // 4. The planner's emitted argv — the same slug WITH --no-entity —
      //    is accepted verbatim by the real CLI (PipelineRunner runs
      //    exactly this).
      final fixed = await Process.run(Platform.resolvedExecutable, [
        p.join(repoRoot.path, 'bin', 'zfa.dart'),
        ...argv,
      ], workingDirectory: tmp.path);
      final fixedOutput = '${fixed.stdout}${fixed.stderr}';
      expect(
        fixed.exitCode,
        0,
        reason:
            'the real zfa CLI rejected the planner-emitted argv '
            '($argv) — planner/CLI drift:\n$fixedOutput',
      );
      expect(
        fixedOutput,
        isNot(contains('no entity source file was found')),
        reason:
            'the --no-entity flag must bypass the #496 fail-fast '
            '(issue #696):\n$fixedOutput',
      );
    });
  });
}
