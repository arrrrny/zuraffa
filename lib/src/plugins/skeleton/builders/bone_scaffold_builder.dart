/// Writes the working-slice bone directory tree (042).
///
/// Library mode emits: bone.yaml, entities/, domain/ (repositories +
/// usecases), data/ (datasources + repositories), di/, test/.
/// `--flutter` mode additionally emits: pubspec.yaml, lib/main.dart,
/// `presentation/<feature>_page.dart`, and the page widget test.
library;

import 'dart:io';

import '../models/bone.dart';
import 'entity_stub_builder.dart';
import 'manifest_builder.dart';
import 'slice/app_entry_builder.dart';
import 'slice/datasource_builder.dart';
import 'slice/injection_builder.dart';
import 'slice/presentation_builder.dart';
import 'slice/repository_builder.dart';
import 'slice/usecase_builder.dart';

/// Builds the bone directory structure on the filesystem.
class BoneScaffoldBuilder {
  /// Creates a [BoneScaffoldBuilder].
  BoneScaffoldBuilder({
    ManifestBuilder? manifestBuilder,
    EntityStubBuilder? entityStubBuilder,
  }) : manifestBuilder = manifestBuilder ?? ManifestBuilder(),
       entityStubBuilder = entityStubBuilder ?? EntityStubBuilder();

  final ManifestBuilder manifestBuilder;
  final EntityStubBuilder entityStubBuilder;

  /// Writes the bone scaffold to the filesystem at [boneDir].
  Future<void> build(Bone bone, String boneDir) async {
    // Atomic regeneration: replace any previous bone (042, FR-014).
    final existing = Directory(boneDir);
    if (await existing.exists()) {
      await existing.delete(recursive: true);
    }

    await _write(boneDir, 'bone.yaml', manifestBuilder.render(bone.manifest));

    // Entities: own entities with full wiring + inlined dependency entities
    // (entity files only).
    for (final stub in bone.entityStubs) {
      await _write(boneDir, stub.sourcePath, entityStubBuilder.build(stub));
    }
    for (final stub in bone.inlinedEntities) {
      await _write(boneDir, stub.sourcePath, entityStubBuilder.build(stub));
    }

    final repositoryBuilder = RepositoryBuilder();
    final datasourceBuilder = DataSourceBuilder();
    final usecaseBuilder = UseCaseBuilder();

    for (final stub in bone.entityStubs) {
      final snake = pascalToSnake(stub.name);

      // Domain.
      await _write(
        boneDir,
        'domain/repositories/${snake}_repository.dart',
        repositoryBuilder.buildRepositoryInterface(stub.name, stub.fields),
      );
      final usecases = usecaseBuilder.buildAll(stub.name);
      for (final entry in usecases.entries) {
        await _write(boneDir, 'domain/usecases/${entry.key}', entry.value);
      }

      // Data.
      await _write(
        boneDir,
        'data/datasources/${snake}_datasource.dart',
        repositoryBuilder.buildDataSourceInterface(stub.name),
      );
      await _write(
        boneDir,
        'data/datasources/${snake}_mock.dart',
        datasourceBuilder.buildMock(stub.name, stub.fields),
      );
      await _write(
        boneDir,
        'data/datasources/${snake}_firebase.dart',
        datasourceBuilder.buildFirebase(stub.name, stub.fields),
      );
      await _write(
        boneDir,
        'data/repositories/data_${snake}_repository.dart',
        repositoryBuilder.buildDataImplementation(stub.name),
      );

      // Per-entity tests.
      await _write(boneDir, 'test/${snake}_test.dart', _buildEntityTest(stub));
    }

    // DI container + wiring test (single source of truth: the manifest).
    final diChoice = bone.manifest.diChoice;
    if (diChoice != null) {
      final injectionBuilder = InjectionBuilder();
      await _write(
        boneDir,
        'di/injection.dart',
        injectionBuilder.build(
          featureSlug: bone.featureSlug,
          entities: [
            for (final stub in bone.entityStubs) (stub.name, stub.fields),
          ],
          diChoice: diChoice,
        ),
      );
      await _write(boneDir, 'test/di_test.dart', _buildDiTest(bone));
    }

    // Flutter extras.
    if (bone.manifest.flutter) {
      final appEntry = AppEntryBuilder();
      await _write(
        boneDir,
        'pubspec.yaml',
        appEntry.buildPubspec(bone.featureSlug),
      );
      await _write(
        boneDir,
        'lib/main.dart',
        appEntry.buildMainDart(bone.featureSlug),
      );

      final presentation = PresentationBuilder();
      final primary = bone.entityStubs.first;
      await _write(
        boneDir,
        'presentation/${slugToSnakeCase(bone.featureSlug)}_page.dart',
        presentation.buildPage(
          featureSlug: bone.featureSlug,
          primaryEntity: primary.name,
          fields: primary.fields,
        ),
      );
      await _write(
        boneDir,
        'test/${slugToSnakeCase(bone.featureSlug)}_page_test.dart',
        presentation.buildPageTest(
          featureSlug: bone.featureSlug,
          primaryEntity: primary.name,
        ),
      );
    }
  }

  Future<void> _write(
    String boneDir,
    String relativePath,
    String content,
  ) async {
    final file = File('$boneDir/$relativePath');
    await file.create(recursive: true);
    await file.writeAsString(content);
  }

  /// The self-contained per-entity test: plain Dart, `dart run`-able with no
  /// pub get, no network (042, FR-012 / US6).
  String _buildEntityTest(EntityStub stub) {
    final name = stub.name;
    final snake = pascalToSnake(name);
    final fields = stub.fields;
    final buffer = StringBuffer();

    buffer.writeln("import '../entities/$snake.dart';");
    buffer.writeln();
    buffer.writeln('/// Self-contained test for the $name entity.');
    buffer.writeln('/// Run with: `dart test/${snake}_test.dart`.');
    buffer.writeln('void main() {');
    if (fields.isEmpty) {
      buffer.writeln('  const instance = $name();');
      buffer.writeln(
        "  _check(instance.toJson().isEmpty, 'field-less toJson is empty');",
      );
      buffer.writeln(
        '  final roundTripped = $name.fromJson(instance.toJson());',
      );
      buffer.writeln('  _check(');
      buffer.writeln('    validate$name(roundTripped).isEmpty,');
      buffer.writeln("    'validate passes for a field-less instance',");
      buffer.writeln('  );');
    } else {
      buffer.writeln('  final original = $name(');
      for (final field in fields.where((f) => !f.nullable)) {
        buffer.writeln(
          '    ${field.name}: ${EntityStubBuilder.sampleValue(field)},',
        );
      }
      buffer.writeln('  );');
      buffer.writeln(
        '  final roundTripped = $name.fromJson(original.toJson());',
      );
      for (final field in fields) {
        buffer.writeln('  _check(');
        buffer.writeln('    ${_roundTripCheck(field)},');
        buffer.writeln("    '${field.name} round-trips',");
        buffer.writeln('  );');
      }
      final editTargets = fields
          .where((f) => !f.nullable && f.type == 'String')
          .toList();
      if (editTargets.isNotEmpty) {
        final editField = editTargets.last;
        buffer.writeln('  final edited = original.copyWith(');
        buffer.writeln(
          '    ${editField.name}: ${EntityStubBuilder.editValue(editField)},',
        );
        buffer.writeln('  );');
        buffer.writeln('  _check(');
        buffer.writeln(
          '    edited.${editField.name} != original.${editField.name},',
        );
        buffer.writeln("    'copyWith overrides ${editField.name}',");
        buffer.writeln('  );');
      }
      final blankTargets = fields
          .where((f) => !f.nullable && f.type == 'String')
          .toList();
      if (blankTargets.isNotEmpty) {
        final blankField = blankTargets.first;
        buffer.writeln('  final blank = original.copyWith(');
        buffer.writeln("    ${blankField.name}: ' ',");
        buffer.writeln('  );');
        buffer.writeln('  _check(');
        buffer.writeln('    validate$name(blank).isNotEmpty,');
        buffer.writeln("    'validate flags blank required fields',");
        buffer.writeln('  );');
      }
      buffer.writeln('  _check(');
      buffer.writeln('    validate$name(original).isEmpty,');
      buffer.writeln("    'validate passes a filled instance',");
      buffer.writeln('  );');
      final requiredFields = fields.where((f) => !f.nullable).toList();
      if (requiredFields.isNotEmpty) {
        buffer.writeln(
          '  final missing = Map<String, dynamic>.of(original.toJson())',
        );
        buffer.writeln("    ..remove('${requiredFields.first.name}');");
        buffer.writeln('  Object? thrown;');
        buffer.writeln('  try {');
        buffer.writeln('    $name.fromJson(missing);');
        buffer.writeln('  } catch (e) {');
        buffer.writeln('    thrown = e;');
        buffer.writeln('  }');
        buffer.writeln('  _check(');
        buffer.writeln('    thrown is FormatException,');
        buffer.writeln("    'fromJson rejects missing required fields',");
        buffer.writeln('  );');
      }
    }
    buffer.writeln("  print('$snake test: PASS');");
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('void _check(bool condition, String label) {');
    buffer.writeln("  if (!condition) throw StateError('FAILED: ' + label);");
    buffer.writeln('}');
    return buffer.toString();
  }

  String _roundTripCheck(EntityField field) {
    switch (field.type) {
      case 'List<String>':
        return 'original.${field.name}.length == '
            'roundTripped.${field.name}.length && '
            '(original.${field.name}.isEmpty || '
            'original.${field.name}.first == '
            'roundTripped.${field.name}.first)';
      case 'Map<String, dynamic>':
        return 'original.${field.name}.length == '
            'roundTripped.${field.name}.length';
      default:
        return 'original.${field.name} == roundTripped.${field.name}';
    }
  }

  /// The self-contained DI wiring test: mock backend end-to-end through the
  /// container plus the firebase-without-credentials guard (042, US2/US6).
  String _buildDiTest(Bone bone) {
    final pascal = slugToPascalCase(bone.featureSlug);
    final primary = bone.entityStubs.first;
    final camel = pascalToCamel(primary.name);
    final hasPk = primary.fields.isNotEmpty;
    final sampleArgs = primary.fields
        .where((f) => !f.nullable)
        .map((f) => '${f.name}: ${EntityStubBuilder.sampleValue(f)}')
        .join(', ');
    final pk = hasPk
        ? DataSourceBuilder().primaryKeyExpr(primary.fields, 'sample')
        : "'di-check'";
    final defaultBackend = bone.manifest.diChoice!.backendName;
    final usesMockDefault = defaultBackend == 'mock';

    final buffer = StringBuffer();
    buffer.writeln("import '../entities/${pascalToSnake(primary.name)}.dart';");
    buffer.writeln("import '../di/injection.dart';");
    buffer.writeln();
    buffer.writeln('/// DI wiring test for the ${bone.featureSlug} bone.');
    buffer.writeln('/// Run with: `dart test/di_test.dart`.');
    buffer.writeln('Future<void> main() async {');
    if (usesMockDefault) {
      buffer.writeln('  final services = ${pascal}Services.create();');
      buffer.writeln('  _check(');
      buffer.writeln('    services.backend == BoneBackend.mock,');
      buffer.writeln(
        "    'default backend is mock (baked by --di $defaultBackend)',",
      );
      buffer.writeln('  );');
    } else {
      buffer.writeln(
        '  final services = '
        '${pascal}Services.create(backend: BoneBackend.mock);',
      );
      buffer.writeln('  _check(');
      buffer.writeln('    services.backend == BoneBackend.mock,');
      buffer.writeln("    'runtime override selects the mock backend',");
      buffer.writeln('  );');
      buffer.writeln('  Object? defaultGuard;');
      buffer.writeln('  try {');
      buffer.writeln('    ${pascal}Services.create();');
      buffer.writeln('  } catch (e) {');
      buffer.writeln('    defaultGuard = e;');
      buffer.writeln('  }');
      buffer.writeln('  _check(');
      buffer.writeln('    defaultGuard is StateError,');
      buffer.writeln(
        "    'firebase default without credentials is a StateError',",
      );
      buffer.writeln('  );');
    }
    buffer.writeln(
      '  final seeded = '
      'await services.${camel}Repository.getAll${primary.name}s();',
    );
    buffer.writeln("  _check(seeded.isNotEmpty, 'mock store is seeded');");
    if (hasPk) {
      buffer.writeln('  final sample = ${primary.name}($sampleArgs);');
      buffer.writeln('  await services.create${primary.name}(sample);');
      buffer.writeln('  final byId = await services.get${primary.name}($pk);');
      buffer.writeln(
        "  _check(byId != null, 'create + get round-trip through DI');",
      );
      buffer.writeln('  await services.delete${primary.name}($pk);');
      buffer.writeln(
        '  final afterDelete = await services.get${primary.name}($pk);',
      );
      buffer.writeln("  _check(afterDelete == null, 'delete through DI');");
    }
    buffer.writeln('  Object? thrown;');
    buffer.writeln('  try {');
    buffer.writeln(
      '    ${pascal}Services.create(backend: BoneBackend.firebase);',
    );
    buffer.writeln('  } catch (e) {');
    buffer.writeln('    thrown = e;');
    buffer.writeln('  }');
    buffer.writeln('  _check(');
    buffer.writeln('    thrown is StateError,');
    buffer.writeln("    'firebase without credentials throws StateError',");
    buffer.writeln('  );');
    buffer.writeln("  _check(");
    buffer.writeln("    '\$thrown'.toLowerCase().contains('credential'),");
    buffer.writeln("    'error names credentials',");
    buffer.writeln('  );');
    buffer.writeln("  print('di test: PASS');");
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('void _check(bool condition, String label) {');
    buffer.writeln("  if (!condition) throw StateError('FAILED: ' + label);");
    buffer.writeln('}');
    return buffer.toString();
  }
}
