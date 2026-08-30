/// `SingleTestRunner` — executes exactly one test through the
/// `single` command template from `.specify/memory/tdd-profile.md`
/// (spec 046-tdd-verify-red, FR-003, T005).
///
/// Responsibilities:
///   1. Load the profile's `single` template (machine-readable Keys block
///      first, then the `- Single test:` bullet), misfire-stopping when
///      the profile is missing or carries no single command.
///   2. Substitute the target test path and name into the template —
///      never a hard-coded runner invocation.
///   3. Execute it via `Process.run` in the given working directory,
///      capturing exit code, combined stdout+stderr, and whether the
///      process launched at all.
///   4. Return a [RunRecord] with the parsed executed-test count.
///
/// Runner-level failures (executable not found, launch error) are NOT
/// thrown: they come back as `startedProcess: false` so the classifier
/// can grade them as `runner-error` honestly.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/red_classification.dart';
import 'red_classifier.dart';

class SingleTestRunner {
  const SingleTestRunner();

  /// Default profile location relative to the working directory.
  static const defaultProfilePath = '.specify/memory/tdd-profile.md';

  /// Load the `single` command template from the TDD profile.
  ///
  /// Resolution order:
  ///   1. the `single:` key inside the `## Keys (machine-readable)`
  ///      yaml block (the shape `zfa setup` writes);
  ///   2. the `` - Single test: `...` `` bullet in `## Commands`,
  ///      normalizing legacy `<path>`/`<name>` placeholders to
  ///      `{file}`/`{name}`.
  ///
  /// Misfire-stop (FR-010): throws [StateError] when the profile file is
  /// missing/unreadable or contains no single command.
  Future<String> loadSingleTemplate({
    required String workingDirectory,
    String profilePath = defaultProfilePath,
  }) async {
    final file = File(p.join(workingDirectory, profilePath));
    if (!await file.exists()) {
      throw StateError(
        'zfa tdd verify-red: TDD profile not found at ${file.path}. '
        'Run `zfa tdd init` (or create the profile), then re-run.',
      );
    }
    final String raw;
    try {
      raw = await file.readAsString();
    } catch (e) {
      throw StateError(
        'zfa tdd verify-red: cannot read TDD profile at ${file.path}: $e',
      );
    }

    // 1. Machine-readable Keys block.
    final keysBlock = RegExp(
      r'##\s*Keys \(machine-readable\)\s*\n+```ya?ml\n(.*?)```',
      dotAll: true,
    ).firstMatch(raw);
    if (keysBlock != null) {
      final single = RegExp(
        r"""^\s*single:\s*['"](.+)['"]\s*$""",
        multiLine: true,
      ).firstMatch(keysBlock.group(1)!);
      if (single != null && single.group(1)!.trim().isNotEmpty) {
        return _normalize(single.group(1)!.trim());
      }
    }

    // 2. Human-facing bullet.
    final bullet = RegExp(r'-\s*Single test:\s*`([^`]+)`').firstMatch(raw);
    if (bullet != null && bullet.group(1)!.trim().isNotEmpty) {
      return _normalize(bullet.group(1)!.trim());
    }

    throw StateError(
      'zfa tdd verify-red: no `single` command template found in '
      '${file.path}. Add a `single:` key to the Keys (machine-readable) '
      'block or a `- Single test:` bullet, then re-run.',
    );
  }

  /// Normalize legacy `<path>`/`<file>`/`<name>` placeholders to the
  /// canonical `{file}`/`{name}` forms.
  String _normalize(String template) => template
      .replaceAll('<path>', '{file}')
      .replaceAll('<file>', '{file}')
      .replaceAll('<name>', '{name}');

  /// Run exactly one test through the template.
  ///
  /// [singleTemplate] is the profile template (with `{file}`/`{name}`
  /// placeholders); [testPath] and [testName] are substituted in.
  Future<RunRecord> runSingle({
    required String singleTemplate,
    required String testPath,
    required String testName,
    required String workingDirectory,
  }) async {
    final display = _substitute(singleTemplate, testPath, testName);
    final tokens = _tokenize(singleTemplate, testPath, testName);
    final executable = tokens.first;
    final args = tokens.skip(1).toList();

    try {
      final result = await Process.run(
        executable,
        args,
        workingDirectory: workingDirectory,
      );
      final output = '${result.stdout}${result.stderr}';
      return RunRecord(
        command: display,
        exitCode: result.exitCode,
        output: output,
        startedProcess: true,
        testCount: parseExecutedTestCount(output),
      );
    } on ProcessException catch (e) {
      return RunRecord(
        command: display,
        exitCode: -1,
        output: 'Failed to start "$executable": $e',
        startedProcess: false,
      );
    }
  }

  /// Substitute placeholders for display/evidence (keeps quoting).
  String _substitute(String template, String file, String name) =>
      template.replaceAll('{file}', file).replaceAll('{name}', name);

  /// Tokenize the template into an executable + argument list.
  ///
  /// Splitting happens BEFORE substitution so a test name containing
  /// spaces stays one argument; quote pairs wrapping a substituted token
  /// are stripped (they were the template's shell quoting, not data).
  List<String> _tokenize(String template, String file, String name) {
    final rawTokens = template.trim().split(RegExp(r'\s+'));
    return rawTokens.map((token) {
      var out = token.replaceAll('{file}', file).replaceAll('{name}', name);
      if (out.length >= 2 && out.startsWith('"') && out.endsWith('"')) {
        out = out.substring(1, out.length - 1);
      } else if (out.length >= 2 && out.startsWith("'") && out.endsWith("'")) {
        out = out.substring(1, out.length - 1);
      }
      return out;
    }).toList();
  }
}
