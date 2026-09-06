// Bug 1198 (part of #908 P0) — template self-hosting: downstream-compile
// gate.
//
// Emits ALL generator templates (usecase, service, repository, datasource,
// mock, di, view/skin, state, route) for the fixture entity into ONE
// minimal FLUTTER package and asserts the package analyzes clean. This is
// the #1189/#1190 referee at TEMPLATE level: import/dep drift (a template
// starting to import something the consumer graph does not resolve) fails
// here — in front of the consumer, not in the consumer's app.
//
// Tagged `flutter`: needs the Flutter SDK, so it runs in the CI flutter
// lane (`flutter test --tags flutter`) and is excluded from the pure-Dart
// lane (`dart test --exclude-tags flutter`).
@Tags(['flutter'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/controller/controller_plugin.dart';
import 'package:zuraffa/src/plugins/datasource/datasource_plugin.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';
import 'package:zuraffa/src/plugins/presenter/presenter_plugin.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';
import 'package:zuraffa/src/plugins/state/state_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

import '../../plugins/helpers/flutter_cluster_fixture.dart';
import '../../helpers/template_self_hosting.dart';

const String _fixtureName = 'zfa1198_downstream_gate';

void main() {
  late Directory projectRoot;
  late String flutterExe;

  setUpAll(() async {
    final repoRoot = await findProjectRoot();
    projectRoot = await Directory.systemTemp.createTemp('zfa1198_gate_');

    // Minimal Flutter consumer package: Flutter SDK + go_router (the route
    // template's import surface) + zuraffa_flutter (the view template's
    // import surface). THIS CHECKOUT is wired in through dependency_overrides
    // (zuraffa_flutter depends on zuraffa from hosted; the override points
    // every zuraffa reference at the working tree) — the #1189-class drift
    // referee. This override lives in the throwaway fixture, never in the
    // repo's own pubspec.
    await File(p.join(projectRoot.path, 'pubspec.yaml')).writeAsString('''
name: $_fixtureName
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
  go_router: ^17.2.3
  zuraffa_flutter: ^6.1.0
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  uses-material-design: true
dependency_overrides:
  zuraffa:
    path: $repoRoot
  # The cluster-fixture workaround (flutter_cluster_fixture.dart): the
  # Flutter SDK pins meta (1.17.0 at 3.41.x) while the checkout's
  # analyzer ^14.0.0 needs meta ^1.18.3. Harmless on 3.47.x CI.
  meta: ^1.18.3
''');

    // Fixture entity at the canonical lib/src path the templates import.
    await writeFixtureEntity(projectRoot);

    flutterExe = await resolveFlutterExe();
    final pub = await flutterPubGet(projectRoot, flutterExe);
    expect(
      pub.exitCode,
      0,
      reason:
          'flutter pub get must succeed in the downstream gate fixture — '
          'a failure here is exactly the #1189/#1190-class consumer-graph '
          'drift this gate exists to catch at template level.\n'
          '${pub.stdout}\n${pub.stderr}',
    );
  });

  tearDownAll(() async {
    if (projectRoot.existsSync()) projectRoot.delete(recursive: true);
  });

  test('all nine templates emit into the minimal Flutter package and it '
      'analyzes clean', () async {
    final libSrc = p.join(projectRoot.path, 'lib', 'src');
    const opts = kSelfHostOptions;
    GeneratorConfig configFor(List<String> methods) => GeneratorConfig(
      name: kFixtureEntityName,
      methods: methods,
      outputDir: libSrc,
    );

    // 1. usecase
    final usecaseFiles = await UseCasePlugin(
      outputDir: libSrc,
      options: opts,
    ).generate(configFor(const ['get', 'getList']));
    expect(usecaseFiles, isNotEmpty, reason: 'usecase template');

    // 2. service
    final serviceFiles = await ServicePlugin(outputDir: libSrc, options: opts)
        .generate(
          GeneratorConfig(
            name: 'GetProduct',
            methods: const [],
            service: 'Product',
            domain: 'product',
            paramsType: 'QueryParams<Product>',
            returnsType: 'Product',
            outputDir: libSrc,
          ),
        );
    expect(serviceFiles, isNotEmpty, reason: 'service template');

    // 3. repository (+ datasource interface it consumes)
    final repositoryFiles =
        await RepositoryPlugin(outputDir: libSrc, options: opts).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateRepository: true,
            generateData: true,
            generateDataSource: true,
            outputDir: libSrc,
          ),
        );
    expect(repositoryFiles, isNotEmpty, reason: 'repository template');

    // 4. datasource (interface + local + remote)
    final datasourceFiles =
        await DataSourcePlugin(outputDir: libSrc, options: opts).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateData: true,
            enableCache: true,
            outputDir: libSrc,
          ),
        );
    expect(datasourceFiles, isNotEmpty, reason: 'datasource template');

    // 5. mock
    final mockFiles = await MockPlugin(outputDir: libSrc, options: opts)
        .generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateMock: true,
            outputDir: libSrc,
          ),
        );
    expect(mockFiles, isNotEmpty, reason: 'mock template');

    // 6. di
    final diFiles = await DiPlugin(outputDir: libSrc, options: opts).generate(
      GeneratorConfig(
        name: kFixtureEntityName,
        methods: const ['get'],
        generateData: true,
        generateDi: true,
        outputDir: libSrc,
      ),
    );
    expect(diFiles, isNotEmpty, reason: 'di template');

    // 7. state
    final stateFiles = await StatePlugin(outputDir: libSrc, options: opts)
        .generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateState: true,
            outputDir: libSrc,
          ),
        );
    expect(stateFiles, isNotEmpty, reason: 'state template');

    // 8. view/skin + presenter + controller (the full presentation
    // cluster — the emitted view imports its controller + presenter;
    // all emitted into lib/src where the route template imports them).
    final viewFiles = await ViewPlugin(outputDir: libSrc, options: opts)
        .generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get'],
            generateView: true,
            outputDir: libSrc,
          ),
        );
    expect(viewFiles, isNotEmpty, reason: 'view template');

    final presenterFiles =
        await PresenterPlugin(outputDir: libSrc, options: opts).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get'],
            generatePresenter: true,
            outputDir: libSrc,
          ),
        );
    expect(presenterFiles, isNotEmpty, reason: 'presenter template');

    final controllerFiles =
        await ControllerPlugin(outputDir: libSrc, options: opts).generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get'],
            generateController: true,
            outputDir: libSrc,
          ),
        );
    expect(controllerFiles, isNotEmpty, reason: 'controller template');

    // 9. route (imports the generated view — full presentation graph).
    final routeFiles = await RoutePlugin(outputDir: libSrc, options: opts)
        .generate(
          GeneratorConfig(
            name: kFixtureEntityName,
            methods: const ['get', 'getList'],
            generateRoute: true,
            outputDir: libSrc,
          ),
        );
    expect(routeFiles, isNotEmpty, reason: 'route template');

    // THE GATE: the minimal Flutter consumer of ALL emitted templates
    // must analyze clean.
    final result = await Process.run(flutterExe, [
      'analyze',
      '--no-fatal-infos',
      '--no-fatal-warnings',
      'lib',
      'test',
    ], workingDirectory: projectRoot.path);
    final output = '${result.stdout}\n${result.stderr}';

    expect(
      result.exitCode,
      0,
      reason:
          'downstream-compile gate failed: the minimal Flutter '
          'package consuming ALL nine templates does not analyze clean '
          '(#1189/#1190-class template-level drift). Output:\n$output',
    );
    expect(
      output,
      isNot(contains(' error - ')),
      reason:
          'no analyzer errors allowed in the downstream consumer:\n'
          '$output',
    );
  }, timeout: const Timeout(Duration(minutes: 8)));
}
