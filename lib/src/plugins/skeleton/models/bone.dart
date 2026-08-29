/// Core value-object models for the skeleton plugin.
///
/// All models are immutable: plain Dart classes with `final` fields. Only
/// [BoneManifest] is serialized to YAML (see `manifest_builder.dart`).
library;

/// An entity field: a name/type pair inside an [EntityStub].
class EntityField {
  /// Creates an [EntityField].
  const EntityField({required this.name, required this.type});

  /// Field name (camelCase).
  final String name;

  /// Dart type annotation.
  final String type;
}

/// A placeholder Dart class for one entity inside a bone.
class EntityStub {
  /// Creates an [EntityStub].
  const EntityStub({
    required this.name,
    this.fields = const [],
    required this.sourcePath,
  });

  /// PascalCase entity name.
  final String name;

  /// Fields on this entity.
  final List<EntityField> fields;

  /// Bone-relative path, `lib/entities/<snake>.dart`.
  final String sourcePath;
}

/// One edge in the dependency graph.
class BoneDependency {
  /// Creates a [BoneDependency].
  const BoneDependency({required this.bone, required this.entities});

  /// Slug of the depended-on bone.
  final String bone;

  /// Shared entity names justifying the edge (≥ 1).
  final List<String> entities;
}

/// Metadata file within a bone, serialized to `bone.yaml`.
class BoneManifest {
  /// Creates a [BoneManifest].
  const BoneManifest({
    required this.version,
    required this.feature,
    required this.generatedAt,
    required this.specVersion,
    required this.entities,
    this.dependencies = const [],
    this.layers = const ['domain', 'data', 'presentation'],
    this.xray = const {},
  });

  /// Manifest schema version; currently `1`.
  final int version;

  /// Kebab-case feature slug.
  final String feature;

  /// ISO-8601 UTC emission timestamp.
  final String generatedAt;

  /// `sha256:` + 64 lowercase hex chars of the source spec.
  final String specVersion;

  /// Entity names declared by this bone (≥ 1).
  final List<String> entities;

  /// Dependency edges; empty when standalone.
  final List<BoneDependency> dependencies;

  /// Layer names with placeholders present.
  final List<String> layers;

  /// Xray overlay markers extracted from the source spec, if any.
  ///
  /// Keys are marker names; values are the marker content strings.
  /// Preserved verbatim from `<!-- xray: ... -->` HTML comments in the spec.
  final Map<String, String> xray;
}

/// An empty-but-present layer directory with a README placeholder.
class LayerPlaceholder {
  /// Creates a [LayerPlaceholder].
  const LayerPlaceholder({required this.layer, required this.path});

  /// One of `domain`, `data`, `presentation`.
  final String layer;

  /// Bone-relative directory path.
  final String path;
}

/// A self-contained scaffold for a single feature.
class Bone {
  /// Creates a [Bone].
  const Bone({
    required this.featureSlug,
    required this.featureName,
    required this.rootDir,
    required this.manifest,
    required this.entityStubs,
    required this.layers,
  });

  /// Kebab-case slug, unique across `.zfa/bones/`.
  final String featureSlug;

  /// PascalCase display name.
  final String featureName;

  /// `.zfa/bones/<feature-slug>/`.
  final String rootDir;

  /// The bone's manifest.
  final BoneManifest manifest;

  /// Entity stubs (≥ 1 for generation).
  final List<EntityStub> entityStubs;

  /// Layer placeholders (domain, data, presentation).
  final List<LayerPlaceholder> layers;
}
