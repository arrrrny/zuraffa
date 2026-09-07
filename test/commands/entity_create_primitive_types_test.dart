// Issue #1270 — `zfa entity create` must recognize built-in primitive types
// (bool/Boolean, int, double, String, num) and emit them DIRECTLY in the
// generated entity instead of rejecting them with "Unknown type … no
// matching entity directory or enum file found".
//
// The issue repro spells the boolean primitive `Boolean` — the natural
// spelling for many users (and other codegen ecosystems) but not a Dart
// built-in. The type-resolution path must recognize the alias as the
// built-in `bool` and emit `bool get isLoading;` (inline primitive — the
// preferred remediation; primitives are Dart built-ins and must not require
// enum/entity directory scaffolding).
//
// Driven through a real subprocess ([runZfaSource]): `entity` calls
// `exit()` on its error paths, and a subprocess keeps the process-global
// `Directory.current` hermetic under parallel `dart test` (issue #506
// pattern, see entity_receipt_test.dart).
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/run_zfa_source.dart';
import 'package:zuraffa/src/utils/entity_utils.dart';

void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_entity_prim1270_');
    await Directory(
      p.join(workspace.path, 'lib', 'src'),
    ).create(recursive: true);
    await File(p.join(workspace.path, 'pubspec.yaml')).writeAsString('''
name: zfa_entity_primitive_types_test
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
''');
  });

  tearDown(() {
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows file-lock flakiness; best-effort cleanup.
      }
    }
  });

  String entitySource(String snake) => File(
    p.join(
      workspace.path,
      'lib',
      'src',
      'domain',
      'entities',
      snake,
      '$snake.dart',
    ),
  ).readAsStringSync();

  group('issue #1270 — primitive field types resolve without scaffolding', () {
    test(
      'accepts the EXACT issue repro (isLoading:Boolean) and emits bool',
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Login',
          '--field',
          'isLoading:Boolean',
          '--field',
          'hasError:Boolean',
        ], workingDirectory: workspace.path);

        expect(
          result.exitCode,
          0,
          reason:
              'Boolean is the built-in bool spelled by the issue reporter — '
              'entity create must recognize it as a primitive and inline it, '
              'not demand enum/entity scaffolding.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          File(
            p.join(
              workspace.path,
              'lib',
              'src',
              'domain',
              'entities',
              'login',
              'login.dart',
            ),
          ).existsSync(),
          isTrue,
        );
        final source = entitySource('login');
        // Inline primitive emission — the preferred remediation.
        expect(source, contains('bool get isLoading;'));
        expect(source, contains('bool get hasError;'));
        // Never emitted as an unresolvable alias token or a directory ref.
        expect(source, isNot(contains('Boolean')));
      },
    );

    test(
      'accepts every core primitive (bool/int/double/String/num) inline',
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'PrimitiveAll',
          '--fields',
          'title:String,count:int,ratio:double,active:bool,score:num',
        ], workingDirectory: workspace.path);

        expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
        final source = entitySource('primitive_all');
        expect(source, contains('String get title;'));
        expect(source, contains('int get count;'));
        expect(source, contains('double get ratio;'));
        expect(source, contains('bool get active;'));
        expect(source, contains('num get score;'));
      },
    );

    test(
      'normalizes the Boolean alias inside generics and nullability',
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'AliasForms',
          '--fields',
          'flags:List<Boolean>,maybe:Boolean?,rate:Map<String, Boolean>',
        ], workingDirectory: workspace.path);

        expect(result.exitCode, 0, reason: 'stdout=${result.stdout}');
        final source = entitySource('alias_forms');
        expect(source, contains('List<bool> get flags;'));
        expect(source, contains('bool? get maybe;'));
        expect(source, contains('Map<String, bool> get rate;'));
        expect(source, isNot(contains('Boolean')));
      },
    );

    test(
      'add-field shares the primitive resolution (flag:Boolean appends bool)',
      () async {
        final create = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Task',
          '--fields',
          'title:String',
        ], workingDirectory: workspace.path);
        expect(create.exitCode, 0, reason: 'stdout=${create.stdout}');

        final add = await runZfaSource([
          'entity',
          'add-field',
          '-n',
          'Task',
          '--field',
          'done:Boolean',
        ], workingDirectory: workspace.path);

        expect(add.exitCode, 0, reason: 'stdout=${add.stdout}');
        final source = entitySource('task');
        expect(source, contains('bool get done;'));
        expect(source, isNot(contains('Boolean')));
      },
    );
  });

  group('issue #1270 — custom (non-primitive) resolution unchanged', () {
    test(
      'still rejects a custom type with no entity dir / enum file',
      () async {
        final result = await runZfaSource([
          'entity',
          'create',
          '-n',
          'Order',
          '--fields',
          'product:Product',
        ], workingDirectory: workspace.path);

        // Constraint: the fix must NOT loosen custom-type resolution. A
        // missing Product entity is still the #296 loud error.
        expect(result.exitCode, isNot(0), reason: 'stdout=${result.stdout}');
        expect(result.stdout, contains('field type(s) could not be resolved'));
        expect(result.stdout, contains('Unknown type "Product"'));
        expect(
          File(
            p.join(
              workspace.path,
              'lib',
              'src',
              'domain',
              'entities',
              'order',
              'order.dart',
            ),
          ).existsSync(),
          isFalse,
          reason: 'No entity file may be written for unresolved custom types',
        );
      },
    );
  });

  group('EntityUtils.normalizePrimitiveTypeAliases — unit contract', () {
    test('maps the boolean alias to the built-in in every spelling', () {
      expect(EntityUtils.normalizePrimitiveTypeAliases('Boolean'), 'bool');
      expect(EntityUtils.normalizePrimitiveTypeAliases('boolean'), 'bool');
      expect(EntityUtils.normalizePrimitiveTypeAliases('BOOLEAN'), 'bool');
      expect(EntityUtils.normalizePrimitiveTypeAliases('Boolean?'), 'bool?');
    });

    test('maps the alias inside generic inners only at word boundaries', () {
      expect(
        EntityUtils.normalizePrimitiveTypeAliases('List<Boolean>'),
        'List<bool>',
      );
      expect(
        EntityUtils.normalizePrimitiveTypeAliases('Map<String, Boolean>'),
        'Map<String, bool>',
      );
    });

    test('leaves built-ins and custom types untouched', () {
      expect(EntityUtils.normalizePrimitiveTypeAliases('bool'), 'bool');
      expect(EntityUtils.normalizePrimitiveTypeAliases('int'), 'int');
      expect(EntityUtils.normalizePrimitiveTypeAliases('double'), 'double');
      expect(EntityUtils.normalizePrimitiveTypeAliases('String'), 'String');
      expect(EntityUtils.normalizePrimitiveTypeAliases('num'), 'num');
      expect(EntityUtils.normalizePrimitiveTypeAliases('Product'), 'Product');
      expect(
        EntityUtils.normalizePrimitiveTypeAliases('List<Product>'),
        'List<Product>',
      );
      // A custom type whose name merely CONTAINS the alias is not rewritten.
      expect(
        EntityUtils.normalizePrimitiveTypeAliases('BooleanFilter'),
        'BooleanFilter',
      );
    });
  });
}
