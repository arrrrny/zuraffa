// Spec 1122 — route: `--explain` flag + real config schema (issue #1122).
//
// The route plugin is at B+ after spec 0971: it has the `--json` verdict
// envelope, the drift verify gate, and route receipts — but no `--explain`
// and the plugin's `configSchema` is the empty `{}` that silently accepts
// any config. This file pins the A+ contract:
//
//   1. `zfa route create Product --explain` emits the explain block:
//      which routes are emitted, which platform slots each route targets,
//      which shell/guard binding is used, which state machine is
//      referenced.
//   2. `zfa route verify --explain` describes the drift verdict in prose.
//   3. `configSchema` declares the real properties (shell, deep-link,
//      platform-matrix, guard, state-machine) and `validateRouteConfig`
//      rejects unknown route shell names with the usage exit — the
//      issue's "exit 64", which the ratified SPEC 917 protocol maps onto
//      the canonical `ExitProtocol.usage` (ExitProtocol.canonicalize(64)
//      == 2; the golden test retires the legacy literal).
//
// Constraints pinned here: the existing `--json` envelope keys are
// unchanged (an `explain` key is ADDED only when `--explain` is passed),
// and `validateRouteConfig` refuses an empty `{}` schema outright
// (it would silently accept anything).
//
// Style: spec_971_t002_create_json_envelope_test.dart (real plugin
// generation into a temp Flutter-flavored project) +
// route_verify_verdict_test.dart (IOOverrides stdout capture for the
// drift mode, which writes through `stdout.writeln`).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';
import 'package:zuraffa/src/commands/route_command.dart';
import 'package:zuraffa/src/commands/route_verify_command.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';

Future<String> capturePrints(Future<void> Function() body) async {
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

/// Minimal [Stdout] adapter so the drift-mode prose (written through
/// `stdout.writeln`) can be captured without spawning a process.
class _StringSinkStdout implements Stdout {
  _StringSinkStdout(this._target);
  final StringBuffer _target;

  @override
  void write(Object? obj) => _target.write(obj);

  @override
  void writeln([Object? obj = '']) => _target.writeln(obj);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _target.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _target.writeCharCode(charCode);

  @override
  bool get hasTerminal => false;

  @override
  IOSink get nonBlocking => throw UnsupportedError('nonBlocking');

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  int get terminalColumns => throw UnsupportedError('terminalColumns');

  @override
  int get terminalLines => throw UnsupportedError('terminalLines');

  @override
  bool get supportsAnsiEscapes => false;

  @override
  String get lineTerminator => '\n';

  @override
  set lineTerminator(String value) {}

  @override
  void add(List<int> data) => _target.write(utf8.decode(data));

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done => Future.value();

  @override
  Future<void> flush() async {}
}

const _shellFixture = '''
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: navigationShell);
}

List<RouteBase> mainShellRoute() => [
      StatefulShellRoute.indexedStack(
        builder: (context, state) => MainShell(
          navigationShell: StatefulNavigationShell.of(context),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/product',
                name: 'productList',
                builder: (context, state) => Object(),
              ),
            ],
          ),
        ],
      ),
    ];
''';

const _cliFixture = '''
import 'package:go_router/go_router.dart';

abstract class ProductRoutes {
  static const String list = '/products';
  static const String detail = '/products/:id';
}

List<GoRoute> productRoutes() => [
      GoRoute(
        path: ProductRoutes.list,
        name: 'productList',
        builder: (context, state) => Object(),
      ),
      GoRoute(
        path: ProductRoutes.detail,
        name: 'productDetail',
        builder: (context, state) => Object(),
      ),
    ];
''';

const _ddaFixture = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
GoRouter createZfaRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/products',
        name: 'ProductView',
        builder: (context, state) => Object(),
      ),
      GoRoute(
        path: '/products/:id',
        name: 'ProductDetailView',
        builder: (context, state) => Object(),
      ),
    ],
  );
}
''';

const _ddaAboutFixture = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
GoRouter createZfaRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/products',
        name: 'ProductView',
        builder: (context, state) => Object(),
      ),
      GoRoute(
        path: '/about',
        name: 'AboutView',
        builder: (context, state) => Object(),
      ),
    ],
  );
}
''';

void main() {
  group('spec 1122: route config schema', () {
    test('configSchema declares the five real properties', () {
      final props =
          RoutePlugin(outputDir: 'lib/src').configSchema['properties'] as Map;
      expect(
        props.keys.toSet(),
        equals({
          'shell',
          'deep-link',
          'platform-matrix',
          'guard',
          'state-machine',
        }),
        reason:
            'issue #1122 order 2: the empty {} schema must be filled '
            'with the real route config vocabulary',
      );
    });

    test('shell property is an enum of the real shell kinds', () {
      final props =
          RoutePlugin(outputDir: 'lib/src').configSchema['properties'] as Map;
      final shell = props['shell'] as Map;
      expect(shell['type'], equals('string'));
      expect(
        (shell['enum'] as List).toSet(),
        equals({'none', 'bottom-nav', 'rail', 'adaptive'}),
        reason:
            'the shell kinds ShellRoutesBuilder actually emits '
            '(--bottom-nav / --rail / --adaptive), plus none',
      );
    });

    test('validateRouteConfig accepts real values', () {
      expect(
        validateRouteConfig({
          'shell': 'bottom-nav',
          'deep-link': true,
          'platform-matrix': ['ios', 'android'],
          'guard': 'authGuard',
          'state-machine': 'observer',
        }),
        isEmpty,
      );
    });

    test('validateRouteConfig rejects an unknown shell name', () {
      final violations = validateRouteConfig({'shell': 'bogus'});
      expect(violations, hasLength(1));
      expect(violations.single, contains('shell'));
      expect(violations.single, contains('bogus'));
      expect(
        violations.single,
        contains('bottom-nav'),
        reason: 'the violation names the allowed shell kinds',
      );
    });

    test('validateRouteConfig rejects unknown properties and wrong types', () {
      expect(
        validateRouteConfig({'nav': 'side'}),
        hasLength(1),
        reason: 'unknown route config property',
      );
      expect(
        validateRouteConfig({'deep-link': 'yes'}),
        hasLength(1),
        reason: 'deep-link is boolean-typed',
      );
    });

    test('validateRouteConfig refuses an empty {} schema', () {
      // The pre-#1122 schema shape: an object schema with no properties
      // would silently accept anything.
      final violations = validateRouteConfig(
        {'shell': 'bogus'},
        schema: {'type': 'object', 'properties': {}},
      );
      expect(violations, hasLength(1));
      expect(violations.single, contains('empty'));
    });

    test(
      'unknown route shell name exits the usage code with a fix line',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'spec1122_shell_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final projectRoot = tempDir.path;
        await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: route_app
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
  go_router: ^14.0.0
''');
        final runner = CommandRunner<void>('zfa', 'test')
          ..addCommand(
            RouteCommand(
              RoutePlugin(
                outputDir: '$projectRoot/lib/src',
                projectRoot: projectRoot,
              ),
              projectRoot: projectRoot,
            ),
          );

        final out = await capturePrints(
          () => runner.run(['route', 'create', 'Product', '--shell', 'bogus']),
        );

        // The issue's "exit 64" through the ratified protocol: legacy 64
        // (EX_USAGE) canonicalizes onto ExitProtocol.usage, and the golden
        // test retires the literal 64.
        expect(
          ExitProtocol.canonicalize(ExitProtocol.legacyUsage),
          equals(ExitProtocol.usage),
        );
        expect(
          exitCode,
          equals(ExitProtocol.usage),
          reason: 'unknown shell name is a usage-class rejection',
        );
        expect(out, contains('--> fix:'));
        // A rejected config must not generate anything.
        expect(
          File(
            p.join(projectRoot, 'lib/src/routing/product_routes.dart'),
          ).existsSync(),
          isFalse,
        );
        exitCode = 0;
      },
    );
  });

  group('spec 1122: route create --explain', () {
    late Directory tempDir;
    late String projectRoot;
    late CommandRunner<void> runner;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('spec1122_explain_');
      projectRoot = tempDir.path;
      await File(p.join(projectRoot, 'pubspec.yaml')).writeAsString('''
name: route_app
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
  go_router: ^14.0.0
''');
      runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(
          RouteCommand(
            RoutePlugin(
              outputDir: '$projectRoot/lib/src',
              projectRoot: projectRoot,
            ),
            projectRoot: projectRoot,
          ),
        );
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
      exitCode = 0;
    });

    test('emits the explain block (routes, platform slots, shell, guard, '
        'state machine)', () async {
      final out = await capturePrints(
        () => runner.run(['route', 'create', 'Product', '--explain']),
      );

      expect(exitCode, 0);
      expect(out, contains('explain:'));
      expect(out, contains('routes emitted:'));
      expect(out, contains('/product'), reason: 'the emitted route paths');
      expect(out, contains('platform slots:'));
      expect(
        out,
        contains('routing-index'),
        reason: 'the getAllRoutes aggregation slot',
      );
      expect(
        out,
        contains('route-table-test'),
        reason: 'the proof artifact slot',
      );
      expect(out, contains('shell binding:'));
      expect(out, contains('guard binding:'));
      expect(out, contains('state machine:'));
    });

    test('reports no shell/guard/state bindings on a bare project', () async {
      final out = await capturePrints(
        () => runner.run(['route', 'create', 'Product', '--explain']),
      );
      expect(out, contains('shell binding: none'));
      expect(out, contains('guard binding: none'));
      expect(out, contains('state machine: none'));
    });

    test('discovers the shell module that covers the emitted routes', () async {
      Directory(
        p.join(projectRoot, 'lib/src/routing'),
      ).createSync(recursive: true);
      File(
        p.join(projectRoot, 'lib/src/routing/main_shell.dart'),
      ).writeAsStringSync(_shellFixture);

      final out = await capturePrints(
        () => runner.run(['route', 'create', 'Product', '--explain']),
      );

      expect(
        out,
        contains('main_shell.dart'),
        reason: 'the shell branch root /product covers the entity routes',
      );
      expect(out, contains('StatefulShellRoute.indexedStack'));
    });

    test('discovers the referenced state machine artifact', () async {
      // The state plugin's output convention: <entity_snake>_state.dart
      // carrying class <Entity>State.
      Directory(p.join(projectRoot, 'lib/src')).createSync(recursive: true);
      File(
        p.join(projectRoot, 'lib/src/product_state.dart'),
      ).writeAsStringSync('class ProductState {}\n');

      final out = await capturePrints(
        () => runner.run(['route', 'create', 'Product', '--explain']),
      );

      expect(out, contains('ProductState'));
      expect(out, contains('product_state.dart'));
    });

    test(
      'platform slots name the scheme registrations when --scheme is set',
      () async {
        // The platform slots only exist when the platform manifests exist
        // (ManifestWriter skips registration when they are absent) — create
        // the minimal Android/iOS files first.
        final manifest =
            File(
                p.join(projectRoot, 'android/app/src/main/AndroidManifest.xml'),
              )
              ..createSync(recursive: true)
              ..writeAsStringSync(
                '<manifest><activity android:name=".MainActivity">'
                '<intent-filter /></activity></manifest>\n',
              );
        addTearDown(manifest.delete);
        final plist = File(p.join(projectRoot, 'ios/Runner/Info.plist'))
          ..createSync(recursive: true)
          ..writeAsStringSync(
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
            '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
            '<plist version="1.0"><dict></dict></plist>\n',
          );
        addTearDown(plist.delete);

        final out = await capturePrints(
          () => runner.run([
            'route',
            'create',
            'Product',
            '--explain',
            '--scheme',
            'gozuzu',
          ]),
        );

        expect(out, contains('android-scheme'));
        expect(out, contains('ios-scheme'));
      },
    );

    test('--explain --json ADDS the explain key without breaking the '
        'envelope', () async {
      final out = await capturePrints(
        () => runner.run(['route', 'create', 'Product', '--explain', '--json']),
      );
      final envelope = _envelopeFrom(out);

      // The canonical frame (SPEC 1105) plus the route surface in `details`
      // (issue #971 order 2 keys stay intact).
      expect(envelope['schema'], 'zuraffa.verdict.v1');
      final details = envelope['details'] as Map<String, dynamic>;
      expect(details['routes'], isA<List>());
      expect(details['deepLinks'], isA<List>());
      expect(details['schemeRegistrations'], isA<List>());
      expect(details['routeTableTestPath'], isNotNull);
      // The additive explain block.
      final explain = envelope['explain'] as Map<String, dynamic>;
      expect(explain['routes'], isA<List>());
      expect(explain['platformSlots'], isA<List>());
      expect(explain['shell'], isA<Map<String, dynamic>>());
      expect(explain['guard'], isA<Map<String, dynamic>>());
      expect(explain['stateMachine'], isA<Map<String, dynamic>>());
    });

    test('without --explain the envelope stays byte-compatible (no '
        'explain key)', () async {
      final out = await capturePrints(
        () => runner.run(['route', 'create', 'Product', '--json']),
      );
      final envelope = _envelopeFrom(out);
      expect(
        envelope.containsKey('explain'),
        isFalse,
        reason:
            'back-compat: the #971 envelope gains nothing unless '
            '--explain is requested',
      );
      expect(out.contains('explain:'), isFalse);
    });
  });

  group('spec 1122: route verify --explain', () {
    Future<Directory> writeProject({
      Map<String, String> cliModules = const {},
      String? ddaRouter,
    }) async {
      final project = await Directory.systemTemp.createTemp('spec1122_ver_');
      final routing = Directory('${project.path}/lib/src/routing')
        ..createSync(recursive: true);
      cliModules.forEach((moduleSlug, content) {
        File(
          '${routing.path}/${moduleSlug}_routes.dart',
        ).writeAsStringSync(content);
      });
      if (ddaRouter != null) {
        File('${routing.path}/zfa_router.g.dart').writeAsStringSync(ddaRouter);
      }
      addTearDown(() => project.delete(recursive: true));
      return project;
    }

    Future<String> runDriftExplain(Directory project) async {
      final capture = StringBuffer();
      exitCode = 0;
      final runner = CommandRunner<void>('verify-test', 'test')
        ..addCommand(RouteVerifyCommand(projectRoot: project.path));
      await IOOverrides.runZoned(
        () => runner.run(['verify', '--explain']),
        stdout: () => _StringSinkStdout(capture),
      );
      return capture.toString();
    }

    Future<Map<String, dynamic>> runDriftExplainJson(Directory project) async {
      final out = File('${project.path}/route-table.json');
      exitCode = 0;
      final runner = CommandRunner<void>('verify-test', 'test')
        ..addCommand(RouteVerifyCommand(projectRoot: project.path));
      await runner.run(['verify', '--explain', '--json', '--out', out.path]);
      return jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    }

    test('describes a match verdict in prose', () async {
      final project = await writeProject(
        cliModules: {'product': _cliFixture},
        ddaRouter: _ddaFixture,
      );

      final out = await runDriftExplain(project);

      expect(exitCode, 0);
      expect(out, contains('explain:'));
      expect(out, contains('match'));
      expect(
        out,
        contains('2 path'),
        reason: 'the prose names how many paths agree',
      );
    });

    test(
      'describes a drift verdict in prose, naming the drifted paths',
      () async {
        final project = await writeProject(
          cliModules: {'product': _cliFixture},
          ddaRouter: _ddaAboutFixture,
        );

        final out = await runDriftExplain(project);

        expect(exitCode, 1);
        expect(out, contains('explain:'));
        expect(out, contains('drift'));
        expect(
          out,
          contains('/about'),
          reason: 'the one-sided path is named in prose',
        );
        expect(
          out,
          contains('/products/:id'),
          reason: 'the CLI-only path is named in prose',
        );
      },
    );

    test('describes an insufficient-input verdict in prose', () async {
      final project = await writeProject(cliModules: {'product': _cliFixture});

      final out = await runDriftExplain(project);

      expect(exitCode, 2);
      expect(out, contains('explain:'));
      expect(out, contains('insufficient-input'));
      expect(
        out,
        contains('zfa_router.g.dart'),
        reason: 'the missing system is named',
      );
    });

    test('--explain --json adds an explain block to the drift artifact '
        'without breaking it', () async {
      final project = await writeProject(
        cliModules: {'product': _cliFixture},
        ddaRouter: _ddaFixture,
      );

      final payload = await runDriftExplainJson(project);

      // The pre-existing drift artifact keys stay intact.
      expect(payload['verdict'], equals('match'));
      expect(payload['routes'], isA<List>());
      // The additive prose block.
      final explain = payload['explain'] as Map<String, dynamic>;
      expect(explain['verdict'], equals('match'));
      expect(explain['prose'], isA<String>());
    });
  });
}

/// Extracts the JSON verdict envelope from captured command output: the
/// single line that decodes to a JSON object.
Map<String, dynamic> _envelopeFrom(String output) {
  for (final line in output.split('\n').reversed) {
    final trimmed = line.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Not the envelope line — keep scanning.
      }
    }
  }
  fail('no JSON envelope found in CLI output:\n$output');
}
