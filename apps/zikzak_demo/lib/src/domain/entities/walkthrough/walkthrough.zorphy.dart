// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'walkthrough.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Walkthrough {
  Walkthrough({
    required String this.id,
    required String this.name,
    required String this.version,
    required List<WalkthroughStep> this.steps,
    required bool this.isCompleted,
    DateTime? this.completedAt,
    String? this.currentStepId,
    required int this.currentStepIndex,
  });

  factory Walkthrough.fromJson(Map<String, dynamic> json) =>
      _$WalkthroughFromJson(json);

  final String id;

  final String name;

  final String version;

  final List<WalkthroughStep> steps;

  final bool isCompleted;

  final DateTime? completedAt;

  final String? currentStepId;

  final int currentStepIndex;

  Walkthrough copyWith({
    String? id,
    String? name,
    String? version,
    List<WalkthroughStep>? steps,
    bool? isCompleted,
    DateTime? completedAt,
    String? currentStepId,
    int? currentStepIndex,
  }) {
    return Walkthrough(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      steps: steps ?? this.steps,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      currentStepId: currentStepId ?? this.currentStepId,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Walkthrough copyWithField<T>(Field<Walkthrough, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'name':
        return copyWith(name: value as String);
      case 'version':
        return copyWith(version: value as String);
      case 'steps':
        return copyWith(steps: value as List<WalkthroughStep>);
      case 'isCompleted':
        return copyWith(isCompleted: value as bool);
      case 'completedAt':
        return copyWith(completedAt: value as DateTime?);
      case 'currentStepId':
        return copyWith(currentStepId: value as String?);
      case 'currentStepIndex':
        return copyWith(currentStepIndex: value as int);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Walkthrough has no settable field with this name',
        );
    }
  }

  Walkthrough copyWithWalkthrough({
    String? id,
    String? name,
    String? version,
    List<WalkthroughStep>? steps,
    bool? isCompleted,
    DateTime? completedAt,
    String? currentStepId,
    int? currentStepIndex,
  }) {
    return copyWith(
      id: id,
      name: name,
      version: version,
      steps: steps,
      isCompleted: isCompleted,
      completedAt: completedAt,
      currentStepId: currentStepId,
      currentStepIndex: currentStepIndex,
    );
  }

  Walkthrough patchWithWalkthrough([WalkthroughPatch? patchInput]) {
    final _patcher = patchInput ?? WalkthroughPatch();
    final _patchMap = _patcher.patchMap;
    return Walkthrough(
      id: _patchMap.containsKey(Walkthrough$.id)
          ? ((_patchMap[Walkthrough$.id] is Function)
                    ? _patchMap[Walkthrough$.id](this.id)
                    : (_patchMap[Walkthrough$.id] is Patch)
                    ? _patchMap[Walkthrough$.id].applyTo(this.id)
                    : _patchMap[Walkthrough$.id])
                as String
          : this.id,
      name: _patchMap.containsKey(Walkthrough$.name_)
          ? ((_patchMap[Walkthrough$.name_] is Function)
                    ? _patchMap[Walkthrough$.name_](this.name)
                    : (_patchMap[Walkthrough$.name_] is Patch)
                    ? _patchMap[Walkthrough$.name_].applyTo(this.name)
                    : _patchMap[Walkthrough$.name_])
                as String
          : this.name,
      version: _patchMap.containsKey(Walkthrough$.version)
          ? ((_patchMap[Walkthrough$.version] is Function)
                    ? _patchMap[Walkthrough$.version](this.version)
                    : (_patchMap[Walkthrough$.version] is Patch)
                    ? _patchMap[Walkthrough$.version].applyTo(this.version)
                    : _patchMap[Walkthrough$.version])
                as String
          : this.version,
      steps: _patchMap.containsKey(Walkthrough$.steps)
          ? ((_patchMap[Walkthrough$.steps] is Function)
                    ? _patchMap[Walkthrough$.steps](this.steps)
                    : (_patchMap[Walkthrough$.steps] is Patch)
                    ? _patchMap[Walkthrough$.steps].applyTo(this.steps)
                    : _patchMap[Walkthrough$.steps])
                as List<WalkthroughStep>
          : this.steps,
      isCompleted: _patchMap.containsKey(Walkthrough$.isCompleted)
          ? ((_patchMap[Walkthrough$.isCompleted] is Function)
                    ? _patchMap[Walkthrough$.isCompleted](this.isCompleted)
                    : (_patchMap[Walkthrough$.isCompleted] is Patch)
                    ? _patchMap[Walkthrough$.isCompleted].applyTo(
                        this.isCompleted,
                      )
                    : _patchMap[Walkthrough$.isCompleted])
                as bool
          : this.isCompleted,
      completedAt: _patchMap.containsKey(Walkthrough$.completedAt)
          ? ((_patchMap[Walkthrough$.completedAt] is Function)
                    ? _patchMap[Walkthrough$.completedAt](this.completedAt)
                    : (_patchMap[Walkthrough$.completedAt] is Patch)
                    ? _patchMap[Walkthrough$.completedAt].applyTo(
                        this.completedAt,
                      )
                    : _patchMap[Walkthrough$.completedAt])
                as DateTime?
          : this.completedAt,
      currentStepId: _patchMap.containsKey(Walkthrough$.currentStepId)
          ? ((_patchMap[Walkthrough$.currentStepId] is Function)
                    ? _patchMap[Walkthrough$.currentStepId](this.currentStepId)
                    : (_patchMap[Walkthrough$.currentStepId] is Patch)
                    ? _patchMap[Walkthrough$.currentStepId].applyTo(
                        this.currentStepId,
                      )
                    : _patchMap[Walkthrough$.currentStepId])
                as String?
          : this.currentStepId,
      currentStepIndex: _patchMap.containsKey(Walkthrough$.currentStepIndex)
          ? ((_patchMap[Walkthrough$.currentStepIndex] is Function)
                    ? _patchMap[Walkthrough$.currentStepIndex](
                        this.currentStepIndex,
                      )
                    : (_patchMap[Walkthrough$.currentStepIndex] is Patch)
                    ? _patchMap[Walkthrough$.currentStepIndex].applyTo(
                        this.currentStepIndex,
                      )
                    : _patchMap[Walkthrough$.currentStepIndex])
                as int
          : this.currentStepIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Walkthrough &&
        id == other.id &&
        name == other.name &&
        version == other.version &&
        steps == other.steps &&
        isCompleted == other.isCompleted &&
        completedAt == other.completedAt &&
        currentStepId == other.currentStepId &&
        currentStepIndex == other.currentStepIndex;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.name,
      this.version,
      this.steps,
      this.isCompleted,
      this.completedAt,
      this.currentStepId,
      this.currentStepIndex,
    );
  }

  @override
  String toString() {
    return 'Walkthrough(' +
        'id: ${id}' +
        ', ' +
        'name: ${name}' +
        ', ' +
        'version: ${version}' +
        ', ' +
        'steps: ${steps}' +
        ', ' +
        'isCompleted: ${isCompleted}' +
        ', ' +
        'completedAt: ${completedAt}' +
        ', ' +
        'currentStepId: ${currentStepId}' +
        ', ' +
        'currentStepIndex: ${currentStepIndex})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$WalkthroughToJson(this);
    _sanitizeJson(data);
    return data;
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('__typename');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }
}

extension WalkthroughPropertyHelpers on Walkthrough {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasName {
    return this.name.isNotEmpty;
  }

  bool get noName {
    return this.name.isEmpty;
  }

  bool get hasVersion {
    return this.version.isNotEmpty;
  }

  bool get noVersion {
    return this.version.isEmpty;
  }

  bool get hasSteps {
    return this.steps.isNotEmpty;
  }

  bool get noSteps {
    return this.steps.isEmpty;
  }

  bool get hasCompletedAt {
    return this.completedAt != null;
  }

  bool get noCompletedAt {
    return this.completedAt == null;
  }

  DateTime get completedAtRequired {
    return this.completedAt ??
        (throw StateError('completedAt is required but was null'));
  }

  bool get hasCurrentStepId {
    return this.currentStepId?.isNotEmpty == true;
  }

  bool get noCurrentStepId {
    return this.currentStepId?.isEmpty ?? true;
  }

  String get currentStepIdRequired {
    return this.currentStepId ??
        (throw StateError('currentStepId is required but was null'));
  }
}

extension WalkthroughSerialization on Walkthrough {
  Map<String, dynamic> toJson() {
    return _$WalkthroughToJson(this);
  }
}

enum Walkthrough$ {
  id,
  name_,
  version,
  steps,
  isCompleted,
  completedAt,
  currentStepId,
  currentStepIndex,
}

class WalkthroughPatch extends PatchBase<Walkthrough, Walkthrough$> {
  Walkthrough applyTo(Walkthrough entity) {
    return entity.patchWithWalkthrough(this);
  }

  WalkthroughPatch withId(String? value) {
    patchMap[Walkthrough$.id] = value;
    return this;
  }

  WalkthroughPatch withName(String? value) {
    patchMap[Walkthrough$.name_] = value;
    return this;
  }

  WalkthroughPatch withVersion(String? value) {
    patchMap[Walkthrough$.version] = value;
    return this;
  }

  WalkthroughPatch withSteps(List<WalkthroughStep>? value) {
    patchMap[Walkthrough$.steps] = value;
    return this;
  }

  WalkthroughPatch updateStepsAt(
    int index,
    WalkthroughStepPatch Function(WalkthroughStepPatch) patch,
  ) {
    patchMap[Walkthrough$.steps] = (List<dynamic> list) {
      var updatedList = List<WalkthroughStep>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          WalkthroughStepPatch(),
        ).applyTo(updatedList[index] as WalkthroughStep);
      }
      return updatedList;
    };
    return this;
  }

  WalkthroughPatch withIsCompleted(bool? value) {
    patchMap[Walkthrough$.isCompleted] = value;
    return this;
  }

  WalkthroughPatch withCompletedAt(DateTime? value) {
    patchMap[Walkthrough$.completedAt] = value;
    return this;
  }

  WalkthroughPatch withCurrentStepId(String? value) {
    patchMap[Walkthrough$.currentStepId] = value;
    return this;
  }

  WalkthroughPatch withCurrentStepIndex(int? value) {
    patchMap[Walkthrough$.currentStepIndex] = value;
    return this;
  }
}

/// Field descriptors for [Walkthrough] query construction
abstract final class WalkthroughFields {
  static const id = Field<Walkthrough, String>('id', _$id);

  static const name = Field<Walkthrough, String>('name', _$name);

  static const version = Field<Walkthrough, String>('version', _$version);

  static const steps = Field<Walkthrough, List<WalkthroughStep>>(
    'steps',
    _$steps,
  );

  static const isCompleted = Field<Walkthrough, bool>(
    'isCompleted',
    _$isCompleted,
  );

  static const completedAt = Field<Walkthrough, DateTime?>(
    'completedAt',
    _$completedAt,
  );

  static const currentStepId = Field<Walkthrough, String?>(
    'currentStepId',
    _$currentStepId,
  );

  static const currentStepIndex = Field<Walkthrough, int>(
    'currentStepIndex',
    _$currentStepIndex,
  );

  static String _$id(Walkthrough e) {
    return e.id;
  }

  static String _$name(Walkthrough e) {
    return e.name;
  }

  static String _$version(Walkthrough e) {
    return e.version;
  }

  static List<WalkthroughStep> _$steps(Walkthrough e) {
    return e.steps;
  }

  static bool _$isCompleted(Walkthrough e) {
    return e.isCompleted;
  }

  static DateTime? _$completedAt(Walkthrough e) {
    return e.completedAt;
  }

  static String? _$currentStepId(Walkthrough e) {
    return e.currentStepId;
  }

  static int _$currentStepIndex(Walkthrough e) {
    return e.currentStepIndex;
  }
}

extension WalkthroughCompareE on Walkthrough {
  Map<String, dynamic> compareToWalkthrough(Walkthrough other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (name != other.name) {
      diff['name'] = () => other.name;
    }

    if (version != other.version) {
      diff['version'] = () => other.version;
    }

    if (steps != other.steps) {
      diff['steps'] = () => other.steps;
    }

    if (isCompleted != other.isCompleted) {
      diff['isCompleted'] = () => other.isCompleted;
    }

    if (completedAt != other.completedAt) {
      diff['completedAt'] = () => other.completedAt;
    }

    if (currentStepId != other.currentStepId) {
      diff['currentStepId'] = () => other.currentStepId;
    }

    if (currentStepIndex != other.currentStepIndex) {
      diff['currentStepIndex'] = () => other.currentStepIndex;
    }
    return diff;
  }
}
