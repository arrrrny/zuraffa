/// Orchestrates one bone build: reads spec, validates, writes working slice.
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

/// Orchestrates bone generation for a single feature (042 working slice).
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
  ///
  /// 042: [diChoice] bakes a swappable DI backend into the slice,
  /// [flutter] adds pubspec/main/page/widget-test, and [includeDeps] inlines
  /// the minimal transitive set of shared dependency entities.
  Future<String> generate({
    required File specPath,
    required String outputDir,
    String? specsRoot,
    DiChoice? diChoice,
    bool flutter = false,
    bool includeDeps = false,
  }) async {
    // 1. Read spec (may throw SpecReadError on unsupported field types).
    final SpecReadResult specResult;
    try {
      specResult = specReader.read(specPath);
    } on SpecReadError catch (e) {
      throw BoneGenerationError(e.message);
    }

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
            fields: specResult.entityFields[name] ?? const [],
            sourcePath: 'entities/${pascalToSnake(name)}.dart',
          ),
        )
        .toList();

    // 4. Resolve dependencies (and optionally the transitive shared-entity
    //    closure) when specsRoot is provided.
    var dependencies = <BoneDependency>[];
    var inlinedEntities = <EntityStub>[];
    if (specsRoot != null) {
      final scanned = _scanFeatures(specsRoot);
      if (scanned.features.containsKey(featureSlug)) {
        final resolver = DependencyResolver(features: scanned.features);
        try {
          dependencies = resolver.resolve(featureSlug);
          if (includeDeps) {
            inlinedEntities = _collectInlinedEntities(
              resolver,
              scanned,
              featureSlug,
              dependencies,
              entityStubs.map((stub) => stub.name).toSet(),
            );
          }
        } on DependencyResolutionError catch (e) {
          throw BoneGenerationError(e.message);
        } on CycleException catch (e) {
          throw BoneGenerationError(
            'Circular dependency detected: ${e.cycleMembers.join(', ')}. '
            'Generation refused until the cycle is resolved.',
          );
        }
      }
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
      // The working slice always carries a DI container: a direct API call
      // without an explicit choice defaults to auto-resolved mock.
      diChoice: diChoice ?? DiChoice.auto().resolve(detectedBackend: null),
      flutter: flutter,
    );

    final bone = Bone(
      featureSlug: featureSlug,
      featureName: slugToPascalCase(featureSlug),
      rootDir: boneDir,
      manifest: manifest,
      entityStubs: entityStubs,
      layers: [
        const LayerPlaceholder(layer: 'domain', path: 'domain/'),
        const LayerPlaceholder(layer: 'data', path: 'data/'),
        const LayerPlaceholder(layer: 'presentation', path: 'presentation/'),
      ],
      inlinedEntities: inlinedEntities,
    );

    // 5. Write the working slice. On any error, clean up partial output
    //    (U22). The scaffold builder itself replaces previous bones
    //    atomically (042, FR-014).
    try {
      await scaffoldBuilder.build(bone, boneDir);
    } catch (e) {
      final dir = Directory(boneDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      rethrow;
    }

    return boneDir;
  }

  /// The result of scanning a specs root: features map + per-slug parsed
  /// results (for field lookup of inlined entities).
  _ScanResult _scanFeatures(String specsRoot) {
    final specsSub = Directory(p.join(specsRoot, 'specs'));
    final root = specsSub.existsSync() ? specsSub : Directory(specsRoot);
    final scanned = _ScanResult(
      features: <String, FeatureSpec>{},
      results: <String, SpecReadResult>{},
    );
    if (!root.existsSync()) return scanned;

    for (final entity in root.listSync().whereType<Directory>()) {
      final specFile = File('${entity.path}/spec.md');
      if (!specFile.existsSync()) continue;
      try {
        final result = specReader.read(specFile);
        scanned.features[result.featureSlug] = FeatureSpec(
          slug: result.featureSlug,
          declaredEntities: result.entities,
          specContent: specFile.readAsStringSync(),
        );
        scanned.results[result.featureSlug] = result;
      } on SpecReadError {
        // A sibling spec with unsupported types must not break the target's
        // dependency scan; it simply cannot contribute entities.
        continue;
      }
    }
    return scanned;
  }

  /// Walks the dependency closure of [targetSlug] and returns the minimal
  /// transitive set of shared entities as stubs (own entities excluded).
  List<EntityStub> _collectInlinedEntities(
    DependencyResolver resolver,
    _ScanResult scanned,
    String targetSlug,
    List<BoneDependency> directDeps,
    Set<String> ownEntities,
  ) {
    final inlined = <EntityStub>[];
    final inlinedNames = <String>{};
    final visited = <String>{targetSlug};

    void visit(BoneDependency dep) {
      if (!visited.add(dep.bone)) return;
      final result = scanned.results[dep.bone];
      for (final entityName in dep.entities) {
        if (ownEntities.contains(entityName)) continue;
        if (!inlinedNames.add(entityName)) continue;
        inlined.add(
          EntityStub(
            name: entityName,
            fields: result?.entityFields[entityName] ?? const [],
            sourcePath: 'entities/${pascalToSnake(entityName)}.dart',
          ),
        );
      }
      // Recurse into the dependency's own dependencies (transitive closure).
      final next = resolver.resolve(dep.bone);
      for (final nextDep in next) {
        visit(nextDep);
      }
    }

    for (final dep in directDeps) {
      visit(dep);
    }
    return inlined;
  }
}

/// Scan result for a specs root: dependency features map plus per-slug
/// parsed results (for field lookup of inlined entities).
class _ScanResult {
  const _ScanResult({required this.features, required this.results});

  final Map<String, FeatureSpec> features;
  final Map<String, SpecReadResult> results;
}
