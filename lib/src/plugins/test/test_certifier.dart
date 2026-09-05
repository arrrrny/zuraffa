import 'dart:convert';
import 'dart:io';

import '../../models/generated_file.dart';

/// Spec 980 / FR-001 — self-certification for the test plugin.
///
/// After the test plugin writes a generated test file, [TestSelfCertifier]
/// runs a scoped `dart analyze` on that file and produces a
/// [TestCertification]: the machine verdict line
/// `test: entity=<X> tests=<N> compile=pass|fail --> fix: <first error>`
/// and the `--json` envelope `{entity, tests, compile, errors[], schema:1}`.
/// A test generator must never emit a test it has not proven compiles.

/// One compile error reported by the scoped analysis of a generated test.
class TestCompileError {
  /// Path of the analyzed file, as passed to the analyzer.
  final String file;

  /// 1-based line of the diagnostic.
  final int line;

  /// Human-readable diagnostic message.
  final String message;

  const TestCompileError({
    required this.file,
    required this.line,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
    'file': file,
    'line': line,
    'message': message,
  };

  factory TestCompileError.fromJson(Map<String, dynamic> json) =>
      TestCompileError(
        file: json['file'] as String,
        line: (json['line'] as num?)?.toInt() ?? 0,
        message: json['message'] as String,
      );

  @override
  String toString() => '$file:$line: $message';
}

/// Machine verdict for one test generation run (schema 1).
class TestCertification {
  static const int schemaVersion = 1;

  /// Entity (or usecase target) the tests were generated for.
  final String entity;

  /// Number of generated `test(...)` blocks across all files.
  final int tests;

  /// True when every generated file analyzed clean (compile = pass).
  final bool compile;

  /// First errors per file (machine verdict names only the first one).
  final List<TestCompileError> errors;

  const TestCertification({
    required this.entity,
    required this.tests,
    required this.compile,
    required this.errors,
  });

  /// The machine verdict line:
  /// `test: entity=<X> tests=<N> compile=pass|fail --> fix: <first error>`
  String get verdictLine {
    final base =
        'test: entity=$entity tests=$tests compile=${compile ? 'pass' : 'fail'}';
    if (compile) return base;
    final fix = errors.isNotEmpty ? errors.first.message : 'unknown';
    return '$base --> fix: $fix';
  }

  /// The `--json` envelope: `{entity, tests, compile, errors[], schema:1}`.
  Map<String, dynamic> toJson() => {
    'entity': entity,
    'tests': tests,
    'compile': compile ? 'pass' : 'fail',
    'errors': errors.map((e) => e.toJson()).toList(),
    'schema': schemaVersion,
  };

  factory TestCertification.fromJson(Map<String, dynamic> json) =>
      TestCertification(
        entity: json['entity'] as String,
        tests: (json['tests'] as num?)?.toInt() ?? 0,
        compile: (json['compile'] as String? ?? 'fail') == 'pass',
        errors: (json['errors'] as List? ?? const [])
            .map(
              (e) => TestCompileError.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(growable: false),
      );
}

/// Result of one scoped `dart analyze` invocation.
class ScopedAnalysisResult {
  /// False when the analyzer executable could not run at all (missing SDK,
  /// process error). The certifier then refuses to claim compile=pass.
  final bool ran;

  /// ERROR-severity diagnostics for the analyzed file.
  final List<TestCompileError> errors;

  const ScopedAnalysisResult({required this.ran, required this.errors});
}

/// Runs a scoped `dart analyze` on a single file.
///
/// Injected into [TestSelfCertifier]; the production implementation is
/// [ProcessScopedAnalyzer], tests inject fakes.
abstract class ScopedAnalyzer {
  Future<ScopedAnalysisResult> analyzeFile(String projectRoot, String filePath);

  /// Parses `dart analyze --format=machine` output lines
  /// (`ERROR|type|code|path|line|col|colEnd|message`) into error records.
  /// Only ERROR-severity lines count against the compile verdict; warnings
  /// and infos do not. Message text may itself contain `|`, so everything
  /// after the seventh separator is the message.
  static List<TestCompileError> parseMachineLines(List<String> lines) {
    final errors = <TestCompileError>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final parts = line.split('|');
      if (parts.length < 8) continue;
      if (parts[0] != 'ERROR') continue;
      final file = parts[3];
      final lineNo = int.tryParse(parts[4]) ?? 0;
      final message = parts.sublist(7).join('|');
      errors.add(TestCompileError(file: file, line: lineNo, message: message));
    }
    return errors;
  }
}

/// Production [ScopedAnalyzer]: shells out to `dart analyze --format=machine`
/// scoped to the single generated test file, with the working directory set
/// to the project root so package resolution matches the user's project.
class ProcessScopedAnalyzer implements ScopedAnalyzer {
  /// Command used to launch the analyzer; `dart` by default. Injectable so
  /// environments with a custom SDK layout can point elsewhere.
  final String dartExecutable;

  const ProcessScopedAnalyzer({this.dartExecutable = 'dart'});

  @override
  Future<ScopedAnalysisResult> analyzeFile(
    String projectRoot,
    String filePath,
  ) async {
    final workingDir = projectRoot.isEmpty
        ? Directory.current.path
        : projectRoot;
    try {
      final result = await Process.run(
        dartExecutable,
        ['analyze', '--format=machine', filePath],
        workingDirectory: workingDir,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      final stdout = result.stdout as String;
      final lines = const LineSplitter().convert(stdout);
      return ScopedAnalysisResult(
        ran: true,
        errors: ScopedAnalyzer.parseMachineLines(lines),
      );
    } catch (e) {
      // The analyzer itself could not run — that is NOT a pass.
      return ScopedAnalysisResult(
        ran: false,
        errors: [
          TestCompileError(
            file: filePath,
            line: 0,
            message: 'dart analyze failed to run: $e',
          ),
        ],
      );
    }
  }
}

/// Counts `test(...)` blocks in generated test sources. Exported for the
/// receipt writer so `tests=<N>` and the receipt agree by construction.
int countTestBlocks(Iterable<String> contents) {
  final pattern = RegExp(r'\btest\s*\(');
  var count = 0;
  for (final content in contents) {
    count += pattern.allMatches(content).length;
  }
  return count;
}

/// Self-certifies generated test files: one scoped analysis per written
/// file, then a single machine verdict.
class TestSelfCertifier {
  final ScopedAnalyzer analyzer;

  TestSelfCertifier({ScopedAnalyzer? analyzer})
    : analyzer = analyzer ?? const ProcessScopedAnalyzer();

  /// Certifies [files]. Returns null when there is nothing to certify
  /// (no written test files — e.g. a dry run or an all-skipped generation).
  Future<TestCertification?> certify({
    required String entity,
    required String projectRoot,
    required List<GeneratedFile> files,
  }) async {
    final written = files
        .where((f) => f.type == 'test' && f.action != 'skipped')
        .toList(growable: false);
    if (written.isEmpty) return null;

    final tests = countTestBlocks(
      written.map((f) => f.content ?? '').where((c) => c.isNotEmpty),
    );

    final errors = <TestCompileError>[];
    var compile = true;
    for (final file in written) {
      final result = await analyzer.analyzeFile(projectRoot, file.path);
      if (!result.ran) {
        // The analyzer itself failed — that is NOT a pass, and it is
        // never silent: synthesize a diagnostic naming the file.
        compile = false;
        errors.add(
          result.errors.isNotEmpty
              ? result.errors.first
              : TestCompileError(
                  file: file.path,
                  line: 0,
                  message: 'dart analyze failed to run for ${file.path}',
                ),
        );
        continue;
      }
      if (result.errors.isNotEmpty) {
        compile = false;
        errors.add(result.errors.first);
      }
    }

    return TestCertification(
      entity: entity,
      tests: tests,
      compile: compile,
      errors: errors.take(8).toList(growable: false),
    );
  }
}
