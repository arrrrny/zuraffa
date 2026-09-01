/// Core value-object models for the skeleton plugin.
///
/// All models are immutable: plain Dart classes with `final` fields. Only
/// [BoneManifest] is serialized to YAML (see `manifest_builder.dart`).
library;

/// An entity field: a name/type pair inside an [EntityStub].
class EntityField {
  /// Creates an [EntityField].
  const EntityField({
    required this.name,
    required this.type,
    this.nullable = false,
  });

  /// Field name (camelCase).
  final String name;

  /// Dart type annotation.
  final String type;

  /// Whether the field is optional (spec syntax `- name?: Type`).
  final bool nullable;

  /// The field types a working-slice entity can carry (042, FR-001).
  static const Set<String> supportedTypes = {
    'String',
    'int',
    'double',
    'num',
    'bool',
    'List<String>',
    'Map<String, dynamic>',
    'DateTime',
  };

  /// Whether [type] is one of [supportedTypes].
  static bool isSupportedType(String type) => supportedTypes.contains(type);
}

/// Which data-source backend a bone wires by default (042, FR-009).
enum BoneBackendKind { mock, firebase }

/// How a [DiChoice] was determined (042, FR-007).
enum DiChoiceSource { flag, autoDetected, autoFallback }

/// The resolved `--di` choice baked into a bone (042).
class DiChoice {
  const DiChoice._({
    required this.requested,
    required this.backend,
    required this.source,
  });

  /// An unresolved choice: `--di auto` (resolved via [resolve]).
  factory DiChoice.auto() => const DiChoice._(
    requested: 'auto',
    backend: BoneBackendKind.mock,
    source: DiChoiceSource.autoFallback,
  );

  /// An explicit `--di mock|firebase` choice.
  ///
  /// Throws [ArgumentError] for any other value.
  factory DiChoice.fromFlag(String value) {
    switch (value) {
      case 'mock':
        return const DiChoice._(
          requested: 'mock',
          backend: BoneBackendKind.mock,
          source: DiChoiceSource.flag,
        );
      case 'firebase':
        return const DiChoice._(
          requested: 'firebase',
          backend: BoneBackendKind.firebase,
          source: DiChoiceSource.flag,
        );
      default:
        throw ArgumentError.value(
          value,
          'di',
          'must be one of: mock, firebase, auto',
        );
    }
  }

  /// The value the user passed (`mock`, `firebase`, or `auto`).
  final String requested;

  /// The backend that will be wired as the container default.
  final BoneBackendKind backend;

  /// How [backend] was determined.
  final DiChoiceSource source;

  /// Resolves an `auto` choice against an optional [detectedBackend].
  ///
  /// Explicit flag choices resolve to themselves unchanged.
  DiChoice resolve({BoneBackendKind? detectedBackend}) {
    if (requested != 'auto') return this;
    if (detectedBackend == null) {
      return const DiChoice._(
        requested: 'auto',
        backend: BoneBackendKind.mock,
        source: DiChoiceSource.autoFallback,
      );
    }
    return DiChoice._(
      requested: 'auto',
      backend: detectedBackend,
      source: DiChoiceSource.autoDetected,
    );
  }

  /// Whether the user requested [value] on the command line.
  bool wasRequested(String value) => requested == value;

  /// `mock` or `firebase` — used in the manifest and artifact names.
  String get backendName =>
      backend == BoneBackendKind.mock ? 'mock' : 'firebase';

  /// `flag`, `auto-detected`, or `auto-fallback`.
  String get sourceName {
    switch (source) {
      case DiChoiceSource.flag:
        return 'flag';
      case DiChoiceSource.autoDetected:
        return 'auto-detected';
      case DiChoiceSource.autoFallback:
        return 'auto-fallback';
    }
  }
}

/// Strips a leading `NNN-` numeric prefix from a feature slug so the rest of
/// the name can seed Dart identifiers (042 edge case: `042-…` slugs).
String stripSlugPrefix(String slug) =>
    slug.replaceFirst(RegExp(r'^\d+(-|$)'), '');

/// `042-bone-working-slice` → `BoneWorkingSlice`.
String slugToPascalCase(String slug) =>
    stripSlugPrefix(slug)
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join();

/// `042-bone-working-slice` → `bone_working_slice`.
String slugToSnakeCase(String slug) =>
    stripSlugPrefix(slug).replaceAll('-', '_');

/// `042-bone-working-slice` → `Bone Working Slice`.
String slugToDisplayName(String slug) =>
    stripSlugPrefix(slug)
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');

/// Converts a PascalCase name to snake_case (`CartItem` → `cart_item`).
String pascalToSnake(String name) {
  final result = name
      .replaceAll('-', '_')
      .replaceAllMapped(
        RegExp(r'([A-Z])'),
        (m) => '_${m.group(1)!.toLowerCase()}',
      );
  return result.startsWith('_') ? result.substring(1) : result;
}

/// Converts a PascalCase name to camelCase (`CartItem` → `cartItem`).
String pascalToCamel(String name) =>
    name.isEmpty ? name : name[0].toLowerCase() + name.substring(1);

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
    this.diChoice,
    this.flutter = false,
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

  /// The resolved `--di` choice (042); null keeps the legacy manifest shape.
  final DiChoice? diChoice;

  /// Whether the bone was generated with `--flutter` (042).
  final bool flutter;
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
    this.inlinedEntities = const [],
  });

  /// Kebab-case slug, unique across `.zfa/bones/`.
  final String featureSlug;

  /// PascalCase display name.
  final String featureName;

  /// `.zfa/bones/<feature-slug>/`.
  final String rootDir;

  /// The bone's manifest — single source of truth for the DI choice and
  /// flutter mode (042).
  final BoneManifest manifest;

  /// Entity stubs (≥ 1 for generation).
  final List<EntityStub> entityStubs;

  /// Layer placeholders (domain, data, presentation).
  final List<LayerPlaceholder> layers;

  /// Shared entities inlined from dependency features via `--include-deps`
  /// (042, FR-010): entity files only, no extra wiring.
  final List<EntityStub> inlinedEntities;
}
