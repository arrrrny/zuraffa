// Spec 1110 (issue #1110) — the mock failure preset:
// `zfa mock create <Entity> --fail` generates a FailingMockProvider whose
// every method throws the entity's sealed failure type (an AppFailure
// subtype). This is the framework feature that replaces the pilot's
// hand-written `_FailingAuthService` (005-login-engine).
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/failing_mock_provider_builder.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_1110_fail_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  void writeEntity(String name) {
    final dir = Directory('$outputDir/domain/entities/${name.toLowerCase()}');
    dir.createSync(recursive: true);
    File('${dir.path}/${name.toLowerCase()}.dart').writeAsStringSync(
      'class $name { final String id; const $name(this.id); }\n',
    );
  }

  test('builder emits <Entity>FailingMockProvider implementing the '
      'datasource interface, every method throwing', () async {
    writeEntity('Login');

    final builder = FailingMockProviderBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    final file = await builder.generateFailingMockProvider(
      GeneratorConfig(
        name: 'Login',
        methods: const ['get', 'getList', 'create', 'update', 'delete'],
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    final path =
        '$outputDir/data/datasources/login/'
        'login_failing_mock_provider.dart';
    expect(file.path, path);
    expect(File(path).existsSync(), isTrue, reason: 'file written');
    expect(file.type, 'failing_mock_provider');

    final source = File(path).readAsStringSync();
    // The class: the failure-path twin of the certified mock.
    expect(source, contains('class LoginFailingMockProvider'));
    expect(source, contains('implements LoginDataSource'));
    expect(source, contains('GENERATED - DO NOT EDIT'));
    // Every method throws the sealed failure type — a throwing double,
    // never a silent Fake.
    expect(source, contains('Future<Login> get(QueryParams<Login> params)'));
    expect(
      source,
      contains(
        'Future<List<Login>> getList('
        'ListQueryParams<Login> params)',
      ),
    );
    expect(source, contains('Future<Login> create(Login item)'));
    expect(
      source,
      contains('Future<Login> update(UpdateParams<String, LoginPatch> params)'),
    );
    expect(
      source,
      contains('Future<void> delete(DeleteParams<String> params)'),
    );
    final throwsCount = 'throw const ServerFailure'.allMatches(source).length;
    expect(
      throwsCount,
      5,
      reason:
          'every generated method throws ServerFailure '
          '(found $throwsCount)',
    );
    expect(source, contains("import 'package:zuraffa/mock.dart'"));
  });

  test('the throw messages name the entity and the method', () async {
    writeEntity('Login');

    final builder = FailingMockProviderBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    await builder.generateFailingMockProvider(
      GeneratorConfig(
        name: 'Login',
        methods: const ['get'],
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    final source = File(
      '$outputDir/data/datasources/login/login_failing_mock_provider.dart',
    ).readAsStringSync();
    expect(source, contains('Login mock failure'));
    expect(source, contains('method get'));
  });

  test('watch/watchList methods throw on the stream path too', () async {
    writeEntity('Session');

    final builder = FailingMockProviderBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    await builder.generateFailingMockProvider(
      GeneratorConfig(
        name: 'Session',
        methods: const ['watch', 'watchList'],
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    final source = File(
      '$outputDir/data/datasources/session/session_failing_mock_provider.dart',
    ).readAsStringSync();
    expect(source, contains('Stream<Session> watch('));
    expect(source, contains('Stream<List<Session>> watchList('));
    // Stream methods deliver the sealed failure through the stream's
    // error channel — Stream.error(const ServerFailure(...)) — one per
    // method.
    expect('Stream.error('.allMatches(source).length, 2);
    expect('const ServerFailure('.allMatches(source).length, 2);
    expect(
      'throw const ServerFailure'.allMatches(source).length,
      0,
      reason:
          'stream methods fail through the error channel, not a '
          'synchronous throw',
    );
  });

  test('an existing failing provider is overwritten with --force (the '
      'preset is idempotent)', () async {
    writeEntity('Login');

    final builder = FailingMockProviderBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    final first = await builder.generateFailingMockProvider(
      GeneratorConfig(
        name: 'Login',
        methods: const ['get'],
        generateMock: true,
        outputDir: outputDir,
      ),
    );
    final second = await builder.generateFailingMockProvider(
      GeneratorConfig(
        name: 'Login',
        methods: const ['get'],
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    expect(first.action, 'created');
    expect(second.action, 'overwritten');
  });

  group('MockPlugin --fail preset (spec 1110)', () {
    test('generate() emits the failing provider alongside the certified '
        'mock artifacts (failMock: true)', () async {
      writeEntity('Login');

      final plugin = MockPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await plugin.generate(
        GeneratorConfig(
          name: 'Login',
          methods: const ['get'],
          generateMock: true,
          failMock: true,
          outputDir: outputDir,
        ),
      );

      final failing = files
          .where((f) => f.type == 'failing_mock_provider')
          .toList();
      expect(failing, hasLength(1));
      expect(
        failing.single.path,
        '$outputDir/data/datasources/login/'
        'login_failing_mock_provider.dart',
      );
      // The succeeding (certifiable) mock is still generated — the pair
      // is the feature: failure-path + success-path doubles.
      expect(
        files
            .where(
              (f) =>
                  f.path.endsWith('login_mock_datasource.dart') ||
                  f.path.endsWith('login_mock_data.dart'),
            )
            .length,
        greaterThanOrEqualTo(2),
      );
    });

    test('failMock: false (the default) emits no failing provider — '
        'backwards compatible', () async {
      writeEntity('Login');

      final plugin = MockPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(force: true),
      );
      final files = await plugin.generate(
        GeneratorConfig(
          name: 'Login',
          methods: const ['get'],
          generateMock: true,
          outputDir: outputDir,
        ),
      );

      expect(
        files.where((f) => f.type == 'failing_mock_provider').toList(),
        isEmpty,
      );
    });
  });
}
