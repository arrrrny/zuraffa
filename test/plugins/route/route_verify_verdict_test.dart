// BUG 1060 — route verify honest verdict set.
//
// `zfa route verify` used to be a permanent no-op PASS: on any project
// where one or both route systems were missing it printed "no drift" and
// exited 0 — a lie-certifying PASS. This file pins the honest verdict
// contract:
//
//   verdict             exit code    meaning
//   ------------------  -----------  ------------------------------------
//   match                0           both systems present, path sets agree
//   drift                1           overlap findings and/or one-sided paths
//   insufficient-input   2           a system has no routes at all (exit 1
//                                    with --strict)
//
// Fixtures use the real generated shapes: CLI side `<entity>_routes.dart`
// (constants + GoRoute list), DDA side `zfa_router.g.dart` (literals).

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/route_verify_command.dart';

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

const _cliOrdersFixture = '''
import 'package:go_router/go_router.dart';

abstract class OrderRoutes {
  static const String list = '/orders';
}

List<GoRoute> orderRoutes() => [
      GoRoute(
        path: OrderRoutes.list,
        name: 'orderList',
        builder: (context, state) => Object(),
      ),
    ];
''';

Future<Directory> _writeProject({
  Map<String, String> cliModules = const {},
  String? ddaRouter,
}) async {
  final project = await Directory.systemTemp.createTemp('route_verdict_');
  final routing = Directory('${project.path}/lib/src/routing')
    ..createSync(recursive: true);
  // One module per file — mirrors the real generated layout
  // (`<entity>_routes.dart` holds a single `<Entity>Routes` class).
  cliModules.forEach((moduleSlug, content) {
    File(
      '${routing.path}/${moduleSlug}_routes.dart',
    ).writeAsStringSync(content);
  });
  if (ddaRouter != null) {
    File('${routing.path}/zfa_router.g.dart').writeAsStringSync(ddaRouter);
  }
  return project;
}

Future<Map<String, Object?>> _runVerify(
  Directory project, {
  List<String> extraArgs = const [],
}) async {
  final output = File('${project.path}/route-table.json');
  exitCode = 0;
  final runner = CommandRunner<void>('verify-test', 'test')
    ..addCommand(RouteVerifyCommand(projectRoot: project.path));
  await runner.run(['verify', '--json', '--out', output.path, ...extraArgs]);
  final payload = jsonDecode(output.readAsStringSync()) as Map<String, Object?>;
  return payload;
}

Future<String> _runVerifyPlain(Directory project) async {
  final stdoutCapture = StringBuffer();
  exitCode = 0;
  final runner = CommandRunner<void>('verify-test', 'test')
    ..addCommand(RouteVerifyCommand(projectRoot: project.path));
  await IOOverrides.runZoned(
    () async {
      await runner.run(['verify', '--plain']);
    },
    // The command writes via `stdout.writeln`, which routes through the
    // overridden global `stdout` getter inside this zone.
    stdout: () => _StringSinkStdout(stdoutCapture),
  );
  return stdoutCapture.toString();
}

/// Minimal [Stdout] adapter so `_runVerifyPlain` can capture what the
/// command prints to stdout without spawning a process. Only the
/// [StringSink] surface used by the command is real; everything else
/// throws [UnsupportedError].
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

void main() {
  tearDown(() {
    exitCode = 0;
  });

  group('bug 1060: honest verdicts', () {
    test('V1 (a): matching systems → verdict match, exit 0', () async {
      final project = await _writeProject(
        cliModules: {'product': _cliFixture},
        ddaRouter: _ddaFixture,
      );
      addTearDown(() => project.delete(recursive: true));

      final payload = await _runVerify(project);

      expect(exitCode, equals(0), reason: 'match must exit 0');
      expect(payload['verdict'], equals('match'));
      expect(payload['drift'], hasLength(0));
      expect(payload['oneSided'], hasLength(0));
    });

    test(
      'V2 (b): path in one system only → drift with path named, exit 1',
      () async {
        // CLI declares /orders that the DDA router never declares.
        final project = await _writeProject(
          cliModules: {'product': _cliFixture, 'order': _cliOrdersFixture},
          ddaRouter: _ddaFixture,
        );
        addTearDown(() => project.delete(recursive: true));

        final payload = await _runVerify(project);

        expect(exitCode, equals(1), reason: 'drift must exit 1');
        expect(payload['verdict'], equals('drift'));
        final oneSided = (payload['oneSided']! as List)
            .cast<Map<String, Object?>>();
        expect(oneSided, hasLength(1));
        expect(oneSided.single['path'], equals('/orders'));
        final sources = (oneSided.single['sources']! as List)
            .cast<Map<String, Object?>>();
        expect(sources.single['source'], equals('cli'));
        // The overlaps on /products and /products/:id are still reported by
        // the detector.
        final drift = (payload['drift']! as List).cast<Map<String, Object?>>();
        expect(drift.map((d) => d['path']), ['/products', '/products/:id']);
      },
    );

    test('V2b (b): DDA-only path is drift too (symmetric)', () async {
      final project = await _writeProject(
        cliModules: {'product': _cliFixture},
        ddaRouter: _ddaAboutFixture,
      );
      addTearDown(() => project.delete(recursive: true));

      final payload = await _runVerify(project);

      expect(exitCode, equals(1), reason: 'drift must exit 1');
      expect(payload['verdict'], equals('drift'));
      final oneSided = (payload['oneSided']! as List)
          .cast<Map<String, Object?>>();
      // /products/:id exists only on the CLI side, /about only on the DDA
      // side — both are one-sided drift, each named.
      expect(oneSided.map((d) => d['path']), ['/about', '/products/:id']);
      final about = oneSided.firstWhere((d) => d['path'] == '/about');
      final sources = (about['sources']! as List).cast<Map<String, Object?>>();
      expect(sources.single['source'], equals('dda'));
    });

    test('V3 (c): missing DDA input → insufficient-input, exit 2', () async {
      final project = await _writeProject(cliModules: {'product': _cliFixture});
      addTearDown(() => project.delete(recursive: true));

      final payload = await _runVerify(project);

      expect(exitCode, equals(2), reason: 'insufficient-input must exit 2');
      expect(payload['verdict'], equals('insufficient-input'));
      // The missing input is named, never a silent PASS.
      expect(
        (payload['missingInput'] as String? ?? ''),
        contains('zfa_router.g.dart'),
      );
    });

    test('V3b (c): missing CLI input → insufficient-input, exit 2', () async {
      final project = await _writeProject(ddaRouter: _ddaFixture);
      addTearDown(() => project.delete(recursive: true));

      final payload = await _runVerify(project);

      expect(exitCode, equals(2), reason: 'insufficient-input must exit 2');
      expect(payload['verdict'], equals('insufficient-input'));
      expect(payload['missingInput'] as String?, isNotNull);
    });

    test(
      'V3c (c): no route inputs at all → insufficient-input, exit 2',
      () async {
        final project = await _writeProject();
        addTearDown(() => project.delete(recursive: true));

        final payload = await _runVerify(project);

        expect(exitCode, equals(2), reason: 'insufficient-input must exit 2');
        expect(payload['verdict'], equals('insufficient-input'));
      },
    );

    test(
      'V4: --strict makes insufficient-input fail the run (exit 1)',
      () async {
        final project = await _writeProject(
          cliModules: {'product': _cliFixture},
        );
        addTearDown(() => project.delete(recursive: true));

        await _runVerify(project, extraArgs: ['--strict']);

        expect(exitCode, equals(1), reason: '--strict must fail the run');
      },
    );

    test('V5: verdicts and exit codes are documented in help', () {
      final command = RouteVerifyCommand();
      final help = '${command.description}\n${command.argParser.usage}';
      expect(help, contains('match'));
      expect(help, contains('drift'));
      expect(help, contains('insufficient-input'));
      expect(help, contains('exit 0'));
      expect(help, contains('exit 1'));
      expect(help, contains('exit 2'));
    });

    test(
      'V6: insufficient-input is distinguishable from match in text',
      () async {
        final matchProject = await _writeProject(
          cliModules: {'product': _cliFixture},
          ddaRouter: _ddaFixture,
        );
        addTearDown(() => matchProject.delete(recursive: true));
        final matchText = await _runVerifyPlain(matchProject);
        expect(matchText, contains('verdict: match'));

        final missingProject = await _writeProject(
          cliModules: {'product': _cliFixture},
        );
        addTearDown(() => missingProject.delete(recursive: true));
        final missingText = await _runVerifyPlain(missingProject);
        expect(missingText, contains('verdict: insufficient-input'));
        // Text output names the offending path for one-sided drift too.
        final driftProject = await _writeProject(
          cliModules: {'product': _cliFixture, 'order': _cliOrdersFixture},
          ddaRouter: _ddaFixture,
        );
        addTearDown(() => driftProject.delete(recursive: true));
        final driftText = await _runVerifyPlain(driftProject);
        expect(driftText, contains('verdict: drift'));
        expect(driftText, contains('/orders'));
      },
    );

    test('V7: CLI walker also reads *_shell.dart branch routes', () async {
      final project = await _writeProject(
        cliModules: {},
        ddaRouter: _ddaFixture,
      );
      addTearDown(() => project.delete(recursive: true));
      File('${project.path}/lib/src/routing/home_shell.dart').writeAsStringSync(
        '''
import 'package:go_router/go_router.dart';

List<RouteBase> homeShellRoute() => [
      StatefulShellRoute.indexedStack(
        builder: (context, state, child) => Object(),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                name: 'HomeBranch',
                builder: (context, state) => Object(),
              ),
              GoRoute(
                path: '/products/:id',
                name: 'HomeDetailBranch',
                builder: (context, state) => Object(),
              ),
            ],
          ),
        ],
      ),
    ];
''',
      );

      final payload = await _runVerify(project);

      // The shell branch routes count as CLI-side input, so the project is
      // no longer missing an input and the path sets agree → match.
      expect(payload['verdict'], equals('match'));
      expect(exitCode, equals(0));
    });
  });
}
