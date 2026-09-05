// RouteVerifyCommand — `zfa route verify`.
//
// Two grammars, one command (spec 0971, T004):
//
//   * `zfa route verify` (no positional) — the drift observability seam
//     (bug: route-dual-system-unreconciled): reads the route table from
//     disk (CLI side: `*_routes.dart`, DDA side: generated
//     `zfa_router.g.dart` if present), runs drift detection, and emits a
//     result in text, plain, or JSON form.
//
//   * `zfa route verify <Entity>` (spec 0971 order 4) — the A+ verdict:
//     resolves the entity's routes receipt
//     (`.zfa/receipts/routes-<Entity>.json`, order 3) as the declared
//     table, proves the CURRENT tree against it (declared vs resolved
//     routes, GoRoute builder presence, deep-link patterns, the
//     route-table test artifact digest), runs the generated route-table
//     test headlessly, emits a verdict receipt, and exits 0/1 with
//     `--> fix:` lines on every mismatch.
//
// The headless test runner is injectable (the tdd realize suite-runner
// pattern): real `flutter test` / `dart test` in production, faked in
// tests so both exit paths stay deterministic.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../core/project/receipt_store.dart';
import '../plugins/route/builders/route_table_test_builder.dart';
import '../plugins/route/route_receipt.dart';
import '../utils/string_utils.dart';
import '../version.dart';
import '../plugins/route/route_drift_detector.dart';
import '../plugins/route/route_table.dart';

/// Runs one route-table test headlessly: returns the process exit code
/// and captured output. Throws [ProcessException] when no runner is
/// available for the suite (the verdict then falls back to the static
/// checks — an environment without a runner must not fail a statically
/// healthy table).
typedef RouteTableTestRunner =
    Future<({int exitCode, String output})> Function(
      String testPath,
      String workingDirectory,
    );

class RouteVerifyCommand extends Command<void> {
  RouteVerifyCommand({String? projectRoot, RouteTableTestRunner? testRunner})
    : _projectRoot = projectRoot ?? Directory.current.path,
      _testRunnerOverride = testRunner {
    argParser.addFlag(
      'json',
      negatable: false,
      help:
          'Emit a machine verdict (drift mode: route-table.json '
          'artifact; entity mode: the schema-1 verdict envelope).',
    );
    argParser.addFlag(
      'plain',
      negatable: false,
      help: 'Strip emoji and color from output (CI-friendly).',
    );
    argParser.addFlag(
      'strict',
      negatable: false,
      help: 'Treat drift warnings as errors (exit 1).',
    );
    argParser.addOption(
      'out',
      help: 'Write JSON to this path instead of stdout.',
    );
  }

  final _detector = const RouteDriftDetector();
  final String _projectRoot;
  final RouteTableTestRunner? _testRunnerOverride;

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Verify routes: with <Entity>, prove the declared table against the '
      'current tree and run the route-table test headlessly (spec 0971); '
      'without, compare CLI-generated and DDA-annotated routes for drift.';

  @override
  Future<void> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isNotEmpty) {
      await _runEntityVerify(rest.first);
      return;
    }
    await _runDriftVerify();
  }

  // ---------------------------------------------------------------------------
  // Entity mode (spec 0971 order 4)
  // ---------------------------------------------------------------------------

  Future<void> _runEntityVerify(String entityRaw) async {
    final asJson = argResults?['json'] == true;
    final plain = argResults?['plain'] == true;
    final outPath = argResults?['out'] as String?;
    final entity = StringUtils.convertToPascalCase(entityRaw);

    final receiptFile = File(
      RouteReceiptWriter.receiptPath(_projectRoot, entity),
    );
    if (!receiptFile.existsSync()) {
      _entityFail(
        'no routes receipt for "$entity" — nothing declares its route table',
        fix: 'run `zfa route create $entity` first, then re-verify',
        entity: entity,
        asJson: asJson,
        outPath: outPath,
        findings: const [],
        routes: const [],
        deepLinks: const [],
        testRun: null,
      );
      return;
    }

    final Map<String, dynamic> receipt;
    try {
      receipt =
          jsonDecode(receiptFile.readAsStringSync()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      _entityFail(
        'routes receipt for "$entity" is not parseable JSON: $e',
        fix: 're-run `zfa route create $entity` to rewrite the receipt',
        entity: entity,
        asJson: asJson,
        outPath: outPath,
        findings: const [],
        routes: const [],
        deepLinks: const [],
        testRun: null,
      );
      return;
    }

    final declaredRoutes = (receipt['routes'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final declaredLinks = (receipt['deepLinks'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final testPath = receipt['routeTableTestPath'] as String?;
    final recordedTestHash = receipt['routeTableTestSha256'] as String?;

    final findings = <Map<String, dynamic>>[];

    // 1. The proof artifact (the generated route-table test) must exist
    //    and still hash to the recorded digest.
    if (testPath == null) {
      findings.add({
        'kind': 'route-table-test-missing',
        'detail':
            'the routes receipt records no route-table test — the table has '
            'no proof artifact',
        'fix':
            're-run `zfa route create $entity` to regenerate the '
            'route-table test',
      });
    } else {
      final testFile = File(p.join(_projectRoot, testPath));
      if (!testFile.existsSync()) {
        findings.add({
          'kind': 'route-table-test-missing',
          'path': testPath,
          'detail': 'route-table test $testPath does not exist on disk',
          'fix': 're-run `zfa route create $entity` to regenerate it',
        });
      } else if (recordedTestHash != null) {
        final actual = crypto.sha256
            .convert(testFile.readAsBytesSync())
            .toString();
        if (actual != recordedTestHash) {
          findings.add({
            'kind': 'route-table-test-drift',
            'path': testPath,
            'detail':
                'route-table test hash drift: receipt says '
                '${recordedTestHash.substring(0, 12)}, disk has '
                '${actual.substring(0, 12)}',
            'fix':
                'regenerate the table (`zfa route create $entity`) or '
                'revert the hand edit to $testPath',
          });
        }
      }
    }

    // 2. Declared vs resolved: the receipt's declared table against the
    //    modules on disk (manifest discovery — same parser the generator
    //    uses), and every GoRoute in the routing tree must carry a
    //    builder/pageBuilder/redirect (the route-table test's first
    //    assertion, mirrored statically).
    final outputDir = p.join(_projectRoot, 'lib', 'src');
    final manifest = await RouteTableTestBuilder().discover(
      outputDir: outputDir,
    );
    final diskPaths = manifest.declaredRoutes.map((r) => r.path).toSet();
    for (final route in declaredRoutes) {
      if (!diskPaths.contains(route['path'])) {
        findings.add({
          'kind': 'declared-route-missing',
          'path': route['path'],
          'owner': route['owner'],
          'detail':
              'declared route ${route['path']} (${route['owner']}) is no '
              'longer declared on disk',
          'fix':
              're-run `zfa route create $entity` (or restore the '
              'constant ${route['owner']})',
        });
      }
    }
    // Reverse direction (audit F1): a route module that appeared on disk
    // AFTER the receipt was written means the ledger row no longer
    // describes the tree — the receipt is stale, not the tree healthy.
    // Both directions must drift-fail symmetrically (#963 ledger).
    final receiptPaths = declaredRoutes.map((r) => r['path']).toSet();
    for (final disk in manifest.declaredRoutes) {
      if (!receiptPaths.contains(disk.path)) {
        findings.add({
          'kind': 'disk-route-unprovenanced',
          'path': disk.path,
          'owner': disk.owner,
          'detail':
              'route ${disk.path} (${disk.owner}) is declared on disk but '
              'no routes receipt covers it — the receipt is stale',
          'fix':
              're-run `zfa route create $entity` to refresh the ledger '
              'row (or remove the stale module)',
        });
      }
    }
    for (final finding in _goRouteBuilderFindings(entity)) {
      findings.add(finding);
    }

    // 3. Deep-link patterns must still parse with the same typed params.
    final diskLinks = <String, List<String>>{
      for (final link in manifest.deepLinks) link.pattern: link.params,
    };
    for (final link in declaredLinks) {
      final pattern = link['pattern'] as String;
      final params = (link['params'] as List).cast<String>();
      if (!diskLinks.containsKey(pattern)) {
        findings.add({
          'kind': 'deep-link-missing',
          'path': pattern,
          'detail': 'deep-link pattern $pattern is no longer declared',
          'fix': 're-run `zfa route create $entity` to restore the pattern',
        });
      } else if (!_listEquals(diskLinks[pattern]!, params)) {
        findings.add({
          'kind': 'deep-link-params-drift',
          'path': pattern,
          'detail':
              'deep-link pattern $pattern params drifted: receipt says '
              '${params.join(', ')}, disk says '
              '${diskLinks[pattern]!.join(', ')}',
          'fix': 're-run `zfa route create $entity` to realign the pattern',
        });
      }
    }

    // 4. Run the generated route-table test headlessly. A missing runner
    //    (no Flutter SDK / no resolved package config) is an environment
    //    fact, not a table mismatch — the static verdict stands.
    Map<String, dynamic>? testRun;
    if (testPath != null && File(p.join(_projectRoot, testPath)).existsSync()) {
      final runner = _testRunnerOverride ?? _defaultTestRunner;
      try {
        final result = await runner(testPath, _projectRoot);
        testRun = {
          'status': result.exitCode == 0 ? 'pass' : 'failed',
          'exitCode': result.exitCode,
          'output': _bounded(result.output, 2000),
        };
        if (result.exitCode != 0) {
          findings.add({
            'kind': 'route-table-test-failed',
            'path': testPath,
            'detail':
                'the route-table test run failed (exit ${result.exitCode})',
            'fix':
                'run `dart test $testPath` (or `flutter test $testPath`) '
                'and fix the failing route-table assertions',
          });
        }
      } on ProcessException catch (e) {
        testRun = {'status': 'unavailable', 'reason': e.message};
      }
    }

    final ok = findings.isEmpty;

    // 5. Emit the verdict receipt (order 4): the #963 ledger and CI can
    //    read the LATEST verdict at the deterministic path.
    await _writeVerdictReceipt(
      entity: entity,
      ok: ok,
      declaredRoutes: declaredRoutes,
      declaredLinks: declaredLinks,
      testPath: testPath,
      testRun: testRun,
      findings: findings,
    );

    final envelope = <String, dynamic>{
      'schema': 1,
      'verdict': ok ? 'pass' : 'fail',
      'entity': entity,
      'routes': declaredRoutes,
      'resolvedRoutes': manifest.declaredRoutes
          .map((r) => r.path)
          .toList(growable: false),
      'deepLinks': declaredLinks,
      'routeTableTestPath': testPath,
      'testRun': testRun,
      'findings': findings,
    };

    final encoded = jsonEncode(envelope);
    if (outPath != null) {
      await File(outPath).writeAsString('$encoded\n');
    } else if (asJson) {
      print(encoded);
    } else {
      _printEntityVerdict(entity, ok, findings, testRun, plain: plain);
    }

    exitCode = ok ? 0 : 1;
  }

  /// Static mirror of the route-table test's first assertion: every
  /// `GoRoute(...)` in the routing tree carries a builder/pageBuilder/
  /// redirect. A route whose builder is missing is the exact mismatch
  /// issue #971's acceptance pins (exit 1 + `--> fix:`).
  List<Map<String, dynamic>> _goRouteBuilderFindings(String entity) {
    final findings = <Map<String, dynamic>>[];
    final routingDir = Directory(p.join(_projectRoot, 'lib', 'src', 'routing'));
    if (!routingDir.existsSync()) return findings;
    final files =
        routingDir
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => p.extension(f.path) == '.dart')
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final source = file.readAsStringSync();
      final goRoutePattern = RegExp(r'\bGoRoute\s*\(');
      for (final match in goRoutePattern.allMatches(source)) {
        final openParen = source.indexOf('(', match.start);
        final closeParen = _matchingParen(source, openParen);
        if (closeParen == null) continue;
        final invocation = source.substring(openParen + 1, closeParen);
        final pathExpression = _namedArgument(invocation, 'path');
        // Handler PRESENCE, not value extraction: a builder is a function
        // expression (`(context, state) {...}`), which the string/identifier
        // value grammar of [_namedArgument] deliberately does not match.
        final hasHandler = RegExp(
          r'\b(builder|pageBuilder|redirect)\s*:',
        ).hasMatch(invocation);
        if (hasHandler) continue;

        final line =
            '\n'.allMatches(source.substring(0, match.start)).length + 1;
        final routePath = pathExpression ?? '(unresolved path)';
        findings.add({
          'kind': 'route-builder-missing',
          'path': routePath,
          'file': p.relative(file.path, from: _projectRoot),
          'line': line,
          'detail':
              'route $routePath at '
              '${p.relative(file.path, from: _projectRoot)}:$line has no '
              'builder/pageBuilder/redirect',
          'fix':
              'restore the route\'s builder (or re-run `zfa route create '
              '$entity` to regenerate the module)',
        });
      }
    }
    return findings;
  }

  /// The production headless runner: `flutter test` for suites that
  /// import the Flutter SDK, `dart test` otherwise. Throws
  /// [ProcessException] when the required runner is not on PATH — the
  /// unavailable case, left to the static verdict.
  Future<({int exitCode, String output})> _defaultTestRunner(
    String testPath,
    String workingDirectory,
  ) async {
    final suite = File(p.join(workingDirectory, testPath));
    final importsFlutter =
        suite.existsSync() &&
        suite.readAsStringSync().contains("import 'package:flutter");

    if (importsFlutter) {
      try {
        final result = await Process.run('flutter', [
          'test',
          testPath,
        ], workingDirectory: workingDirectory);
        return (
          exitCode: result.exitCode,
          output: '${result.stdout}${result.stderr}',
        );
      } on ProcessException {
        // The suite needs the Flutter SDK but no `flutter` is on PATH.
        throw const ProcessException('flutter', [
          'test',
        ], 'no Flutter SDK on PATH for a flutter-importing route-table test');
      }
    }

    final result = await Process.run('dart', [
      'test',
      testPath,
    ], workingDirectory: workingDirectory);
    final output = '${result.stdout}${result.stderr}';
    if (result.exitCode != 0 &&
        output.contains('Could not find package config')) {
      // The project has not been resolved (`dart pub get` never ran) — an
      // environment fact, not a table mismatch.
      throw const ProcessException('dart', [
        'test',
      ], 'target project has no resolved package config — run dart pub get');
    }
    return (exitCode: result.exitCode, output: output);
  }

  Future<void> _writeVerdictReceipt({
    required String entity,
    required bool ok,
    required List<Map<String, dynamic>> declaredRoutes,
    required List<Map<String, dynamic>> declaredLinks,
    required String? testPath,
    required Map<String, dynamic>? testRun,
    required List<Map<String, dynamic>> findings,
  }) async {
    try {
      await ReceiptStore(projectRoot: _projectRoot).saveNamed(
        RouteReceiptWriter.receiptFileName('$entity-verify'),
        GenerationReceipt(
          command: 'zfa route verify',
          target: entity,
          repro: 'zfa route verify $entity',
          at: DateTime.now().toUtc(),
          generatorVersion: version,
          input: {
            'verdict': ok ? 'pass' : 'fail',
            'declaredRoutes': declaredRoutes.length,
            'deepLinks': declaredLinks.length,
            'findings': findings.length,
          },
          files: const [],
        ),
        extra: {
          'verdict': {
            'ok': ok,
            'routes': declaredRoutes,
            'deepLinks': declaredLinks,
            'routeTableTestPath': testPath,
            'testRun': testRun,
            'findings': findings,
          },
        },
      );
    } catch (_) {
      // Best-effort: the verdict is already on stdout; a receipt-write
      // failure must not flip the exit code.
    }
  }

  void _entityFail(
    String message, {
    required String fix,
    required String entity,
    required bool asJson,
    required String? outPath,
    required List<Map<String, dynamic>> findings,
    required List<Map<String, dynamic>> routes,
    required List<Map<String, dynamic>> deepLinks,
    required Map<String, dynamic>? testRun,
  }) {
    final envelope = <String, dynamic>{
      'schema': 1,
      'verdict': 'fail',
      'entity': entity,
      'routes': routes,
      'deepLinks': deepLinks,
      'routeTableTestPath': null,
      'testRun': testRun,
      'findings': [
        ...findings,
        {'kind': 'verify-error', 'detail': message, 'fix': fix},
      ],
    };
    if (outPath != null) {
      File(outPath).writeAsStringSync('${jsonEncode(envelope)}\n');
    } else if (asJson) {
      print(jsonEncode(envelope));
    } else {
      print('❌ $message');
      print('--> fix: $fix');
    }
    exitCode = 1;
  }

  void _printEntityVerdict(
    String entity,
    bool ok,
    List<Map<String, dynamic>> findings,
    Map<String, dynamic>? testRun, {
    required bool plain,
  }) {
    final mark = plain ? '' : (ok ? '✅ ' : '❌ ');
    final testRunSummary = testRun == null
        ? '(not run)'
        : switch (testRun['status'] as String? ?? '') {
            'pass' => 'pass',
            'failed' => 'FAILED (exit ${testRun['exitCode']})',
            'unavailable' =>
              'unavailable (${testRun['reason'] ?? 'no runner on PATH'})',
            _ => 'unknown',
          };
    print(
      '${mark}route verify: $entity — '
      '${ok ? 'healthy table' : '${findings.length} finding(s)'} '
      '(route-table test: $testRunSummary)',
    );
    for (final finding in findings) {
      final detail = finding['detail'] as String? ?? '';
      print('  - $detail');
      print('    --> fix: ${finding['fix']}');
    }
  }

  // ---------------------------------------------------------------------------
  // Drift mode (pre-existing semantics — bug route-dual-system-unreconciled)
  // ---------------------------------------------------------------------------

  Future<void> _runDriftVerify() async {
    final json = argResults?['json'] == true;
    final plain = argResults?['plain'] == true;
    final strict = argResults?['strict'] == true;
    final outPath = argResults?['out'] as String?;

    final table = _readRouteTable();
    final drifts = _detector.detect(table);

    if (json) {
      final payload = {
        'version': table.version,
        'routes': canonicalRouteEntries(
          table.routes,
        ).map((e) => e.toJson()).toList(),
        'drift': drifts
            .map(
              (d) => {
                'path': d.path,
                'sources': canonicalRouteEntries(
                  d.sources,
                ).map((s) => s.toJson()).toList(),
              },
            )
            .toList(),
      };
      final encoded = jsonEncode(payload);
      if (outPath != null) {
        await File(outPath).writeAsString('$encoded\n');
        stdout.writeln('Wrote $outPath');
      } else {
        stdout.writeln(encoded);
      }
    } else if (plain) {
      stdout.writeln('routes: ${table.routes.length}');
      stdout.writeln('drift: ${drifts.length}');
      stdout.write(
        _renderDrifts(drifts, driftPrefix: 'DRIFT', sourceIndent: '  '),
      );
    } else {
      stdout.writeln('routes: ${table.routes.length}');
      stdout.writeln('drift: ${drifts.length}');
      stdout.write(
        _renderDrifts(drifts, driftPrefix: '⚠️  DRIFT', sourceIndent: '    '),
      );
    }

    if (drifts.isNotEmpty && strict) {
      exitCode = 1;
    }
  }

  /// Render drift findings to a string. [driftPrefix] is prepended to
  /// each drift path; [sourceIndent] precedes each source line.
  /// The plain path uses `DRIFT` (no emoji) + 2-space indent; the
  /// default path uses `⚠️  DRIFT` + 4-space indent.
  String _renderDrifts(
    List<RouteDrift> drifts, {
    String driftPrefix = '⚠️  DRIFT',
    String sourceIndent = '    ',
  }) {
    final buf = StringBuffer();
    for (final d in drifts) {
      buf.writeln('$driftPrefix ${d.path}');
      for (final s in d.sources) {
        buf.writeln(
          '$sourceIndent${s.source.name}: ${s.file}:${s.line} (${s.name})',
        );
      }
    }
    return buf.toString();
  }

  /// Reads CLI `*_routes.dart` modules and the DDA `zfa_router.g.dart`.
  RouteTable _readRouteTable() {
    final libDirectory = Directory(p.join(_projectRoot, 'lib'));
    if (!libDirectory.existsSync()) {
      return const RouteTable(version: 1, routes: []);
    }

    final files =
        libDirectory
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => p.extension(file.path) == '.dart')
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    final cli = <RouteEntry>[];
    final dda = <RouteEntry>[];
    for (final file in files) {
      final fileName = p.basename(file.path);
      if (fileName == 'zfa_router.g.dart') {
        dda.addAll(_parseRoutes(file, RouteSource.dda));
      } else if (fileName.endsWith('_routes.dart') &&
          fileName != 'app_routes.dart') {
        cli.addAll(_parseRoutes(file, RouteSource.cli));
      }
    }
    return RouteTable.fromSources(cli: cli, dda: dda);
  }

  List<RouteEntry> _parseRoutes(File file, RouteSource routeSource) {
    final source = file.readAsStringSync();
    final constants = _routeConstants(source);
    final entries = <RouteEntry>[];
    final goRoutePattern = RegExp(r'\bGoRoute\s*\(');

    for (final match in goRoutePattern.allMatches(source)) {
      final openParen = source.indexOf('(', match.start);
      final closeParen = _matchingParen(source, openParen);
      if (closeParen == null) continue;
      final invocation = source.substring(openParen + 1, closeParen);
      final pathExpression = _namedArgument(invocation, 'path');
      final nameExpression = _namedArgument(invocation, 'name');
      final routePath = _resolveValue(pathExpression, constants);
      final routeName = _resolveValue(nameExpression, constants);
      if (routePath == null || routeName == null) continue;

      entries.add(
        RouteEntry(
          path: routePath,
          name: routeName,
          source: routeSource,
          file: p.relative(file.path, from: _projectRoot),
          line: '\n'.allMatches(source.substring(0, match.start)).length + 1,
        ),
      );
    }
    return entries;
  }

  Map<String, String> _routeConstants(String source) {
    final constants = <String, String>{};
    final pattern = RegExp(
      r'''static\s+const\s+String\s+([A-Za-z_]\w*)\s*=\s*((?:r)?'(?:\\.|[^'\\])*'|(?:r)?"(?:\\.|[^"\\])*")\s*;''',
    );
    for (final match in pattern.allMatches(source)) {
      final value = _stringLiteralValue(match.group(2)!);
      if (value != null) constants[match.group(1)!] = value;
    }
    return constants;
  }

  String? _namedArgument(String invocation, String name) {
    final pattern = RegExp(
      '\\b$name\\s*:\\s*'
      r'''((?:r)?'(?:\\.|[^'\\])*'|(?:r)?"(?:\\.|[^"\\])*"|[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*)''',
    );
    return pattern.firstMatch(invocation)?.group(1);
  }

  String? _resolveValue(String? expression, Map<String, String> constants) {
    if (expression == null) return null;
    return _stringLiteralValue(expression) ??
        constants[expression.split('.').last];
  }

  String? _stringLiteralValue(String expression) {
    var literal = expression;
    final raw = literal.startsWith('r');
    if (raw) literal = literal.substring(1);
    if (literal.length < 2) return null;
    final quote = literal[0];
    if ((quote != "'" && quote != '"') ||
        literal[literal.length - 1] != quote) {
      return null;
    }
    final value = literal.substring(1, literal.length - 1);
    if (raw) return value;
    return value.replaceAll('\\$quote', quote).replaceAll(r'\\', r'\');
  }

  int? _matchingParen(String source, int openParen) {
    var depth = 0;
    String? quote;
    var escaped = false;
    for (var index = openParen; index < source.length; index++) {
      final character = source[index];
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (character == r'\') {
          escaped = true;
        } else if (character == quote) {
          quote = null;
        }
        continue;
      }
      if (character == "'" || character == '"') {
        quote = character;
      } else if (character == '(') {
        depth++;
      } else if (character == ')' && --depth == 0) {
        return index;
      }
    }
    return null;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static String _bounded(String text, int limit) {
    if (text.length <= limit) return text;
    return '${text.substring(0, limit)}…';
  }
}
