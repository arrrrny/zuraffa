/// The mock certification sandbox (spec 1001, issue #1001): a throwaway
/// Dart package where the auto-generated contract test proves the mock
/// satisfies its interface BEFORE a receipt is written.
///
/// Flow ([MockCertificationSandbox.run]):
/// 1. resolve the zuraffa framework package root (from the target
///    project's `.dart_tool/package_config.json`, else from the running
///    CLI's script location);
/// 2. copy the mock's import closure (entity, datasource interface, mock
///    datasource, mock data, and every relative import/part they reach)
///    into a temp package's `lib/`, preserving the layout so the contract
///    test's relative imports are byte-identical;
/// 3. copy the contract test to `test/mock/<snake>/…`;
/// 4. `dart pub get` (offline first, warm-cache friendly), `dart analyze`
///    (must be error-free), `dart test <contract-test>` with the JSON
///    reporter — per-method outcomes are parsed from the test events.
///
/// The runner is `dart analyze` + `dart test` (package:test — the same
/// engine `flutter test` wraps): the zuraffa root package is pure Dart
/// (see `.specify/memory/tdd-profile.md`) and CI has no Flutter SDK on
/// the dart lane, so the deterministic, CI-parity choice is the Dart
/// toolchain.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../utils/string_utils.dart';
import 'mock_contract_test_writer.dart';

/// The outcome of one sandbox certification run.
class MockCertificationRun {
  const MockCertificationRun({
    required this.analyzeIssues,
    required this.analyzeErrors,
    required this.passedTests,
    required this.failedTests,
    required this.methodOutcomes,
    required this.runner,
    required this.logs,
  });

  /// Total analyzer issues reported for the sandbox package.
  final int analyzeIssues;

  /// Analyzer issues at error severity (any one fails certification).
  final int analyzeErrors;

  /// Test names that passed (contract test file must compile for any).
  final List<String> passedTests;

  /// Test names that failed.
  final List<String> failedTests;

  /// method name -> satisfied. Derived from the per-method test names;
  /// when the file fails to compile, every contract method is honestly
  /// unsatisfied.
  final Map<String, bool> methodOutcomes;

  /// The test runner used (`dart`).
  final String runner;

  /// Diagnostic tail (analyze + test output) for honest failure reports.
  final List<String> logs;

  bool get allMethodsSatisfied =>
      methodOutcomes.values.isNotEmpty &&
      methodOutcomes.values.every((satisfied) => satisfied);

  bool get analyzeClean => analyzeErrors == 0;
}

/// Runs the contract test in a temp sandbox and reports per-method
/// outcomes.
class MockCertificationSandbox {
  MockCertificationSandbox({
    this.testTimeout = const Duration(minutes: 5),
    this.pubGetTimeout = const Duration(minutes: 3),
  });

  final Duration testTimeout;
  final Duration pubGetTimeout;

  /// Execute the contract test for [entityName] against the subjects
  /// under [projectRoot]/[outputDir]. [contractTestSource] is the exact
  /// file content also committed to the target project. [methods] is the
  /// pinned contract (names only are used here).
  Future<MockCertificationRun> run({
    required String entityName,
    required String projectRoot,
    required String outputDir,
    required String contractTestSource,
    required List<ContractMethod> methods,
    bool verbose = false,
  }) async {
    final sandbox = await Directory.systemTemp.createTemp('zfa_mock_cert_');
    final logs = <String>[];
    try {
      final frameworkRoot = resolveFrameworkRoot(projectRoot);
      if (frameworkRoot == null) {
        return _unresolvedRun(
          methods,
          logs..add(
            'zfa mock certify: cannot resolve the zuraffa package root — '
            'run `dart pub get` in the target project first.',
          ),
        );
      }

      // 1. pubspec with a path dependency on the resolved framework.
      await File(p.join(sandbox.path, 'pubspec.yaml')).writeAsString('''
name: zfa_mock_cert_sandbox
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: ${jsonEncode(p.normalize(frameworkRoot))}
dev_dependencies:
  test: ^1.25.0
''');

      // 2. Copy the subject import closure into lib/.
      final copied = await _copyImportClosure(
        sandbox: sandbox,
        entityName: entityName,
        projectRoot: projectRoot,
        outputDir: outputDir,
        logs: logs,
      );
      if (!copied) {
        return _unresolvedRun(
          methods,
          logs..add('mock subjects are incomplete — nothing to certify'),
        );
      }

      // 3. The contract test at the same relative position.
      final testRel = MockContractTestWriter.contractTestPath(entityName);
      final testFile = File(p.join(sandbox.path, testRel));
      await testFile.parent.create(recursive: true);
      await testFile.writeAsString(contractTestSource);

      // 4. dart pub get (offline first — warm cache, no network).
      var pubGet = await _run(
        'dart',
        ['pub', 'get', '--offline'],
        sandbox.path,
        pubGetTimeout,
      );
      if (pubGet.exitCode != 0) {
        pubGet = await _run(
          'dart',
          ['pub', 'get'],
          sandbox.path,
          pubGetTimeout,
        );
      }
      if (pubGet.exitCode != 0) {
        logs.add('dart pub get failed:\n${_tail(pubGet.stderr)}');
        return _unresolvedRun(methods, logs);
      }

      // 5. dart analyze — errors fail certification outright. Infos are
      //    not fatal by default in the Dart SDK; warnings are demoted so
      //    only real errors block (the sandbox has no analysis_options,
      //    so lints never apply).
      final analyze = await _run(
        'dart',
        ['analyze', '.', '--no-fatal-warnings'],
        sandbox.path,
        testTimeout,
      );
      final analyzeIssues = _countAnalyzeIssues(analyze.stdout);
      final analyzeErrors = _countAnalyzeErrors(
        analyze.stdout + analyze.stderr,
      );
      logs.add(
        'dart analyze: $analyzeIssues issue(s), '
        '$analyzeErrors error(s)',
      );
      if (analyze.exitCode != 0 || analyzeErrors > 0) {
        logs.add('dart analyze output:\n${_tail(analyze.stdout)}');
        return MockCertificationRun(
          analyzeIssues: analyzeIssues,
          analyzeErrors: analyzeErrors,
          passedTests: const [],
          failedTests: const [],
          methodOutcomes: {for (final m in methods) m.name: false},
          runner: 'dart',
          logs: logs,
        );
      }

      // 6. dart test with the JSON reporter — per-method outcomes.
      final test = await _run(
        'dart',
        ['test', testRel, '--reporter', 'json'],
        sandbox.path,
        testTimeout,
      );
      final outcomes = _parseTestOutcomes(test.stdout, methods);
      final passed = <String>[];
      final failed = <String>[];
      for (final m in methods) {
        (outcomes[m.name] == true ? passed : failed).add(m.name);
      }
      if (test.exitCode != 0 && failed.isEmpty) {
        // Compilation/load failure: every method is honestly red.
        logs.add(
          'dart test failed to run the contract test:\n'
          '${_tail(test.stdout + test.stderr)}',
        );
        return MockCertificationRun(
          analyzeIssues: analyzeIssues,
          analyzeErrors: analyzeErrors,
          passedTests: const [],
          failedTests: [for (final m in methods) m.name],
          methodOutcomes: {for (final m in methods) m.name: false},
          runner: 'dart',
          logs: logs,
        );
      }
      if (verbose) {
        logs.add('sandbox: ${sandbox.path}');
      }
      return MockCertificationRun(
        analyzeIssues: analyzeIssues,
        analyzeErrors: analyzeErrors,
        passedTests: passed,
        failedTests: failed,
        methodOutcomes: outcomes,
        runner: 'dart',
        logs: logs,
      );
    } finally {
      await _delete(sandbox);
    }
  }

  MockCertificationRun _unresolvedRun(
    List<ContractMethod> methods,
    List<String> logs,
  ) => MockCertificationRun(
    analyzeIssues: 0,
    analyzeErrors: 1,
    passedTests: const [],
    failedTests: [for (final m in methods) m.name],
    methodOutcomes: {for (final m in methods) m.name: false},
    runner: 'dart',
    logs: logs,
  );

  /// Copy the mock's transitive relative-import closure into the sandbox
  /// `lib/` while preserving paths.
  Future<bool> _copyImportClosure({
    required Directory sandbox,
    required String entityName,
    required String projectRoot,
    required String outputDir,
    required List<String> logs,
  }) async {
    final snake = StringUtils.camelToSnake(entityName);
    final anchor = p.absolute(projectRoot);
    final roots = <String>[
      p.join(outputDir, 'domain', 'entities', snake, '$snake.dart'),
      p.join(
        outputDir,
        'data',
        'datasources',
        snake,
        '${snake}_datasource.dart',
      ),
      p.join(
        outputDir,
        'data',
        'datasources',
        snake,
        '${snake}_mock_datasource.dart',
      ),
      p.join(outputDir, 'data', 'mock', '${snake}_mock_data.dart'),
    ];
    final existingRoots = roots
        .map((r) => p.absolute(r))
        .where((r) => File(r).existsSync())
        .toList();
    if (existingRoots.length < 3) {
      logs.add(
        'mock subjects missing under $outputDir (found '
        '${existingRoots.length}/4): ${roots.join(', ')}',
      );
      return false;
    }

    // Every source path is normalized ABSOLUTE (p.join discards its
    // first argument when the second is absolute — the classic silent
    // bug), and the sandbox target mirrors the project-root-relative
    // layout so the contract test's relative imports are unchanged.
    String? sandboxTargetOf(String absoluteSource) {
      final rel = p.relative(absoluteSource, from: anchor);
      if (rel.startsWith('..')) return null;
      return p.join(sandbox.path, rel);
    }

    final queue = List<String>.of(existingRoots);
    final copied = <String>{};
    while (queue.isNotEmpty) {
      final source = p.absolute(queue.removeLast());
      if (copied.contains(source)) continue;
      if (!File(source).existsSync()) {
        logs.add('subject import missing: $source');
        return false;
      }
      final target = sandboxTargetOf(source);
      if (target == null) {
        logs.add(
          'subject outside the project root cannot be sandboxed: $source',
        );
        return false;
      }
      copied.add(source);
      await File(target).parent.create(recursive: true);
      await File(target).writeAsString(await File(source).readAsString());

      for (final ref in _relativeRefs(await File(source).readAsString())) {
        final resolved = p.normalize(
          p.absolute(p.join(p.dirname(source), ref)),
        );
        if (!copied.contains(resolved) && File(resolved).existsSync()) {
          queue.add(resolved);
        } else if (!File(resolved).existsSync()) {
          logs.add('subject import missing: $resolved');
          return false;
        }
      }
    }
    return true;
  }

  /// Relative (non-package, non-dart:) import/export/part URIs in a
  /// source file.
  static List<String> _relativeRefs(String source) {
    final refs = <String>[];
    final pattern = RegExp(
      r"^(?:import|export|part)\s+'([^']+)'\s*(?:as\s+\w+)?\s*;",
      multiLine: true,
    );
    for (final match in pattern.allMatches(source)) {
      final uri = match.group(1)!;
      if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
      refs.add(uri);
    }
    return refs;
  }

  /// Resolve the zuraffa framework package root:
  /// 1. the target project's `.dart_tool/package_config.json` entry;
  /// 2. the running CLI's own script (`bin/zfa.dart` → repo root);
  /// 3. a `pubspec.yaml` named zuraffa from the cwd upward.
  static String? resolveFrameworkRoot(String projectRoot) {
    // 1. package_config.json
    final config = File(
      p.join(projectRoot, '.dart_tool', 'package_config.json'),
    );
    if (config.existsSync()) {
      try {
        final doc =
            jsonDecode(config.readAsStringSync()) as Map<String, dynamic>;
        for (final pkg in (doc['packages'] as List<dynamic>? ?? const [])) {
          if (pkg is Map<String, dynamic> && pkg['name'] == 'zuraffa') {
            final rootUri = pkg['rootUri'] as String?;
            if (rootUri == null) continue;
            final rootPath = rootUri.startsWith('file:')
                ? Uri.parse(rootUri).toFilePath()
                : p.normalize(
                    p.absolute(p.join(projectRoot, '.dart_tool', rootUri)),
                  );
            if (Directory(rootPath).existsSync()) return rootPath;
          }
        }
      } catch (_) {
        // Fall through to the script heuristic.
      }
    }

    // 2. The CLI's own script (dart run bin/zfa.dart / pub global).
    try {
      final script = Platform.script;
      if (script.scheme == 'file' || script.scheme == 'data') {
        final scriptPath = script.toFilePath();
        if (p.basename(scriptPath) == 'zfa.dart' ||
            p.basename(scriptPath) == 'zuraffa.dart') {
          final root = p.dirname(p.dirname(scriptPath));
          if (_looksLikeZuraffa(root)) return root;
        }
      }
    } catch (_) {
      // Platform.script unavailable in this embedder.
    }

    // 3. cwd upward search.
    var dir = Directory.current.path;
    for (var i = 0; i < 6; i++) {
      if (_looksLikeZuraffa(dir)) return dir;
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
    return null;
  }

  static bool _looksLikeZuraffa(String dir) {
    final pubspec = File(p.join(dir, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    return pubspec.readAsStringSync().contains(RegExp(r'^name:\s*zuraffa\b'));
  }

  Map<String, bool> _parseTestOutcomes(
    String stdout,
    List<ContractMethod> methods,
  ) {
    final outcomes = <String, bool>{};
    String? currentTest;
    for (final line in stdout.split('\n')) {
      if (line.isEmpty || !line.startsWith('{')) continue;
      Map<String, dynamic>? event;
      try {
        event = jsonDecode(line) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      final type = event['type'];
      if (type == 'testStart') {
        final test = event['test'] as Map<String, dynamic>?;
        currentTest = test?['name'] as String?;
      } else if (type == 'testDone') {
        final result = event['result'] as String?;
        final name = currentTest;
        if (name != null) {
          final method = _methodFromTestName(name, methods);
          if (method != null) {
            outcomes[method] = result == 'success';
          }
        }
        currentTest = null;
      } else if (type == 'error' || type == 'print') {
        // Load errors: leave methods unresolved (all-false default).
      }
    }
    // Methods with no recorded outcome default to unsatisfied.
    for (final m in methods) {
      outcomes.putIfAbsent(m.name, () => false);
    }
    return outcomes;
  }

  String? _methodFromTestName(String testName, List<ContractMethod> methods) {
    // Test names look like:
    // "Login mock contract (spec 1001) get: exists, returns Future<Login>…"
    for (final m in methods) {
      if (testName.contains('${m.name}:')) return m.name;
    }
    return null;
  }

  int _countAnalyzeIssues(String stdout) {
    final match = RegExp(r'(\d+) issues? found').firstMatch(stdout);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  int _countAnalyzeErrors(String output) {
    return RegExp(
      r'^\s*(error|ERROR)\s*-\s',
      multiLine: true,
    ).allMatches(output).length;
  }

  Future<ProcessOutput> _run(
    String executable,
    List<String> args,
    String workingDirectory,
    Duration timeout,
  ) async {
    try {
      final proc = await Process.start(
        executable,
        args,
        workingDirectory: workingDirectory,
      );
      final stdoutFuture = proc.stdout.transform(utf8.decoder).join();
      final stderrFuture = proc.stderr.transform(utf8.decoder).join();
      final exitFuture = proc.exitCode.timeout(
        timeout,
        onTimeout: () {
          proc.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final results = await Future.wait<dynamic>([
        exitFuture,
        stdoutFuture,
        stderrFuture,
      ]);
      return ProcessOutput(
        exitCode: results[0] as int,
        stdout: results[1] as String,
        stderr: results[2] as String,
      );
    } catch (e) {
      return ProcessOutput(exitCode: -1, stdout: '', stderr: '$e');
    }
  }

  String _tail(String output) {
    final lines = output.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length <= 30) return lines.join('\n');
    return '${lines.take(15).join('\n')}\n…\n'
        '${lines.skip(lines.length - 15).join('\n')}';
  }

  Future<void> _delete(Directory dir) async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup — the OS temp cleaner owns the rest.
    }
  }
}

class ProcessOutput {
  const ProcessOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
