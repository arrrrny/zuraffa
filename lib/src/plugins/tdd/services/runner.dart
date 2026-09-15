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
import 'test_reporter_args.dart';
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

  /// True for a SYNTHETIC record whose verdict was inherited from an
  /// earlier certified run rather than produced by a process of its own
  /// (issue #1624: the refactor's re-proof when the pass registry changed
  /// no file). Such a record carries [startedProcess] `false` and exit `0`,
  /// so a consumer that gates on "did a process run" must branch on THIS —
  /// never on [startedProcess] alone, and never by parsing [output] as a
  /// transcript.
  final bool inherited;

  /// True when the record carries a verdict the caller may grade: a suite
  /// process launched ([startedProcess]), or the verdict was inherited
  /// from an earlier certified run ([inherited]). Gate on this rather than
  /// on [startedProcess] so an inherited green is not read as a suite that
  /// never launched.
  bool get hasVerdict => startedProcess || inherited;

  const SuiteRunRecord({
    required this.command,
    required this.exitCode,
    required this.output,
    required this.startedProcess,
    this.timedOut = false,
    this.inherited = false,
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
      final single = _matchQuotedScalar(
        r'''^\s*single:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        keysBlock.group(1)!,
      );
      if (single != null && single.value.trim().isNotEmpty) {
        return _prepareSingleScalar(
          single.value.trim(),
          doubleQuoted: single.doubleQuoted,
          workingDirectory: workingDirectory,
          profilePath: profilePath,
        );
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
      var single = _matchQuotedScalar(
        r'''^\s*single:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        frontmatter,
      );
      if (single != null && single.value.trim().isNotEmpty) {
        return _prepareSingleScalar(
          single.value.trim(),
          doubleQuoted: single.doubleQuoted,
          workingDirectory: workingDirectory,
          profilePath: profilePath,
        );
      }
      // Fall back to `stacks: <label>:\s+single:` nesting (keys are
      // indented under their nesting labels; drop ^ anchor so any indentation
      // level is matched). Also handles bare top-level `single:` in flat YAML.
      final nestedSingle = _matchQuotedScalar(
        r'''^\s*single:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))''',
        frontmatter,
      );
      if (nestedSingle != null && nestedSingle.value.trim().isNotEmpty) {
        return _prepareSingleScalar(
          nestedSingle.value.trim(),
          doubleQuoted: nestedSingle.doubleQuoted,
          workingDirectory: workingDirectory,
          profilePath: profilePath,
        );
      }
    }

    // 2. Human-facing bullet.
    final bulletValue = _firstMatchValue(r'-\s*Single test:\s*`([^`]+)`', raw);
    if (bulletValue != null && bulletValue.trim().isNotEmpty) {
      return _prepareSingleScalar(
        bulletValue.trim(),
        doubleQuoted: false,
        workingDirectory: workingDirectory,
        profilePath: profilePath,
      );
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
      final suite = _matchQuotedScalar(
        r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        keysBlock.group(1)!,
      );
      if (suite != null && suite.value.trim().isNotEmpty) {
        return _prepareSuiteScalar(
          suite.value.trim(),
          doubleQuoted: suite.doubleQuoted,
        );
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
      var suite = _matchQuotedScalar(
        r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        frontmatter,
      );
      if (suite != null && suite.value.trim().isNotEmpty) {
        return _prepareSuiteScalar(
          suite.value.trim(),
          doubleQuoted: suite.doubleQuoted,
        );
      }
      // Fall back to `stacks: <label>:\s+suite:` nesting.
      final nestedSuite = _matchQuotedScalar(
        r'''^\s*suite:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))''',
        frontmatter,
      );
      if (nestedSuite != null && nestedSuite.value.trim().isNotEmpty) {
        return _prepareSuiteScalar(
          nestedSuite.value.trim(),
          doubleQuoted: nestedSuite.doubleQuoted,
        );
      }
    }

    // 2. Human-facing bullet — pick the first `- Full suite` line.
    final bulletValue = _firstMatchValue(
      r'-\s*Full suite[^\n]*?:\s*`([^`]+)`',
      raw,
    );
    if (bulletValue != null && bulletValue.trim().isNotEmpty) {
      return bulletValue.trim();
    }

    throw StateError(
      'zfa tdd make: no `suite` command template found in '
      '${p.join(workingDirectory, profilePath)}. Add a `suite:` key to '
      'the Keys (machine-readable) block or a `- Full suite ...:` bullet, '
      'then re-run.',
    );
  }

  /// Load the `file` (whole-file) command template from the TDD profile
  /// (spec 069-corpus-economics T002: the batched verify-red lane).
  ///
  /// Resolution order mirrors [loadSingleTemplate]: the `file:` key in
  /// the machine-readable Keys block first, then the human-facing
  /// `- Whole file:` bullet. The template carries exactly one `{file}`
  /// placeholder (the batch substitutes the first target path and
  /// appends the rest — `dart test a_test.dart b_test.dart`).
  /// Misfire-stop: throws [StateError] when the profile is missing or
  /// contains no `file` command.
  Future<String> loadFileTemplate({
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
      final file = _matchQuotedScalar(
        r'''^\s*file:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))\s*$''',
        keysBlock.group(1)!,
      );
      if (file != null && file.value.trim().isNotEmpty) {
        return _prepareFileScalar(
          file.value.trim(),
          doubleQuoted: file.doubleQuoted,
        );
      }
    }

    // 1b. Legacy frontmatter YAML block.
    final frontmatterBlock = RegExp(
      r'^---\n([\s\S]*?)\n---',
      dotAll: true,
    ).firstMatch(raw);
    if (frontmatterBlock != null) {
      final file = _matchQuotedScalar(
        r'''^\s*file:\s*(?:"(.+?)"|'(.+?)'|([^\s#]+(?:[ \t]+[^\s#]+)*))''',
        frontmatterBlock.group(1)!,
      );
      if (file != null && file.value.trim().isNotEmpty) {
        return _prepareFileScalar(
          file.value.trim(),
          doubleQuoted: file.doubleQuoted,
        );
      }
    }

    // 2. Human-facing bullet — the first `- Whole file` line.
    final bulletValue = _firstMatchValue(
      r'-\s*Whole file[^\n]*?:\s*`([^`]+)`',
      raw,
    );
    if (bulletValue != null && bulletValue.trim().isNotEmpty) {
      return _normalize(bulletValue.trim());
    }

    throw StateError(
      'zfa tdd verify-red: no `file` command template found in '
      '${p.join(workingDirectory, profilePath)}. Add a `file:` key to '
      'the Keys (machine-readable) block or a `- Whole file:` bullet, '
      'then re-run (spec 069 T002: the batched red lane needs the '
      'whole-file runner).',
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

  /// Post-process a scalar pulled from a `single:` key or the `- Single
  /// test:` bullet (issue #1535): unescape the YAML double-quoted style's
  /// escape sequences, normalize the legacy placeholders, then reject any
  /// UNKNOWN placeholder spelling at LOAD time. The two failure modes that
  /// used to survive loading here and surface downstream as load-error /
  /// runner-error (exit 79) on an honest red — a misclassification that
  /// dead-ended `zfa tdd run` on a profile the toolchain itself accepted.
  String _prepareSingleScalar(
    String scalar, {
    required bool doubleQuoted,
    required String workingDirectory,
    required String profilePath,
  }) {
    var template = doubleQuoted ? _yamlUnescapeDoubleQuoted(scalar) : scalar;
    template = _normalize(template.trim());
    final unknown = <String>[];
    for (final match in RegExp(r'\{[^{}]*\}|<[^<>]*>').allMatches(template)) {
      final token = match.group(0)!;
      if (token != '{file}' && token != '{name}' && !unknown.contains(token)) {
        unknown.add(token);
      }
    }
    if (unknown.isNotEmpty) {
      throw StateError(
        'zfa tdd verify-red: unknown placeholder ${unknown.join(', ')} in '
        'the `single:` command template of '
        '${p.join(workingDirectory, profilePath)}. Accepted placeholders: '
        '{file}, {name} (the legacy <path>/<file>/<name> spellings are '
        'normalized automatically). Rewrite the `single:` value with an '
        'accepted placeholder, then re-run.',
      );
    }
    return template;
  }

  /// Post-process a scalar pulled from a `file:` key (issue #1535):
  /// double-quoted escapes unescaped, legacy placeholders normalized. No
  /// unknown-placeholder rejection — the batched lane substitutes only
  /// `{file}`, and a rejected load here would not change any classification
  /// the single lane does not already catch.
  String _prepareFileScalar(String scalar, {required bool doubleQuoted}) =>
      _normalize(
        doubleQuoted ? _yamlUnescapeDoubleQuoted(scalar) : scalar,
      ).trim();

  /// Post-process a scalar pulled from a `suite:` key (issue #1535):
  /// double-quoted escapes unescaped verbatim-style — the suite carries no
  /// placeholders, so nothing is normalized or validated.
  String _prepareSuiteScalar(String scalar, {required bool doubleQuoted}) =>
      (doubleQuoted ? _yamlUnescapeDoubleQuoted(scalar) : scalar).trim();

  /// Unescape the escape sequences YAML allows inside a DOUBLE-QUOTED
  /// scalar (YAML 1.2 §5.7): `\"` → `"`, `\\` → `\`, the C0 escapes
  /// (`\t`, `\n`, `\r`, …), and the `\x..` / `\u....` / `\U........` hex
  /// forms.
  ///
  /// Single-quoted and unquoted scalars NEVER reach this method — their
  /// backslashes are literal data (a single-quoted `'...\d...'` template
  /// must survive byte-for-byte), which is exactly why the quote style is
  /// tracked during extraction. An escape NOT in the YAML table is kept
  /// verbatim — lenient where YAML itself would error, so a template like
  /// `--name "\d+"` survives a double-quoted authoring style.
  String _yamlUnescapeDoubleQuoted(String scalar) {
    if (!scalar.contains(r'\')) return scalar;
    const simple = <String, int>{
      '0': 0x00,
      'a': 0x07,
      'b': 0x08,
      't': 0x09,
      'n': 0x0A,
      'v': 0x0B,
      'f': 0x0C,
      'r': 0x0D,
      'e': 0x1B,
      ' ': 0x20,
      '"': 0x22,
      '/': 0x2F,
      r'\': 0x5C,
      'N': 0x85,
      '_': 0xA0,
      'L': 0x2028,
      'P': 0x2029,
    };
    final out = StringBuffer();
    var i = 0;
    while (i < scalar.length) {
      final c = scalar[i];
      if (c != r'\' || i + 1 >= scalar.length) {
        out.write(c);
        i++;
        continue;
      }
      final marker = scalar[i + 1];
      final simpleCode = simple[marker];
      if (simpleCode != null) {
        out.writeCharCode(simpleCode);
        i += 2;
        continue;
      }
      final hexDigits = switch (marker) {
        'x' => 2,
        'u' => 4,
        'U' => 8,
        _ => 0,
      };
      if (hexDigits > 0) {
        final code = _hexCodePointAt(scalar, i + 2, hexDigits);
        if (code != null) {
          out.writeCharCode(code);
          i += 2 + hexDigits;
          continue;
        }
      }
      // Unknown or malformed escape: keep it verbatim.
      out.write(c);
      out.write(marker);
      i += 2;
    }
    return out.toString();
  }

  /// Parse [digits] hex characters at [start] into a code point, or null
  /// when they are missing or not hex (the caller then keeps the escape
  /// verbatim).
  int? _hexCodePointAt(String s, int start, int digits) {
    if (start + digits > s.length) return null;
    var value = 0;
    for (var i = start; i < start + digits; i++) {
      final digit = int.tryParse(s[i], radix: 16);
      if (digit == null) return null;
      value = value * 16 + digit;
    }
    return value;
  }

  /// Match a YAML scalar that may be double-quoted, single-quoted, or
  /// unquoted, and report WHICH style matched (issue #1535): the
  /// double-quoted style is the only one whose backslash sequences are
  /// escapes, so the caller can unescape exactly those values. Returns
  /// null when [pattern] matches nothing.
  ///
  /// The value is the first captured group that matched (the three
  /// alternatives of the profile-scalar grammar, in order).
  ({String value, bool doubleQuoted})? _matchQuotedScalar(
    String pattern,
    String input,
  ) {
    final match = RegExp(pattern, multiLine: true).firstMatch(input);
    if (match == null) return null;
    final doubleQuoted = match.group(1);
    if (doubleQuoted != null && doubleQuoted.isNotEmpty) {
      return (value: doubleQuoted, doubleQuoted: true);
    }
    final singleQuoted = match.group(2);
    if (singleQuoted != null && singleQuoted.isNotEmpty) {
      return (value: singleQuoted, doubleQuoted: false);
    }
    final bare = match.group(3);
    if (bare != null && bare.isNotEmpty) {
      return (value: bare, doubleQuoted: false);
    }
    return null;
  }

  /// Match a YAML scalar and return the raw captured value, or null.
  ///
  /// Instance method by design (issue #695): the call sites invoke it
  /// unqualified from instance methods, so a `static` declaration is a
  /// static/instance mismatch that breaks compilation downstream.
  String? _firstMatchValue(String pattern, String input) =>
      _matchQuotedScalar(pattern, input)?.value;

  /// Run exactly one test through the template.
  ///
  /// [singleTemplate] is the profile template (with `{file}`/`{name}`
  /// placeholders); [testPath] and [testName] are substituted in.
  ///
  /// [timeout] is the hard deadline for the spawned test process (bug
  /// #742): a hanging child is killed and the returned [RunRecord] carries
  /// `timedOut: true` with the timeout message as its output — never a
  /// hang, never a certified red. Defaults to [TddTimeouts.defaultSingleTest].
  ///
  /// [environment] (spec 1520) is the caller's per-run scratch environment
  /// (`ScratchTmpDir.childEnvironment`) — MERGED into the child's inherited
  /// environment by `Process.start`, so `PATH`/`HOME` survive while
  /// `TMPDIR`/`TEMP`/`TMP` point at the run's own scratch. Null inherits
  /// the parent environment unchanged.
  Future<RunRecord> runSingle({
    required String singleTemplate,
    required String testPath,
    required String testName,
    required String workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  }) async {
    final display = _substitute(singleTemplate, testPath, testName);
    final tokens = withCompactReporter(
      _tokenize(singleTemplate, testPath, testName),
    );
    final executable = tokens.first;
    final args = tokens.skip(1).toList();

    try {
      final result = await runTimed(
        executable,
        args,
        workingDirectory: workingDirectory,
        timeout: timeout ?? TddTimeouts.defaultSingleTest,
        environment: environment,
      );
      // CRLF first: a lone-`\r` fold would turn every Windows-style
      // CRLF into two newlines, and the blank line breaks the trailing
      // failure-block regex in SuiteGuard.parse.
      final output = '${result.stdout}${result.stderr}'
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
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
  /// command is split into an executable + args list; the split is
  /// quote-aware — quote pairs wrapping a segment are stripped and the
  /// segment stays ONE token — so a suite command carrying a path with
  /// spaces (the scoped re-proof's quoted covering tests, spec 069 T001)
  /// survives, the same token contract as [_tokenize] and the refactor
  /// pass executor (bug #689).
  ///
  /// [timeout] is the hard deadline for the spawned suite process (bug
  /// #742): a hanging child is killed and the returned [SuiteRunRecord]
  /// carries `timedOut: true`. Defaults to [TddTimeouts.defaultSuite].
  ///
  /// [environment] (spec 1520) is the caller's per-run scratch environment
  /// (`ScratchTmpDir.childEnvironment`), forwarded to the spawn chokepoint
  /// exactly like [runSingle]'s. Null inherits the parent environment.
  Future<SuiteRunRecord> runSuite({
    required String suiteTemplate,
    required String workingDirectory,
    Duration? timeout,
    Map<String, String>? environment,
  }) async {
    final command = suiteTemplate.trim();
    final tokens = withCompactReporter(splitCommand(command));
    final executable = tokens.first;
    final args = tokens.skip(1).toList();

    try {
      final result = await runTimed(
        executable,
        args,
        workingDirectory: workingDirectory,
        timeout: timeout ?? TddTimeouts.defaultSuite,
        environment: environment,
      );
      // CRLF first (see runSingle): two-newline folds break the trailing
      // failure-block regex in SuiteGuard.parse.
      final output = '${result.stdout}${result.stderr}'
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n');
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

  /// Tokenize a command line into an executable + argument list (static
  /// so [runSuite] and callers share one contract).
  ///
  /// The splitter is quote-aware: quote pairs wrapping a segment are
  /// stripped and the segment stays ONE token even when it contains
  /// whitespace — shell quoting, not data (mirrors the refactor pass
  /// executor's tokenizer, bug #689).
  static List<String> splitCommand(String command) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    String? quote;
    for (var i = 0; i < command.length; i++) {
      final c = command[i];
      if (quote != null) {
        if (c == quote) {
          quote = null;
        } else {
          buffer.write(c);
        }
        continue;
      }
      if (c == '"' || c == "'") {
        quote = c;
        continue;
      }
      if (c.trim().isEmpty) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      buffer.write(c);
    }
    if (buffer.isNotEmpty) tokens.add(buffer.toString());
    return tokens;
  }

  /// Escape regex metacharacters so a string is matched literally by a
  /// regex-flavored filter (bug #760): escapes `\.^$*+?()[]{}|`.
  String _escapeRegExp(String s) {
    final special = RegExp(r'[\.\\^$*+?()\[\]{}|]');
    return s.replaceAllMapped(special, (m) => '\\${m.group(0)}');
  }
}
