/// `SingleTestRunner` — executes exactly one test through the
/// `single` command template from `.specify/memory/tdd-profile.md`
/// (spec 046-tdd-verify-red, FR-003, T005).
///
/// Extended by spec 047-tdd-make (T004): also loads the `suite`
/// command template and exposes `runSuite()` to capture the full
/// suite's exit code + combined output (used by the regression guard).
///
/// Responsibilities:
///   1. Load the profile's `single` (and now `suite`) template
///      (machine-readable Keys block first, then the human-facing
///      bullet), misfire-stopping when the profile is missing or
///      carries no command.
///   2. Substitute the target test path and name into the template —
///      never a hard-coded runner invocation.
///   3. Execute it via `Process.run` in the given working directory,
///      capturing exit code, combined stdout+stderr, and whether the
///      process launched at all.
///   4. Return a [RunRecord] with the parsed executed-test count
///      (single) or a [SuiteRunRecord] capturing the full suite
///      transcript (suite — used by the regression guard to identify
///      NEW failures by name).
///
/// Runner-level failures (executable not found, launch error) are NOT
/// thrown: they come back as `startedProcess: false` so the classifier
/// / suite guard can grade them honestly.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/red_classification.dart';
import 'red_classifier.dart';
import 'tdd_timeout.dart';

/// Captured result of a `suite` command invocation. The full
/// transcript is returned verbatim so the [SuiteGuard] can parse
/// failing-test identifiers from it.
class SuiteRunRecord {
  /// The executed command line (post-substitution — `suite` carries no
  /// placeholders, so this is the template verbatim).
  final String command;

  /// Exit code of the suite. `-1` when the process never started.
  final int exitCode;

  /// Combined stdout + stderr of the suite.
  final String output;

  /// `false` when the executable failed to launch at all.
  final bool startedProcess;

  /// True when the suite process was killed by the per-command timeout
  /// (bug #742): the process launched but outlived the deadline.
  final bool timedOut;

  const SuiteRunRecord({
    required this.command,
    required this.exitCode,
    required this.output,
    required this.startedProcess,
    this.timedOut = false,
  });

  @override
  String toString() =>
      'SuiteRunRecord(command: $command, exit: $exitCode, '
      'started: $startedProcess)';
}

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
    final raw = await _readProfile(workingDirectory, profilePath);

    // 1. Machine-readable Keys block.
    final keysBlock = RegExp(
      r'##\s*Keys \(machine-readable\)\s*\n+```ya?ml\n(.*?)```',
      dotAll: true,
    ).firstMatch(raw);
    if (keysBlock != null) {
      final single = _firstMatchValue(
        r'''^\s*single:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        keysBlock.group(1)!,
      );
      if (single != null && single.isNotEmpty) {
        return _normalize(single.trim());
      }
    }

    // 1b. Legacy frontmatter YAML block (pre-spec-kit-detector format):
    // extract the `single:` value from inside the `---...---` YAML frontmatter.
    // Supports both `single:` and `stacks:...single:` nesting (see
    // https://github.com/arrrrny/zuraffa/issues/664 for context).
    // NOTE: dotAll (NOT multiLine). multiLine:true makes ^ match at every line
    // start, so the non-greedy [\s\S]*? stops at the FIRST \n--- in the file
    // (e.g. a `---` inside a nested block) and captures only a prefix of the
    // frontmatter — see issue #681. dotAll keeps ^ anchored to the string start
    // while still allowing . to match newlines.
    final frontmatterBlock = RegExp(
      r'^---\n([\s\S]*?)\n---',
      dotAll: true,
    ).firstMatch(raw);
    if (frontmatterBlock != null) {
      final frontmatter = frontmatterBlock.group(1)!;
      // Try top-level `single:` first.
      var single = _firstMatchValue(
        r'''^\s*single:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        frontmatter,
      );
      if (single != null && single.isNotEmpty) {
        return _normalize(single.trim());
      }
      // Fall back to `stacks: <label>:\s+single:` nesting (keys are
      // indented under their nesting labels; drop ^ anchor so any indentation
      // level is matched). Also handles bare top-level `single:` in flat YAML.
      final nestedSingle = _firstMatchValue(
        r'''^\s*single:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))''',
        frontmatter,
      );
      if (nestedSingle != null && nestedSingle.isNotEmpty) {
        return _normalize(nestedSingle.trim());
      }
    }

    // 2. Human-facing bullet.
    final bullet = RegExp(r'-\s*Single test:\s*`([^`]+)`').firstMatch(raw);
    if (bullet != null && bullet.group(1)!.trim().isNotEmpty) {
      return _normalize(bullet.group(1)!.trim());
    }

    throw StateError(
      'zfa tdd verify-red: no `single` command template found in '
      '${p.join(workingDirectory, profilePath)}. Add a `single:` key to '
      'the Keys (machine-readable) block or a `- Single test:` bullet, '
      'then re-run.',
    );
  }

  /// Load the `suite` command template from the TDD profile
  /// (spec 047-tdd-make T004; data-model.md).
  ///
  /// Resolution order mirrors [loadSingleTemplate]: the `suite:` key in
  /// the machine-readable Keys block first, then the human-facing
  /// `- Full suite (repo)` bullet (any line starting with `-\s*Full suite`).
  /// Misfire-stop: throws [StateError] when the profile is missing or
  /// contains no `suite` command.
  Future<String> loadSuiteTemplate({
    required String workingDirectory,
    String profilePath = defaultProfilePath,
  }) async {
    final raw = await _readProfile(workingDirectory, profilePath);

    // 1. Machine-readable Keys block.
    final keysBlock = RegExp(
      r'##\s*Keys \(machine-readable\)\s*\n+```ya?ml\n(.*?)```',
      dotAll: true,
    ).firstMatch(raw);
    if (keysBlock != null) {
      final suite = _firstMatchValue(
        r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        keysBlock.group(1)!,
      );
      if (suite != null && suite.isNotEmpty) {
        return suite.trim();
      }
    }

    // 1b. Legacy frontmatter YAML block (pre-spec-kit-detector format):
    // extract the `suite:` value from inside the `---...---` YAML frontmatter.
    // Supports both `suite:` and `stacks:...suite:` nesting.
    // NOTE: dotAll (NOT multiLine) — see issue #681. multiLine:true makes ^ match
    // at every line start, so the non-greedy [\s\S]*? stops at the FIRST \n---
    // in the file and captures only a prefix of the frontmatter.
    final frontmatterBlock = RegExp(
      r'^---\n([\s\S]*?)\n---',
      dotAll: true,
    ).firstMatch(raw);
    if (frontmatterBlock != null) {
      final frontmatter = frontmatterBlock.group(1)!;
      // Try top-level `suite:` first.
      var suite = _firstMatchValue(
        r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        frontmatter,
      );
      if (suite != null && suite.isNotEmpty) {
        return suite.trim();
      }
      // Fall back to `stacks: <label>:\s+suite:` nesting.
      final nestedSuite = _firstMatchValue(
        r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))''',
        frontmatter,
      );
      if (nestedSuite != null && nestedSuite.isNotEmpty) {
        return nestedSuite.trim();
      }
    }

    // 2. Human-facing bullet — pick the first `- Full suite` line.
    final bullet = RegExp(
      r'-\s*Full suite[^\n]*?:\s*`([^`]+)`',
    ).firstMatch(raw);
    if (bullet != null && bullet.group(1)!.trim().isNotEmpty) {
      return bullet.group(1)!.trim();
    }

    throw StateError(
      'zfa tdd make: no `suite` command template found in '
      '${p.join(workingDirectory, profilePath)}. Add a `suite:` key to '
      'the Keys (machine-readable) block or a `- Full suite ...:` bullet, '
      'then re-run.',
    );
  }

  /// Read the raw profile contents, misfire-stopping on missing file or
  /// unreadable content.
  Future<String> _readProfile(
    String workingDirectory,
    String profilePath,
  ) async {
    final file = File(p.join(workingDirectory, profilePath));
    if (!await file.exists()) {
      throw StateError(
        'zfa tdd: TDD profile not found at ${file.path}. Run '
        '`zfa tdd init` (or create the profile), then re-run.',
      );
    }
    try {
      return await file.readAsString();
    } catch (e) {
      throw StateError('zfa tdd: cannot read TDD profile at ${file.path}: $e');
    }
  }

  /// Normalize legacy `<path>`/`<file>`/`<name>` placeholders to the
  /// canonical `{file}`/`{name}` forms.
  String _normalize(String template) => template
      .replaceAll('<path>', '{file}')
      .replaceAll('<file>', '{file}')
      .replaceAll('<name>', '{name}');

  /// Match a YAML scalar that may be double-quoted, single-quoted, or
  /// unquoted. Returns the first captured group that matched, or null.
  ///
  /// Instance method by design (issue #695): all six call sites invoke it
  /// unqualified from instance methods, so a `static` declaration is a
  /// static/instance mismatch that breaks compilation downstream.
  String? _firstMatchValue(String pattern, String input) {
    final match = RegExp(pattern, multiLine: true).firstMatch(input);
    if (match == null) return null;
    for (var i = 1; i <= match.groupCount; i++) {
      final g = match.group(i);
      if (g != null && g.isNotEmpty) return g;
    }
    return null;
  }

  /// Run exactly one test through the template.
  ///
  /// [singleTemplate] is the profile template (with `{file}`/`{name}`
  /// placeholders); [testPath] and [testName] are substituted in.
  ///
  /// [timeout] is the hard deadline for the spawned test process (bug
  /// #742): a hanging child is killed and the returned [RunRecord] carries
  /// `timedOut: true` with the timeout message as its output — never a
  /// hang, never a certified red. Defaults to [TddTimeouts.defaultSingleTest].
  Future<RunRecord> runSingle({
    required String singleTemplate,
    required String testPath,
    required String testName,
    required String workingDirectory,
    Duration? timeout,
  }) async {
    final display = _substitute(singleTemplate, testPath, testName);
    final tokens = _tokenize(singleTemplate, testPath, testName);
    final executable = tokens.first;
    final args = tokens.skip(1).toList();

    try {
      final result = await runTimed(
        executable,
        args,
        workingDirectory: workingDirectory,
        timeout: timeout ?? TddTimeouts.defaultSingleTest,
      );
      final output = '${result.stdout}${result.stderr}';
      return RunRecord(
        command: display,
        exitCode: result.exitCode,
        output: output,
        startedProcess: true,
        testCount: parseExecutedTestCount(output),
      );
    } on ProcessTimeoutException catch (e) {
      return RunRecord(
        command: display,
        exitCode: -1,
        output: e.toString(),
        startedProcess: true,
        timedOut: true,
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

  /// Run the full suite through the `suite` template (spec 047-tdd-make
  /// T004; data-model.md). Captures exit code + combined output for the
  /// regression guard.
  ///
  /// [suiteTemplate] is the profile template (no placeholders). The
  /// command is split on whitespace into an executable + args list.
  ///
  /// [timeout] is the hard deadline for the spawned suite process (bug
  /// #742): a hanging child is killed and the returned [SuiteRunRecord]
  /// carries `timedOut: true`. Defaults to [TddTimeouts.defaultSuite].
  Future<SuiteRunRecord> runSuite({
    required String suiteTemplate,
    required String workingDirectory,
    Duration? timeout,
  }) async {
    final command = suiteTemplate.trim();
    final tokens = command.split(RegExp(r'\s+'));
    final executable = tokens.first;
    final args = tokens.skip(1).toList();

    try {
      final result = await runTimed(
        executable,
        args,
        workingDirectory: workingDirectory,
        timeout: timeout ?? TddTimeouts.defaultSuite,
      );
      final output = '${result.stdout}${result.stderr}';
      return SuiteRunRecord(
        command: command,
        exitCode: result.exitCode,
        output: output,
        startedProcess: true,
      );
    } on ProcessTimeoutException catch (e) {
      return SuiteRunRecord(
        command: command,
        exitCode: -1,
        output: e.toString(),
        startedProcess: true,
        timedOut: true,
      );
    } on ProcessException catch (e) {
      return SuiteRunRecord(
        command: command,
        exitCode: -1,
        output: 'Failed to start "$executable": $e',
        startedProcess: false,
      );
    }
  }

  /// Substitute placeholders for display/evidence (keeps quoting).
  String _substitute(String template, String file, String name) =>
      template.replaceAll('{file}', file).replaceAll('{name}', name);

  /// Escape regex metacharacters so a test name containing `(...)`,
  /// `[...]`, etc. matches literally under `dart test -n` (issue #760).
  String _escapeRegExp(String s) {
    final special = RegExp(r'[\\^$.*+?()\[\]{}|]');
    return s.replaceAllMapped(special, (m) => '\\${m.group(0)}');
  }

  /// Tokenize the template into an executable + argument list.
  ///
  /// Splitting happens BEFORE substitution so a test name containing
  /// spaces stays one argument; quote pairs wrapping a substituted token
  /// are stripped (they were the template's shell quoting, not data).
  ///
  /// Bug #760: the name lands in a regex-flavored filter (`dart test -n` /
  /// `--name`) unless the template opts into the literal matcher
  /// `--plain-name` (issue #756). Regex metacharacters in the name —
  /// `(sticky)`, `(FR-XXX)`, dots, brackets — would change the matching
  /// semantics ("No tests match regular expression", exit 79, classified
  /// as runner-error), so the substituted name is escaped UNLESS the
  /// template carries `--plain-name`, where escaping would corrupt the
  /// literal match. `{file}` is NOT escaped: it lands in a positional
  /// path argument, which `dart test` matches as a path, not a pattern.
  List<String> _tokenize(String template, String file, String name) {
    final escapeName = !template.contains('--plain-name');
    final rawTokens = template.trim().split(RegExp(r'\s+'));
    return rawTokens.map((token) {
      var out = token
          .replaceAll('{file}', file)
          .replaceAll('{name}', escapeName ? _escapeRegExp(name) : name);
      if (out.length >= 2 && out.startsWith('"') && out.endsWith('"')) {
        out = out.substring(1, out.length - 1);
      } else if (out.length >= 2 && out.startsWith("'") && out.endsWith("'")) {
        out = out.substring(1, out.length - 1);
      }
      return out;
    }).toList();
  }

  /// Escape regex metacharacters so a string is matched literally by a
  /// regex-flavored filter (bug #760): escapes `\.^$*+?()[]{}|`.
  String _escapeRegExp(String s) {
    final special = RegExp(r'[\.\\^$*+?()\[\]{}|]');
    return s.replaceAllMapped(special, (m) => '\\${m.group(0)}');
  }
}
