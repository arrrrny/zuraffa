// Issue #1898: a non-CRUD-surface entity (a plain DTO) with a request
// for ONLY non-CRUD verbs (`list`, or any verb outside the standard CRUD
// vocabulary) must still emit the class-shaped datasource/mock-datasource
// pair, because those verbs do not need the entity's `id` /
// `copyWithField` / `<Type>Patch` surface. Issue #1747's guard must only
// fire when the requested methods actually require that surface.
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/utils/entity_analyzer.dart';

Future<List<String>> _capturePrints(Future<void> Function() body) async {
  final prints = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, String message) {
        prints.add(message);
      },
    ),
  );
  return prints;
}

const _loginResponseEntity = '''
class LoginResponse {
  final String userId;
  final String displayName;
  final String method;

  const LoginResponse({
    required this.userId,
    required this.displayName,
    required this.method,
  });
}
''';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_1898_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> writeDto() async {
    final entityDir = Directory('$outputDir/domain/entities/login_response');
    await entityDir.create(recursive: true);
    await File(
      '${entityDir.path}/login_response.dart',
    ).writeAsString(_loginResponseEntity);
  }

  test('issue #1898: a no-CRUD-surface DTO with methods: [list] emits '
      'the datasource pair', () async {
    await writeDto();

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    late List<String> prints;
    late List files;
    prints = await _capturePrints(() async {
      files = await builder.generate(
        GeneratorConfig(
          name: 'LoginResponse',
          methods: const ['list'],
          generateMock: true,
          outputDir: outputDir,
        ),
      );
    });

    expect(
      File(
        '$outputDir/data/datasources/login_response/'
        'login_response_datasource.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/datasources/login_response/'
        'login_response_mock_datasource.dart',
      ).existsSync(),
      isTrue,
    );
    expect(files.any((f) => f.path.contains('_datasource')), isTrue);
    expect(prints.join('\n'), isNot(contains('issue #1747')));
  });

  test('issue #1898: a no-CRUD-surface DTO with a mixed [list, get] '
      'request still skips the CRUD surface', () async {
    await writeDto();

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    await _capturePrints(() async {
      await builder.generate(
        GeneratorConfig(
          name: 'LoginResponse',
          methods: const ['list', 'get'],
          generateMock: true,
          outputDir: outputDir,
        ),
      );
    });

    expect(
      File(
        '$outputDir/data/datasources/login_response/'
        'login_response_datasource.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        '$outputDir/data/datasources/login_response/'
        'login_response_mock_datasource.dart',
      ).existsSync(),
      isFalse,
    );
  });

  test('issue #1898: an omitted (empty) methods list is treated as CRUD '
      'so the guard keeps firing for public plugin entry points', () async {
    await writeDto();

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(
        dryRun: false,
        force: true,
        verbose: false,
      ),
    );

    await _capturePrints(() async {
      await builder.generate(
        GeneratorConfig(
          name: 'LoginResponse',
          methods: const [],
          generateMock: true,
          outputDir: outputDir,
        ),
      );
    });

    expect(
      File(
        '$outputDir/data/datasources/login_response/'
        'login_response_datasource.dart',
      ).existsSync(),
      isFalse,
    );

    // Predicate-level guard: empty request still requires the CRUD surface.
    expect(EntityAnalyzer.methodsRequireCrudSurface(const []), isTrue);
    expect(EntityAnalyzer.methodsRequireCrudSurface(const ['list']), isFalse);
    expect(
      EntityAnalyzer.methodsRequireCrudSurface(const ['list', 'get']),
      isTrue,
    );
    expect(
      EntityAnalyzer.methodsRequireCrudSurface(const ['customVerb']),
      isFalse,
    );
  });

  test('issue #1898: MockPlugin emits the simulation binding for a '
      'list-only request on a no-CRUD-surface DTO', () async {
    await writeDto();

    final plugin = MockPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    late List files;
    await _capturePrints(() async {
      files = await plugin.generate(
        GeneratorConfig(
          name: 'LoginResponse',
          methods: const ['list'],
          generateMock: true,
          outputDir: outputDir,
        ),
      );
    });

    expect(files.any((f) => f.path.contains('_datasource')), isTrue);
    expect(
      File(
        '$outputDir/di/simulation/'
        'login_response_simulation_datasource_di.dart',
      ).existsSync(),
      isTrue,
    );
  });
}
