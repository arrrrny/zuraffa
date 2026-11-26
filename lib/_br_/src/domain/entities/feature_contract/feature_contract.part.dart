// dart format off
part of '../../../../../src/domain/entities/feature_contract/feature_contract.dart';

// === zorphy:zorphy contribution.
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
final class _ZorphyCopyWithSentinel {
  const _ZorphyCopyWithSentinel();
}

const Object _sentinel = _ZorphyCopyWithSentinel();

final class FeatureContract implements ZorphyEntityBase<String> {
  FeatureContract.fromTrusted({
    required this.id,
    required this.displayName,
    List<String>? entities,
    this.boundary,
    Set<String>? routes,
    this.xrayLayer,
    Map<String, dynamic>? argSchema,
  }) : entities = entities == null ? null : List<String>.of(entities),
       routes = routes == null ? null : Set<String>.of(routes),
       argSchema = argSchema == null
           ? null
           : Map<String, dynamic>.of(argSchema);

  final String id;

  final String displayName;

  final List<String>? entities;

  final SliceBoundary? boundary;

  final Set<String>? routes;

  final XRayLayer? xrayLayer;

  final Map<String, dynamic>? argSchema;

  static const FeatureContractLenses lenses = FeatureContractLenses();

  static const ZorphyEntityDescriptor<FeatureContract> descriptor =
      _FeatureContractDescriptor._();

  FeatureContract copyWith({
    String? id,
    String? displayName,
    Object? entities = _sentinel,
    Object? boundary = _sentinel,
    Object? routes = _sentinel,
    Object? xrayLayer = _sentinel,
    Object? argSchema = _sentinel,
  }) {
    return FeatureContract.fromTrusted(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      entities: identical(entities, _sentinel)
          ? this.entities
          : entities as List<String>?,
      boundary: identical(boundary, _sentinel)
          ? this.boundary
          : boundary as SliceBoundary?,
      routes: identical(routes, _sentinel)
          ? this.routes
          : routes as Set<String>?,
      xrayLayer: identical(xrayLayer, _sentinel)
          ? this.xrayLayer
          : xrayLayer as XRayLayer?,
      argSchema: identical(argSchema, _sentinel)
          ? this.argSchema
          : argSchema as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeatureContract &&
        this.id == other.id &&
        this.displayName == other.displayName &&
        FeatureContract._zorphyCollectionEquals(
          this.entities,
          other.entities,
        ) &&
        this.boundary == other.boundary &&
        FeatureContract._zorphyCollectionEquals(this.routes, other.routes) &&
        this.xrayLayer == other.xrayLayer &&
        FeatureContract._zorphyCollectionEquals(
          this.argSchema,
          other.argSchema,
        );
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    displayName,
    FeatureContract._zorphyCollectionHash(entities),
    boundary,
    FeatureContract._zorphyCollectionHash(routes),
    xrayLayer,
    FeatureContract._zorphyCollectionHash(argSchema),
  ]);

  @override
  String toString() =>
      'FeatureContract(id: $id, displayName: $displayName, entities: $entities, boundary: $boundary, routes: $routes, xrayLayer: $xrayLayer, argSchema: $argSchema)';

  static bool _zorphyCollectionEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }
    if (a is Set && b is Set) {
      if (a.length != b.length) return false;
      return a.every(b.contains);
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  static int _zorphyCollectionHash(Object? value) {
    if (value is List) return Object.hashAll(value);
    if (value is Set) {
      return value.fold<int>(0, (hash, element) => hash + element.hashCode);
    }
    if (value is Map) {
      return value.entries.fold<int>(
        0,
        (hash, entry) => hash + Object.hash(entry.key, entry.value),
      );
    }
    return value.hashCode;
  }

  String get principalKey => id;

  static ZorphyBoundaryResult<FeatureContract> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final Object? raw_id = raw['id'];
    String? _id;
    _id = _boundaryAs<String>(raw_id, '/id', violations);
    final Object? raw_displayName = raw['displayName'];
    String? _displayName;
    _displayName = _boundaryAs<String>(
      raw_displayName,
      '/displayName',
      violations,
    );
    final Object? raw_entities = raw['entities'];
    List<String>? _entities;
    if (raw_entities != null) {
      final list_entities = _boundaryList(
        raw_entities,
        '/entities',
        violations,
      );
      if (list_entities != null) {
        final decoded_entities = <String>[];
        for (var i = 0; i < list_entities.length; i++) {
          final path_entities = '/entities' + '[$i]';
          final element_entities = _boundaryAs<String>(
            list_entities[i],
            path_entities,
            violations,
          );
          if (element_entities != null) {
            decoded_entities.add(element_entities);
          }
        }
        _entities = decoded_entities;
      }
    }
    final Object? raw_boundary = raw['boundary'];
    SliceBoundary? _boundary;
    if (raw_boundary != null) {
      _boundary = _boundaryAs<SliceBoundary>(
        raw_boundary,
        '/boundary',
        violations,
      );
    }
    final Object? raw_routes = raw['routes'];
    Set<String>? _routes;
    if (raw_routes != null) {
      _routes = _boundaryAs<Set<String>>(raw_routes, '/routes', violations);
    }
    final Object? raw_xrayLayer = raw['xrayLayer'];
    XRayLayer? _xrayLayer;
    if (raw_xrayLayer != null) {
      _xrayLayer = _boundaryAs<XRayLayer>(
        raw_xrayLayer,
        '/xrayLayer',
        violations,
      );
    }
    final Object? raw_argSchema = raw['argSchema'];
    Map<String, dynamic>? _argSchema;
    if (raw_argSchema != null) {
      final map_argSchema = _boundaryObject(
        raw_argSchema,
        '/argSchema',
        violations,
      );
      if (map_argSchema != null) {
        final decoded_argSchema = <String, dynamic>{};
        for (final entry in map_argSchema.entries) {
          final path_argSchema = '/argSchema' + '/' + entry.key;
          if (map_argSchema[entry.key] == null) {
            decoded_argSchema[entry.key] = null;
          } else {
            final element_argSchema = _boundaryAs<dynamic>(
              map_argSchema[entry.key],
              path_argSchema,
              violations,
            );
            if (element_argSchema != null) {
              decoded_argSchema[entry.key] = element_argSchema;
            }
          }
        }
        _argSchema = decoded_argSchema;
      }
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<FeatureContract>(
        targetType: 'FeatureContract',
        violations: violations,
      );
    }
    return BoundaryOk<FeatureContract>(
      FeatureContract.fromTrusted(
        id: _id!,
        displayName: _displayName!,
        entities: _entities,
        boundary: _boundary,
        routes: _routes,
        xrayLayer: _xrayLayer,
        argSchema: _argSchema,
      ),
    );
  }

  Map<String, Object?> toWire() {
    final map = <String, Object?>{};
    map['id'] = this.id;
    map['displayName'] = this.displayName;
    final _entities = this.entities;
    if (_entities != null) {
      map['entities'] = _entities;
    }
    final _boundary = this.boundary;
    if (_boundary != null) {
      map['boundary'] = _boundary;
    }
    final _routes = this.routes;
    if (_routes != null) {
      map['routes'] = _routes;
    }
    final _xrayLayer = this.xrayLayer;
    if (_xrayLayer != null) {
      map['xrayLayer'] = _xrayLayer;
    }
    final _argSchema = this.argSchema;
    if (_argSchema != null) {
      map['argSchema'] = _argSchema;
    }
    return map;
  }

  /// Resolves a JSON Pointer into a [ZorphyLens] over [FeatureContract].
  ///
  /// One switch step per segment, so a pointer costs O(depth)
  /// — no regex, no mirrors, no reflective lookup.
  ///
  /// A pointer this node does not carry answers `null`.
  static ZorphyLens<FeatureContract, Object?>? resolvePath(String pointer) {
    return switch (pointer) {
      '/id' => ZorphyLens<FeatureContract, Object?>(
        path: '/id',
        get: (root) => root.id,
        set: (root, value) => root.copyWith(id: value as String),
      ),
      '/displayName' => ZorphyLens<FeatureContract, Object?>(
        path: '/displayName',
        get: (root) => root.displayName,
        set: (root, value) => root.copyWith(displayName: value as String),
      ),
      '/entities' => ZorphyLens<FeatureContract, Object?>(
        path: '/entities',
        get: (root) => root.entities,
        set: (root, value) => root.copyWith(entities: value as List<String>?),
      ),
      '/boundary' => ZorphyLens<FeatureContract, Object?>(
        path: '/boundary',
        get: (root) => root.boundary,
        set: (root, value) => root.copyWith(boundary: value as SliceBoundary?),
      ),
      '/routes' => ZorphyLens<FeatureContract, Object?>(
        path: '/routes',
        get: (root) => root.routes,
        set: (root, value) => root.copyWith(routes: value as Set<String>?),
      ),
      '/xrayLayer' => ZorphyLens<FeatureContract, Object?>(
        path: '/xrayLayer',
        get: (root) => root.xrayLayer,
        set: (root, value) => root.copyWith(xrayLayer: value as XRayLayer?),
      ),
      '/argSchema' => ZorphyLens<FeatureContract, Object?>(
        path: '/argSchema',
        get: (root) => root.argSchema,
        set: (root, value) =>
            root.copyWith(argSchema: value as Map<String, dynamic>?),
      ),
      _ => null,
    };
  }
}

final class FeatureContractPatch implements ZorphyPatch<FeatureContract> {
  FeatureContractPatch({
    PatchValue<String> id = const PatchValue.unchanged(),
    PatchValue<String> displayName = const PatchValue.unchanged(),
    PatchValue<List<String>?> entities = const PatchValue.unchanged(),
    PatchValue<SliceBoundary?> boundary = const PatchValue.unchanged(),
    PatchValue<Set<String>?> routes = const PatchValue.unchanged(),
    PatchValue<XRayLayer?> xrayLayer = const PatchValue.unchanged(),
    PatchValue<Map<String, dynamic>?> argSchema = const PatchValue.unchanged(),
  }) : id = id,
       displayName = displayName,
       entities = entities,
       boundary = boundary,
       routes = routes,
       xrayLayer = xrayLayer,
       argSchema = argSchema;

  final PatchValue<String> id;

  final PatchValue<String> displayName;

  final PatchValue<List<String>?> entities;

  final PatchValue<SliceBoundary?> boundary;

  final PatchValue<Set<String>?> routes;

  final PatchValue<XRayLayer?> xrayLayer;

  final PatchValue<Map<String, dynamic>?> argSchema;

  FeatureContractPatch withId(String value) {
    return FeatureContractPatch(
      id: PatchValue.set(value),
      displayName: this.displayName,
      entities: this.entities,
      boundary: this.boundary,
      routes: this.routes,
      xrayLayer: this.xrayLayer,
      argSchema: this.argSchema,
    );
  }

  FeatureContractPatch withDisplayName(String value) {
    return FeatureContractPatch(
      id: this.id,
      displayName: PatchValue.set(value),
      entities: this.entities,
      boundary: this.boundary,
      routes: this.routes,
      xrayLayer: this.xrayLayer,
      argSchema: this.argSchema,
    );
  }

  FeatureContractPatch withEntities(List<String>? value) {
    return FeatureContractPatch(
      id: this.id,
      displayName: this.displayName,
      entities: PatchValue.set(value),
      boundary: this.boundary,
      routes: this.routes,
      xrayLayer: this.xrayLayer,
      argSchema: this.argSchema,
    );
  }

  FeatureContractPatch withBoundary(SliceBoundary? value) {
    return FeatureContractPatch(
      id: this.id,
      displayName: this.displayName,
      entities: this.entities,
      boundary: PatchValue.set(value),
      routes: this.routes,
      xrayLayer: this.xrayLayer,
      argSchema: this.argSchema,
    );
  }

  FeatureContractPatch withRoutes(Set<String>? value) {
    return FeatureContractPatch(
      id: this.id,
      displayName: this.displayName,
      entities: this.entities,
      boundary: this.boundary,
      routes: PatchValue.set(value),
      xrayLayer: this.xrayLayer,
      argSchema: this.argSchema,
    );
  }

  FeatureContractPatch withXrayLayer(XRayLayer? value) {
    return FeatureContractPatch(
      id: this.id,
      displayName: this.displayName,
      entities: this.entities,
      boundary: this.boundary,
      routes: this.routes,
      xrayLayer: PatchValue.set(value),
      argSchema: this.argSchema,
    );
  }

  FeatureContractPatch withArgSchema(Map<String, dynamic>? value) {
    return FeatureContractPatch(
      id: this.id,
      displayName: this.displayName,
      entities: this.entities,
      boundary: this.boundary,
      routes: this.routes,
      xrayLayer: this.xrayLayer,
      argSchema: PatchValue.set(value),
    );
  }

  @override
  bool get isEmpty {
    return id.isUnchanged &&
        displayName.isUnchanged &&
        entities.isUnchanged &&
        boundary.isUnchanged &&
        routes.isUnchanged &&
        xrayLayer.isUnchanged &&
        argSchema.isUnchanged;
  }

  @override
  bool get isNotEmpty {
    return !isEmpty;
  }

  @override
  FeatureContract apply(covariant FeatureContract target) {
    if (isEmpty) return target;
    return target.copyWith(
      id: this.id.isUnchanged ? target.id : this.id.valueOrNull,
      displayName: this.displayName.isUnchanged
          ? target.displayName
          : this.displayName.valueOrNull,
      entities: this.entities.isUnchanged
          ? target.entities
          : this.entities.valueOrNull,
      boundary: this.boundary.isUnchanged
          ? target.boundary
          : this.boundary.valueOrNull,
      routes: this.routes.isUnchanged ? target.routes : this.routes.valueOrNull,
      xrayLayer: this.xrayLayer.isUnchanged
          ? target.xrayLayer
          : this.xrayLayer.valueOrNull,
      argSchema: this.argSchema.isUnchanged
          ? target.argSchema
          : this.argSchema.valueOrNull,
    );
  }

  @override
  FeatureContractPatch compose(ZorphyPatch<FeatureContract> next) {
    if (next.isEmpty) return this;
    if (next is! FeatureContractPatch) {
      throw ArgumentError.value(
        next,
        'next',
        'FeatureContractPatch cannot compose ${next.runtimeType}',
      );
    }
    if (isEmpty) return next;
    return FeatureContractPatch(
      id: next.id.isUnchanged ? this.id : next.id,
      displayName: next.displayName.isUnchanged
          ? this.displayName
          : next.displayName,
      entities: next.entities.isUnchanged ? this.entities : next.entities,
      boundary: next.boundary.isUnchanged ? this.boundary : next.boundary,
      routes: next.routes.isUnchanged ? this.routes : next.routes,
      xrayLayer: next.xrayLayer.isUnchanged ? this.xrayLayer : next.xrayLayer,
      argSchema: next.argSchema.isUnchanged ? this.argSchema : next.argSchema,
    );
  }

  @override
  FeatureContractPatch invert(FeatureContract before) {
    return FeatureContractPatch(
      id: this.id.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.id),
      displayName: this.displayName.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.displayName),
      entities: this.entities.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.entities),
      boundary: this.boundary.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.boundary),
      routes: this.routes.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.routes),
      xrayLayer: this.xrayLayer.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.xrayLayer),
      argSchema: this.argSchema.isUnchanged
          ? const PatchValue.unchanged()
          : PatchValue.set(before.argSchema),
    );
  }

  @override
  Map<String, Object?> toWire() {
    final wire = <String, Object?>{};
    if (this.id.isSet) wire['id'] = this.id.valueOrNull;
    if (this.displayName.isSet)
      wire['displayName'] = this.displayName.valueOrNull;
    if (this.entities.isSet) wire['entities'] = this.entities.valueOrNull;
    if (this.boundary.isSet) wire['boundary'] = this.boundary.valueOrNull;
    if (this.routes.isSet) wire['routes'] = this.routes.valueOrNull;
    if (this.xrayLayer.isSet) wire['xrayLayer'] = this.xrayLayer.valueOrNull;
    if (this.argSchema.isSet) wire['argSchema'] = this.argSchema.valueOrNull;
    return wire;
  }

  Map<String, Object?> toEnvelope({Object? principalKey}) {
    return <String, Object?>{
      'entityType': 'FeatureContract',
      'patchKind': 'FeatureContract',
      'principalKey': principalKey,
      'ops': toWire(),
    };
  }

  static FeatureContractPatch diff(
    FeatureContract previous,
    FeatureContract next,
  ) {
    if (identical(previous, next)) return FeatureContractPatch();
    var changes = FeatureContractPatch();
    if (previous.id != next.id) changes = changes.withId(next.id);
    if (previous.displayName != next.displayName)
      changes = changes.withDisplayName(next.displayName);
    if (previous.entities != next.entities)
      changes = changes.withEntities(next.entities);
    if (previous.boundary != next.boundary)
      changes = changes.withBoundary(next.boundary);
    if (previous.routes != next.routes)
      changes = changes.withRoutes(next.routes);
    if (previous.xrayLayer != next.xrayLayer)
      changes = changes.withXrayLayer(next.xrayLayer);
    if (previous.argSchema != next.argSchema)
      changes = changes.withArgSchema(next.argSchema);
    return changes;
  }

  static ZorphyBoundaryResult<FeatureContractPatch> fromWire(
    Map<String, Object?> raw,
  ) {
    final violations = <FieldViolation>[];
    final ops = ZorphyPatchWire.opsOf(raw, '', violations);
    final prefix = ZorphyPatchWire.opsPathOf(raw);
    PatchValue<String>? idValue;
    if (ops != null && ops.containsKey('id')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['id'],
        '$prefix/id',
        violations,
      );
      idValue = (() {
        final idDecoded = ZorphyPatchWire.as<String>(
          rawValue,
          '$prefix/id',
          violations,
        );
        return idDecoded == null ? null : PatchValue<String>.set(idDecoded);
      })();
    }
    PatchValue<String>? displayNameValue;
    if (ops != null && ops.containsKey('displayName')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['displayName'],
        '$prefix/displayName',
        violations,
      );
      displayNameValue = (() {
        final displayNameDecoded = ZorphyPatchWire.as<String>(
          rawValue,
          '$prefix/displayName',
          violations,
        );
        return displayNameDecoded == null
            ? null
            : PatchValue<String>.set(displayNameDecoded);
      })();
    }
    PatchValue<List<String>?>? entitiesValue;
    if (ops != null && ops.containsKey('entities')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['entities'],
        '$prefix/entities',
        violations,
      );
      entitiesValue = (() {
        if (rawValue == null) return PatchValue<List<String>?>.set(null);
        final entitiesDecoded = ZorphyPatchWire.as<List<String>?>(
          rawValue,
          '$prefix/entities',
          violations,
        );
        return entitiesDecoded == null
            ? null
            : PatchValue<List<String>?>.set(entitiesDecoded);
      })();
    }
    PatchValue<SliceBoundary?>? boundaryValue;
    if (ops != null && ops.containsKey('boundary')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['boundary'],
        '$prefix/boundary',
        violations,
      );
      boundaryValue = (() {
        if (rawValue == null) return PatchValue<SliceBoundary?>.set(null);
        final boundaryDecoded = ZorphyPatchWire.as<SliceBoundary?>(
          rawValue,
          '$prefix/boundary',
          violations,
        );
        return boundaryDecoded == null
            ? null
            : PatchValue<SliceBoundary?>.set(boundaryDecoded);
      })();
    }
    PatchValue<Set<String>?>? routesValue;
    if (ops != null && ops.containsKey('routes')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['routes'],
        '$prefix/routes',
        violations,
      );
      routesValue = (() {
        if (rawValue == null) return PatchValue<Set<String>?>.set(null);
        final routesDecoded = ZorphyPatchWire.as<Set<String>?>(
          rawValue,
          '$prefix/routes',
          violations,
        );
        return routesDecoded == null
            ? null
            : PatchValue<Set<String>?>.set(routesDecoded);
      })();
    }
    PatchValue<XRayLayer?>? xrayLayerValue;
    if (ops != null && ops.containsKey('xrayLayer')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['xrayLayer'],
        '$prefix/xrayLayer',
        violations,
      );
      xrayLayerValue = (() {
        if (rawValue == null) return PatchValue<XRayLayer?>.set(null);
        final xrayLayerDecoded = ZorphyPatchWire.as<XRayLayer?>(
          rawValue,
          '$prefix/xrayLayer',
          violations,
        );
        return xrayLayerDecoded == null
            ? null
            : PatchValue<XRayLayer?>.set(xrayLayerDecoded);
      })();
    }
    PatchValue<Map<String, dynamic>?>? argSchemaValue;
    if (ops != null && ops.containsKey('argSchema')) {
      final Object? rawValue = ZorphyPatchWire.fieldValue(
        ops['argSchema'],
        '$prefix/argSchema',
        violations,
      );
      argSchemaValue = (() {
        if (rawValue == null)
          return PatchValue<Map<String, dynamic>?>.set(null);
        final argSchemaDecoded = ZorphyPatchWire.as<Map<String, dynamic>?>(
          rawValue,
          '$prefix/argSchema',
          violations,
        );
        return argSchemaDecoded == null
            ? null
            : PatchValue<Map<String, dynamic>?>.set(argSchemaDecoded);
      })();
    }
    if (violations.isNotEmpty) {
      return BoundaryErr<FeatureContractPatch>(
        targetType: 'FeatureContractPatch',
        violations: violations,
      );
    }
    return BoundaryOk<FeatureContractPatch>(
      FeatureContractPatch(
        id: idValue ?? const PatchValue<String>.unchanged(),
        displayName: displayNameValue ?? const PatchValue<String>.unchanged(),
        entities: entitiesValue ?? const PatchValue<List<String>?>.unchanged(),
        boundary: boundaryValue ?? const PatchValue<SliceBoundary?>.unchanged(),
        routes: routesValue ?? const PatchValue<Set<String>?>.unchanged(),
        xrayLayer: xrayLayerValue ?? const PatchValue<XRayLayer?>.unchanged(),
        argSchema:
            argSchemaValue ??
            const PatchValue<Map<String, dynamic>?>.unchanged(),
      ),
    );
  }
}

class FeatureContractMockData {
  FeatureContractMockData._();

  static FeatureContract single({int seed = 0}) {
    return FeatureContract.fromTrusted(
      id: 'id-${seed}',
      displayName: 'displayname-${seed}',
      entities: ['entities-${seed}'],
      routes: {'routes-${seed}'},
      argSchema: {},
    );
  }

  static List<FeatureContract> list({int count = 10}) {
    return List<FeatureContract>.generate(
      count,
      (index) => single(seed: index),
    );
  }

  static FeatureContractPatch samplePatch() {
    var patch = FeatureContractPatch();
    patch = patch.withId('id-${0}');
    patch = patch.withDisplayName('displayname-${0}');
    patch = patch.withEntities(['entities-${0}']);
    patch = patch.withRoutes({'routes-${0}'});
    patch = patch.withArgSchema({});
    return patch;
  }
}

class FeatureContractWireFixtures {
  FeatureContractWireFixtures._();

  static Map<String, Object?> validMap({int seed = 0}) {
    return FeatureContractMockData.single(seed: seed).toWire();
  }

  static List<Map<String, Object?>> corruptMaps() {
    final base = validMap();
    final maps = <Map<String, Object?>>[];
    maps.add(Map<String, Object?>.of(base)..remove('id'));
    maps.add(Map<String, Object?>.of(base)..['id'] = 12345);
    maps.add(Map<String, Object?>.of(base)..remove('displayName'));
    maps.add(Map<String, Object?>.of(base)..['displayName'] = 12345);
    maps.add(Map<String, Object?>.of(base)..['entities'] = 'not-a-list');
    maps.add(Map<String, Object?>.of(base)..['routes'] = 'not-a-list');
    maps.add(Map<String, Object?>.of(base)..['argSchema'] = 'not-a-map');
    return maps;
  }
}

String _boundaryDescribe(Object? value) {
  if (value == null) return 'null';
  final text = value.toString();
  final clipped = text.length > 60 ? '${text.substring(0, 60)}…' : text;
  return '${value.runtimeType} ("$clipped")';
}

T? _boundaryAs<T>(Object? value, String path, List<FieldViolation> violations) {
  if (value is T) return value;
  violations.add(
    FieldViolation(
      path: path,
      expected: '$T',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

Map<String, Object?>? _boundaryObject(
  Object? value,
  String path,
  List<FieldViolation> violations,
) {
  if (value is Map<String, Object?>) return value;
  violations.add(
    FieldViolation(
      path: path,
      expected: 'Map<String, Object?>',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

List<Object?>? _boundaryList(
  Object? value,
  String path,
  List<FieldViolation> violations,
) {
  if (value is List<Object?>) return value;
  if (value is List) return List<Object?>.of(value);
  violations.add(
    FieldViolation(
      path: path,
      expected: 'List<Object?>',
      actual: _boundaryDescribe(value),
    ),
  );
  return null;
}

/// Typed lenses over [FeatureContract] — one per writable field.
///
/// Compose with `then` to reach a nested value:
/// `FeatureContract.lenses.<field>.then(<Nested>.lenses.<leaf>)`.
final class FeatureContractLenses {
  const FeatureContractLenses();

  ZorphyLens<FeatureContract, String> get id =>
      const ZorphyLens<FeatureContract, String>(
        path: '/id',
        get: _getId,
        set: _setId,
      );

  static String _getId(FeatureContract root) => root.id;

  static FeatureContract _setId(FeatureContract root, String value) =>
      root.copyWith(id: value);

  ZorphyLens<FeatureContract, String> get displayName =>
      const ZorphyLens<FeatureContract, String>(
        path: '/displayName',
        get: _getDisplayName,
        set: _setDisplayName,
      );

  static String _getDisplayName(FeatureContract root) => root.displayName;

  static FeatureContract _setDisplayName(FeatureContract root, String value) =>
      root.copyWith(displayName: value);

  ZorphyLens<FeatureContract, List<String>?> get entities =>
      const ZorphyLens<FeatureContract, List<String>?>(
        path: '/entities',
        get: _getEntities,
        set: _setEntities,
      );

  static List<String>? _getEntities(FeatureContract root) => root.entities;

  static FeatureContract _setEntities(
    FeatureContract root,
    List<String>? value,
  ) => root.copyWith(entities: value);

  ZorphyLens<FeatureContract, SliceBoundary?> get boundary =>
      const ZorphyLens<FeatureContract, SliceBoundary?>(
        path: '/boundary',
        get: _getBoundary,
        set: _setBoundary,
      );

  static SliceBoundary? _getBoundary(FeatureContract root) => root.boundary;

  static FeatureContract _setBoundary(
    FeatureContract root,
    SliceBoundary? value,
  ) => root.copyWith(boundary: value);

  ZorphyLens<FeatureContract, Set<String>?> get routes =>
      const ZorphyLens<FeatureContract, Set<String>?>(
        path: '/routes',
        get: _getRoutes,
        set: _setRoutes,
      );

  static Set<String>? _getRoutes(FeatureContract root) => root.routes;

  static FeatureContract _setRoutes(FeatureContract root, Set<String>? value) =>
      root.copyWith(routes: value);

  ZorphyLens<FeatureContract, XRayLayer?> get xrayLayer =>
      const ZorphyLens<FeatureContract, XRayLayer?>(
        path: '/xrayLayer',
        get: _getXrayLayer,
        set: _setXrayLayer,
      );

  static XRayLayer? _getXrayLayer(FeatureContract root) => root.xrayLayer;

  static FeatureContract _setXrayLayer(
    FeatureContract root,
    XRayLayer? value,
  ) => root.copyWith(xrayLayer: value);

  ZorphyLens<FeatureContract, Map<String, dynamic>?> get argSchema =>
      const ZorphyLens<FeatureContract, Map<String, dynamic>?>(
        path: '/argSchema',
        get: _getArgSchema,
        set: _setArgSchema,
      );

  static Map<String, dynamic>? _getArgSchema(FeatureContract root) =>
      root.argSchema;

  static FeatureContract _setArgSchema(
    FeatureContract root,
    Map<String, dynamic>? value,
  ) => root.copyWith(argSchema: value);
}

/// Typed field descriptors over [FeatureContract] — one
/// `ZorphyField` per payload field, inherited fields
/// included (issue #247).
///
/// Query with the predicate methods, sort with `asc` /
/// `desc`, resolve wire pointers through
/// `FeatureContractFields.all`.
abstract final class FeatureContractFields {
  static const ZorphyField<FeatureContract, String> id =
      ZorphyField<FeatureContract, String>(
        name: 'id',
        jsonKey: 'id',
        pointer: '/id',
        get: _getId,
        set: _setId,
      );

  static const ZorphyField<FeatureContract, String> displayName =
      ZorphyField<FeatureContract, String>(
        name: 'displayName',
        jsonKey: 'displayName',
        pointer: '/displayName',
        get: _getDisplayName,
        set: _setDisplayName,
      );

  static const ZorphyField<FeatureContract, List<String>?> entities =
      ZorphyField<FeatureContract, List<String>?>(
        name: 'entities',
        jsonKey: 'entities',
        pointer: '/entities',
        get: _getEntities,
        set: _setEntities,
      );

  static const ZorphyField<FeatureContract, SliceBoundary?> boundary =
      ZorphyField<FeatureContract, SliceBoundary?>(
        name: 'boundary',
        jsonKey: 'boundary',
        pointer: '/boundary',
        get: _getBoundary,
        set: _setBoundary,
      );

  static const ZorphyField<FeatureContract, Set<String>?> routes =
      ZorphyField<FeatureContract, Set<String>?>(
        name: 'routes',
        jsonKey: 'routes',
        pointer: '/routes',
        get: _getRoutes,
        set: _setRoutes,
      );

  static const ZorphyField<FeatureContract, XRayLayer?> xrayLayer =
      ZorphyField<FeatureContract, XRayLayer?>(
        name: 'xrayLayer',
        jsonKey: 'xrayLayer',
        pointer: '/xrayLayer',
        get: _getXrayLayer,
        set: _setXrayLayer,
      );

  static const ZorphyField<FeatureContract, Map<String, dynamic>?> argSchema =
      ZorphyField<FeatureContract, Map<String, dynamic>?>(
        name: 'argSchema',
        jsonKey: 'argSchema',
        pointer: '/argSchema',
        get: _getArgSchema,
        set: _setArgSchema,
      );

  static final List<ZorphyField<FeatureContract, Object?>> all = [
    id.asObject,
    displayName.asObject,
    entities.asObject,
    boundary.asObject,
    routes.asObject,
    xrayLayer.asObject,
    argSchema.asObject,
  ];

  static String _getId(FeatureContract root) => root.id;

  static FeatureContract _setId(FeatureContract root, String value) =>
      root.copyWith(id: value);

  static String _getDisplayName(FeatureContract root) => root.displayName;

  static FeatureContract _setDisplayName(FeatureContract root, String value) =>
      root.copyWith(displayName: value);

  static List<String>? _getEntities(FeatureContract root) => root.entities;

  static FeatureContract _setEntities(
    FeatureContract root,
    List<String>? value,
  ) => root.copyWith(entities: value);

  static SliceBoundary? _getBoundary(FeatureContract root) => root.boundary;

  static FeatureContract _setBoundary(
    FeatureContract root,
    SliceBoundary? value,
  ) => root.copyWith(boundary: value);

  static Set<String>? _getRoutes(FeatureContract root) => root.routes;

  static FeatureContract _setRoutes(FeatureContract root, Set<String>? value) =>
      root.copyWith(routes: value);

  static XRayLayer? _getXrayLayer(FeatureContract root) => root.xrayLayer;

  static FeatureContract _setXrayLayer(
    FeatureContract root,
    XRayLayer? value,
  ) => root.copyWith(xrayLayer: value);

  static Map<String, dynamic>? _getArgSchema(FeatureContract root) =>
      root.argSchema;

  static FeatureContract _setArgSchema(
    FeatureContract root,
    Map<String, dynamic>? value,
  ) => root.copyWith(argSchema: value);
}

/// The reflection-free descriptor for [FeatureContract] (issue #251).
final class _FeatureContractDescriptor
    implements ZorphyEntityDescriptor<FeatureContract> {
  const _FeatureContractDescriptor._();

  String get typeName {
    return 'FeatureContract';
  }

  Field<FeatureContract, Object?> get principalKeyField {
    return Field<FeatureContract, Object?>('id', (entity) => entity.id);
  }

  List<Field<FeatureContract, Object?>> get fields {
    return [
      Field<FeatureContract, Object?>('id', (entity) => entity.id),
      Field<FeatureContract, Object?>(
        'displayName',
        (entity) => entity.displayName,
      ),
      Field<FeatureContract, Object?>('entities', (entity) => entity.entities),
      Field<FeatureContract, Object?>('boundary', (entity) => entity.boundary),
      Field<FeatureContract, Object?>('routes', (entity) => entity.routes),
      Field<FeatureContract, Object?>(
        'xrayLayer',
        (entity) => entity.xrayLayer,
      ),
      Field<FeatureContract, Object?>(
        'argSchema',
        (entity) => entity.argSchema,
      ),
    ];
  }

  ZorphyPatch<FeatureContract> diff(
    FeatureContract previous,
    FeatureContract next,
  ) {
    return FeatureContractPatch.diff(previous, next);
  }

  FeatureContract applyPatch(
    FeatureContract entity,
    ZorphyPatch<FeatureContract> patch,
  ) {
    return patch.apply(entity);
  }

  Map<String, Object?> toWire(FeatureContract entity) {
    return entity.toWire();
  }

  ZorphyBoundaryResult<FeatureContract> fromWire(Map<String, Object?> raw) {
    return FeatureContract.fromWire(raw);
  }

  Object principalKeyOf(FeatureContract entity) {
    return entity.id;
  }

  Field<FeatureContract, Object?>? fieldByPath(String jsonPointer) {
    final name = jsonPointer.startsWith('/')
        ? jsonPointer.substring(1)
        : jsonPointer;
    for (final field in fields) {
      if (field.name == name) return field;
    }
    return null;
  }

  Set<String> conflictingPaths(
    ZorphyPatch<FeatureContract> a,
    ZorphyPatch<FeatureContract> b,
  ) {
    final mine = a.toWire().keys.toSet();
    final theirs = b.toWire().keys.toSet();
    return <String>{for (final key in mine.intersection(theirs)) '/$key'};
  }

  ZorphyPatch<FeatureContract> composePatches(
    ZorphyPatch<FeatureContract> base,
    ZorphyPatch<FeatureContract> next,
  ) {
    return base.compose(next);
  }
}

