import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/provider_verify_command.dart';

/// Spec 979, orders 2 + 4 — the provider verify gate (`zfa provider verify
/// <Entity>`), tested both ways:
///
///   * stub gate positive  — a provider whose methods still throw
///     `UnimplementedError` fails verification (exit 1) with a `--> fix:`
///     line naming the FILE and the METHOD;
///   * stub gate negative  — filled bodies pass (exit 0);
///   * conformance positive — a provider missing a method declared by its
///     target Service interface fails (exit 1) with a `--> fix:` line
///     naming the missing method (the provider analog of the #921 guard);
///   * conformance negative — a full mirror of the interface passes.
///
/// Fast tier: in-process command invocation against a temp project
/// (no subprocesses).
void main() {
  late Directory project;
  late String outputDir;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('zfa_provider_verify_');
    outputDir = p.join(project.path, 'lib', 'src');
  });

  tearDown(() async {
    if (project.existsSync()) {
      await project.delete(recursive: true);
    }
  });

  /// Writes a `ProductService` interface declaring [methods].
  void writeService(List<String> methods) {
    final dir = p.join(outputDir, 'domain', 'services');
    Directory(dir).createSync(recursive: true);
    final members = methods
        .map((m) => '  Future<void> $m(NoParams params);')
        .join('\n');
    File(p.join(dir, 'product_service.dart')).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

abstract class ProductService {
$members
}
''');
  }

  /// Writes a `ProductProvider` implementing [methods] with
  /// [stubbed] bodies (UnimplementedError, the generated skeleton shape)
  /// or filled bodies otherwise.
  void writeProvider(List<String> methods, {required bool stubbed}) {
    final dir = p.join(outputDir, 'data', 'providers');
    Directory(dir).createSync(recursive: true);
    final members = methods
        .map(
          (m) => stubbed
              ? '''
  @override
  Future<void> $m(NoParams params) {
    final error = UnimplementedError('$m not implemented');
    final stack = StackTrace.current;
    logAndHandleError(error, stack);
    throw error;
  }
'''
              : '''
  @override
  Future<void> $m(NoParams params) async {}
''',
        )
        .join('\n');
    File(p.join(dir, 'product_provider.dart')).writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';
import '../../domain/services/product_service.dart';

class ProductProvider with Loggable, FailureHandler implements ProductService {
$members
}
''');
  }

  /// Runs `zfa provider verify <entity>` in-process, capturing stdout and
  /// the process exit code (hermetic: exitCode is reset around the run).
  Future<({int code, String output})> runVerify(
    String entity, {
    List<String> extra = const [],
  }) async {
    final command = ProviderVerifyCommand(projectRoot: project.path);
    final runner = CommandRunner<void>('zfa', 'test')..addCommand(command);
    final lines = <String>[];
    exitCode = 0;
    await runZoned(
      () => runner.run(['verify', entity, ...extra]),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, String line) => lines.add(line),
      ),
    );
    final code = exitCode;
    exitCode = 0; // hermetic: never leak a failure code into the suite
    return (code: code, output: lines.join('\n'));
  }

  group('zfa provider verify — stub-escape gate (order 2)', () {
    test('positive: surviving UnimplementedError bodies fail with exit 1 '
        '+ --> fix: naming file and method', () async {
      writeService(['execute']);
      writeProvider(['execute'], stubbed: true);

      final result = await runVerify('Product');

      expect(result.code, equals(1), reason: 'a surviving stub must fail');
      expect(
        result.output,
        contains('UnimplementedError'),
        reason: 'the verdict must name the stub kind',
      );
      expect(
        result.output,
        contains('product_provider.dart'),
        reason: 'the finding must name the provider file',
      );
      expect(
        result.output,
        contains('execute'),
        reason: 'the finding must name the stubbed method',
      );
      expect(
        result.output,
        contains('--> fix:'),
        reason: 'the finding must carry an actionable fix line',
      );
    });

    test('negative: filled bodies pass with exit 0', () async {
      writeService(['execute']);
      writeProvider(['execute'], stubbed: false);

      final result = await runVerify('Product');

      expect(result.code, equals(0), reason: 'no stubs, no missing methods');
      expect(result.output, contains('findings : 0'));
    });
  });

  group('zfa provider verify — conformance gate (order 4)', () {
    test('positive: provider missing an interface method fails with exit 1 '
        '+ --> fix: naming the method', () async {
      writeService(['execute', 'rollback']);
      // The provider implements only one of the two interface methods.
      writeProvider(['execute'], stubbed: false);

      final result = await runVerify('Product');

      expect(
        result.code,
        equals(1),
        reason: 'a missing interface method must fail (#921 analog)',
      );
      expect(
        result.output,
        contains('rollback'),
        reason: 'the finding must name the missing method',
      );
      expect(result.output, contains('--> fix:'));
    });

    test('negative: full mirror of the interface passes with exit 0', () async {
      writeService(['execute', 'rollback']);
      writeProvider(['execute', 'rollback'], stubbed: false);

      final result = await runVerify('Product');

      expect(result.code, equals(0));
    });

    test('missing provider file fails with exit 1 + fix naming the create '
        'command', () async {
      writeService(['execute']);

      final result = await runVerify('Product');

      expect(result.code, equals(1));
      expect(result.output, contains('--> fix:'));
      expect(result.output, contains('provider create'));
    });

    test(
      '--json emits a single machine verdict object with schema/ok/findings',
      () async {
        writeService(['execute']);
        writeProvider(['execute'], stubbed: true);

        final result = await runVerify('Product', extra: ['--json']);

        expect(result.code, equals(1));
        // Exactly one JSON object on stdout (#778 single-object convention).
        final jsonLine = result.output
            .split('\n')
            .firstWhere((l) => l.trim().startsWith('{'), orElse: () => '');
        expect(jsonLine, isNot(''), reason: 'a JSON verdict must be printed');
        final verdict = jsonDecodeMap(jsonLine);
        expect(verdict['schema'], equals(1));
        expect(verdict['ok'], isFalse);
        expect(verdict['entity'], equals('Product'));
        final findings = verdict['findings'] as List;
        expect(findings, isNotEmpty);
        final first = findings.first as Map<String, dynamic>;
        expect(first['kind'], equals('stub'));
        expect(first['method'], equals('execute'));
        expect(first['fix'], contains('--> fix:'));
      },
    );
  });
}

/// Parses a JSON object line defensively.
Map<String, dynamic> jsonDecodeMap(String line) {
  final decoded = jsonDecode(line);
  if (decoded is Map<String, dynamic>) return decoded;
  return <String, dynamic>{};
}
