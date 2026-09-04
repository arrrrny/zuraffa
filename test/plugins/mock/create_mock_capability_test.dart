import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/mock/capabilities/create_mock_capability.dart';
import 'package:zuraffa/src/plugins/mock/mock_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;
  late MockPlugin plugin;
  late CreateMockCapability capability;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_mock_create_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
    final entityDir = Directory('$outputDir/domain/entities/product');
    entityDir.createSync(recursive: true);
    File('${entityDir.path}/product.dart').writeAsStringSync(
      'class Product { final String id; final String name; const Product(this.id, this.name); }',
    );
    plugin = MockPlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(dryRun: false, force: true),
    );
    capability = CreateMockCapability(plugin);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.delete(recursive: true);
    }
  });

  // Issue #770: `zfa mock create --name X` (and the positional `zfa mock X`)
  // both funnel into MockPlugin with an explicit mock request
  // (`generateMock: true`) and no data-layer flags. The plugin's stale
  // presentation-only gate then returned [] — zero files, no warning, exit 0
  // — even though the user explicitly asked for mocks. The builder itself is
  // standalone-safe: since #417 the mock-datasource path emits the missing
  // datasource interface itself, and the data-only path has always
  // generated. An explicit mock request must always generate. And the
  // capability must default to the canonical CRUD method set (#294) so the
  // emitted mock datasource actually satisfies the interface it implements.
  group('issue #770 — explicit mock request is never a silent no-op', () {
    test(
      'capability: minimal invocation generates mock artifacts (canonical methods)',
      () async {
        final result = await capability.execute({'name': 'Product'});

        expect(result.success, isTrue);
        expect(result.files, isNotEmpty);
        expect(
          result.files.any(
            (p) => p.endsWith('data/mock/product_mock_data.dart'),
          ),
          isTrue,
          reason: 'the mock data artifact for the entity is generated',
        );
        expect(
          result.files.any(
            (p) =>
                p.endsWith(
                  'data/datasources/product/product_mock_datasource.dart',
                ) ||
                p.endsWith('data/mock/product_mock_provider.dart'),
          ),
          isTrue,
          reason: 'the mock datasource (or provider) artifact is generated',
        );
      },
    );

    test(
      'capability: emitted mock datasource implements the interface members',
      () async {
        final result = await capability.execute({'name': 'Product'});
        final generated = result.data?['generatedFiles'] as List<dynamic>;

        final mockDatasources = generated
            .where(
              (f) => f.path.endsWith(
                'data/datasources/product/product_mock_datasource.dart',
              ),
            )
            .toList();
        if (mockDatasources.isNotEmpty) {
          final mockDatasource = mockDatasources.first;
          expect(mockDatasource.content, contains('get'));
          expect(
            mockDatasource.content,
            contains('update'),
            reason:
                'with the canonical method set the mock datasource must '
                'provide concrete implementations, otherwise analyze fails '
                'with non_abstract_class_inherits_abstract_member (#294)',
          );
        }
      },
    );

    test('capability: schema declares NO static methods default — it is '
        'mode-dependent (entity CRUD vs service conformance, issue #1027)', () {
      final props =
          capability.inputSchema['properties'] as Map<String, dynamic>;
      expect(
        (props['methods'] as Map<String, dynamic>)['default'],
        isNull,
        reason:
            'a static schema default would materialize through '
            'CapabilityCommand (addMultiOption defaultsTo:) and the '
            'service-mode branch in execute() could never fire (#1027). '
            'The effective default is applied in execute(): the canonical '
            'CRUD set for entity mode (#770/#294), an empty set for '
            'service mode.',
      );
    });

    test(
      'plugin: generateMock without any data-layer flags generates the mock artifacts',
      () async {
        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const ['get', 'update', 'toggle'],
            generateMock: true,
            generateData: false,
            generateDataSource: false,
            generateRepository: false,
            appendToExisting: false,
            outputDir: outputDir,
          ),
        );

        expect(
          files,
          isNotEmpty,
          reason: 'an explicit mock request must not silently generate nothing',
        );
        expect(
          files.any((f) => f.path.endsWith('data/mock/product_mock_data.dart')),
          isTrue,
        );
      },
    );

    test(
      'plugin: generateMockDataOnly keeps generating the standalone fixtures',
      () async {
        final files = await plugin.generate(
          GeneratorConfig(
            name: 'Product',
            methods: const [],
            generateMock: false,
            generateMockDataOnly: true,
            generateData: false,
            generateDataSource: false,
            generateRepository: false,
            appendToExisting: false,
            outputDir: outputDir,
          ),
        );

        expect(files, isNotEmpty);
        expect(
          files.any((f) => f.path.endsWith('data/mock/product_mock_data.dart')),
          isTrue,
        );
      },
    );

    test('plugin: generated artifacts are written to disk', () async {
      final files = await plugin.generate(
        GeneratorConfig(
          name: 'Product',
          methods: const ['get', 'update', 'toggle'],
          generateMock: true,
          generateData: false,
          generateDataSource: false,
          generateRepository: false,
          appendToExisting: false,
          outputDir: outputDir,
        ),
      );

      expect(files, isNotEmpty);
      for (final file in files) {
        expect(
          File(file.path).existsSync(),
          isTrue,
          reason: '${file.path} must be written',
        );
      }
    });
  });

  group(
    'issue #1027 — service-mode mock conforms to the service interface',
    () {
      test(
        'capability: --service with no explicit methods parses the interface '
        'and generates a conforming provider (no entity-methods crash)',
        () async {
          // Scaffold the internal service interface (production shape:
          // AuthService.login(AuthRequest) -> User).
          final serviceDir = Directory('$outputDir/domain/services');
          serviceDir.createSync(recursive: true);
          File('${serviceDir.path}/auth_service.dart').writeAsStringSync('''
abstract class AuthService {
  Future<User> login(AuthRequest params);
}
''');

          // No 'methods' key — the exact CLI shape of
          // `zfa mock create --name Auth --service Auth ...`. Before the fix
          // this crashed with ArgumentError('Unknown entity method: toggle')
          // because the entity-CRUD default hijacked the service path.
          final result = await capability.execute({
            'name': 'Auth',
            'service': 'Auth',
            'domain': 'auth',
            'params': 'AuthRequest',
            'returns': 'User',
          });

          expect(
            result.success,
            isTrue,
            reason: 'service mode must not crash on the entity-methods default',
          );

          final providerPath = result.files
              .where((p) => p.contains('data/providers/'))
              .firstOrNull;
          expect(
            providerPath,
            isNotNull,
            reason: 'a mock provider is generated',
          );
          final content = File(providerPath!).readAsStringSync();

          expect(
            content.contains('implements AuthService'),
            isTrue,
            reason: 'the provider implements the declared service interface',
          );
          expect(
            content.contains('login'),
            isTrue,
            reason:
                'the provider conforms to the interface login method '
                '(parsed from the interface, not the entity-CRUD default)',
          );
          expect(content.contains("Unknown entity method"), isFalse);
        },
      );

      test('CLI layer: unprovided --methods via CapabilityCommand conforms in '
          'service mode and keeps the CRUD default in entity mode', () async {
        final serviceDir = Directory('$outputDir/domain/services');
        serviceDir.createSync(recursive: true);
        File('${serviceDir.path}/auth_service.dart').writeAsStringSync('''
abstract class AuthService {
  Future<User> auth(AuthRequest params);

  Future<User> login(AuthRequest params);
}
''');

        // Drive the real CLI layer: CapabilityCommand materializes
        // schema-derived argResults into the capability args map. Before
        // the schema default was removed, an unprovided --methods arrived
        // here as ['get','update','toggle'] and crashed service mode; with
        // the default removed it arrives as [] and must not strip the
        // entity-mode CRUD default (#770).
        final runner = CommandRunner('zfa_test', 'capability command test')
          ..addCommand(CapabilityCommand(capability));

        // Service mode: no --methods — must conform to the interface.
        await runner.run([
          'create',
          '--name',
          'Auth',
          '--service',
          'Auth',
          '--domain',
          'auth',
          '--params',
          'AuthRequest',
          '--returns',
          'User',
        ]);
        final providerPath = File(
          '$outputDir/data/providers/auth/auth_mock_provider.dart',
        );
        expect(
          providerPath.existsSync(),
          isTrue,
          reason: 'service-mode provider generated through the CLI layer',
        );
        final providerContent = providerPath.readAsStringSync();
        expect(providerContent.contains('implements AuthService'), isTrue);
        expect(providerContent.contains('login'), isTrue);

        // Issue #1030 follow-up: the canned return must come from the
        // RETURNS type's mock data (UserMockData.sampleUser), not from a
        // phantom class named after --name (AuthMockData.sampleAuth).
        expect(providerContent.contains('UserMockData.sampleUser'), isTrue);
        expect(providerContent.contains('AuthMockData'), isFalse);

        // Entity mode: no --methods — the canonical CRUD default survives.
        await runner.run(['create', '--name', 'Product']);
        final datasourcePath = File(
          '$outputDir/data/datasources/product/product_mock_datasource.dart',
        );
        expect(
          datasourcePath.existsSync(),
          isTrue,
          reason:
              'entity-mode mock datasource generated through the CLI '
              'layer (empty-list must not strip the CRUD default)',
        );
        final datasourceContent = datasourcePath.readAsStringSync();
        expect(
          datasourceContent.contains('toggle'),
          isTrue,
          reason: 'the canonical CRUD method set is applied in entity mode',
        );
      });
    },
  );
}
