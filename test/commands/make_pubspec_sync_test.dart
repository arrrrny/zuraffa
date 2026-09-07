/// SDD-TDD suite for issue #1190 — `zfa make` prints the exact `pub add`
/// one-liner on completion when the generated code imports packages the
/// target's pubspec doesn't declare.
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

  /// The single `--> fix:` suggestion line the post-pass prints.
  String fixLineIn(String output) => output
      .split('\n')
      .firstWhere((l) => l.contains('--> fix:'), orElse: () => '');

  group('make completion pubspec-dep suggestion (issue #1190)', () {
    test(
      'U-1190-M1: generated imports missing from pubspec print the one-liner',
      () async {
        final output = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(args());

        expect(output, contains('✅ Generation complete'));
        // The generated code imports package:zuraffa (framework) — the
        // fixture pubspec declares NOTHING, so the run must surface the
        // gap with the exact healing command on a single fix line.
        expect(output, contains("pubspec.yaml doesn't declare"));
        final fixLine = fixLineIn(output);
        expect(fixLine, contains('dart pub add'));
        expect(fixLine, contains('zuraffa'));
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
        final output = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(args(withVpc: false));

        expect(output, contains('✅ Generation complete'));
        expect(output, isNot(contains("pubspec.yaml doesn't declare")));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'U-1190-M3: json mode carries the gap inside the single JSON object',
      () async {
        final output = await CliRunner(
          exitOnCompletion: false,
        ).runCapturing(args(format: 'json'));

        final jsonStart = output.indexOf('{');
        expect(jsonStart, isNonNegative, reason: 'no JSON in output: $output');
        final decoded = jsonDecodeLoose(output.substring(jsonStart));
        expect(decoded['success'], isTrue);
        final gap = decoded['missing_pubspec_deps'] as Map<String, dynamic>?;
        expect(gap, isNotNull, reason: 'gap must be reported in json mode');
        expect((gap!['packages'] as List).cast<String>(), contains('zuraffa'));
        final fix = gap['suggested_fix'] as String?;
        expect(fix, isNotNull);
        expect(fix, contains('pub add'));
        expect(fix, contains('zuraffa'));
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
