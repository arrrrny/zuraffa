// Issue #1747: `zfa mock create <Type>` classified ANY non-enum named type
// as a CRUD entity and emitted a CRUD datasource/provider pair whose body
// calls members a plain DTO / value class does not have (`id`,
// `copyWithField`, a `<Type>Patch` companion). The emitted pair did not
// compile, and the mock certification still reported `(conforms)` — the
// non-compiling output was never flagged.
//
// The fix probes for that CRUD surface before emitting the pair, and
// degrades to the fixtures-only path the enum branch (#1037) already takes.
import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/builders/mock_builder.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

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

/// A hand-written DTO (the `LoginResponse` shape from the issue): named
/// fields, no `id`, no `copyWithField`, no `<Type>Patch`.
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

/// A realistic Zorphy entity: the abstract `\$<Type>` source file plus the
/// generated `.zorphy.dart` part that carries the concrete class, its
/// `copyWithField`, and the `<Type>Patch` companion.
const _todoEntity = '''
import 'package:zorphy_annotation/zorphy_annotation.dart';

part 'todo.zorphy.dart';

@Zorphy(generateJson: true)
abstract class \$Todo {
  String get id;
  String get title;
}
''';

const _todoZorphyPart = '''
part of 'todo.dart';

class Todo {
  Todo({required String this.id, required String this.title});

  final String id;
  final String title;

  Todo copyWith({String? id, String? title}) {
    return Todo(id: id ?? this.id, title: title ?? this.title);
  }

  Todo copyWithField<T>(Field<Todo, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      default:
        return this;
    }
  }
}

class TodoPatch extends PatchBase<Todo, Todo\$> {
  TodoPatch({Todo\$? changes});
}
''';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_1747_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('issue #1747: a DTO with no CRUD surface gets fixtures only, '
      'no CRUD datasource/provider', () async {
    final entityDir = Directory('$outputDir/domain/entities/login_response');
    await entityDir.create(recursive: true);
    await File(
      '${entityDir.path}/login_response.dart',
    ).writeAsString(_loginResponseEntity);

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
          methods: const ['get', 'update', 'toggle'],
          generateMock: true,
          outputDir: outputDir,
        ),
      );
    });

    // The fixture file IS generated — the type is still mockable data.
    expect(
      File('$outputDir/data/mock/login_response_mock_data.dart').existsSync(),
      isTrue,
    );
    // The CRUD surface is NOT: it cannot compile against this type.
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
    expect(files.any((f) => f.path.contains('_datasource')), isFalse);
    expect(prints.join('\n'), contains('issue #1747'));
  });

  test('issue #1747: a value object with no id gets fixtures only', () async {
    final entityDir = Directory('$outputDir/domain/entities/shell_nav_item');
    await entityDir.create(recursive: true);
    await File('${entityDir.path}/shell_nav_item.dart').writeAsString('''
class ShellNavItem {
  final int index;
  final int? branchIndex;

  const ShellNavItem({required this.index, this.branchIndex});

  bool get isBranch => branchIndex != null;
}
''');

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    final files = await builder.generate(
      GeneratorConfig(
        name: 'ShellNavItem',
        methods: const ['get', 'update', 'toggle'],
        generateMock: true,
        outputDir: outputDir,
      ),
    );

    expect(files.any((f) => f.path.contains('_datasource')), isFalse);
    expect(
      File('$outputDir/data/mock/shell_nav_item_mock_data.dart').existsSync(),
      isTrue,
    );
  });

  test('issue #1747: the DI simulation binding is not emitted for a DTO — '
      'it would import the datasource pair that was skipped', () async {
    final entityDir = Directory('$outputDir/domain/entities/login_response');
    await entityDir.create(recursive: true);
    await File(
      '${entityDir.path}/login_response.dart',
    ).writeAsString(_loginResponseEntity);

    final plugin = MockPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    late List files;
    await _capturePrints(() async {
      files = await plugin.generate(
        GeneratorConfig(
          name: 'LoginResponse',
          methods: const ['get', 'update', 'toggle'],
          generateMock: true,
          outputDir: outputDir,
        ),
      );
    });

    expect(files.any((f) => f.path.contains('_datasource')), isFalse);
    expect(
      File(
        '$outputDir/di/simulation/'
        'login_response_simulation_datasource_di.dart',
      ).existsSync(),
      isFalse,
    );
    final indexFile = File('$outputDir/di/simulation/index.dart');
    if (indexFile.existsSync()) {
      expect(
        indexFile.readAsStringSync(),
        isNot(contains('login_response_simulation_datasource_di.dart')),
      );
    }
  });

  test('issue #1747: a re-run purges the CRUD artifacts an older run left for '
      'a no-CRUD-surface type', () async {
    final entityDir = Directory('$outputDir/domain/entities/login_response');
    await entityDir.create(recursive: true);
    await File(
      '${entityDir.path}/login_response.dart',
    ).writeAsString(_loginResponseEntity);

    const marker = '// GENERATED - DO NOT EDIT';
    final dsDir = Directory('$outputDir/data/datasources/login_response');
    await dsDir.create(recursive: true);
    await File(
      '${dsDir.path}/login_response_datasource.dart',
    ).writeAsString('$marker\n// broken interface');
    await File(
      '${dsDir.path}/login_response_mock_datasource.dart',
    ).writeAsString('$marker\n// broken mock datasource');

    final plugin = MockPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    await _capturePrints(() async {
      await plugin.generate(
        GeneratorConfig(
          name: 'LoginResponse',
          methods: const ['get', 'update', 'toggle'],
          generateMock: true,
          outputDir: outputDir,
        ),
      );
    });

    expect(
      File('${dsDir.path}/login_response_datasource.dart').existsSync(),
      isTrue,
    );
    expect(
      File('${dsDir.path}/login_response_mock_datasource.dart').existsSync(),
      isFalse,
    );
  });

  test('issue #1747: a Zorphy entity with the full CRUD surface still gets '
      'the CRUD datasource', () async {
    final entityDir = Directory('$outputDir/domain/entities/todo');
    await entityDir.create(recursive: true);
    await File('${entityDir.path}/todo.dart').writeAsString(_todoEntity);
    await File(
      '${entityDir.path}/todo.zorphy.dart',
    ).writeAsString(_todoZorphyPart);

    final builder = MockBuilder(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );

    await _capturePrints(() async {
      await builder.generate(
        GeneratorConfig(
          name: 'Todo',
          methods: const ['get', 'update', 'toggle'],
          generateMock: true,
          outputDir: outputDir,
        ),
      );
    });

    expect(
      File(
        '$outputDir/data/datasources/todo/todo_datasource.dart',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '$outputDir/data/datasources/todo/todo_mock_datasource.dart',
      ).existsSync(),
      isTrue,
    );
  });
}
