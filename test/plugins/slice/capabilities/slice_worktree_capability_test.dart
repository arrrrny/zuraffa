// Spec 1114 — slice-based feature worktree tests.
//
// `zfa slice worktree <feature-id>` creates a git worktree ROOTED AT THE
// SLICE (`.zfa/slices/<id>`), so the agent's working tree is the feature
// (not the whole repo). The worktree records its parent linkage
// (`.slice/parent.json`) and the tdd transaction written inside it is the
// same transaction.json as the parent repo's, with paths rewritten to the
// slice root (the #1113 glue-back).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/project/project_root.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_transaction.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/compose_slice_capability.dart';
import 'package:zuraffa/src/plugins/slice/capabilities/slice_worktree_capability.dart';

import '../helpers/feature_slice_fixture.dart';

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_slice_worktree_');
    buildLoginProbe(workspace.path);
    await gitInitWithCommit(workspace.path);
  });

  tearDown(() async {
    // Detach the worktree's repo metadata before deleting the temp tree.
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

  String sliceRoot() => p.join(workspace.path, '.zfa', 'slices', 'login');

  Future<ProcessResult> gitIn(String dir, List<String> args) =>
      Process.run('git', args, workingDirectory: dir);

  ProcessResult processResult(
    int exitCode, {
    String out = '',
    String err = '',
  }) => ProcessResult(1, exitCode, out, err);

  group('SliceWorktreeCapability (spec 1114: worktree at the slice root)', () {
    test('opens a worktree at the slice root on branch slice/<id>', () async {
      final result = await SliceWorktreeCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );

      expect(result.success, isTrue, reason: result.message);
      expect(result.worktreePath, sliceRoot());
      expect(result.branch, 'slice/login');
      expect(result.commit, isNotNull);

      // The slice root IS a git working tree.
      final inside = await gitIn(sliceRoot(), [
        'rev-parse',
        '--is-inside-work-tree',
      ]);
      expect(inside.exitCode, 0, reason: inside.stderr.toString());
      expect(inside.stdout.toString().trim(), 'true');

      // On the slice branch, with a commit whose tree is the slice.
      final branch = await gitIn(sliceRoot(), [
        'rev-parse',
        '--abbrev-ref',
        'HEAD',
      ]);
      expect(branch.stdout.toString().trim(), 'slice/login');

      // The working tree is the FEATURE: engine/, skin/, contract/,
      // receipts/ — never the parent repo's whole tree.
      expect(Directory(p.join(sliceRoot(), 'engine')).existsSync(), isTrue);
      expect(Directory(p.join(sliceRoot(), 'skin')).existsSync(), isTrue);
      expect(Directory(p.join(sliceRoot(), 'contract')).existsSync(), isTrue);
      expect(Directory(p.join(sliceRoot(), 'receipts')).existsSync(), isTrue);
      expect(
        Directory(p.join(sliceRoot(), 'lib')).existsSync(),
        isFalse,
        reason: 'the whole-repo layout must not leak into the slice worktree',
      );

      // Clean status: the composition is committed, not pending.
      final status = await gitIn(sliceRoot(), ['status', '--porcelain']);
      expect(
        status.stdout.toString().trim(),
        isEmpty,
        reason: 'the worktree starts committed/clean',
      );
    });

    test(
      'records the parent linkage for the glue-back (.slice/parent.json)',
      () async {
        final parentHead = (await gitIn(workspace.path, [
          'rev-parse',
          'HEAD',
        ])).stdout.toString().trim();

        final result = await SliceWorktreeCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );
        expect(result.success, isTrue, reason: result.message);

        final parentJson =
            jsonDecode(
                  File(
                    p.join(sliceRoot(), '.slice', 'parent.json'),
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(parentJson['feature_id'], 'login');
        expect(parentJson['parent_root'], workspace.path);
        expect(parentJson['parent_branch'], 'master');
        expect(parentJson['parent_head'], parentHead);
        expect(parentJson['parent_head'], isNot(isEmpty));
      },
    );

    test('the slice manifest records the opened worktree', () async {
      final result = await SliceWorktreeCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );
      expect(result.success, isTrue);

      final manifestYaml = File(
        p.join(sliceRoot(), 'slice.yaml'),
      ).readAsStringSync();
      expect(manifestYaml, contains('worktree:'));
      expect(manifestYaml, contains('slice/login'));
      // The HEAD sha is deliberately NOT pinned into committed files —
      // it moves with every agent commit (the returned result carries
      // the creation commit instead).
      expect(result.commit, isNotNull);
    });

    test('an unknown feature id fails honestly (usage, no stack)', () async {
      final result = await SliceWorktreeCapability().execute(
        projectRoot: workspace.path,
        featureId: 'checkout',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('checkout'));
      expect(result.message, contains('login'));
    });

    test(
      'rejects feature ids that are not a single safe path component',
      () async {
        for (final featureId in [
          '../escape',
          'nested/login',
          r'nested\login',
          '.',
          '..',
          '',
        ]) {
          final result = await SliceWorktreeCapability().execute(
            projectRoot: workspace.path,
            featureId: featureId,
          );
          expect(result.success, isFalse, reason: featureId);
          expect(result.message, contains('Invalid feature id'));
        }
        expect(
          Directory(p.join(workspace.path, '.zfa', 'escape')).existsSync(),
          isFalse,
        );
      },
    );

    test('reports git add failures with stderr', () async {
      await ComposeSliceCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );
      final result = await SliceWorktreeCapability(
        gitLauncher: (args, workingDir) async {
          if (args case ['rev-parse', '--show-toplevel']) {
            return processResult(0, out: sliceRoot());
          }
          if (args case ['rev-parse', '--abbrev-ref', 'HEAD']) {
            return processResult(0, out: 'slice/login');
          }
          if (args case ['add', '-A']) {
            return processResult(1, err: 'index is locked');
          }
          return processResult(0, out: 'parent-head');
        },
      ).execute(projectRoot: workspace.path, featureId: 'login');

      expect(result.success, isFalse);
      expect(result.message, contains('index is locked'));
    });

    test('reports git commit failures and does not resolve HEAD', () async {
      await ComposeSliceCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );
      var resolvedHead = false;
      final result = await SliceWorktreeCapability(
        gitLauncher: (args, workingDir) async {
          if (args case ['rev-parse', '--show-toplevel']) {
            return processResult(0, out: sliceRoot());
          }
          if (args case ['rev-parse', '--abbrev-ref', 'HEAD']) {
            return processResult(0, out: 'slice/login');
          }
          if (args.first == 'commit') {
            return processResult(1, err: 'commit hook rejected');
          }
          if (args case ['status', '--porcelain']) {
            return processResult(0, out: 'M slice.yaml');
          }
          if (workingDir == sliceRoot() &&
              args.length == 2 &&
              args[0] == 'rev-parse' &&
              args[1] == 'HEAD') {
            resolvedHead = true;
          }
          return processResult(0, out: 'parent-head');
        },
      ).execute(projectRoot: workspace.path, featureId: 'login');

      expect(result.success, isFalse);
      expect(result.message, contains('commit hook rejected'));
      expect(resolvedHead, isFalse);
    });

    test(
      'a clean-tree commit no-op still resolves the existing HEAD',
      () async {
        await ComposeSliceCapability().execute(
          projectRoot: workspace.path,
          featureId: 'login',
        );
        final result = await SliceWorktreeCapability(
          gitLauncher: (args, workingDir) async {
            if (args case ['rev-parse', '--show-toplevel']) {
              return processResult(0, out: sliceRoot());
            }
            if (args case ['rev-parse', '--abbrev-ref', 'HEAD']) {
              return processResult(0, out: 'slice/login');
            }
            if (args.first == 'commit') {
              return processResult(1, err: 'nothing to commit');
            }
            if (args case ['status', '--porcelain']) {
              return processResult(0);
            }
            if (args case ['rev-parse', 'HEAD']) {
              return processResult(0, out: 'abc123');
            }
            return processResult(0, out: 'parent-head');
          },
        ).execute(projectRoot: workspace.path, featureId: 'login');

        expect(result.success, isTrue, reason: result.message);
        expect(result.commit, 'abc123');
      },
    );

    test('zfa tdd transaction equivalence: the transaction inside the '
        'worktree is the parent transaction with paths rewritten '
        '(#1113 glue-back)', () async {
      final result = await SliceWorktreeCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );
      expect(result.success, isTrue, reason: result.message);

      // Parent-side transaction (specs/login/tdd/transaction.json).
      final parentFeatureDir = p.join(workspace.path, 'specs', 'login');
      final parentTx = TddTransaction(parentFeatureDir);
      await parentTx.begin(behavior: 'U1', step: 'red');

      // The SAME write driven from inside the slice worktree: the tdd
      // mount is <sliceRoot()>/specs/login, so the transaction lands at
      // <sliceRoot()>/specs/login/tdd/transaction.json — the same record,
      // paths rewritten relative to the slice root.
      final sliceFeatureDir = p.join(sliceRoot(), 'specs', 'login');
      final sliceTx = TddTransaction(sliceFeatureDir);
      await sliceTx.begin(behavior: 'U1', step: 'red');

      final parentJournal =
          jsonDecode(
                File(
                  p.join(parentFeatureDir, 'tdd', 'transaction.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final sliceJournal =
          jsonDecode(
                File(
                  p.join(sliceFeatureDir, 'tdd', 'transaction.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;

      // Same transaction record: the feature axis is identical.
      expect(sliceJournal['feature'], parentJournal['feature']);
      expect(sliceJournal['feature'], 'login');
      expect(sliceJournal['behavior'], parentJournal['behavior']);
      expect(sliceJournal['step'], parentJournal['step']);
      expect(sliceJournal['status'], 'pending');

      // Paths rewritten: the transaction file sits at the same relative
      // structure under each root (specs/<feature>/tdd/transaction.json).
      final parentRel = p.relative(
        p.join(parentFeatureDir, 'tdd', 'transaction.json'),
        from: workspace.path,
      );
      final sliceRel = p.relative(
        p.join(sliceFeatureDir, 'tdd', 'transaction.json'),
        from: sliceRoot(),
      );
      expect(sliceRel, parentRel);
    });

    test('the tdd driver resolves its project root INSIDE the worktree '
        '(engine + skin cycles run inside the slice, #1114 item 6)', () async {
      final result = await SliceWorktreeCapability().execute(
        projectRoot: workspace.path,
        featureId: 'login',
      );
      expect(result.success, isTrue, reason: result.message);

      // The agent cd'd into the slice worktree: ProjectRoot.find
      // (anchorDir: 'specs' — the tdd run/run-engine/run-skin
      // resolution) must stop at the SLICE root, not walk to the
      // parent repo.
      final resolved = ProjectRoot.find(
        startPath: sliceRoot(),
        anchorDir: 'specs',
      );
      expect(
        p.canonicalize(resolved),
        p.canonicalize(sliceRoot()),
        reason: 'the tdd cycles run inside the slice, not the parent',
      );

      // And the feature dir the driver joins resolves to the mount.
      final featureDir = p.join(resolved, 'specs', 'login');
      expect(
        File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
        isTrue,
        reason: 'the driver finds the feature\'s test list inside the slice',
      );
    });
  });
}
