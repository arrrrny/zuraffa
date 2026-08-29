import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/agent/plugin/usecase_introspector.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('agent_plugin_introspect_');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  Future<void> writeFixtureUseCases(String entitySnake) async {
    final dir = Directory(
      p.join(tmp.path, 'lib', 'src', 'domain', 'usecases', entitySnake),
    );
    await dir.create(recursive: true);

    await File(
      p.join(dir.path, 'create_${entitySnake}_usecase.dart'),
    ).writeAsString('''
import 'package:zuraffa/zuraffa.dart';
class Create${_toPascal(entitySnake)}UseCase extends UseCase<${_toPascal(entitySnake)}, ${_toPascal(entitySnake)}> {
  Create${_toPascal(entitySnake)}UseCase(super.source);
  @override
  Future<${_toPascal(entitySnake)}> call(${_toPascal(entitySnake)} params) async => params;
}
''');

    await File(
      p.join(dir.path, 'get_${entitySnake}_usecase.dart'),
    ).writeAsString('''
import 'package:zuraffa/zuraffa.dart';
class Get${_toPascal(entitySnake)}UseCase extends UseCase<${_toPascal(entitySnake)}, QueryParams<${_toPascal(entitySnake)}>> {
  Get${_toPascal(entitySnake)}UseCase(super.source);
  @override
  Future<${_toPascal(entitySnake)}> call(QueryParams<${_toPascal(entitySnake)}> params) async => ${_toPascal(entitySnake)}();
}
''');

    await File(
      p.join(dir.path, 'delete_${entitySnake}_usecase.dart'),
    ).writeAsString('''
import 'package:zuraffa/zuraffa.dart';
@AgentInternal()
class Delete${_toPascal(entitySnake)}UseCase extends UseCase<bool, String> {
  Delete${_toPascal(entitySnake)}UseCase(super.source);
  @override
  Future<bool> call(String id) async => true;
}
''');

    await File(
      p.join(dir.path, 'get_${entitySnake}_list_usecase.dart'),
    ).writeAsString('''
import 'package:zuraffa/zuraffa.dart';
class Get${_toPascal(entitySnake)}ListUseCase extends UseCase<List<${_toPascal(entitySnake)}>, ListQueryParams<${_toPascal(entitySnake)}>> {
  Get${_toPascal(entitySnake)}ListUseCase(super.source);
  @override
  Future<List<${_toPascal(entitySnake)}>> call(ListQueryParams<${_toPascal(entitySnake)}> params) async => [];
}
''');
  }

  group('UseCaseIntrospector — FR-004', () {
    test('introspect fixture Listing entity → 4 use case records', () async {
      await writeFixtureUseCases('listing');
      final introspector = UseCaseIntrospector(projectRoot: tmp.path);
      final results = await introspector.introspect('Listing');
      expect(results.length, 4);

      final classNames = results.map((m) => m.className).toSet();
      expect(classNames, contains('CreateListingUseCase'));
      expect(classNames, contains('GetListingUseCase'));
      expect(classNames, contains('DeleteListingUseCase'));
      expect(classNames, contains('GetListingListUseCase'));

      // Verb derivation.
      final byClass = {for (final m in results) m.className: m};
      expect(byClass['CreateListingUseCase']!.verb, 'create');
      expect(byClass['GetListingUseCase']!.verb, 'get');
      expect(byClass['DeleteListingUseCase']!.verb, 'delete');
      expect(byClass['GetListingListUseCase']!.verb, 'list');

      // Return type extraction.
      expect(byClass['DeleteListingUseCase']!.returnType, 'bool');
      expect(byClass['GetListingListUseCase']!.returnType, 'List<Listing>');

      // @AgentInternal detection.
      expect(byClass['DeleteListingUseCase']!.isAgentInternal, isTrue);
      expect(byClass['CreateListingUseCase']!.isAgentInternal, isFalse);
    });

    test(
      'introspect entity with no usecases → empty list, informational message',
      () async {
        // Create the entity dir but with no usecase files.
        final dir = Directory(
          p.join(tmp.path, 'lib', 'src', 'domain', 'usecases', 'orphan'),
        );
        await dir.create(recursive: true);
        final introspector = UseCaseIntrospector(projectRoot: tmp.path);
        final results = await introspector.introspect('orphan');
        expect(results, isEmpty);
      },
    );

    test('introspect entity with NO usecase directory → empty list', () async {
      final introspector = UseCaseIntrospector(projectRoot: tmp.path);
      final results = await introspector.introspect('Nope');
      expect(results, isEmpty);
    });
  });
}

String _toPascal(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}
