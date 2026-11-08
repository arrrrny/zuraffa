@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/agent/plugin/agent_plugin.dart';
import 'package:zuraffa/src/models/generator_config.dart';

import '../../helpers/project_root.dart';
import '../../helpers/run_zfa_source.dart' show scaleDuration;

/// The fixture package name — the emitted tool file's package-relative
/// import (`package:<name>/domain/usecases/...`) is derived from the
/// fixture pubspec's `name:`, so the driver's imports must match it.
const String _fixtureName = 'tool_params_coercion_e2e_app';

/// The executable counterpart to the source-assertion emission test in
/// `tool_params_coercion_test.dart` (zuraffa#2061 review finding): source
/// assertions still pass if the wrapper stops passing `_buildParams` to
/// the use case, so this suite ACTUALLY invokes the generated wrapper.
///
/// It builds a throwaway fixture package, generates the wrapper with the
/// real `AgentPlugin`, then runs a driver child (`dart run`) inside the
/// fixture that registers a `fromWire` factory, invokes the generated
/// tool, and asserts the use case received the coerced
/// `IdentifierLookupParams` — the full `McpTool.call → _buildParams →
/// UseCase.call` seam, compiled and executed (a raw map pass-through
/// would die on the typed `call(IdentifierLookupParams)` signature and
/// surface as an error result instead).
///
/// Spawns real `dart pub get` / `dart run` children and builds a
/// throwaway temp project — the #1510 heavyweight semantics, hence the
/// `e2e` tag (tier_integrity B5) keeping it off the fast lane; the lane
/// budget ladder's ceilings do not apply to an explicitly-Timeout-ed
/// test, so this suite stretches its own ceiling through
/// [scaleDuration] together with the child guards (issue #1187).
///
/// Note: an explicit `Timeout(Duration)` constructor bypasses
/// `dart_test.yaml`'s factor — intentional, so the ceiling grows with
/// the child guards at any scale (see `feature_flag_cli_test.dart`).
final Timeout _suiteTimeout = Timeout(
  scaleDuration(const Duration(minutes: 6)),
);

/// The compilable usecase source the fixture is built around. The
/// service-locator global mirrors what the DI plugin generates into real
/// host apps (`service_locator.dart`: `final GetIt getIt =
/// GetIt.instance;`) — the emitted tool file calls `getIt<...>()`
/// against that convention, and this file is the only package-relative
/// import the emitted tool carries, so the fixture defines the global
/// here.
const String _usecaseSource = '''
import 'package:get_it/get_it.dart';

import 'package:zuraffa/src/core/cancel_token.dart';
import 'package:zuraffa/src/domain/usecase.dart';

/// The host service-locator global the generated tool resolves through.
final GetIt getIt = GetIt.instance;

/// Typed params value class in the shape zfa-generated usecases take
/// (zuraffa#2061): NOT a map, so a raw pass-through crashes the call.
class IdentifierLookupParams {
  final String code;

  const IdentifierLookupParams({required this.code});
}

class BarcodeLookupResult {
  final String code;

  const BarcodeLookupResult({required this.code});
}

class GetIdentifierLookupUsecase
    extends UseCase<BarcodeLookupResult, IdentifierLookupParams> {
  /// The params the last [execute] received — the driver asserts on it.
  static Object? lastParams;

  @override
  Future<BarcodeLookupResult> execute(
    IdentifierLookupParams params,
    CancelToken? cancelToken,
  ) async {
    lastParams = params;
    return BarcodeLookupResult(code: params.code);
  }
}
''';

/// The child driver: registers the factory through the registry API,
/// registers the usecase into the (host-convention) getIt global, invokes
/// the GENERATED wrapper, and asserts the use case received the coerced
/// typed params. Exits non-zero on any miss so the parent test can gate
/// on the exit code.
const String _driverSource =
    '''
import 'dart:io';

import 'package:$_fixtureName/src/agent/tools/identifier_lookup_get_tool.dart';
import 'package:$_fixtureName/domain/usecases/identifier_lookup/get_identifier_lookup_usecase.dart';
import 'package:zuraffa/src/agent/plugin/tool_params_registry.dart';

Future<void> main() async {
  ToolParamsRegistry.register(
    'IdentifierLookupParams',
    (wire) => IdentifierLookupParams(code: wire['code'] as String),
  );
  getIt.registerFactory<GetIdentifierLookupUsecase>(
    () => GetIdentifierLookupUsecase(),
  );

  // Not const: the generated tool's constructor is not const either.
  final tool = GetIdentifier_lookupTool();
  final result = await tool.call({'code': 'abc'});

  if (result.isError) {
    stderr.writeln('tool.call returned isError: \${result.text}');
    exitCode = 1;
    return;
  }

  final params = GetIdentifierLookupUsecase.lastParams;
  if (params is! IdentifierLookupParams) {
    stderr.writeln(
      'usecase received \${params.runtimeType} instead of '
      'IdentifierLookupParams',
    );
    exitCode = 1;
    return;
  }
  if (params.code != 'abc') {
    stderr.writeln('coerced params lost the wire value: \${params.code}');
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'OK: usecase received IdentifierLookupParams(code: \${params.code})',
  );
}
''';

void main() {
  group('generated wrapper invocation (zuraffa#2061) — e2e', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('tool_params_coercion_e2e_');
    });

    tearDown(() async {
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
    });

    test(
      'the generated wrapper passes coerced typed params to the use case',
      () async {
        final repoRoot = await findProjectRoot();
        final fixtureRoot = p.join(tmp.path, _fixtureName);

        // The introspector scans `lib/src/domain/usecases/{entity}/` while
        // the emitted tool file imports
        // `package:<name>/domain/usecases/{entity}/...` — the fixture
        // satisfies both, so generation finds the use case AND the
        // generated file compiles.
        final usecaseFile = 'get_identifier_lookup_usecase.dart';
        for (final base in [
          p.join(fixtureRoot, 'lib', 'src', 'domain', 'usecases'),
          p.join(fixtureRoot, 'lib', 'domain', 'usecases'),
        ]) {
          final dir = Directory(p.join(base, 'identifier_lookup'));
          dir.createSync(recursive: true);
          File(p.join(dir.path, usecaseFile)).writeAsStringSync(_usecaseSource);
        }

        File(p.join(fixtureRoot, 'pubspec.yaml')).writeAsStringSync(
          'name: $_fixtureName\n'
          'environment:\n'
          '  sdk: ^3.0.0\n'
          'dependencies:\n'
          '  get_it: ^9.2.1\n'
          '  zuraffa:\n'
          '    path: $repoRoot\n',
        );

        // Generate the wrapper with the real plugin (in-process — the
        // child only executes the OUTPUT).
        final outputDir = p.join(fixtureRoot, 'lib', 'src');
        final plugin = AgentPlugin(
          outputDir: outputDir,
          namespaceOverride: 'app',
          projectRootOverride: fixtureRoot,
        );
        await plugin.generate(
          GeneratorConfig(
            name: 'IdentifierLookup',
            outputDir: outputDir,
            force: true,
          ),
        );
        final toolFile = File(
          p.join(
            outputDir,
            'agent',
            'tools',
            'identifier_lookup_get_tool.dart',
          ),
        );
        expect(
          toolFile.existsSync(),
          isTrue,
          reason: 'AgentPlugin did not emit the wrapper at ${toolFile.path}',
        );

        final driverFile = File(
          p.join(fixtureRoot, 'tool', 'coercion_e2e_driver.dart'),
        );
        driverFile.createSync(recursive: true);
        driverFile.writeAsStringSync(_driverSource);

        final dartBin = Platform.resolvedExecutable;

        // Resolve the fixture fully offline: every constraint resolves
        // from the local pub cache (the checkout itself resolved the same
        // set), so the e2e never touches the network.
        final pubGet = await _runSupervised(
          [dartBin, 'pub', 'get', '--offline'],
          workingDirectory: fixtureRoot,
          timeout: scaleDuration(const Duration(seconds: 75)),
        );
        expect(
          pubGet.exitCode,
          0,
          reason: 'fixture pub get failed:\n${_combined(pubGet)}',
        );

        final run = await _runSupervised(
          [dartBin, 'run', 'tool/coercion_e2e_driver.dart'],
          workingDirectory: fixtureRoot,
          timeout: scaleDuration(const Duration(seconds: 135)),
        );
        expect(
          run.exitCode,
          0,
          reason:
              'the generated wrapper did not pass the coerced typed '
              'params to the use case:\n${_combined(run)}',
        );
        expect(
          run.stdout,
          contains('OK: usecase received IdentifierLookupParams'),
        );
      },
      timeout: _suiteTimeout,
    );
  });
}

/// Start [command] in [workingDirectory], capture its output, and kill it
/// (SIGKILL) when [timeout] elapses — the repo's supervised-child shape
/// (`run_zfa_source.dart`): a hung child fails fast with the captured
/// output instead of silently consuming the enclosing test ceiling.
Future<ProcessResult> _runSupervised(
  List<String> command, {
  required String workingDirectory,
  required Duration timeout,
}) async {
  final process = await Process.start(
    command.first,
    command.sublist(1),
    workingDirectory: workingDirectory,
  );
  final stdout = StringBuffer();
  final stderr = StringBuffer();
  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .listen(stdout.write)
      .asFuture<void>();
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .listen(stderr.write)
      .asFuture<void>();

  final exitCode = await process.exitCode.timeout(
    timeout,
    onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      throw TimeoutException(
        'child exceeded its ${timeout.inSeconds}s guard: '
        '${command.join(' ')}',
        timeout,
      );
    },
  );
  // The streams close when the child exits (killed or not); drain them so
  // the captured output is complete before the caller reads it.
  await Future.wait<void>([stdoutDone, stderrDone]).catchError((_) => <void>[]);
  return ProcessResult(
    process.pid,
    exitCode,
    stdout.toString(),
    stderr.toString(),
  );
}

/// Merge the captured stdout + stderr into a single diagnostics string.
String _combined(ProcessResult result) => '${result.stdout}${result.stderr}';
