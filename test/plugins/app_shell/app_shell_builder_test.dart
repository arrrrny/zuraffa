import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/app_shell/builders/app_shell_builder.dart';

void main() {
  group('AppShellBuilder', () {
    const builder = AppShellBuilder();

    group('buildMain', () {
      // The default (no flags) models a no-arg, synchronous custom DI
      // entrypoint: `void main() { setupDependencies(); runApp(...); }`.
      test('emits a synchronous `void main()` entrypoint by default', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        // Default DI is synchronous (void return), so main must NOT be
        // async — `await` on a void is use_of_void_result. See issue #370.
        expect(src, contains('void main() {'));
        expect(src, isNot(contains('void main() async')));
      });

      test('calls setupDependencies() with no args by default', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        expect(src, contains('setupDependencies();'));
        // Must NOT await a synchronous void call.
        expect(src, isNot(contains('await setupDependencies')));
      });

      test('does NOT import zuraffa when DI takes no GetIt', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        expect(src, isNot(contains('package:zuraffa/zuraffa.dart')));
      });

      // The canonical `zfa di` / `zfa make --with=di` case: the DI barrel
      // declares `void setupDependencies(GetIt getIt)` (synchronous, GetIt).
      test(
        'passes GetIt.instance when diTakesGetIt is true (canonical DI)',
        () {
          final src = builder.buildMain(appName: 'my_app', diTakesGetIt: true);
          expect(src, contains('setupDependencies(GetIt.instance);'));
          // Canonical DI is synchronous void — still no await.
          expect(src, isNot(contains('await setupDependencies')));
          expect(src, contains('void main() {'));
          expect(src, isNot(contains('void main() async')));
        },
      );

      test(
        'imports package:zuraffa/zuraffa.dart for GetIt when diTakesGetIt',
        () {
          final src = builder.buildMain(appName: 'my_app', diTakesGetIt: true);
          // zuraffa re-exports get_it (lib/zuraffa.dart: export 'package:get_it/get_it.dart';)
          // so generated apps — which already depend on zuraffa for DI —
          // resolve GetIt without adding get_it as a direct dependency.
          expect(src, contains("import 'package:zuraffa/zuraffa.dart';"));
        },
      );

      test(
        'awaits setupDependencies() when diIsAsync is true (async no-arg DI)',
        () {
          final src = builder.buildMain(appName: 'my_app', diIsAsync: true);
          expect(src, contains('void main() async'));
          expect(src, contains('await setupDependencies();'));
        },
      );

      test('awaits setupDependencies(GetIt.instance) when GetIt + async', () {
        final src = builder.buildMain(
          appName: 'my_app',
          diTakesGetIt: true,
          diIsAsync: true,
        );
        expect(src, contains('void main() async'));
        expect(src, contains('await setupDependencies(GetIt.instance);'));
        expect(src, contains("import 'package:zuraffa/zuraffa.dart';"));
      });

      test('runs MyApp', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        expect(src, contains('runApp(const MyApp())'));
      });

      test('imports the generated DI barrel via the app package name', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        expect(src, contains("import 'package:my_app/src/di/index.dart';"));
      });

      test('imports MyApp from the app package', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        expect(src, contains("import 'package:my_app/src/app/my_app.dart';"));
      });

      test('derives imports from a custom output dir', () {
        final src = builder.buildMain(
          appName: 'my_app',
          outputDir: 'lib/custom',
        );
        expect(
          src,
          contains("import 'package:my_app/custom/app/my_app.dart';"),
        );
        expect(src, contains("import 'package:my_app/custom/di/index.dart';"));
        // No hardcoded src/ imports should leak through.
        expect(src, isNot(contains('package:my_app/src/')));
      });

      test('maps output dir lib/ to package-root imports', () {
        final src = builder.buildMain(appName: 'my_app', outputDir: 'lib');
        expect(src, contains("import 'package:my_app/app/my_app.dart';"));
        expect(src, contains("import 'package:my_app/di/index.dart';"));
      });

      test('imports flutter widgets for runApp', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        expect(src, contains("import 'package:flutter/widgets.dart';"));
      });

      test('stamps the file with the zfa header', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        expect(src.startsWith('// Generated by zfa'), isTrue);
      });

      test('adds the mock-mode hint when mockHint is true', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: true);
        expect(src, contains('Mock DI mode'));
        expect(src, contains('zfa di <Entity> --use-mock'));
      });

      test('does NOT add the mock hint when mockHint is false', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        expect(src.contains('Mock DI mode'), isFalse);
      });

      test('is not wrapped in // GENERATED - DO NOT EDIT markers', () {
        final src = builder.buildMain(appName: 'my_app', mockHint: false);
        // main.dart is user-editable glue — it should not be auto-replaced
        // by the AST merge engine on every `zfa build`.
        expect(src.contains('GENERATED - DO NOT EDIT'), isFalse);
      });
    });

    group('setupDependenciesTakesGetIt', () {
      test('returns true for the canonical GetIt signature', () {
        // Emitted by registration_builder.dart (zfa di / zfa make --with=di).
        const di = '''
import 'package:get_it/get_it.dart';
void setupDependencies(GetIt getIt) {
  registerAllUseCases(getIt);
}
''';
        expect(
          AppShellBuilder.setupDependenciesTakesGetIt(di),
          isTrue,
          reason: 'canonical `void setupDependencies(GetIt getIt)`',
        );
      });

      test('returns false for a no-arg signature', () {
        const di = 'Future<void> setupDependencies() async {}';
        expect(
          AppShellBuilder.setupDependenciesTakesGetIt(di),
          isFalse,
          reason: 'no-arg `setupDependencies()`',
        );
      });

      test('returns false when setupDependencies is absent', () {
        const di = '// no DI here\nvoid unrelated() {}';
        expect(AppShellBuilder.setupDependenciesTakesGetIt(di), isFalse);
      });

      test('returns true for a GetIt param among several params', () {
        const di =
            'void setupDependencies(GetIt getIt, {bool useMock = false}) {}';
        expect(AppShellBuilder.setupDependenciesTakesGetIt(di), isTrue);
      });
    });

    group('setupDependenciesIsAsync', () {
      test('returns false for the canonical synchronous void DI', () {
        const di =
            'void setupDependencies(GetIt getIt) { registerAllUseCases(getIt); }';
        expect(
          AppShellBuilder.setupDependenciesIsAsync(di),
          isFalse,
          reason: 'canonical `void setupDependencies(GetIt getIt)` is sync',
        );
      });

      test('returns true for a Future return type', () {
        const di = 'Future<void> setupDependencies(GetIt getIt) async {}';
        expect(AppShellBuilder.setupDependenciesIsAsync(di), isTrue);
      });

      test('returns true for an async modifier even without Future', () {
        const di = 'void setupDependencies() async {}';
        expect(AppShellBuilder.setupDependenciesIsAsync(di), isTrue);
      });

      test('returns true for a bare Future return (no async keyword)', () {
        const di =
            'Future setupDependencies(GetIt getIt) { return Future.value(); }';
        expect(AppShellBuilder.setupDependenciesIsAsync(di), isTrue);
      });

      test('returns false when setupDependencies is absent', () {
        const di = '// no DI here';
        expect(AppShellBuilder.setupDependenciesIsAsync(di), isFalse);
      });
    });

    group('hasSetupDependenciesDeclaration', () {
      test('returns true for the canonical GetIt declaration', () {
        const di =
            "import 'package:get_it/get_it.dart';\n"
            'void setupDependencies(GetIt getIt) {}';
        expect(AppShellBuilder.hasSetupDependenciesDeclaration(di), isTrue);
      });

      test('returns true for a no-arg declaration', () {
        const di = 'void setupDependencies() {}';
        expect(AppShellBuilder.hasSetupDependenciesDeclaration(di), isTrue);
      });

      test('returns false when the name appears only in a line comment', () {
        // Regression for issue #370: the old substring check accepted this
        // and then emitted a non-compiling main.dart.
        const di =
            '// TODO: call setupDependencies() once DI is generated\n'
            'void unrelated() {}';
        expect(AppShellBuilder.hasSetupDependenciesDeclaration(di), isFalse);
      });

      test('returns false when the name appears only in a block comment', () {
        const di =
            '/* setupDependencies() is not implemented yet */\n'
            'void unrelated() {}';
        expect(AppShellBuilder.hasSetupDependenciesDeclaration(di), isFalse);
      });

      test('returns false when setupDependencies is absent', () {
        const di = 'void unrelated() {}';
        expect(AppShellBuilder.hasSetupDependenciesDeclaration(di), isFalse);
      });
    });

    group('buildMyApp', () {
      test('emits a StatelessWidget named MyApp', () {
        final src = builder.buildMyApp();
        expect(src, contains('class MyApp extends StatelessWidget'));
      });

      test('has a const constructor', () {
        final src = builder.buildMyApp();
        expect(src, contains('const MyApp'));
      });

      test('emits a super parameter, not a broken super.key initializer', () {
        final src = builder.buildMyApp();
        // Regression guard: the previous implementation emitted
        // `const MyApp() : super.key();`, which does not compile —
        // StatelessWidget has no constructor named `key`. code_builder
        // emits a typed super parameter instead (`{Key? super.key}`),
        // which is valid Dart.
        expect(src, contains('const MyApp({Key? super.key});'));
        expect(src, isNot(contains(': super.key();')));
      });

      test('returns MaterialApp.router', () {
        final src = builder.buildMyApp();
        expect(src, contains('MaterialApp.router('));
      });

      test('wires routerConfig to appRouter', () {
        final src = builder.buildMyApp();
        expect(src, contains('routerConfig: appRouter'));
      });

      test('uses the provided title', () {
        final src = builder.buildMyApp(title: 'Hello World');
        expect(src, contains("title: 'Hello World'"));
      });

      test('falls back to "Zuraffa App" title when none provided', () {
        final src = builder.buildMyApp();
        expect(src, contains("title: 'Zuraffa App'"));
      });

      test('hides the debug banner', () {
        final src = builder.buildMyApp();
        expect(src, contains('debugShowCheckedModeBanner: false'));
      });

      test('imports the app_router glue but NOT go_router (analyze-clean)', () {
        final src = builder.buildMyApp();
        // Regression guard (issue #469 follow-up): my_app.dart never
        // references a go_router symbol — MaterialApp.router comes from
        // material.dart and appRouter arrives via the app_router glue —
        // so a direct go_router import is an unused_import that made
        // `flutter analyze` exit 1 on every freshly generated shell.
        expect(
          src,
          isNot(contains("import 'package:go_router/go_router.dart';")),
        );
        expect(src, contains("import '../routing/app_router.dart';"));
      });

      test('xray mode also omits the direct go_router import', () {
        final src = builder.buildMyApp(xray: true);
        // go_router symbols remain reachable through the zuraffa_flutter
        // barrel (it re-exports go_router), so xray mode must stay
        // analyze-clean without the direct import too.
        expect(
          src,
          isNot(contains("import 'package:go_router/go_router.dart';")),
        );
        expect(
          src,
          contains("import 'package:zuraffa_flutter/zuraffa_flutter.dart';"),
        );
      });

      test('imports flutter material', () {
        final src = builder.buildMyApp();
        expect(src, contains("import 'package:flutter/material.dart';"));
      });

      test('stamps the file with the zfa header', () {
        final src = builder.buildMyApp();
        expect(src.startsWith('// Generated by zfa'), isTrue);
      });
    });

    group('buildAppRouter', () {
      test('declares a final GoRouter appRouter', () {
        final src = builder.buildAppRouter();
        expect(src, contains('final GoRouter appRouter'));
      });

      test('constructs GoRouter with getAllRoutes()', () {
        final src = builder.buildAppRouter();
        expect(src, contains('GoRouter('));
        expect(src, contains('routes: getAllRoutes()'));
      });

      test('imports go_router', () {
        final src = builder.buildAppRouter();
        expect(src, contains("import 'package:go_router/go_router.dart';"));
      });

      test('imports the routing index (getAllRoutes source)', () {
        final src = builder.buildAppRouter();
        expect(src, contains("import 'index.dart';"));
      });

      test('stamps the file with the zfa header', () {
        final src = builder.buildAppRouter();
        expect(src.startsWith('// Generated by zfa'), isTrue);
      });
    });

    group('parseAppName', () {
      test('parses the name field from a pubspec', () {
        const pubspec = '''
name: my_app
description: A test app.
environment:
  sdk: ^3.11.0
''';
        expect(AppShellBuilder.parseAppName(pubspec), 'my_app');
      });

      test('parses the name field even when other fields precede it', () {
        const pubspec = '''
description: A test app.
name: my_app
environment:
  sdk: ^3.11.0
''';
        expect(AppShellBuilder.parseAppName(pubspec), 'my_app');
      });

      test('returns null when no name field is present', () {
        const pubspec = '''
description: no name here
environment:
  sdk: ^3.11.0
''';
        expect(AppShellBuilder.parseAppName(pubspec), isNull);
      });

      test('rejects names starting with a digit', () {
        // The regex requires [A-Za-z] as the first character, so a name
        // starting with a digit returns null even though YAML would
        // technically accept it as a string. This matches the Dart
        // package-name convention.
        const pubspec = 'name: 1bad\n';
        expect(AppShellBuilder.parseAppName(pubspec), isNull);
      });
    });
  });
}
