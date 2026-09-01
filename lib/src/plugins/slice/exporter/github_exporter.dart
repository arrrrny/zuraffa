/// GithubExporter (spec 043): private-repo slice export (US8, FR-018).
///
/// Creates a private GitHub repository via the `gh` CLI, stages the sandbox
/// as the initial commit (with `SLICE.md` promoted to `README.md`), pushes,
/// and returns the repo URL for the manifest's `exportedTo` field (FR-004).
///
/// All external commands run through an injectable [GhLauncher] seam: `gh`
/// commands are passed verbatim; git plumbing is prefixed with `git` as the
/// first argument so tests can fake the whole pipeline.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Process execution seam for `gh`/`git` commands.
///
/// [args] are the command arguments: either `gh` arguments (e.g.
/// `['auth', 'status']`) or `['git', ...]` for git plumbing.
typedef GhLauncher =
    Future<ProcessResult> Function(
      List<String> args, {
      String? workingDirectory,
    });

/// The outcome of a GitHub export.
class GithubExportResult {
  /// Creates the result.
  const GithubExportResult({required this.success, this.repoUrl, this.message});

  /// Whether the repo was created and pushed.
  final bool success;

  /// The repository URL (set on success).
  final String? repoUrl;

  /// Human-readable summary or error.
  final String? message;
}

/// Exports a slice sandbox to a fresh private GitHub repository.
class GithubExporter {
  /// Creates the exporter with an injectable [ghLauncher] seam.
  GithubExporter({GhLauncher? ghLauncher})
    : _launcher = ghLauncher ?? _defaultLauncher;

  final GhLauncher _launcher;

  static Future<ProcessResult> _defaultLauncher(
    List<String> args, {
    String? workingDirectory,
  }) {
    if (args.first == 'git') {
      return Process.run(
        'git',
        args.sublist(1),
        workingDirectory: workingDirectory,
      );
    }
    return Process.run('gh', args, workingDirectory: workingDirectory);
  }

  /// Exports the sandbox at [sandboxDir].
  ///
  /// [repo] is the target repository in `owner/name` form; when null a name
  /// is generated from [packageName] and [sliceName] (U60).
  /// [pubspecContent], when given, is written as the sandbox's
  /// `pubspec.yaml` so the pushed repo is a working, self-contained package
  /// (FR-018).
  Future<GithubExportResult> export({
    required String sandboxDir,
    required String packageName,
    required String sliceName,
    String? repo,
    String? pubspecContent,
  }) async {
    // 1. Authentication gate (U62): fail fast with the fix named.
    final auth = await _launcher(const ['auth', 'status']);
    if (auth.exitCode != 0) {
      return const GithubExportResult(
        success: false,
        message:
            'gh is not authenticated — run `gh auth login` first, then '
            're-run zfa slice export.',
      );
    }

    // 2. Promote SLICE.md to README.md so the repo opens with the agent
    //    instructions (U59), and embed the filtered pubspec so the pushed
    //    tree is a working package (FR-018).
    final sliceDoc = File(p.join(sandboxDir, 'SLICE.md'));
    if (sliceDoc.existsSync()) {
      final readme = File(p.join(sandboxDir, 'README.md'));
      if (!readme.existsSync()) {
        readme.writeAsStringSync(sliceDoc.readAsStringSync());
      }
    }
    if (pubspecContent != null) {
      await File(
        p.join(sandboxDir, 'pubspec.yaml'),
      ).writeAsString(pubspecContent);
    }

    final repoName = repo ?? '${_slug(packageName)}-slice-${_slug(sliceName)}';

    // 3. Stage the sandbox as a git commit (identity pinned so export works
    //    on machines without global git config).
    final staging = <List<String>>[
      ['git', '-C', sandboxDir, 'init'],
      ['git', '-C', sandboxDir, 'add', '.'],
      [
        'git',
        '-C',
        sandboxDir,
        '-c',
        'user.name=Zuraffa Slice',
        '-c',
        'user.email=slice@zuraffa.local',
        'commit',
        '-m',
        'slice $sliceName: exported by zfa slice export',
      ],
      [
        'repo',
        'create',
        repoName,
        '--private',
        '--source',
        sandboxDir,
        '--remote',
        'origin',
        '--push',
      ],
    ];
    for (final command in staging) {
      final result = await _launcher(List.unmodifiable(command));
      if (result.exitCode != 0) {
        final output = '${result.stdout}${result.stderr}';
        final exists = output.contains('already exists');
        if (command.first == 'repo' && exists) {
          continue; // re-export over an existing repo is idempotent
        }
        return GithubExportResult(
          success: false,
          message:
              'Failed to export "$sliceName" to $repoName '
              '(`${command.join(' ')}` exited ${result.exitCode}): '
              '${output.trim().isEmpty ? 'no output' : output.trim()}',
        );
      }
    }

    // 4. Resolve the repo URL (U61) — `gh repo view --json url` in
    //    production; plain `url: ...` text is accepted for the seam.
    final view = await _launcher(['repo', 'view', repoName, '--json', 'url']);
    final repoUrl =
        _parseRepoUrl('${view.stdout}') ?? 'https://github.com/$repoName';
    return GithubExportResult(
      success: true,
      repoUrl: repoUrl,
      message: 'Exported slice "$sliceName" to $repoUrl (private).',
    );
  }

  /// Parses a repo URL from `gh repo view` output (JSON or text form).
  static String? _parseRepoUrl(String output) {
    final jsonMatch = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(output);
    if (jsonMatch != null) return jsonMatch.group(1);
    final textMatch = RegExp(r'url:\s*(\S+)').firstMatch(output);
    return textMatch?.group(1);
  }

  /// Slugs a name for repo naming: underscores and spaces become hyphens,
  /// lowercased, non-alphanumerics dropped.
  static String _slug(String name) {
    final slugged = name
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(' ', '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '');
    return slugged.isEmpty ? 'slice' : slugged;
  }
}
