@Tags(['regression'])
library;

// Regression test for issue #2118:
// https://github.com/arrrrny/zuraffa/issues/2118
//
// `zfa di register --target=ImportOrdersUseCase --domain=import_orders`
// emitted `di/usecases/import_orders_usecase_di.dart` that referenced
// `ImportOrdersUseCase()` with NO arguments, even though the generated
// usecase constructor is `ImportOrdersUseCase(this._importOrdersService)`
// and requires an `ImportOrdersService`. The analyzer gate then failed the
// build:
//
//   import_orders_usecase_di.dart:11:78 - 1 positional argument expected by
//   ImportOrdersUseCase.new, but 0 found.
//
// Root cause: the custom-usecase DI generator (`_generateCustomUseCaseDI`)
// only wired constructor args from the config's `effectiveRepos` /
// `effectiveService`, but the `di register` path carries NEITHER (it only
// knows the target class name + domain). The fix infers the constructor's
// required dependency type(s) from the already-generated usecase source and
// resolves them through `getIt`.
//
// These tests pin the fix by exercising `RegisterCapability` (the
// `zfa di register` code path) against a real usecase file emitted by
// `UseCasePlugin`, so the DI import resolves to a real file and the
// constructor call matches the real generated signature.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/di/capabilities/register_capability.dart';
import 'package:zuraffa/src/plugins/di/di_plugin.dart';
import 'package:zuraffa/src/plugins/usecase/usecase_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_issue_2118_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    final serviceDir = Directory(p.join(outputDir, 'domain', 'services'));
    await serviceDir.create(recursive: true);
    await File(
      p.join(serviceDir.path, 'import_orders_service.dart'),
    ).writeAsString(
      'abstract class ImportOrdersService {\n'
      '  Stream<ImportRow> import(ImportParams params);\n'
      '}',
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'di register wires the custom usecase service constructor argument',
    () async {
      // 1. Generate the custom stream usecase the way `zfa make` would —
      //    it declares a required service dependency in its constructor.
      final usecaseFiles =
          await UseCasePlugin(
            outputDir: outputDir,
            options: const GeneratorOptions(dryRun: false, force: true),
          ).generate(
            GeneratorConfig(
              name: 'ImportOrders',
              useCaseType: 'stream',
              domain: 'import_orders',
              service: 'ImportOrdersService',
              paramsType: 'ImportParams',
              returnsType: 'ImportRow',
              outputDir: outputDir,
            ),
          );

      final usecaseFile = usecaseFiles
          .where((f) => f.type == 'usecase')
          .map((f) => f.path)
          .first;
      final usecaseContent = File(usecaseFile).readAsStringSync();
      // Precondition: the generated usecase actually requires the service.
      expect(
        usecaseContent,
        contains('ImportOrdersUseCase(this._importOrdersService);'),
        reason:
            'the generated usecase constructor must inject the service — '
            'this is the signature the DI file must match',
      );

      // 2. `zfa di register --target=ImportOrdersUseCase --domain=import_orders`
      final diPlugin = DiPlugin(
        outputDir: outputDir,
        options: const GeneratorOptions(dryRun: false, force: true),
      );
      final register = RegisterCapability(diPlugin, projectRoot: tempDir.path);

      final result = await register.execute({
        'target': 'ImportOrdersUseCase',
        'domain': 'import_orders',
      });

      expect(result.success, isTrue);

      final diFile = File(
        p.join(outputDir, 'di', 'usecases', 'import_orders_usecase_di.dart'),
      );
      expect(
        diFile.existsSync(),
        isTrue,
        reason: 'di register must emit the usecase DI file',
      );

      final content = diFile.readAsStringSync();

      // The registration must resolve the service through getIt rather than
      // calling the constructor with no args.
      expect(
        content.contains('ImportOrdersUseCase()'),
        isFalse,
        reason:
            'the DI file must NOT call ImportOrdersUseCase with no args — '
            'the constructor requires ImportOrdersService (#2118)',
      );
      expect(
        content.contains('ImportOrdersUseCase(getIt<ImportOrdersService>())'),
        isTrue,
        reason:
            'the DI file must resolve the required ImportOrdersService '
            'dependency through getIt',
      );
      expect(
        content.contains('registerLazySingleton<ImportOrdersUseCase>'),
        isTrue,
      );
      // The import must point at the real service file.
      expect(
        content.contains(
          "import '../../domain/services/import_orders_service.dart';",
        ),
        isTrue,
      );
    },
  );

  test(
    'di register wires a *Repository constructor dependency through getIt',
    () async {
      // A custom usecase generated from a repo dependency declares
      // `Class(this._xRepository)` and requires a `*Repository` — the other
      // branch `_dependencyImportPath` resolves (review finding: the test
      // pinned only the `*Service` happy path).
      final usecaseFiles =
          await UseCasePlugin(
            outputDir: outputDir,
            options: const GeneratorOptions(dryRun: false, force: true),
          ).generate(
            GeneratorConfig(
              name: 'ListOrders',
              useCaseType: 'stream',
              domain: 'orders',
              repo: 'OrderRepository',
              paramsType: 'ListParams',
              returnsType: 'OrderRow',
              outputDir: outputDir,
            ),
          );

      final usecaseFile = usecaseFiles
          .where((f) => f.type == 'usecase')
          .map((f) => f.path)
          .first;
      final usecaseContent = File(usecaseFile).readAsStringSync();
      expect(
        usecaseContent,
        contains('ListOrdersUseCase(this._orderRepository);'),
        reason:
            'the generated usecase must inject the repository — this is the '
            'signature the DI file must match',
      );

      final register = RegisterCapability(
        DiPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        ),
        projectRoot: tempDir.path,
      );

      final result = await register.execute({
        'target': 'ListOrdersUseCase',
        'domain': 'orders',
      });

      expect(result.success, isTrue);

      final diFile = File(
        p.join(outputDir, 'di', 'usecases', 'list_orders_usecase_di.dart'),
      );
      expect(diFile.existsSync(), isTrue);

      final content = diFile.readAsStringSync();
      expect(
        content.contains('ListOrdersUseCase(getIt<OrderRepository>())'),
        isTrue,
        reason:
            'the DI file must resolve the required OrderRepository dependency '
            'through getIt',
      );
      expect(
        content.contains("import '../../domain/repositories/"),
        isTrue,
        reason: 'the repository import must point at the domain repositories',
      );
    },
  );

  test(
    'di register selects the unnamed constructor, not a leading named one',
    () async {
      // coderabbit finding: when a named constructor (`withService`) is
      // declared BEFORE the unnamed one, the inference loop must still select
      // the UNNAMED constructor the registration call actually invokes
      // (`refer(className).call(...)` → `Class.new`). Here the unnamed
      // constructor takes NO arguments and the leading named one requires a
      // service: selecting the named constructor (the pre-fix bug) would emit
      // `ReportsUseCase(getIt<ReportsService>())` against a zero-arg unnamed
      // constructor — a 1-arg-vs-0-positional analyzer failure. The correct
      // selection wires no argument at all.
      final usecaseDir = Directory(
        p.join(outputDir, 'domain', 'usecases', 'reports'),
      );
      await usecaseDir.create(recursive: true);
      await File(p.join(usecaseDir.path, 'reports_usecase.dart')).writeAsString(
        'class ReportsUseCase {\n'
        // Named constructor FIRST — the ordering the bug tripped on.
        '  ReportsUseCase.withService(ReportsService service)\n'
        '      : _reportsService = service;\n'
        // Unnamed constructor takes NO arguments — the one registration uses.
        '  ReportsUseCase();\n'
        '  ReportsService? _reportsService;\n'
        '  Stream<Row> run(Params p) => _reportsService!.run(p);\n'
        '}\n',
      );

      final register = RegisterCapability(
        DiPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(dryRun: false, force: true),
        ),
        projectRoot: tempDir.path,
      );

      final result = await register.execute({
        'target': 'ReportsUseCase',
        'domain': 'reports',
      });

      expect(result.success, isTrue);

      final diFile = File(
        p.join(outputDir, 'di', 'usecases', 'reports_usecase_di.dart'),
      );
      final content = diFile.readAsStringSync();
      expect(
        content.contains('ReportsUseCase()'),
        isTrue,
        reason:
            'the unnamed (zero-arg) constructor must be selected and wired '
            'with no arguments — selecting the leading named constructor '
            'would emit an argument the unnamed constructor cannot accept',
      );
      expect(
        content.contains('ReportsUseCase(getIt'),
        isFalse,
        reason:
            'no getIt argument may be emitted: the unnamed constructor takes '
            'none, so wiring one reproduces the analyzer failure (#2118)',
      );
    },
  );
}
