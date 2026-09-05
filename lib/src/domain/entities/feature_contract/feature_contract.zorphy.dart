// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'feature_contract.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

class FeatureContract {
  FeatureContract({
    required String this.id,
    required String this.displayName,
    List<String>? this.entities,
    SliceBoundary? this.boundary,
    Set<String>? this.routes,
    XRayLayer? this.xrayLayer,
    Map<String, dynamic>? this.argSchema,
  });

  final String id;

  final String displayName;

  final List<String>? entities;

  final SliceBoundary? boundary;

  final Set<String>? routes;

  final XRayLayer? xrayLayer;

  final Map<String, dynamic>? argSchema;

  FeatureContract copyWith({
    String? id,
    String? displayName,
    List<String>? entities,
    SliceBoundary? boundary,
    Set<String>? routes,
    XRayLayer? xrayLayer,
    Map<String, dynamic>? argSchema,
  }) {
    return FeatureContract(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      entities: entities ?? this.entities,
      boundary: boundary ?? this.boundary,
      routes: routes ?? this.routes,
      xrayLayer: xrayLayer ?? this.xrayLayer,
      argSchema: argSchema ?? this.argSchema,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  FeatureContract copyWithField<T>(Field<FeatureContract, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'displayName':
        return copyWith(displayName: value as String);
      case 'entities':
        return copyWith(entities: value as List<String>?);
      case 'boundary':
        return copyWith(boundary: value as SliceBoundary?);
      case 'routes':
        return copyWith(routes: value as Set<String>?);
      case 'xrayLayer':
        return copyWith(xrayLayer: value as XRayLayer?);
      case 'argSchema':
        return copyWith(argSchema: value as Map<String, dynamic>?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'FeatureContract has no settable field with this name',
        );
    }
  }

  FeatureContract copyWithFeatureContract({
    String? id,
    String? displayName,
    List<String>? entities,
    SliceBoundary? boundary,
    Set<String>? routes,
    XRayLayer? xrayLayer,
    Map<String, dynamic>? argSchema,
  }) {
    return copyWith(
      id: id,
      displayName: displayName,
      entities: entities,
      boundary: boundary,
      routes: routes,
      xrayLayer: xrayLayer,
      argSchema: argSchema,
    );
  }

  FeatureContract patchWithFeatureContract([FeatureContractPatch? patchInput]) {
    final _patcher = patchInput ?? FeatureContractPatch();
    final _patchMap = _patcher.patchMap;
    return FeatureContract(
      id: _patchMap.containsKey(FeatureContract$.id)
          ? ((_patchMap[FeatureContract$.id] is Function)
                    ? _patchMap[FeatureContract$.id](this.id)
                    : (_patchMap[FeatureContract$.id] is Patch)
                    ? _patchMap[FeatureContract$.id].applyTo(this.id)
                    : _patchMap[FeatureContract$.id])
                as String
          : this.id,
      displayName: _patchMap.containsKey(FeatureContract$.displayName)
          ? ((_patchMap[FeatureContract$.displayName] is Function)
                    ? _patchMap[FeatureContract$.displayName](this.displayName)
                    : (_patchMap[FeatureContract$.displayName] is Patch)
                    ? _patchMap[FeatureContract$.displayName].applyTo(
                        this.displayName,
                      )
                    : _patchMap[FeatureContract$.displayName])
                as String
          : this.displayName,
      entities: _patchMap.containsKey(FeatureContract$.entities)
          ? ((_patchMap[FeatureContract$.entities] is Function)
                    ? _patchMap[FeatureContract$.entities](this.entities)
                    : (_patchMap[FeatureContract$.entities] is Patch)
                    ? _patchMap[FeatureContract$.entities].applyTo(
                        this.entities,
                      )
                    : _patchMap[FeatureContract$.entities])
                as List<String>?
          : this.entities,
      boundary: _patchMap.containsKey(FeatureContract$.boundary)
          ? ((_patchMap[FeatureContract$.boundary] is Function)
                    ? _patchMap[FeatureContract$.boundary](this.boundary)
                    : (_patchMap[FeatureContract$.boundary] is Patch)
                    ? _patchMap[FeatureContract$.boundary].applyTo(
                        this.boundary,
                      )
                    : _patchMap[FeatureContract$.boundary])
                as SliceBoundary?
          : this.boundary,
      routes: _patchMap.containsKey(FeatureContract$.routes)
          ? ((_patchMap[FeatureContract$.routes] is Function)
                    ? _patchMap[FeatureContract$.routes](this.routes)
                    : (_patchMap[FeatureContract$.routes] is Patch)
                    ? _patchMap[FeatureContract$.routes].applyTo(this.routes)
                    : _patchMap[FeatureContract$.routes])
                as Set<String>?
          : this.routes,
      xrayLayer: _patchMap.containsKey(FeatureContract$.xrayLayer)
          ? ((_patchMap[FeatureContract$.xrayLayer] is Function)
                    ? _patchMap[FeatureContract$.xrayLayer](this.xrayLayer)
                    : (_patchMap[FeatureContract$.xrayLayer] is Patch)
                    ? _patchMap[FeatureContract$.xrayLayer].applyTo(
                        this.xrayLayer,
                      )
                    : _patchMap[FeatureContract$.xrayLayer])
                as XRayLayer?
          : this.xrayLayer,
      argSchema: _patchMap.containsKey(FeatureContract$.argSchema)
          ? ((_patchMap[FeatureContract$.argSchema] is Function)
                    ? _patchMap[FeatureContract$.argSchema](this.argSchema)
                    : (_patchMap[FeatureContract$.argSchema] is Patch)
                    ? _patchMap[FeatureContract$.argSchema].applyTo(
                        this.argSchema,
                      )
                    : _patchMap[FeatureContract$.argSchema])
                as Map<String, dynamic>?
          : this.argSchema,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeatureContract &&
        id == other.id &&
        displayName == other.displayName &&
        entities == other.entities &&
        boundary == other.boundary &&
        routes == other.routes &&
        xrayLayer == other.xrayLayer &&
        argSchema == other.argSchema;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.displayName,
      this.entities,
      this.boundary,
      this.routes,
      this.xrayLayer,
      this.argSchema,
    );
  }

  @override
  String toString() {
    return 'FeatureContract(' +
        'id: ${id}' +
        ', ' +
        'displayName: ${displayName}' +
        ', ' +
        'entities: ${entities}' +
        ', ' +
        'boundary: ${boundary}' +
        ', ' +
        'routes: ${routes}' +
        ', ' +
        'xrayLayer: ${xrayLayer}' +
        ', ' +
        'argSchema: ${argSchema})';
  }
}

extension FeatureContractPropertyHelpers on FeatureContract {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasDisplayName {
    return this.displayName.isNotEmpty;
  }

  bool get noDisplayName {
    return this.displayName.isEmpty;
  }

  List<String> get entitiesRequired {
    return this.entities ??
        (throw StateError('entities is required but was null'));
  }

  bool get hasEntities {
    return this.entities?.isNotEmpty ?? false;
  }

  bool get noEntities {
    return this.entities?.isEmpty ?? true;
  }

  bool get hasBoundary {
    return this.boundary != null;
  }

  bool get noBoundary {
    return this.boundary == null;
  }

  SliceBoundary get boundaryRequired {
    return this.boundary ??
        (throw StateError('boundary is required but was null'));
  }

  Set<String> get routesRequired {
    return this.routes ?? (throw StateError('routes is required but was null'));
  }

  bool get hasRoutes {
    return this.routes?.isNotEmpty ?? false;
  }

  bool get noRoutes {
    return this.routes?.isEmpty ?? true;
  }

  bool get hasXrayLayer {
    return this.xrayLayer != null;
  }

  bool get noXrayLayer {
    return this.xrayLayer == null;
  }

  XRayLayer get xrayLayerRequired {
    return this.xrayLayer ??
        (throw StateError('xrayLayer is required but was null'));
  }

  bool get isXrayLayerPresentation {
    return this.xrayLayer == XRayLayer.presentation;
  }

  bool get isXrayLayerDomain {
    return this.xrayLayer == XRayLayer.domain;
  }

  bool get isXrayLayerData {
    return this.xrayLayer == XRayLayer.data;
  }

  Map<String, dynamic> get argSchemaRequired {
    return this.argSchema ??
        (throw StateError('argSchema is required but was null'));
  }

  bool get hasArgSchema {
    return this.argSchema?.isNotEmpty ?? false;
  }

  bool get noArgSchema {
    return this.argSchema?.isEmpty ?? true;
  }
}

enum FeatureContract$ {
  id,
  displayName,
  entities,
  boundary,
  routes,
  xrayLayer,
  argSchema,
}

class FeatureContractPatch
    extends PatchBase<FeatureContract, FeatureContract$> {
  FeatureContract applyTo(FeatureContract entity) {
    return entity.patchWithFeatureContract(this);
  }

  FeatureContractPatch withId(String? value) {
    patchMap[FeatureContract$.id] = value;
    return this;
  }

  FeatureContractPatch withDisplayName(String? value) {
    patchMap[FeatureContract$.displayName] = value;
    return this;
  }

  FeatureContractPatch withEntities(List<String>? value) {
    patchMap[FeatureContract$.entities] = value;
    return this;
  }

  FeatureContractPatch withBoundary(SliceBoundary? value) {
    patchMap[FeatureContract$.boundary] = value;
    return this;
  }

  FeatureContractPatch withRoutes(Set<String>? value) {
    patchMap[FeatureContract$.routes] = value;
    return this;
  }

  FeatureContractPatch withXrayLayer(XRayLayer? value) {
    patchMap[FeatureContract$.xrayLayer] = value;
    return this;
  }

  FeatureContractPatch withArgSchema(Map<String, dynamic>? value) {
    patchMap[FeatureContract$.argSchema] = value;
    return this;
  }
}

/// Field descriptors for [FeatureContract] query construction
abstract final class FeatureContractFields {
  static const id = Field<FeatureContract, String>('id', _$id);

  static const displayName = Field<FeatureContract, String>(
    'displayName',
    _$displayName,
  );

  static const entities = Field<FeatureContract, List<String>?>(
    'entities',
    _$entities,
  );

  static const boundary = Field<FeatureContract, SliceBoundary?>(
    'boundary',
    _$boundary,
  );

  static const routes = Field<FeatureContract, Set<String>?>(
    'routes',
    _$routes,
  );

  static const xrayLayer = Field<FeatureContract, XRayLayer?>(
    'xrayLayer',
    _$xrayLayer,
  );

  static const argSchema = Field<FeatureContract, Map<String, dynamic>?>(
    'argSchema',
    _$argSchema,
  );

  static String _$id(FeatureContract e) {
    return e.id;
  }

  static String _$displayName(FeatureContract e) {
    return e.displayName;
  }

  static List<String>? _$entities(FeatureContract e) {
    return e.entities;
  }

  static SliceBoundary? _$boundary(FeatureContract e) {
    return e.boundary;
  }

  static Set<String>? _$routes(FeatureContract e) {
    return e.routes;
  }

  static XRayLayer? _$xrayLayer(FeatureContract e) {
    return e.xrayLayer;
  }

  static Map<String, dynamic>? _$argSchema(FeatureContract e) {
    return e.argSchema;
  }
}

extension FeatureContractCompareE on FeatureContract {
  Map<String, dynamic> compareToFeatureContract(FeatureContract other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (displayName != other.displayName) {
      diff['displayName'] = () => other.displayName;
    }

    if (entities != other.entities) {
      diff['entities'] = () => other.entities;
    }

    if (boundary != other.boundary) {
      diff['boundary'] = () => other.boundary;
    }

    if (routes != other.routes) {
      diff['routes'] = () => other.routes;
    }

    if (xrayLayer != other.xrayLayer) {
      diff['xrayLayer'] = () => other.xrayLayer;
    }

    if (argSchema != other.argSchema) {
      diff['argSchema'] = () => other.argSchema;
    }
    return diff;
  }
}
