/// SliceWorktreeCapability (spec 1114): the slice-based feature
/// worktree.
///
/// `zfa slice worktree <feature-id>` opens a git worktree ROOTED AT
/// THE SLICE (`.zfa/slices/<feature-id>`), so the agent's working tree
/// is the feature — engine/, skin/, contract/, receipts/ — not the
/// whole repo. That is the plugin's stated purpose: scope the agent's
/// CONTEXT, not just its file list (#1114).
///
/// The worktree is a dedicated git repository rooted at the slice:
/// a plain `git worktree add` checks out the ENTIRE parent repo into
/// the working tree, which would hand the agent the whole app — the
/// opposite of the slice. A dedicated repo at the slice root keeps the
/// working tree scoped to the feature, and the parent linkage is
/// recorded in `.slice/parent.json` (parent root, branch, HEAD) plus
/// `slice.yaml`'s worktree record, so `zfa slice merge` glues the
/// agent's work (and the tdd journal, #1113) back into the parent
/// feature.
///
/// Composing first is required — the worktree commits the composed
/// base (auto-composes when the slice is missing).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../generators/feature_slice_composer.dart';
import '../models/feature_slice_manifest.dart';
import 'compose_slice_capability.dart';

/// Runs `git <args>` in [workingDir]; injectable for tests.
typedef SliceGitLauncher =
    Future<ProcessResult> Function(List<String> args, String workingDir);

/// The result of opening a slice worktree.
class SliceWorktreeResult {
  /// Whether the worktree opened.
  final bool success;

  /// Human-readable outcome (INV-1: text, never a stack trace).
  final String message;

  /// Absolute path of the worktree (= the slice root).
  final String? worktreePath;

  /// The worktree branch (`slice/<feature-id>`).
  final String? branch;

  /// The HEAD commit sha of the initial composition commit.
  final String? commit;

  const SliceWorktreeResult({
    required this.success,
    required this.message,
    this.worktreePath,
    this.branch,
    this.commit,
  });
}

/// Opens feature-slice worktrees.
class SliceWorktreeCapability {
  /// Creates the capability. [gitLauncher] injects the git subprocess
  /// (tests); the default runs the real `git`.
  SliceWorktreeCapability({SliceGitLauncher? gitLauncher})
    : _git = gitLauncher ?? _defaultGit;

  final SliceGitLauncher _git;

  static Future<ProcessResult> _defaultGit(
    List<String> args,
    String workingDir,
  ) => Process.run('git', args, workingDirectory: workingDir);

  /// Opens the worktree for [featureId] at `.zfa/slices/<featureId>`.
  ///
  /// Auto-composes the slice when missing ([composeIfMissing]); the
  /// composition (typed contract → engine/skin/contract/receipts) is
  /// committed on branch `slice/<feature-id>`.
  Future<SliceWorktreeResult> execute({
    required String projectRoot,
    required String featureId,
    bool composeIfMissing = true,
  }) async {
    if (featureId.isEmpty ||
        featureId == '.' ||
        featureId == '..' ||
        featureId.contains('/') ||
        featureId.contains(r'\')) {
      return SliceWorktreeResult(
        success: false,
        message:
            'Invalid feature id "$featureId": expected one safe path '
            'component (spec 1114).',
      );
    }
    final slicesRoot = p.canonicalize(
      FeatureSliceComposer.slicesRootOf(projectRoot),
    );
    final sliceRoot = FeatureSliceComposer.sliceRootOf(projectRoot, featureId);
    final canonicalSliceRoot = p.canonicalize(sliceRoot);
    if (!p.isWithin(slicesRoot, canonicalSliceRoot)) {
      return SliceWorktreeResult(
        success: false,
        message:
            'Invalid feature id "$featureId": the slice path escapes the '
            'slices root (spec 1114).',
      );
    }
    final manifestFile = File(p.join(sliceRoot, 'slice.yaml'));

    // 1. Ensure the slice is composed (typed contract resolution runs
    // inside compose — the raw string is never the definition).
    if (!manifestFile.existsSync()) {
      if (!composeIfMissing) {
        return SliceWorktreeResult(
          success: false,
          message:
              'Feature "$featureId" has no composed slice — run '
              '`zfa slice compose $featureId` first (spec 1114).',
        );
      }
      final composed = await ComposeSliceCapability().execute(
        projectRoot: projectRoot,
        featureId: featureId,
      );
      if (!composed.success) {
        return SliceWorktreeResult(success: false, message: composed.message);
      }
    }

    final FeatureSliceManifest manifest;
    try {
      manifest = FeatureSliceManifest.fromYaml(manifestFile.readAsStringSync());
    } on FeatureSliceManifestYamlError catch (error) {
      return SliceWorktreeResult(
        success: false,
        message:
            'The slice manifest at ${manifestFile.path} is corrupt '
            '(${error.message}) — re-run `zfa slice compose $featureId` '
            '(spec 1114).',
      );
    } on FormatException {
      return SliceWorktreeResult(
        success: false,
        message:
            'The slice manifest at ${manifestFile.path} is corrupt '
            '(unparseable) — re-run `zfa slice compose $featureId` '
            '(spec 1114).',
      );
    }
    final contract = manifest.feature;

    // 2. The worktree is a git repository ROOTED AT the slice.
    //
    //    `rev-parse --is-inside-work-tree` is TRUE from any
    //    subdirectory of the PARENT repo — the discriminator is
    //    `--show-toplevel`: the containing repo's root must BE the
    //    slice root, or the slice needs its own `git init`.
    final branch = 'slice/${contract.id}';
    final topLevel = await _git(['rev-parse', '--show-toplevel'], sliceRoot);
    final isSliceRepo =
        topLevel.exitCode == 0 &&
        p.canonicalize(topLevel.stdout.toString().trim()) ==
            p.canonicalize(sliceRoot);
    if (!isSliceRepo) {
      final init = await _git(['init', '-b', branch], sliceRoot);
      if (init.exitCode != 0) {
        return SliceWorktreeResult(
          success: false,
          message:
              'git init failed at the slice root: '
              '${init.stderr.toString().trim()} (spec 1114).',
        );
      }
    } else {
      // An existing slice repo: make sure it sits on the slice branch.
      final current = await _git([
        'rev-parse',
        '--abbrev-ref',
        'HEAD',
      ], sliceRoot);
      if (current.exitCode != 0 || current.stdout.toString().trim() != branch) {
        final checkout = await _git(['checkout', '-B', branch], sliceRoot);
        if (checkout.exitCode != 0) {
          return SliceWorktreeResult(
            success: false,
            message:
                'could not move the slice repo onto "$branch": '
                '${checkout.stderr.toString().trim()} (spec 1114).',
          );
        }
      }
    }
    await _git(['config', 'user.name', 'zfa-slice-agent'], sliceRoot);
    await _git([
      'config',
      'user.email',
      'slice-agent@zuraffa.local',
    ], sliceRoot);

    // 3. Record the parent linkage (the glue-back path).
    final parentBranch = await _git([
      'rev-parse',
      '--abbrev-ref',
      'HEAD',
    ], projectRoot);
    final parentHead = await _git(['rev-parse', 'HEAD'], projectRoot);
    final parentJson = <String, dynamic>{
      'schema': 'slice.parent.v1',
      'feature_id': contract.id,
      'parent_root': projectRoot,
      'parent_branch': parentBranch.exitCode == 0
          ? parentBranch.stdout.toString().trim()
          : null,
      'parent_head': parentHead.exitCode == 0
          ? parentHead.stdout.toString().trim()
          : null,
      'slice_root': p
          .relative(sliceRoot, from: projectRoot)
          .replaceAll('\\', '/'),
      'branch': branch,
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    final parentFile = File(p.join(sliceRoot, '.slice', 'parent.json'));
    parentFile.parent.createSync(recursive: true);
    parentFile.writeAsStringSync(
      JsonEncoder.withIndent('  ').convert(parentJson),
    );

    // 4. Record the worktree on the manifest (path + branch; the HEAD
    // sha is deliberately NOT pinned into committed files — it moves
    // with every agent commit).
    manifestFile.writeAsStringSync(
      manifest
          .copyWith(worktreePath: manifest.sliceRoot, worktreeBranch: branch)
          .toYaml(),
    );

    // 5. Commit the composition (re-open re-commits; a clean tree is
    // not an error).
    final add = await _git(['add', '-A'], sliceRoot);
    if (add.exitCode != 0) {
      return SliceWorktreeResult(
        success: false,
        message:
            'git add failed at the slice root: '
            '${add.stderr.toString().trim()} (spec 1114).',
      );
    }
    final commit = await _git([
      'commit',
      '-m',
      'slice worktree: ${contract.id} (spec 1114) — the feature base, '
          'not the whole repo',
    ], sliceRoot);
    if (commit.exitCode != 0) {
      final status = await _git(['status', '--porcelain'], sliceRoot);
      final clean =
          status.exitCode == 0 && status.stdout.toString().trim().isEmpty;
      if (!clean) {
        return SliceWorktreeResult(
          success: false,
          message:
              'the slice worktree commit failed: '
              '${commit.stderr.toString().trim()} (spec 1114).',
        );
      }
    }
    final head = await _git(['rev-parse', 'HEAD'], sliceRoot);
    if (head.exitCode != 0) {
      return SliceWorktreeResult(
        success: false,
        message:
            'the slice worktree commit failed: '
            '${head.stderr.toString().trim()} (spec 1114).',
      );
    }
    final commitSha = head.stdout.toString().trim();

    return SliceWorktreeResult(
      success: true,
      worktreePath: sliceRoot,
      branch: branch,
      commit: commitSha,
      message:
          'Opened the slice worktree at $sliceRoot (branch $branch, '
          'commit $commitSha). The agent\'s working tree is the feature '
          '"${contract.id}" — cd in and run `zfa tdd run ${contract.id}` '
          '(the journal glues back through `zfa slice merge`, spec 1114).',
    );
  }
}
