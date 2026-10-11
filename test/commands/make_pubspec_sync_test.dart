/// SDD-TDD suite for issue #1190 — `zfa make` heals the generated-imports ↔
/// pubspec gap on completion when the generated code imports packages the
/// target's pubspec doesn't declare.
///
/// Issue #1265 supersedes the warn-only contract: the completion post-pass
/// now AUTO-ADDS the hosted gap via one mechanical `pub add` (the same fix
/// the doctor `--fix` path runs), and the `⚠️ doesn't declare … --> fix:`
/// diagnostic remains only for what the add could not heal. The `pub add`
/// process is intercepted by an injectable runner so the pins stay
/// hermetic — no network, no real dependency resolution.
///
/// Drives the real make pipeline in-process (CliRunner.runCapturing, `-C`
/// temp fixture, exactly like make_command_test.dart) so the pin covers the
/// observable completion contract, not an internal helper.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

/// Records the spawned `pub add` and simulates its effect on the fixture
/// pubspec (dependency inserted under `dependencies:`) — hermetic.
class _RecordingAddRunner {
  final List<String> invocations = [];
  final Directory workspace;
  final int exitCode;
  _RecordingAddRunner(this.workspace, {this.exitCode = 0});

  Future<ProcessResult> call(
    String executable,
    List<String> args,
    String workingDirectory,
  ) async {
    invocations.add('$executable ${args.join(' ')}');
    if (exitCode == 0 &&
        args.length >= 3 &&
        args[0] == 'pub' &&
        args[1] == 'add') {
      final pubspec = File('${workspace.path}/pubspec.yaml');
      final content = pubspec.readAsStringSync();
      final buf = StringBuffer();
      for (final pkg in args.skip(2)) {
        buf.writeln('  $pkg: ^1.0.0');
      }
      pubspec.writeAsStringSync(
        content.contains('dependencies:\n')
            ? content.replaceFirst('dependencies:\n', 'dependencies:\n$buf')
            : '${content}dependencies:\n$buf',
      );
    }
    return ProcessResult(exitCode, exitCode, '', '');
  }
}

void main() {
  late Directory workspace;
  late String outputDir;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_make_pubsync_');
    outputDir = path.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_make_pubsync_test
environment:
  sdk: ^3.11.0
''');
    final entityDir = Directory(
      path.join(outputDir, 'domain', 'entities', 'product'),
    );
    await entityDir.create(recursive: true);
    await File(path.join(entityDir.path, 'product.dart')).writeAsString('''
class Product {
  final String id;

  const Product({required this.id});
}
''');
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      try {
        await workspace.delete(recursive: true);
      } on PathNotFoundException {
        // Workspace already gone — nothing left to clean up.
      }
    }
  });

  List<String> args({String format = 'text', bool withVpc = true}) => [
    '-C',
    workspace.path,
    'make',
    'Product',
    '--preset=crud',
    '--methods=get,getList,create,update,delete',
    if (withVpc) '--with=vpc',
    '--state',
    '--di',
    '--test',
    '--output',
    outputDir,
    if (format != 'text') ...['--format', format],
  ];

  group('make completion pubspec-dep suggestion (issue #1190)', () {
    test(
      'U-1190-M1: generated imports missing from pubspec are auto-added',
      () async {
        final addRunner = _RecordingAddRunner(workspace);
        final output = await CliRunner(
          exitOnCompletion: false,
          makeProcessRunner: addRunner.call,
        ).runCapturing(args());

        expect(output, contains('✅ Generation complete'));
        // Issue #1265: the generated code imports package:test (and
        // others) — the run DECLARES the hosted gap with one mechanical
        // `pub add` (pure-Dart fixture → dart). Issue #1530: the CORE
        // package is ENSURED textually before the add, so the add line
        // no longer carries `zuraffa`.
        expect(output, contains('Auto-added'));
        expect(output, contains('Ensured zuraffa'));
        expect(addRunner.invocations, hasLength(1));
        expect(addRunner.invocations.single, startsWith('dart pub add '));
        expect(
          addRunner.invocations.single.split(' '),
          isNot(contains('zuraffa')),
          reason: '#1530: the ensured core package is not re-`pub add`ed',
        );
        // The pubspec now declares what the generated code imports —
        // the core package via the textual ensure, the rest via pub add.
        final pubspec = File(
          path.join(workspace.path, 'pubspec.yaml'),
        ).readAsStringSync();
        expect(pubspec, contains('zuraffa: ^6.0.0'));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'U-1190-M2: when every imported package is declared, no suggestion',
      () async {
        await File(path.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_make_pubsync_test
environment:
  sdk: ^3.11.0
dependencies:
  zuraffa: ^6.0.0
dev_dependencies:
  test: any
''');
        // No --with=vpc: views are Flutter widgets (issue #420) and would
        // legitimately flag the undeclared `flutter` SDK import; this pin
        // covers the all-declared case, so keep the surface pure Dart.
        final addRunner = _RecordingAddRunner(workspace);
        final output = await CliRunner(
          exitOnCompletion: false,
          makeProcessRunner: addRunner.call,
        ).runCapturing(args(withVpc: false));

        expect(output, contains('✅ Generation complete'));
        expect(output, isNot(contains("pubspec.yaml doesn't declare")));
        // Nothing to declare → no pub add ever spawned (issue #1265).
        expect(addRunner.invocations, isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'U-1190-M3: json mode carries the healed gap inside the JSON object',
      () async {
        final addRunner = _RecordingAddRunner(workspace);
        final output = await CliRunner(
          exitOnCompletion: false,
          makeProcessRunner: addRunner.call,
        ).runCapturing(args(format: 'json'));

        final jsonStart = output.indexOf('{');
        expect(jsonStart, isNonNegative, reason: 'no JSON in output: $output');
        final decoded = jsonDecodeLoose(output.substring(jsonStart));
        expect(decoded['success'], isTrue);
        // Issue #1265: the run declared the gap itself — reported as
        // auto-added, NOT as missing (nothing left for the user to fix).
        // Issue #1530: the ensured core package counts as auto-declared
        // too ("packages the run declared in pubspec.yaml itself").
        expect(
          (decoded['auto_added_pubspec_deps'] as List).cast<String>(),
          containsAll(['zuraffa', 'test']),
        );
        expect(decoded['missing_pubspec_deps'], isNull);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'U-1190-M4: failed auto-add (offline) keeps the gap + fix in json',
      () async {
        final addRunner = _RecordingAddRunner(workspace, exitCode: 1);
        final output = await CliRunner(
          exitOnCompletion: false,
          makeProcessRunner: addRunner.call,
        ).runCapturing(args(format: 'json'));

        final jsonStart = output.indexOf('{');
        final decoded = jsonDecodeLoose(output.substring(jsonStart));
        expect(decoded['success'], isTrue);
        final gap = decoded['missing_pubspec_deps'] as Map<String, dynamic>?;
        expect(gap, isNotNull, reason: 'unhealed gap must be reported in json');
        // Issue #1530: the failed add's REMAINING gap is the non-core
        // package — the core `zuraffa` was ensured textually and rides
        // auto_added_pubspec_deps instead.
        final packages = (gap!['packages'] as List).cast<String>();
        expect(packages, contains('test'));
        expect(
          packages,
          isNot(contains('zuraffa')),
          reason: 'the ensured core package is declared even offline',
        );
        expect(
          (decoded['auto_added_pubspec_deps'] as List).cast<String>(),
          contains('zuraffa'),
        );
        final fix = gap['suggested_fix'] as String?;
        expect(fix, isNotNull);
        expect(fix, contains('pub add'));
        expect(fix, contains('test'));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

/// The make JSON object is printed with `print(jsonEncode(...))` and is the
/// ONLY `{`-starting line in json mode; pull the first balanced object out
/// of the captured output (the JSON may be preceded by non-JSON lines).
Map<String, dynamic> jsonDecodeLoose(String raw) {
  final start = raw.indexOf('{');
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < raw.length; i++) {
    final ch = raw[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (ch == r'\') {
        escaped = true;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        return jsonDecode(raw.substring(start, i + 1)) as Map<String, dynamic>;
      }
    }
  }
  throw StateError('no balanced JSON object found');
}
