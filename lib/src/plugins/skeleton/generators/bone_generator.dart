/// Orchestrates one bone build: reads spec, validates, writes scaffold.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../builders/bone_scaffold_builder.dart';
import '../models/bone.dart';
import '../models/dependency_graph.dart';
import 'dependency_resolver.dart';
import 'spec_reader.dart';

/// Error thrown when the bone generator refuses to produce output.
class BoneGenerationError implements Exception {
  /// Creates a [BoneGenerationError].
  const BoneGenerationError(this.message);

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'BoneGenerationError: $message';
}

/// Orchestrates bone generation for a single feature.
class BoneGenerator {
  /// Creates a [BoneGenerator].
  BoneGenerator({SpecReader? specReader, BoneScaffoldBuilder? scaffoldBuilder})
    : specReader = specReader ?? SpecReader(),
      scaffoldBuilder = scaffoldBuilder ?? BoneScaffoldBuilder();

  final SpecReader specReader;
  final BoneScaffoldBuilder scaffoldBuilder;

  /// Generates the bone for the spec at [specPath] into [outputDir].
  ///
  /// Returns the path to the generated bone directory.
  ///
  /// Throws [BoneGenerationError] if the spec is invalid or generation fails.
  /// On failure, no partial output is left behind.
  ///
  /// When [specsRoot] is provided, cross-feature dependency resolution is
  /// performed: the generator scans all feature specs under [specsRoot] to
  /// build a dependency graph and populates the manifest accordingly.
  Future<String> generate({
    required File specPath,
    required String outputDir,
    String? specsRoot,
  }) async {
    // 1. Read spec.
    final specResult = specReader.read(specPath);

    // 2. Validate: must have at least one entity (U19).
    if (specResult.entities.isEmpty) {
      throw const BoneGenerationError(
        'Spec declares no entities. At least one entity is required.',
      );
    }

    // 3. Build models.
    final featureSlug = specResult.featureSlug;
    final boneDir = p.join(outputDir, featureSlug);

    final entityStubs = specResult.entities
        .map(
          (name) => EntityStub(
            name: name,
            sourcePath: 'lib/entities/${_toSnake(name)}.dart',
          ),
        )
        .toList();

    // 4. Resolve dependencies if specsRoot is provided.
    var dependencies = <BoneDependency>[];
    if (specsRoot != null) {
      dependencies = _resolveDependencies(specsRoot, featureSlug);
    }

    final manifest = BoneManifest(
      version: 1,
      feature: featureSlug,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      specVersion: 'sha256:${specResult.specVersion}',
      entities: specResult.entities,
      dependencies: dependencies,
      layers: ['domain', 'data', 'presentation'],
      xray: specResult.xrayMarkers,
    );

    final layers = [
      const LayerPlaceholder(layer: 'domain', path: 'domain/'),
      const LayerPlaceholder(layer: 'data', path: 'data/'),
      const LayerPlaceholder(layer: 'presentation', path: 'presentation/'),
    ];

    final bone = Bone(
      featureSlug: featureSlug,
      featureName: _toPascal(featureSlug),
      rootDir: boneDir,
      manifest: manifest,
      entityStubs: entityStubs,
      layers: layers,
    );

    // 5. Write scaffold. On any error, clean up partial output (U22).
    try {
      await scaffoldBuilder.build(bone, boneDir);
    } catch (e) {
      // Clean up partial output.
      final dir = Directory(boneDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      rethrow;
    }

    return boneDir;
  }

  /// Scans [specsRoot] for all feature specs and resolves dependencies.
  List<BoneDependency> _resolveDependencies(
    String specsRoot,
    String targetSlug,
  ) {
    final specsDir = Directory(specsRoot);
    if (!specsDir.existsSync()) {
      return const [];
    }

    // Scan for spec.md files in subdirectories.
    final features = <String, FeatureSpec>{};
    for (final entity in specsDir.listSync().whereType<Directory>()) {
      final specFile = File('${entity.path}/spec.md');
      if (!specFile.existsSync()) continue;
      final result = specReader.read(specFile);
      features[result.featureSlug] = FeatureSpec(
        slug: result.featureSlug,
        declaredEntities: result.entities,
        specContent: specFile.readAsStringSync(),
      );
    }

    if (features.isEmpty || !features.containsKey(targetSlug)) {
      return const [];
    }

    final resolver = DependencyResolver(features: features);
    try {
      return resolver.resolve(targetSlug);
    } on DependencyResolutionError catch (e) {
      throw BoneGenerationError(e.message);
    } on CycleException catch (e) {
      throw BoneGenerationError(
        'Circular dependency detected: ${e.cycleMembers.join(', ')}. '
        'Generation refused until the cycle is resolved.',
      );
    }
  }

  String _toSnake(String name) {
    final result = name
        .replaceAll('-', '_')
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => '_${m.group(1)!.toLowerCase()}',
        );
    return result.startsWith('_') ? result.substring(1) : result;
  }

  String _toPascal(String slug) {
    return slug
        .split('-')
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .join();
  }
}
