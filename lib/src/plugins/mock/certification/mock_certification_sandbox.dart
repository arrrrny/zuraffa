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
/// 4. pub get (offline first, warm-cache friendly), analyze (must be
///    error-free), `test <contract-test>` with the JSON reporter —
///    per-method outcomes are parsed from the test events.
///
/// The runner is the plain Dart toolchain by default (`dart analyze` +
/// `dart test` — package:test is the same engine `flutter test` wraps; the
/// zuraffa root package is pure Dart (see
/// `.specify/memory/tdd-profile.md`) and CI has no Flutter SDK on the dart
/// lane, so the deterministic, CI-parity choice is the Dart toolchain).
/// A Flutter-shaped contract test (#1600) is proven with the Flutter
/// toolchain instead: the manifest declares the Flutter SDK + flutter_test
/// and the steps run through `flutter`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
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

  /// The test runner used (`dart` by default, `flutter` for a
  /// Flutter-shaped proof).
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
///
/// [flutterTest] (issue #1600) proves a Flutter-shaped contract test with
/// the Flutter toolchain: the sandbox manifest declares the Flutter SDK and
/// `flutter_test`, and the pub-get / analyze / test steps run through the
/// `flutter` executable (same timeouts, offline-first strategy, JSON
/// reporter, and per-method parsing). The default keeps today's pure-Dart
/// sandbox byte-for-byte.
class MockCertificationSandbox {
  MockCertificationSandbox({
    this.flutterTest = false,
    this.testTimeout = const Duration(minutes: 5),
    this.pubGetTimeout = const Duration(minutes: 3),
  });

  /// Whether the contract test under proof imports the Flutter test
  /// framework (the host project is a Flutter project).
  final bool flutterTest;

  final Duration testTimeout;
  final Duration pubGetTimeout;

  /// The toolchain executable for [flutterTest]: `flutter` proves a
  /// Flutter-shaped test (the plain Dart VM cannot resolve the Flutter SDK
  /// packages), `dart` keeps the deterministic CI-parity default.
  static String toolchainFor(bool flutterTest) =>
      flutterTest ? 'flutter' : 'dart';

  /// The toolchain executable this sandbox runs with.
  String get toolchain => toolchainFor(flutterTest);

  /// Whether a `flutter` executable is available on PATH — the
  /// Flutter-shaped proof needs the Flutter toolchain. Assignable so hosts
  /// and tests can pin the probe: the CLI capabilities consult it BEFORE
  /// the sandbox runs and degrade honestly when it answers false (the
  /// spec-1110 unresolved-environment precedent).
  static bool Function() flutterOnPath = _flutterExecutableOnPathDefault;

  /// Scans a PATH-style string for a flutter executable file.
  ///
  /// Existence alone is not capability (#1600 review): a `flutter` file
  /// without an execute bit cannot start a process, so a PATH entry
  /// holding one is NOT a usable SDK. Requiring the bit keeps the
  /// "no usable flutter" and "no flutter at all" shapes on the SAME
  /// degradation branch instead of the former landing on a red run.
  static bool flutterExecutableOnPath(
    String pathEnv, {
    String delimiter = ':',
  }) {
    for (final dir in pathEnv.split(delimiter)) {
      if (dir.isEmpty) continue;
      final flutter = File(p.join(dir, 'flutter'));
      if (flutter.existsSync() && _isExecutable(flutter)) return true;
      if (File(p.join(dir, 'flutter.bat')).existsSync()) return true;
    }
    return false;
  }

  /// POSIX executability of [file] — the `0o111` execute bits. Windows
  /// carries no exec bit, so the answer there is existence-derived (the
  /// `.bat` entry above covers the real Windows launcher).
  static bool _isExecutable(File file) {
    if (Platform.isWindows) return true;
    try {
      return file.statSync().mode & 0x49 != 0;
    } on FileSystemException {
      return false;
    }
  }

  static bool _flutterExecutableOnPathDefault() => flutterExecutableOnPath(
    Platform.environment['PATH'] ?? '',
    delimiter: Platform.isWindows ? ';' : ':',
  );

  /// The sandbox package manifest for [frameworkRoot]. The Flutter shape
  /// declares the Flutter SDK + `flutter_test` so the Flutter-shaped
  /// contract test resolves; `test` is NOT declared there — flutter_test
  /// pins matcher/test_api with which no published `test` version resolves
  /// once the framework's graphql graph is present (the same #1189
  /// conflict), and the Flutter-shaped test imports only flutter_test. The
  /// default shape is today's exact bytes.
  static String pubspecFor({
    required String frameworkRoot,
    required bool flutterTest,
  }) => flutterTest
      ? '''
name: zfa_mock_cert_sandbox
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  zuraffa:
    path: ${jsonEncode(p.normalize(frameworkRoot))}
dev_dependencies:
  flutter_test:
    sdk: flutter
'''
      : '''
name: zfa_mock_cert_sandbox
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa:
    path: ${jsonEncode(p.normalize(frameworkRoot))}
dev_dependencies:
  test: ^1.25.0
''';

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

      // A Flutter-shaped proof without the Flutter toolchain is an
      // unresolvable environment, not a red contract (#1600) — the CLI
      // capabilities check this BEFORE the sandbox runs; this is the
      // honest defense for direct library use.
      if (flutterTest && !flutterOnPath()) {
        return _unresolvedRun(
          methods,
          logs..add(
            'the Flutter-shaped contract test cannot be certified: no '
            'flutter executable on PATH — install the Flutter SDK, then '
            're-run the certification',
          ),
        );
      }

      // 1. pubspec with a path dependency on the resolved framework (the
      //    Flutter shape declares the Flutter SDK + flutter_test — #1600).
      await File(p.join(sandbox.path, 'pubspec.yaml')).writeAsString(
        pubspecFor(frameworkRoot: frameworkRoot, flutterTest: flutterTest),
      );

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

      // 4. pub get (offline first — warm cache, no network).
      var pubGet = await _run(
        toolchain,
        ['pub', 'get', '--offline'],
        sandbox.path,
        pubGetTimeout,
      );
      if (pubGet.exitCode != 0) {
        pubGet = await _run(
          toolchain,
          ['pub', 'get'],
          sandbox.path,
          pubGetTimeout,
        );
      }
      if (pubGet.exitCode != 0) {
        logs.add('$toolchain pub get failed:\n${_tail(pubGet.stderr)}');
        return _unresolvedRun(methods, logs);
      }

      // 5. analyze — errors fail certification outright. Infos are
      //    not fatal by default in the Dart SDK; warnings are demoted so
      //    only real errors block (the sandbox has no analysis_options,
      //    so lints never apply). `flutter analyze` defaults
      //    `--fatal-infos` ON while `dart analyze` defaults it off, so the
      //    Flutter lane demotes infos too — both lanes block on the same
      //    severities (#1600 review).
      final analyze = await _run(
        toolchain,
        [
          'analyze',
          '.',
          '--no-fatal-warnings',
          if (flutterTest) '--no-fatal-infos',
        ],
        sandbox.path,
        testTimeout,
      );
      final analyzeIssues = _countAnalyzeIssues(analyze.stdout);
      final analyzeErrors = countAnalyzeErrors(analyze.stdout + analyze.stderr);
      logs.add(
        '$toolchain analyze: $analyzeIssues issue(s), '
        '$analyzeErrors error(s)',
      );
      if (analyze.exitCode != 0 || analyzeErrors > 0) {
        logs.add('$toolchain analyze output:\n${_tail(analyze.stdout)}');
        return MockCertificationRun(
          analyzeIssues: analyzeIssues,
          analyzeErrors: analyzeErrors,
          passedTests: const [],
          failedTests: const [],
          methodOutcomes: {for (final m in methods) m.name: false},
          runner: toolchain,
          logs: logs,
        );
      }

      // 6. test with the JSON reporter — per-method outcomes.
      final test = await _run(
        toolchain,
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
          '$toolchain test failed to run the contract test:\n'
          '${_tail(test.stdout + test.stderr)}',
        );
        return MockCertificationRun(
          analyzeIssues: analyzeIssues,
          analyzeErrors: analyzeErrors,
          passedTests: const [],
          failedTests: [for (final m in methods) m.name],
          methodOutcomes: {for (final m in methods) m.name: false},
          runner: toolchain,
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
        runner: toolchain,
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
    runner: toolchain,
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

  /// Errors in analyzer output, across BOTH toolchain line grammars:
  /// `dart analyze`    → `error - <path>:<l>:<c> - <message> - <code>`
  /// `flutter analyze` → `error • <message> • <path>:<l>:<c> • <code>`
  /// Matching only the `-` separator silently counted 0 for every
  /// Flutter-lane error, so `analyzeClean` went vacuous there (#1600
  /// review). Public for the string-level behavior that pins both
  /// grammars without an SDK.
  @visibleForTesting
  static int countAnalyzeErrors(String output) {
    return RegExp(
      r'^\s*(error|ERROR)\s*(?:-|•)\s',
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
