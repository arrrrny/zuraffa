import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/di_verify_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/di/capabilities/verify_capability.dart';
import 'package:zuraffa/src/plugins/tdd/models/verdict_envelope.dart';

/// SPEC 0974 (issue #974, order 2): `zfa di verify` resolves every
/// `getIt<T>()` / `getIt.registerXxx<T>()` call in generated registrations
/// against classes on disk; a dangling binding fails the verdict (exit 1 at
/// the CLI) and names the class plus the expected file with a `--> fix:`
/// hint — the exact failure #284/#410 fixed by hand, made a gate.
void main() {
  late Directory tempDir;
  late String projectRoot;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_di_verify_');
    projectRoot = tempDir.path;
    outputDir = '$projectRoot/lib/src';
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  DiPlugin buildPlugin() =>
      DiPlugin(outputDir: outputDir, options: const GeneratorOptions());

  DiVerifyCapability buildCapability() =>
      DiVerifyCapability(buildPlugin(), projectRoot: projectRoot);

  void writeSource(String relative, String content) {
    final file = File(p.join(projectRoot, relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  test('A2 positive: clean registrations verify green', () async {
    // Real class on disk, real import, real registration — the gate must
    // pass and report what it checked.
    writeSource(
      'lib/src/domain/usecases/general/get_product_usecase.dart',
      'class GetProductUseCase {\n'
          '  final ProductRepository repository;\n'
          '  GetProductUseCase(this.repository);\n'
          '}\n',
    );
    writeSource(
      'lib/src/data/repositories/product_repository.dart',
      'abstract class ProductRepository {}\n',
    );
    writeSource(
      'lib/src/di/usecases/get_product_usecase_di.dart',
      "import 'package:get_it/get_it.dart';\n"
          "import '../../domain/usecases/general/get_product_usecase.dart';\n"
          "import '../../data/repositories/product_repository.dart';\n"
          '\n'
          'void registerGetProductUseCase(GetIt getIt) {\n'
          '  getIt.registerFactory<GetProductUseCase>(\n'
          '    () => GetProductUseCase(getIt<ProductRepository>()),\n'
          '  );\n'
          '}\n',
    );

    final result = await buildCapability().execute({});

    expect(result.success, isTrue, reason: 'clean tree must verify green');
    expect(result.files, contains(endsWith('get_product_usecase_di.dart')));
    expect(result.data?['bindings_checked'], greaterThanOrEqualTo(2));
  });

  test(
    'A2 negative: dangling getIt<Missing>() registration fails with fix hint',
    () async {
      // The registration below binds two classes that exist NOWHERE on
      // disk — the #284/#410 failure mode. The verdict must fail and name
      // each class with a `--> fix:` pointing at the expected file.
      writeSource(
        'lib/src/di/usecases/missing_usecase_di.dart',
        "import 'package:get_it/get_it.dart';\n"
            '\n'
            'void registerMissingUseCase(GetIt getIt) {\n'
            '  getIt.registerFactory<MissingUseCase>(\n'
            '    () => MissingUseCase(getIt<MissingRepository>()),\n'
            '  );\n'
            '}\n',
      );

      final result = await buildCapability().execute({});

      expect(
        result.success,
        isFalse,
        reason: 'a dangling binding must fail the verify gate',
      );
      expect(result.message, isNotNull);
      expect(result.message, contains('MissingUseCase'));
      expect(result.message, contains('MissingRepository'));
      expect(result.message, contains('--> fix:'));
      expect(result.message, contains('missing_usecase.dart'));
      expect(result.data?['findings'], isA<List<dynamic>>());
      expect((result.data?['findings'] as List).length, 2);
    },
  );

  test('U2: a missing di/ tree verifies green (nothing to check)', () async {
    final result = await buildCapability().execute({});
    expect(result.success, isTrue);
  });

  test('U3: a dead import URI in a DI file is reported as a finding', () async {
    // #410's uri_does_not_exist mode: the registration's import points at
    // a file that is not on disk, even though the class name would be
    // conventional.
    writeSource(
      'lib/src/di/repositories/order_repository_di.dart',
      "import 'package:get_it/get_it.dart';\n"
          "import '../../data/repositories/order_repository.dart';\n"
          '\n'
          'void registerOrderRepository(GetIt getIt) {\n'
          '  getIt.registerLazySingleton<OrderRepository>(\n'
          '    () => DataOrderRepository(),\n'
          '  );\n'
          '}\n',
    );

    final result = await buildCapability().execute({});

    expect(result.success, isFalse);
    expect(result.message, contains('order_repository.dart'));
    expect(result.message, contains('--> fix:'));
  });

  test('A2 wiring: the verify capability is registered as a di subcommand', () {
    final names = buildPlugin().capabilities.map((c) => c.name).toList();
    expect(names, contains('verify'));
  });

  group('SPEC 1106 — zfa di verify --json canonical envelope', () {
    Future<String> captureOutput(Future<void> Function() body) async {
      final output = <String>[];
      await runZoned(
        body,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            output.add(line);
          },
        ),
      );
      return output.join('\n');
    }

    CommandRunner<void> runner() {
      final command = DiVerifyCommand(buildPlugin(), projectRoot: projectRoot);
      return CommandRunner<void>('zfa', 'test')..addCommand(command);
    }

    Map<String, Object?> decodeEnvelope(String out) {
      final lines = out.trimRight().split('\n');
      final last = lines.isEmpty ? '' : lines.last;
      final decoded = jsonDecode(last);
      expect(
        decoded,
        isA<Map<String, Object?>>(),
        reason: 'the FINAL stdout line must be a single JSON object: $last',
      );
      return decoded as Map<String, Object?>;
    }

    /// The exact top-level key set SPEC 1106 orders for the di envelope
    /// (plus the treaty-mandated `timestamp`).
    const envelopeKeys = {
      'schema',
      'command',
      'verdict',
      'exit_class',
      'subject',
      'findings',
      'drifts',
      'details',
      'timestamp',
    };

    test('clean tree: pass envelope with exact schema', () async {
      writeSource(
        'lib/src/domain/usecases/general/get_product_usecase.dart',
        'class GetProductUseCase {}\n',
      );
      writeSource(
        'lib/src/di/usecases/get_product_usecase_di.dart',
        "import 'package:get_it/get_it.dart';\n"
            "import '../../domain/usecases/general/get_product_usecase.dart';\n"
            '\n'
            'void registerGetProductUseCase(GetIt getIt) {\n'
            '  getIt.registerFactory<GetProductUseCase>(() => getIt<GetProductUseCase>());\n'
            '}\n',
      );

      final output = await captureOutput(
        () => runner().run(['verify', '--json']),
      );

      expect(exitCode, 0);
      final envelope = decodeEnvelope(output);
      expect(envelope.keys.toSet(), envelopeKeys);
      expect(envelope['schema'], VerdictEnvelope.schema);
      expect(envelope['schema'], 'verdict.v1');
      expect(envelope['command'], 'di verify');
      expect(envelope['verdict'], 'pass');
      expect(envelope['exit_class'], 'ok');
      expect((envelope['subject'] as Map)['kind'], 'di');
      expect(envelope['findings'], isEmpty);
      expect(envelope['drifts'], isEmpty);
      final details = envelope['details'] as Map;
      expect(details['danglingClasses'], isEmpty);
      expect(details['deadImports'], isEmpty);
      expect(envelope['timestamp'], isA<String>());
    });

    test(
      'dangling binding: fail envelope names class in findings/details',
      () async {
        writeSource(
          'lib/src/di/usecases/missing_usecase_di.dart',
          "import 'package:get_it/get_it.dart';\n"
              '\n'
              'void registerMissingUseCase(GetIt getIt) {\n'
              '  getIt.registerFactory<MissingUseCase>(\n'
              '    () => MissingUseCase(getIt<MissingRepository>()),\n'
              '  );\n'
              '}\n',
        );

        final output = await captureOutput(
          () => runner().run(['verify', '--json']),
        );

        expect(exitCode, 1);
        final envelope = decodeEnvelope(output);
        expect(envelope.keys.toSet(), envelopeKeys);
        expect(envelope['schema'], 'verdict.v1');
        expect(envelope['command'], 'di verify');
        expect(envelope['verdict'], 'fail');
        expect(envelope['exit_class'], 'fail');
        expect((envelope['subject'] as Map)['kind'], 'di');

        final findings = envelope['findings'] as List;
        expect(findings, hasLength(2));
        for (final finding in findings) {
          expect((finding as Map).keys.toSet(), {
            'kind',
            'file',
            'member',
            'fix',
          });
          expect(finding['kind'], 'dangling binding');
          expect(finding['file'], contains('missing_usecase_di.dart'));
          expect(finding['fix'], isNotEmpty);
        }
        final members = findings.map((f) => (f as Map)['member']).toSet();
        expect(
          members,
          containsAll(<String>['MissingUseCase', 'MissingRepository']),
        );

        final details = envelope['details'] as Map;
        expect(
          (details['danglingClasses'] as List).toSet(),
          containsAll(<String>['MissingUseCase', 'MissingRepository']),
        );
        expect(details['deadImports'], isEmpty);
        expect((envelope['drifts'] as List), isNotEmpty);
      },
    );

    test('dead import: fail envelope reports deadImports detail', () async {
      writeSource(
        'lib/src/di/repositories/order_repository_di.dart',
        "import 'package:get_it/get_it.dart';\n"
            "import '../../data/repositories/order_repository.dart';\n"
            '\n'
            'void registerOrderRepository(GetIt getIt) {\n'
            '  getIt.registerLazySingleton<OrderRepository>(\n'
            '    () => DataOrderRepository(),\n'
            '  );\n'
            '}\n',
      );

      final output = await captureOutput(
        () => runner().run(['verify', '--json']),
      );

      expect(exitCode, 1);
      final envelope = decodeEnvelope(output);
      expect(envelope['verdict'], 'fail');
      // The dead import makes the class unresolvable too, so the gate
      // reports BOTH drift classes for this fixture.
      final findings = envelope['findings'] as List;
      expect(
        findings.map((f) => (f as Map)['kind']),
        containsAll(<String>['dangling import', 'dangling binding']),
      );
      final details = envelope['details'] as Map;
      expect(
        (details['deadImports'] as List).first,
        contains('order_repository.dart'),
      );
      expect((details['danglingClasses'] as List).first, 'OrderRepository');
    });

    test('missing di/ tree: pass envelope (nothing to verify)', () async {
      final output = await captureOutput(
        () => runner().run(['verify', '--json']),
      );

      expect(exitCode, 0);
      final envelope = decodeEnvelope(output);
      expect(envelope['verdict'], 'pass');
      expect(envelope['exit_class'], 'ok');
      expect(envelope['findings'], isEmpty);
    });

    test(
      'without --json the prose path is unchanged and no envelope appears',
      () async {
        writeSource(
          'lib/src/di/usecases/missing_usecase_di.dart',
          "import 'package:get_it/get_it.dart';\n"
              '\n'
              'void registerMissingUseCase(GetIt getIt) {\n'
              '  getIt.registerFactory<MissingUseCase>(\n'
              '    () => MissingUseCase(getIt<MissingRepository>()),\n'
              '  );\n'
              '}\n',
        );

        final output = await captureOutput(() => runner().run(['verify']));

        expect(exitCode, 1);
        expect(output, contains('--> fix:'));
        expect(output, isNot(contains('"schema":"verdict.v1"')));
      },
    );
  });
}
