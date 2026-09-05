import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/di/capabilities/verify_capability.dart';
import 'package:zuraffa/src/commands/di_verify_command.dart';
import 'package:zuraffa/src/commands/modular_di_command.dart';

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

  // ---------------------------------------------------------------------------
  // Issue #1108 — `zfa di verify --json`: the canonical zuraffa.verdict.v1
  // envelope. Sibling verify gates (cache verify, provider verify, route
  // verify) all ship --json; di verify was the last big-gap unjsoned verify
  // command. The envelope is the single stdout line in --json mode; the text
  // mode (no --json) keeps the #974 verdict prose byte-for-byte.
  // ---------------------------------------------------------------------------

  /// Runs `zfa di verify [args]` in-process through the real command
  /// object (the same class ModularDiCommand registers — see the wiring
  /// test below), capturing stdout and the process exit code (hermetic:
  /// exitCode is reset around the run). projectRoot is injected so the
  /// gate resolves the temp fixture, never the test process's CWD.
  Future<({int code, List<String> lines})> runDiVerify(
    List<String> args,
  ) async {
    final runner = CommandRunner<void>('zfa', 'test')
      ..addCommand(DiVerifyCommand(buildPlugin(), projectRoot: projectRoot));
    final lines = <String>[];
    exitCode = 0;
    await runZoned(
      () => runner.run(['verify', ...args]),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, String line) => lines.add(line),
      ),
    );
    final code = exitCode;
    exitCode = 0; // hermetic: never leak a failure code into the suite
    return (code: code, lines: lines);
  }

  /// The clean #974 A2 fixture: real classes on disk, real registration.
  void writeCleanFixture() {
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
  }

  /// The #284/#410 dangling fixture: two classes exist NOWHERE on disk.
  void writeDanglingFixture() {
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
  }

  group('#1108 di verify --json (zuraffa.verdict.v1)', () {
    test('positive: --json emits exactly one envelope line with the exact '
        'canonical schema', () async {
      writeCleanFixture();

      final result = await runDiVerify(['Product', '--json']);

      expect(result.code, 0, reason: 'a clean tree must verify green');
      expect(
        result.lines,
        hasLength(1),
        reason: '--json mode emits a single parseable line (no prose)',
      );
      final envelope = jsonDecode(result.lines.single) as Map<String, dynamic>;
      expect(
        envelope.keys,
        unorderedEquals([
          'schema',
          'command',
          'verdict',
          'exit_class',
          'subject',
          'findings',
          'drifts',
          'details',
        ]),
        reason: 'the envelope is the canonical #1104 shape — no ad-hoc keys',
      );
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      expect(envelope['command'], 'di verify');
      expect(envelope['verdict'], 'pass');
      expect(envelope['exit_class'], 'ok');
      expect(envelope['subject'], {'kind': 'di', 'entity': 'Product'});
      expect(envelope['findings'], isEmpty);
      expect(envelope['drifts'], isEmpty);
      expect(envelope['details'], {
        'danglingClasses': <String>[],
        'deadImports': <String>[],
      });
    });

    test('negative: --json envelopes the dangling findings with '
        'kind/file/member/fix', () async {
      writeDanglingFixture();

      final result = await runDiVerify(['Product', '--json']);

      expect(result.code, 1, reason: 'a dangling binding must fail the gate');
      expect(result.lines, hasLength(1));
      final envelope = jsonDecode(result.lines.single) as Map<String, dynamic>;
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      expect(envelope['command'], 'di verify');
      expect(envelope['verdict'], 'fail');
      expect(envelope['exit_class'], 'fail');
      expect(envelope['subject'], {'kind': 'di', 'entity': 'Product'});
      expect(envelope['drifts'], isEmpty);

      final findings = envelope['findings'] as List<dynamic>;
      expect(findings, hasLength(2));
      for (final finding in findings) {
        expect(
          (finding as Map<String, dynamic>).keys,
          unorderedEquals(['kind', 'file', 'member', 'fix']),
        );
        expect(finding['kind'], 'dangling binding');
        expect(finding['file'], 'lib/src/di/usecases/missing_usecase_di.dart');
        expect(
          finding['fix'],
          isNot(contains('-->')),
          reason:
              'the JSON fix is the clean remediation; the --> fix: '
              'marker is the text-mode protocol, not a JSON value',
        );
      }
      expect(
        findings.map((f) => (f as Map<String, dynamic>)['member']),
        unorderedEquals(['MissingUseCase', 'MissingRepository']),
      );

      final details = envelope['details'] as Map<String, dynamic>;
      expect(
        details['danglingClasses'],
        unorderedEquals(['MissingUseCase', 'MissingRepository']),
      );
      expect(details['deadImports'], isEmpty);
    });

    test('negative: a dead import lands in findings[].member and '
        'details.deadImports', () async {
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

      final result = await runDiVerify(['Order', '--json']);

      expect(result.code, 1);
      final envelope = jsonDecode(result.lines.single) as Map<String, dynamic>;
      // The U3 fixture trips BOTH #974 failure modes (unchanged semantics):
      // the dead import URI AND the dangling OrderRepository binding.
      final findings = envelope['findings'] as List<dynamic>;
      expect(findings, hasLength(2));

      final importFinding = findings
          .map((f) => f as Map<String, dynamic>)
          .firstWhere((f) => f['kind'] == 'dangling import');
      expect(
        importFinding['member'],
        '../../data/repositories/order_repository.dart',
      );

      final details = envelope['details'] as Map<String, dynamic>;
      expect(details['deadImports'], [
        '../../data/repositories/order_repository.dart',
      ]);
      expect(details['danglingClasses'], ['OrderRepository']);
    });

    test('text mode (no --json) is unchanged: prose verdict + --> fix: '
        'lines, no JSON', () async {
      writeDanglingFixture();

      final result = await runDiVerify(['Product']);

      expect(result.code, 1, reason: 'the gate semantics are unchanged');
      expect(result.lines.map((l) => l).join('\n'), contains('--> fix:'));
      expect(result.lines.join('\n'), contains('MissingUseCase'));
      expect(result.lines.join('\n'), contains('MissingRepository'));
      expect(
        result.lines.join('\n'),
        isNot(contains('{')),
        reason: 'text mode must not leak a JSON object',
      );
    });

    test('wiring: ModularDiCommand registers DiVerifyCommand (--json output) '
        'as the verify subcommand', () {
      final di = ModularDiCommand(buildPlugin());
      final verify = di.subcommands['verify'];
      expect(
        verify,
        isA<DiVerifyCommand>(),
        reason:
            'the manual #1108 subcommand must replace the auto-derived '
            'CapabilityCommand (--json is output here, not input)',
      );
      expect(
        verify!.argParser.options.containsKey('json'),
        isTrue,
        reason: 'zfa di verify --json must parse',
      );
      expect(
        verify.argParser.options['json']!.type,
        OptionType.flag,
        reason: '--json is a flag (JSON output), not an option (JSON input)',
      );
    });

    test('regression (#1108 red): package-resolved registrations must not '
        'crash the resolver — the gate verifies green', () async {
      // Before the fix, _PackageResolver.provides() seeded its visited set
      // with `const {}` and crashed with "Cannot change an unmodifiable
      // set" on ANY project whose .dart_tool/package_config.json resolved
      // a package import — i.e. every real project. The fixtures above
      // never hit it because they ship no package_config.json.
      writeSource(
        'lib/src/di/clients/acme_client_di.dart',
        "import 'package:acme/acme.dart';\n"
            '\n'
            'void registerAcmeClient(GetIt getIt) {\n'
            '  getIt.registerFactory<AcmeClient>(\n'
            '    () => AcmeClient(),\n'
            '  );\n'
            '}\n',
      );
      // Fake package resolution: acme → pkg/acme, lib/ declares AcmeClient.
      writeSource('pkg/acme/lib/acme.dart', 'class AcmeClient {}\n');
      writeSource(
        '.dart_tool/package_config.json',
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'acme', 'rootUri': 'pkg/acme', 'packageUri': 'lib/'},
          ],
        }),
      );

      final result = await buildCapability().execute({});

      expect(
        result.success,
        isTrue,
        reason:
            'AcmeClient resolves through package:acme — the gate must '
            'verify green, not crash with an unmodifiable-set error',
      );
    });
  });
}
