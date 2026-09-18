/// Snippet validation gate (spec 1685): stands between "template rendered"
/// and "suggestion posted" so an un-compilable review suggestion is never
/// published again.
///
/// Issue #1685: `zuraffa-review[bot]` proposed
/// `addTearDown(_tmp.deleteRecursively)` on arrrrny/zuraffa_browser#165 —
/// `deleteRecursively` is not a member of `dart:io`'s `Directory` (only
/// `delete({recursive})` / `deleteSync({recursive})`) and no extension in
/// the snippet's reachable surface provides it. The suggestion landed as
/// `undefined_getter` in the consumer's test suite. Two layers close that
/// class of misfire:
///
/// 1. [SnippetDenyList] — a static, curated scan for member names verified
///    to NOT exist in the snippet's reachable API surface. Pure string
///    work, no I/O; catches the known misfire classes for free.
/// 2. [SnippetCompileCheck.compileCheck] — the REAL, authoritative check:
///    the snippet is written into a wrapper file inside a scratch dir
///    under the gitignored `build/` path (inside the package, so this
///    package's own package config resolves the wrapper imports) and
///    resolved IN-PROCESS with `package:analyzer`. Any ERROR-severity
///    diagnostic fails the check — which is exactly the `undefined_getter`
///    class of failure the issue reports: a non-existent member cannot
///    resolve in any context.
///
/// The gate fails CLOSED: if the package context cannot be established,
/// [SnippetCompileCheck.compileCheck] throws — a gate that silently passes
/// is not a gate.
library;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:path/path.dart' as p;

/// Severity of a [SnippetValidationIssue].
enum SnippetIssueSeverity { error, warning }

/// One finding from a snippet validation pass.
final class SnippetValidationIssue {
  const SnippetValidationIssue({
    required this.severity,
    required this.message,
    this.code,
    this.line,
  });

  final SnippetIssueSeverity severity;
  final String message;

  /// Machine-readable class of the finding (`non_existent_api`,
  /// `undefined_getter`, `syntax_error`, ...).
  final String? code;

  /// 1-based line inside the checked wrapper (best effort).
  final int? line;

  @override
  String toString() =>
      '[${code ?? severity.name}]${line != null ? ' line $line:' : ''} $message';
}

/// The aggregate outcome of a validation pass.
final class SnippetValidationResult {
  const SnippetValidationResult(this.issues);

  final List<SnippetValidationIssue> issues;

  /// True when NO error-severity finding was produced. Warnings do not
  /// block posting; errors do.
  bool get passed =>
      !issues.any((i) => i.severity == SnippetIssueSeverity.error);

  /// The error-severity findings only (what blocked the gate).
  List<SnippetValidationIssue> get errors =>
      issues.where((i) => i.severity == SnippetIssueSeverity.error).toList();

  /// Human-readable block for review-bot logs.
  String get render => issues.isEmpty
      ? 'snippet validation: PASS'
      : 'snippet validation: FAIL\n'
            '${issues.map((i) => '  - $i').join('\n')}';
}

/// The static deny-list: member names verified (this audit, spec 1685) to
/// NOT exist anywhere in the snippets' reachable API surface — `dart:io`
/// and the `package:test` / `test_api` / `flutter_test` extension surface.
///
/// Every entry is a member whose plausible-but-hallucinated name has either
/// already fired in a posted suggestion (`deleteRecursively`, issue #1685)
/// or is the same hallucination class (a "recursive"/"batch" convenience
/// that the platform deliberately models as a named API with a flag
/// instead). Each entry carries the compilable replacement the suggestion
/// should have used, so a scan hit is immediately actionable.
abstract final class SnippetDenyList {
  /// member name (word-boundary matched) → the compilable replacement.
  static const Map<String, String> entries = {
    'deleteRecursively':
        'dart:io cleanup is delete({recursive: true}) (async) / '
        'deleteSync({recursive: true}) (sync) — there is no '
        'deleteRecursively member on Directory, File, or '
        'FileSystemEntity, and no exported extension provides one',
    'deleteRecursivelySync':
        'dart:io cleanup is deleteSync({recursive: true}) — there is no '
        'deleteRecursivelySync member',
    'copyRecursively':
        'dart:io has no recursive copy API — copy entries with '
        'Directory.list(recursive: true) + File.copy, or an archive '
        'package',
    'waitAll':
        'dart:async has no Future.waitAll — use Future.wait(...) / '
        'Future.wait<void>([...])',
  };

  /// Word-boundary pattern for [member] (avoids matching user identifiers
  /// that merely CONTAIN the name, e.g. `myWaitAll`).
  static RegExp patternFor(String member) => RegExp('\\b$member\\b');

  /// Scans [snippet] for every deny-listed member. Returns one
  /// `non_existent_api` issue per hit. Pure string work — no I/O, no
  /// analyzer.
  static List<SnippetValidationIssue> scan(String snippet) {
    final issues = <SnippetValidationIssue>[];
    entries.forEach((member, replacement) {
      if (patternFor(member).hasMatch(snippet)) {
        issues.add(
          SnippetValidationIssue(
            severity: SnippetIssueSeverity.error,
            code: 'non_existent_api',
            message: _nonExistentMessage(member, replacement),
          ),
        );
      }
    });
    return issues;
  }

  static String _nonExistentMessage(String member, String replacement) =>
      'the snippet references "$member", which does not exist in its '
      'reachable API surface (issue #1685 class of misfire). '
      'Compilable replacement: $replacement';
}

/// The snippet compile check: the authoritative validation layer.
///
/// Runs the snippet through a REAL analyzer resolve over a wrapper file
/// (the #1664 scratch pattern: a gitignored `build/` scratch inside the
/// package, so this package's package config resolves the wrapper's
/// imports). Requires a package context where [defaultImports] resolve —
/// run inside the zuraffa package (tests, CI, wired bot runs) or a package
/// that dev-depends on `test`. Fails closed: no package context →
/// [StateError].
final class SnippetCompileCheck {
  const SnippetCompileCheck({this.imports = defaultImports});

  /// The wrapper's import set — the snippet's declared reachable surface.
  /// The default is the minimal set a review cleanup snippet depends on:
  /// dart:io for the `Directory` API and package:test for `addTearDown`.
  static const List<String> defaultImports = [
    'dart:io',
    'package:test/test.dart',
  ];

  /// The import lines (override for snippets with other needs).
  final List<String> imports;

  /// The wrapper function the snippet body is placed in. Top-level so
  /// `addTearDown` (a package:test top-level function) resolves, and async
  /// so snippets may await.
  static const _wrapperHeader =
      '// GENERATED by SnippetCompileCheck '
      '(spec 1685) — scratch, deleted after the check.\n';

  /// Layer 1: the static deny-list scan ([SnippetDenyList.scan]).
  SnippetValidationResult scan(String snippet) =>
      SnippetValidationResult(SnippetDenyList.scan(snippet));

  /// Layer 2: the REAL analyzer compile check. Writes the wrapper, resolves
  /// it, reports every ERROR-severity diagnostic. Warnings/infos (lints,
  /// unused imports) do not block — the gate's job is compilability.
  ///
  /// Each run gets its OWN temp subdirectory under `build/` (gitignored —
  /// the #1664 pattern) and removes only that subdirectory in a `finally`,
  /// so concurrent checks (parallel test isolates, overlapping wired-bot
  /// calls) can never delete or overwrite each other's wrapper mid-resolve.
  Future<SnippetValidationResult> compileCheck(String snippet) async {
    final packageRoot = _findPackageRoot();
    if (packageRoot == null) {
      // Fail CLOSED — a gate that silently passes is not a gate.
      throw StateError(
        'SnippetCompileCheck: no package context found (no pubspec.yaml '
        'with a resolved .dart_tool/package_config.json above the current '
        'directory). The snippet compile check refuses to run outside a '
        'package context — run inside the zuraffa package or a package '
        'that dev-depends on test.',
      );
    }

    final scratchParent = Directory(
      p.normalize(p.join(packageRoot, 'build', 'zuraffa_snippet_checks')),
    );
    await scratchParent.create(recursive: true);
    // One subdirectory per run — concurrent checks must not share or
    // delete each other's wrappers. Still under build/ (gitignored), so
    // the package config keeps resolving the wrapper's imports.
    final scratchDir = scratchParent.createTempSync('run_');
    final wrapperFile = File(p.join(scratchDir.path, 'snippet_check.dart'));
    try {
      await wrapperFile.writeAsString(_wrap(snippet));
      final absolute = wrapperFile.resolveSymbolicLinksSync();
      final collection = AnalysisContextCollection(includedPaths: [absolute]);
      final context = collection.contextFor(absolute);
      final result = await context.currentSession.getResolvedUnit(absolute);
      if (result is! ResolvedUnitResult) {
        return SnippetValidationResult([
          const SnippetValidationIssue(
            severity: SnippetIssueSeverity.error,
            code: 'not_resolved',
            message: 'the analyzer could not resolve the snippet wrapper',
          ),
        ]);
      }
      final lineInfo = result.lineInfo;
      final issues = <SnippetValidationIssue>[];
      for (final diagnostic in result.errors) {
        if (diagnostic.errorCode.errorSeverity != DiagnosticSeverity.ERROR) {
          continue; // lints/infos/warnings do not block compilability
        }
        issues.add(
          SnippetValidationIssue(
            severity: SnippetIssueSeverity.error,
            code: diagnostic.errorCode.name.toLowerCase(),
            line: lineInfo.getLocation(diagnostic.offset).lineNumber,
            message: diagnostic.message,
          ),
        );
      }
      return SnippetValidationResult(issues);
    } finally {
      // Only THIS run's subdirectory is removed — every concurrent run
      // owns its own, so the removal can no longer race another resolve
      // (the old shared-parent delete did exactly that).
      if (scratchDir.existsSync()) {
        await scratchDir.delete(recursive: true);
      }
    }
  }

  /// Both layers, in order: the deny-list scan first (free), the analyzer
  /// pass only when the scan found nothing (the authoritative word).
  Future<SnippetValidationResult> validate(
    String snippet, {
    bool runCompileCheck = true,
  }) async {
    final scanned = scan(snippet);
    if (scanned.issues.isNotEmpty || !runCompileCheck) return scanned;
    return compileCheck(snippet);
  }

  /// Wraps [snippet] in the compilable file shape.
  ///
  /// Visible for testing the wrapper shape itself.
  String _wrap(String snippet) {
    final importLines = imports.map((uri) => "import '$uri';").join('\n');
    // Indent the snippet two spaces so it sits as a statement block inside
    // the wrapper function; an empty snippet leaves an empty body (still
    // compiled).
    final indented = snippet.isEmpty
        ? ''
        : snippet
              .split('\n')
              .map((line) => line.isEmpty ? line : '  $line')
              .join('\n');
    return '$_wrapperHeader'
        "import 'dart:async';\n\n$importLines\n\n"
        'Future<void> snippetBody() async {\n$indented\n}\n';
  }

  /// Walks up from the current directory for a package root: a directory
  /// holding `pubspec.yaml` AND a resolved `.dart_tool/package_config.json`
  /// (the context the wrapper's `package:` imports resolve against).
  static String? _findPackageRoot() {
    var dir = Directory.current;
    while (true) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync() &&
          File(
            p.join(dir.path, '.dart_tool/package_config.json'),
          ).existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }
}
