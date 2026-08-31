@Tags(['regression', 'slow'])
library;

// Regression test for issue #333:
// https://github.com/arrrrny/zuraffa/issues/333
//
// After #331's "probe detail_view on disk" fix, re-running
// `zfa route create <Entity> --methods=get,getList --force` over a
// pre-existing routes file (which referenced <Entity>DetailView)
// produced a malformed detail-route stub:
//
//     GoRoute(path: ErrorLogRoutes.errorLogList, ...),
//     ,                       // <-- stray comma + blank line (syntax error)
//
//     GoRoute(path: ErrorLogRoutes.errorLogDetail, name: 'error_log_detail',
//       builder: (context, state, ) { return  ErrorLogView(id: state.pathParameters  [
// 'id'
// ]!, errorLog: (state.extra as ErrorLog?), ); } , ),
//     ];
//
// Root cause:
//   - `_updateEntityRoutesFile` removed the old detail route via
//     `removeElementsFromReturnListInFunctionWhere` which only cut
//     `element.offset..element.end`, leaving a stray trailing comma.
//   - `_formatSafe` (DartFormatter) then threw on the broken syntax
//     and returned the raw, unformatted source — which contained the
//     raw `code_builder.DartEmitter` output for the new detail route
//     (with the mangled `state.pathParameters  [ 'id' ]!` whitespace).
//
// Fix (#333):
//   A. `route_builder.dart`: when `!hasDetailView`, do NOT emit a
//      detail GoRoute at all (the route file should contain only the
//      routes for views that actually exist on disk).
//   B. `route_builder.dart _updateEntityRoutesFile`: when the new run
//      does NOT include a detail route, remove any stale detail route
//      by `name:` identity so pre-existing broken files are cleaned up
//      on the next `--force` re-run.
//   C. `ast_modifier.dart`: fix
//      `removeElementsFromReturnListInFunctionWhere` and
//      `removeElementFromReturnListInFunction` to also strip the
//      trailing comma after the removed element — so removal never
//      leaves a stray `,` that breaks DartFormatter.
import 'dart:io';

import 'package:dart_style/dart_style.dart' show DartFormatter;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';

/// A pre-#331 routes file: it unconditionally referenced
/// `<Entity>DetailView` even when no `<entity>_detail_view.dart`
/// existed on disk. This is the broken state the smoke-test re-run
/// encountered.
const _preFixRoutesFile = r'''
// GENERATED - DO NOT EDIT
import 'package:go_router/go_router.dart';
import 'package:zuraffa/zuraffa.dart';
import '../domain/entities/error_log/error_log.dart';
import '../presentation/pages/error_log/error_log_view.dart';
import '../presentation/pages/error_log/error_log_detail_view.dart';

abstract class ErrorLogRoutes {
  static const String errorLogList = '/error_log';
  static const String errorLogDetail = '/error_log/:id';
}

List<GoRoute> errorLogRoutes() {
  return [
    GoRoute(
      path: ErrorLogRoutes.errorLogList,
      name: 'error_log_list',
      builder: (context, state) {
        return ErrorLogView(errorLog: (state.extra as ErrorLog?));
      },
    ),
    GoRoute(
      path: ErrorLogRoutes.errorLogDetail,
      name: 'error_log_detail',
      builder: (context, state) {
        return ErrorLogDetailView(
          id: state.pathParameters['id']!,
          errorLog: (state.extra as ErrorLog?),
        );
      },
    ),
  ];
}

// END GENERATED
''';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('issue_333_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('issue #333 — malformed detail-route stub when no detail_view', () {
    test(
      'FRESH generation with no detail_view file omits the detail GoRoute',
      () async {
        // No detail view file on disk — the smoke-test scenario.
        final builder = RouteBuilder(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );

        await builder.generate(
          GeneratorConfig(
            name: 'ErrorLog',
            methods: const ['get', 'getList'],
            generateVpcs: true,
            generateRoute: true,
            outputDir: outputDir,
          ),
        );

        final routesFile = File('$outputDir/routing/error_log_routes.dart');
        expect(routesFile.existsSync(), isTrue);
        final content = routesFile.readAsStringSync();

        // No detail GoRoute stub.
        expect(
          content.contains("name: 'error_log_detail'"),
          isFalse,
          reason:
              'detail GoRoute stub must NOT be emitted when no '
              'detail_view file exists on disk.',
        );
        // No stray comma + blank line.
        expect(
          RegExp(r',\s*\n\s*,').hasMatch(content),
          isFalse,
          reason: 'stray comma + blank line detected',
        );
        // No mangled pathParameters access.
        expect(
          content.contains('pathParameters  [') ||
              content.contains('pathParameters [\n') ||
              content.contains("pathParameters [ 'id'"),
          isFalse,
          reason: 'mangled state.pathParameters access detected',
        );
        // No trailing comma in closure params.
        expect(
          content.contains('(context, state, )'),
          isFalse,
          reason: 'trailing comma in closure params',
        );
        // The list route + import are still present.
        expect(content.contains("name: 'error_log_list'"), isTrue);
        expect(content.contains('error_log_view.dart'), isTrue);
      },
    );

    test('RE-RUN with --force over a pre-fix routes file cleans up the stale '
        'detail route and produces a syntactically valid file', () async {
      // Pre-create the routes file with the pre-#331 broken content
      // (referencing <Entity>DetailView unconditionally).
      final routesDir = Directory('$outputDir/routing');
      await routesDir.create(recursive: true);
      await File(
        '${routesDir.path}/error_log_routes.dart',
      ).writeAsString(_preFixRoutesFile);
      // Pre-create supporting files so _regenerateIndexFile doesn't choke.
      await File(
        '${routesDir.path}/index.dart',
      ).writeAsString("import 'error_log_routes.dart';\n");
      await File('${routesDir.path}/app_routes.dart').writeAsString(
        "import './index.dart';\n"
        "class AppRoutes {}\n"
        "extension RouterExtension on AppRoutes {}\n",
      );

      final builder = RouteBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      await builder.generate(
        GeneratorConfig(
          name: 'ErrorLog',
          methods: const ['get', 'getList'],
          generateVpcs: true,
          generateRoute: true,
          outputDir: outputDir,
        ),
      );

      final routesFile = File('$outputDir/routing/error_log_routes.dart');
      final content = routesFile.readAsStringSync();

      // The stale detail GoRoute (referencing ErrorLogDetailView) must
      // be removed.
      expect(
        content.contains('ErrorLogDetailView'),
        isFalse,
        reason:
            'stale detail route referencing <Entity>DetailView '
            'must be removed on re-run.',
      );
      expect(
        content.contains("name: 'error_log_detail'"),
        isFalse,
        reason:
            'no detail GoRoute stub must be emitted when no '
            'detail_view file exists on disk.',
      );
      // No stray comma + blank line.
      expect(
        RegExp(r',\s*\n\s*,').hasMatch(content),
        isFalse,
        reason: 'stray comma + blank line detected',
      );
      // No mangled pathParameters access.
      expect(
        content.contains('pathParameters  [') ||
            content.contains('pathParameters [\n') ||
            content.contains("pathParameters [ 'id'"),
        isFalse,
        reason: 'mangled state.pathParameters access detected',
      );
      // No trailing comma in closure params.
      expect(
        content.contains('(context, state, )'),
        isFalse,
        reason: 'trailing comma in closure params',
      );
      // The stale detail_view import must be dropped.
      expect(
        content.contains('error_log_detail_view.dart'),
        isFalse,
        reason:
            'stale detail_view import must be dropped when no '
            'detail_view file exists.',
      );
      // The list route + main view import must still be present.
      expect(content.contains("name: 'error_log_list'"), isTrue);
      expect(content.contains('error_log_view.dart'), isTrue);

      // The file must parse cleanly — verify by running the Dart
      // formatter on it (throws on invalid syntax).
      final formatted = _format(content);
      expect(
        formatted,
        isNotNull,
        reason: 'routes file must be parseable by DartFormatter',
      );
    });

    test('RE-RUN with --force is idempotent — second run produces the same '
        'file as the first', () async {
      final builder = RouteBuilder(
        outputDir: outputDir,
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );

      // First run.
      await builder.generate(
        GeneratorConfig(
          name: 'ErrorLog',
          methods: const ['get', 'getList'],
          generateVpcs: true,
          generateRoute: true,
          outputDir: outputDir,
        ),
      );
      final routesFile = File('$outputDir/routing/error_log_routes.dart');
      final firstRun = routesFile.readAsStringSync();

      // Second run.
      await builder.generate(
        GeneratorConfig(
          name: 'ErrorLog',
          methods: const ['get', 'getList'],
          generateVpcs: true,
          generateRoute: true,
          outputDir: outputDir,
        ),
      );
      final secondRun = routesFile.readAsStringSync();

      expect(
        secondRun,
        equals(firstRun),
        reason: 're-running with --force must be idempotent',
      );
    });
  });
}

/// Returns the formatted source, or null if the formatter fails (i.e.
/// the source is not valid Dart).
String? _format(String source) {
  try {
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(source);
  } catch (_) {
    return null;
  }
}
