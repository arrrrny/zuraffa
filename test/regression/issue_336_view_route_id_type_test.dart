// Regression test for issue #336:
// https://github.com/arrrrny/zuraffa/issues/336
//
// `zfa view create` hardcoded the route id param as `String?` while
// `zfa make` types the presenter/controller accessor after the entity's
// ACTUAL id field type. For an entity whose route id path param is
// String (the go_router convention) but whose id field is `int`, the
// regenerated view's `onInitState` passed `widget.id!` (String) into an
// int-typed accessor → argument_type_not_assignable.
//
// Fix:
//   - `CreateViewCapability` / `CreateRouteCapability` resolve the id
//     type by probing the entity source (EntityFieldResolver), falling
//     back to the persisted args of the last `zfa make` run
//     (`.zfa/plans/last_run_<Entity>.json`) for entities whose identity
//     was declared explicitly at make time (e.g. CustomerProfile →
//     yearOfBirth:int, no id-like field on the entity itself).
//   - `RouteBuilder` converts the String path parameter with
//     int.parse/double.parse/num.parse when the id type is numeric.

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/plan_store.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/route/builders/route_builder.dart';
import 'package:zuraffa/src/plugins/route/route_plugin.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';
import 'package:zuraffa/src/utils/entity_id_type.dart';

void main() {
  late Directory tempDir;
  late String originalCwd;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_issue336_');
    // The capabilities resolve the project root from the CWD; run inside
    // the temp project so the entity probe and the persisted-plan
    // fallback read the temp fixtures, not the zuraffa repo itself.
    originalCwd = Directory.current.path;
    Directory.current = tempDir.path;
    PlanStore.instance.rootDirectory = tempDir.path;
  });

  tearDown(() async {
    Directory.current = originalCwd;
    PlanStore.instance.rootDirectory = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Directory entityDir(String snake) =>
      Directory('${tempDir.path}/lib/src/domain/entities/$snake');

  Future<void> writeEntity(String snake, String body) async {
    final dir = entityDir(snake);
    await dir.create(recursive: true);
    await File('${dir.path}/$snake.dart').writeAsString(body);
  }

  // ─────────────────────────────────────────────────────────────────
  // Resolver: probe entity source, then persisted make-plan args
  // ─────────────────────────────────────────────────────────────────

  group('issue #336 — resolveEntityIdFieldType', () {
    test('probes int id field from the entity source', () async {
      await writeEntity(
        'gadget',
        '@Zorphy()\n'
        'abstract class \$Gadget {\n'
        '  int get id;\n'
        '  String get name;\n'
        '}\n',
      );

      final type = await resolveEntityIdFieldType(
        entityName: 'Gadget',
        projectRoot: tempDir.path,
      );
      expect(type, 'int');
    });

    test(
      'falls back to the last make-plan id-field-type for entities with '
      'no id-like field (CustomerProfile case)',
      () async {
        // Entity has NO id-like field; its identity was declared at make
        // time via --id-field=yearOfBirth --id-field-type=int.
        await writeEntity(
          'wardrobe',
          '@Zorphy()\n'
          'abstract class \$Wardrobe {\n'
          '  int get yearOfBirth;\n'
          '  String get style;\n'
          '}\n',
        );
        final plansDir = Directory('${tempDir.path}/.zfa/plans');
        await plansDir.create(recursive: true);
        await File('${plansDir.path}/last_run_Wardrobe.json').writeAsString(
          '{"plan_id":"last_run_Wardrobe","plugin_id":"manager",'
          '"capability_name":"make","args":{"name":"Wardrobe",'
          '"id-field":"yearOfBirth","id-field-type":"int"},'
          '"changes":[],"valid":true}',
        );

        final type = await resolveEntityIdFieldType(
          entityName: 'Wardrobe',
          projectRoot: tempDir.path,
        );
        expect(type, 'int');
      },
    );

    test('returns null when neither source yields a type', () async {
      final type = await resolveEntityIdFieldType(
        entityName: 'Ghost',
        projectRoot: tempDir.path,
      );
      expect(type, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // View: route id param typed after the entity's actual id type
  // ─────────────────────────────────────────────────────────────────

  group('issue #336 — zfa view create id param type', () {
    test(
      'int-id entity gets `final int? id` and passes int into the '
      'accessor (String route id convention vs int entity id)',
      () async {
        await writeEntity(
          'gadget',
          '@Zorphy()\n'
          'abstract class \$Gadget {\n'
          '  int get id;\n'
          '  String get name;\n'
          '}\n',
        );

        final plugin = ViewPlugin(
          outputDir: 'lib/src',
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final capability = plugin.capabilities.firstWhere(
          (c) => c.name == 'create',
        );
        final result = await capability.execute({
          'name': 'Gadget',
          'methods': ['get'],
          'di': true,
          'force': true,
        });

        final files = result.data?['generatedFiles'] as List;
        expect(files, isNotEmpty);
        final content = (files.first as dynamic).content as String;

        expect(
          content.contains('final int? id;'),
          isTrue,
          reason:
              'the route id param must be typed after the entity id field '
              '(int), not the String path-param convention (#336).',
        );
        expect(
          content.contains('final String? id;'),
          isFalse,
          reason: 'String-typed id param is what caused '
              'argument_type_not_assignable for int-id entities.',
        );
        expect(
          content.contains('controller.getGadget(widget.id!)'),
          isTrue,
          reason: 'onInitState must still pass the id into the accessor.',
        );

        // The generated view must actually compile against an int-typed
        // accessor: simulate the controller signature from #336.
        expect(
          RegExp(r'getGadget\(widget\.id!\)').hasMatch(content) &&
              !content.contains('final String? id'),
          isTrue,
        );
      },
    );

    test(
      'no-id-like-field entity restores int id type from the last make '
      'plan (CustomerProfile repro)',
      () async {
        await writeEntity(
          'customer_profile',
          '@Zorphy()\n'
          'abstract class \$CustomerProfile {\n'
          '  int get yearOfBirth;\n'
          '  String get shoppingStyle;\n'
          '}\n',
        );
        final plansDir = Directory('${tempDir.path}/.zfa/plans');
        await plansDir.create(recursive: true);
        await File(
          '${plansDir.path}/last_run_CustomerProfile.json',
        ).writeAsString(
          '{"plan_id":"last_run_CustomerProfile","plugin_id":"manager",'
          '"capability_name":"make","args":{"name":"CustomerProfile",'
          '"id-field":"yearOfBirth","id-field-type":"int"},'
          '"changes":[],"valid":true}',
        );

        final plugin = ViewPlugin(
          outputDir: 'lib/src',
          options: const GeneratorOptions(
            dryRun: false,
            force: true,
            verbose: false,
          ),
        );
        final capability = plugin.capabilities.firstWhere(
          (c) => c.name == 'create',
        );
        final result = await capability.execute({
          'name': 'CustomerProfile',
          'methods': ['get'],
          'di': true,
          'force': true,
        });

        final files = result.data?['generatedFiles'] as List;
        final content = (files.first as dynamic).content as String;
        expect(
          content.contains('final int? id;'),
          isTrue,
          reason:
              'the id type must be restored from the persisted make-plan '
              'args when the entity has no id-like field (#336).',
        );
        expect(content.contains('controller.getCustomerProfile(widget.id!)'),
            isTrue);
      },
    );

    test('string-id entity keeps the String id param (no regression)',
        () async {
      await writeEntity(
        'product',
        '@Zorphy()\n'
        'abstract class \$Product {\n'
        '  String get id;\n'
        '  String get name;\n'
        '}\n',
      );

      final plugin = ViewPlugin(
        outputDir: 'lib/src',
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      final capability = plugin.capabilities.firstWhere(
        (c) => c.name == 'create',
      );
      final result = await capability.execute({
        'name': 'Product',
        'methods': ['get'],
        'di': true,
        'force': true,
      });

      final files = result.data?['generatedFiles'] as List;
      final content = (files.first as dynamic).content as String;
      expect(content.contains('final String? id;'), isTrue);
      expect(content.contains('controller.getProduct(widget.id!)'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // Route: String path params converted for numeric id types
  // ─────────────────────────────────────────────────────────────────

  group('issue #336 — route id path param conversion', () {
    test('int id type emits int.parse(state.pathParameters[\'id\']!)',
        () async {
      final viewDir =
          Directory('${tempDir.path}/lib/src/presentation/pages/gadget');
      await viewDir.create(recursive: true);
      await File('${viewDir.path}/gadget_view.dart')
          .writeAsString('// stub view file\n');
      await File('${viewDir.path}/gadget_detail_view.dart')
          .writeAsString('// stub detail view file\n');

      final builder = RouteBuilder(
        outputDir: 'lib/src',
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      await builder.generate(
        GeneratorConfig(
          name: 'Gadget',
          methods: const ['get', 'getList'],
          generateVpcs: true,
          generateRoute: true,
          idFieldType: 'int',
          outputDir: 'lib/src',
        ),
      );

      final routesFile =
          File('${tempDir.path}/lib/src/routing/gadget_routes.dart');
      expect(routesFile.existsSync(), isTrue);
      final content = routesFile.readAsStringSync();
      expect(
        content.contains("int.parse(state.pathParameters['id']!)"),
        isTrue,
        reason:
            'go_router path params are String; an int-typed view id param '
            'must be converted with int.parse (#336).',
      );
    });

    test('String id type keeps the raw path parameter (no int.parse)',
        () async {
      final viewDir =
          Directory('${tempDir.path}/lib/src/presentation/pages/product');
      await viewDir.create(recursive: true);
      await File('${viewDir.path}/product_view.dart')
          .writeAsString('// stub view file\n');
      await File('${viewDir.path}/product_detail_view.dart')
          .writeAsString('// stub detail view file\n');

      final builder = RouteBuilder(
        outputDir: 'lib/src',
        options: const GeneratorOptions(
          dryRun: false,
          force: true,
          verbose: false,
        ),
      );
      await builder.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'getList'],
          generateVpcs: true,
          generateRoute: true,
          idFieldType: 'String',
          outputDir: 'lib/src',
        ),
      );

      final routesFile =
          File('${tempDir.path}/lib/src/routing/product_routes.dart');
      expect(routesFile.existsSync(), isTrue);
      final content = routesFile.readAsStringSync();
      expect(
        content.contains("state.pathParameters['id']!"),
        isTrue,
      );
      expect(
        content.contains('int.parse'),
        isFalse,
        reason: 'String ids must be passed through unchanged.',
      );
    });

    test('route capability resolves int id type by probing the entity',
        () async {
      await writeEntity(
        'gadget',
        '@Zorphy()\n'
        'abstract class \$Gadget {\n'
        '  int get id;\n'
        '  String get name;\n'
        '}\n',
      );
      final viewDir =
          Directory('${tempDir.path}/lib/src/presentation/pages/gadget');
      await viewDir.create(recursive: true);
      await File('${viewDir.path}/gadget_view.dart')
          .writeAsString('// stub view file\n');
      await File('${viewDir.path}/gadget_detail_view.dart')
          .writeAsString('// stub detail view file\n');

      final plugin = RoutePlugin(outputDir: 'lib/src');
      final capability = plugin.capabilities.firstWhere(
        (c) => c.name == 'create',
      );
      await capability.execute({
        'name': 'Gadget',
        'methods': ['get', 'getList'],
        'force': true,
      });

      final routesFile =
          File('${tempDir.path}/lib/src/routing/gadget_routes.dart');
      expect(routesFile.existsSync(), isTrue);
      final content = routesFile.readAsStringSync();
      expect(
        content.contains("int.parse(state.pathParameters['id']!)"),
        isTrue,
        reason:
            'zfa route create must probe the entity id type and convert '
            'the String path param for int-id entities (#336).',
      );
    });
  });
}
