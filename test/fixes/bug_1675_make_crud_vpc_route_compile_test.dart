@Tags(['regression'])
library;

// Bug 1675 — `zfa make <E> --preset=crud --vpc --route` emits non-compiling
// Dart (GitHub issue #1675, severity high).
//
// Three independent defects, pinned here at the emitted-source / classifier
// level (the fast pure-Dart lane):
//
//   G1 — repository template ↔ package skew: the cache-aware delete body
//        emits `await _cachePolicy.markStale(<key>);` but the published
//        `CachePolicy` API (isValid / markFresh / invalidate / clear) has no
//        `markStale` → `undefined_method` at the consumer. The compile-level
//        referee lives in
//        `test/plugins/repository/repository_compile_test.dart` (its cached
//        variant gains `delete` so the body actually compiles against the
//        package API).
//
//   G2 — route plugin never parses non-String path parameters on the
//        `zfa make` path: `RoutePlugin.generateWithContext` builds its
//        `GeneratorConfig` WITHOUT `idFieldType` (make_command.dart writes
//        `context.data['id-field-type']`; view_plugin.dart reads it;
//        route_plugin.dart silently drops it), so the emitted view builder
//        passes the raw String `state.pathParameters['id']!` into a view
//        whose id is typed from the entity (`id:int` → `int?`) →
//        `argument_type_not_assignable` in `<entity>_routes.dart`.
//
//   G3 — analyze-gate misattribution: `BuildCommand._isGeneratedPath` only
//        recognizes `.g.dart`/`.zorphy.dart` suffixes, so files `zfa make`
//        just wrote (`lib/src/data/repositories/*.dart`,
//        `lib/src/routing/*_routes.dart`) are labeled
//        "hand-authored offending (not generator output)" — the remedy
//        tells the user to hand-patch generated code.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/build_command.dart';
import 'package:zuraffa/src/core/context/file_system.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/discovery_engine.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_context.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

void main() {
  late Directory workspace;
  late String outputDir;
  late FileSystem fs;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_bug_1675_');
    outputDir = p.join(workspace.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);

    // The repro entity: Todo with `id:int` (plus title/done, irrelevant to
    // these pins). make_command resolves `id-field-type: int` into
    // context.data for the plugins it drives.
    final entityDir = Directory(
      p.join(outputDir, 'domain', 'entities', 'todo'),
    );
    await entityDir.create(recursive: true);
    await File(p.join(entityDir.path, 'todo.dart')).writeAsString('''
class Todo {
  final int id;
  final String title;
  final bool done;
  const Todo({required this.id, required this.title, this.done = false});
}

class TodoPatch {
  final int? id;
  final String? title;
  final bool? done;
  const TodoPatch({this.id, this.title, this.done});
}
''');
    fs = FileSystem.create(root: workspace.path);
  });

  tearDown(() async {
    if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  });

  PluginContext buildContext(Map<String, dynamic> data) {
    return PluginContext(
      core: CoreConfig(
        name: 'Todo',
        projectRoot: workspace.path,
        outputDir: outputDir,
        force: true,
      ),
      data: data,
      discovery: DiscoveryEngine(projectRoot: workspace.path, fileSystem: fs),
      fileSystem: fs,
    );
  }

  group('G1: cache-aware delete body emits the published CachePolicy API', () {
    test(
      'U1/A1: repository (cache on, delete in methods) never emits markStale '
      'and calls the published invalidate API',
      () async {
        // Exactly what `zfa make Todo --preset=crud ... --methods=...,delete`
        // hands the repository plugin (crud bundles datasource; `--cache`
        // turns on the cache-aware variant).
        final ctx = buildContext(<String, dynamic>{
          'repository': true,
          'datasource': true,
          'cache': true,
          'methods': ['get', 'delete'],
          'id-field': 'id',
          'id-field-type': 'int',
        });

        final files = await RepositoryPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
        ).generateWithContext(ctx);

        final repoFile = File(
          p.join(
            outputDir,
            'data',
            'repositories',
            'data_todo_repository.dart',
          ),
        );
        expect(
          repoFile.existsSync(),
          isTrue,
          reason:
              'bug 1675: the cached repository must be emitted for the '
              'delete pin. Generated: '
              '${files.map((f) => f.path).join(', ')}',
        );
        final code = repoFile.readAsStringSync();

        // The skew, byte-for-byte: `markStale` does not exist on the
        // published CachePolicy API — the emitted body must not call it.
        expect(
          code,
          isNot(contains('markStale')),
          reason:
              'bug 1675 defect 1: the repository template emitted '
              '`CachePolicy.markStale`, a method the published package '
              '(6.x) does not declare — undefined_method at the consumer.',
        );
        // The published API it must use instead: isValid/markFresh/
        // invalidate/clear. Delete drops the cached entry → invalidate.
        expect(
          code,
          contains('_cachePolicy.invalidate('),
          reason:
              'bug 1675 fix: the cache-aware delete body must await '
              '`_cachePolicy.invalidate(<key>)` — an API the resolved '
              'package actually declares.',
        );
      },
    );
  });

  group('G2: route plugin (zfa make path) parses typed path parameters', () {
    test(
      'U2/A3: generateWithContext forwards id-field-type; the emitted '
      'todo_routes.dart parses the int id instead of passing the raw String',
      () async {
        // Exactly what `zfa make Todo --vpc --route
        // --methods=get,getList,create,update,delete` writes into
        // context.data for an `id:int` entity.
        final ctx = buildContext(<String, dynamic>{
          'route': true,
          'vpc': true,
          'methods': ['get', 'getList', 'create', 'update', 'delete'],
          'id-field': 'id',
          'id-field-type': 'int',
        });

        final files = await RoutePlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(force: true),
        ).generateWithContext(ctx);

        final routesFile = File(
          p.join(outputDir, 'routing', 'todo_routes.dart'),
        );
        expect(
          routesFile.existsSync(),
          isTrue,
          reason:
              'bug 1675: the route module must be emitted through the '
              'generateWithContext (zfa make) path. Generated: '
              '${files.map((f) => f.path).join(', ')}',
        );
        final code = routesFile.readAsStringSync();

        // The skew, byte-for-byte: the raw String path parameter flowing
        // into the int?-typed view field (todo_routes.dart:34/:51 in the
        // issue).
        expect(
          code,
          isNot(contains("id: state.pathParameters['id']!")),
          reason:
              'bug 1675 defect 2: the route builder passed the always-'
              'String `state.pathParameters[\'id\']!` straight into the '
              'view whose id field is typed from the entity (int?) — '
              'argument_type_not_assignable.',
        );
        // The #336 typed-parse form the route table test already pins —
        // int-id entities get the id parsed, not passed raw.
        expect(
          code,
          contains("int.parse(state.pathParameters['id']!)"),
          reason:
              'bug 1675 fix: the route builder must parse path parameters '
              'per the bound field type (int.tryParse/int.parse for int '
              'fields) before handing them to the view.',
        );
      },
    );
  });

  group('G3: analyze gate attributes zfa make output to the generator', () {
    // The analyze-gate excerpt from the issue — both offenders are files
    // `zfa make` just wrote, neither carries a .g.dart/.zorphy.dart suffix.
    const makeOutputAnalyze = '''
Analyzing lib/...
   error - lib/src/data/repositories/data_todo_repository.dart:82:30 - The method 'markStale' isn't defined for the type 'CachePolicy'. - undefined_method
   error - lib/src/routing/todo_routes.dart:34:45 - The argument type 'String' can't be assigned to the parameter type 'int?'. - argument_type_not_assignable
2 issues found.''';

    test('U3/A4: make output files (data/repositories, routing) are attributed '
        'to generator output — never labeled hand-authored', () {
      final lines = BuildCommand.analyzeGateRemedyLines(makeOutputAnalyze);

      expect(
        lines.join('\n'),
        isNot(contains('hand-authored offending')),
        reason:
            'bug 1675 defect 3: the gate labeled files `zfa make` just '
            'wrote as "hand-authored offending (not generator output)" — '
            'the remedy must point at the generator, not the user.',
      );
      expect(
        lines,
        ['Fix the generator or run with --no-analyze to skip this check.'],
        reason:
            'bug 1675 fix: all-generator offender sets keep the existing '
            'single generator remedy (the #1412 contract for the '
            'all-generated case).',
      );
    });

    test('A5: mixed offenders keep both ownership groups — make output stays '
        'in the generator group, real hand-authored files stay honest', () {
      const mixed = '''
Analyzing lib/...
   error - lib/src/data/repositories/data_todo_repository.dart:82:30 - The method 'markStale' isn't defined for the type 'CachePolicy'. - undefined_method
   error - lib/main.dart:9:3 - Something the user wrote. - some_code
2 issues found.''';

      final lines = BuildCommand.analyzeGateRemedyLines(mixed);

      expect(lines, hasLength(3));
      // The generated group names the make output file.
      expect(lines[0], contains('data_todo_repository.dart'));
      // The hand-authored group names only the user's file.
      expect(lines[1], contains('hand-authored offending'));
      expect(lines[1], contains('lib/main.dart'));
      expect(lines[1], isNot(contains('data_todo_repository.dart')));
    });

    test('U3: the make-owned directory conventions are generator output, '
        'backslash-normalized (Windows analyzer output shape)', () {
      // Direct classify probe via the remedy classifier on single-offender
      // inputs — every path below is a file `zfa make` writes.
      const segments = <String, String>{
        'domain': 'lib/src/domain/usecases/todo/get_todo_usecase.dart',
        'data': 'lib/src/data/repositories/data_todo_repository.dart',
        'di': 'lib/src/di/index.dart',
        'routing': 'lib/src/routing/todo_routes.dart',
        'presentation': 'lib/src/presentation/pages/todo/todo_state.dart',
        'cache': 'lib/src/cache/todo_cache.dart',
      };
      for (final entry in segments.entries) {
        final out =
            '''
Analyzing lib/...
   error - ${entry.value}:1:1 - Boom. - boom
1 issue found.''';
        expect(
          BuildCommand.analyzeGateRemedyLines(out),
          ['Fix the generator or run with --no-analyze to skip this check.'],
          reason:
              'make-owned segment "${entry.key}" (${entry.value}) must '
              'be attributed to generator output',
        );
      }

      // Windows-shaped paths (backslash separators) classify the same.
      const winOut = '''
Analyzing lib\\...
   error - lib\\src\\data\\repositories\\data_todo_repository.dart:82:30 - Boom. - boom
1 issue found.''';
      expect(BuildCommand.analyzeGateRemedyLines(winOut), [
        'Fix the generator or run with --no-analyze to skip this check.',
      ], reason: 'backslash paths must normalize to the same attribution');
    });
  });
}
