// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'walkthrough_view.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class WalkthroughView {
  WalkthroughView({
    String? id,
    required String this.walkthroughId,
    required int this.stepIndex,
    DateTime? this.completedAt,
  }) : this.id = id ?? const Uuid().v4();

  factory WalkthroughView.fromJson(Map<String, dynamic> json) =>
      _$WalkthroughViewFromJson(json);

  final String id;

  final String walkthroughId;

  final int stepIndex;

  final DateTime? completedAt;

  WalkthroughView copyWith({
    String? id,
    String? walkthroughId,
    int? stepIndex,
    DateTime? completedAt,
  }) {
    return WalkthroughView(
      id: id ?? this.id,
      walkthroughId: walkthroughId ?? this.walkthroughId,
      stepIndex: stepIndex ?? this.stepIndex,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  WalkthroughView copyWithField<T>(Field<WalkthroughView, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'walkthroughId':
        return copyWith(walkthroughId: value as String);
      case 'stepIndex':
        return copyWith(stepIndex: value as int);
      case 'completedAt':
        return copyWith(completedAt: value as DateTime?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'WalkthroughView has no settable field with this name',
        );
    }
  }

  WalkthroughView copyWithWalkthroughView({
    String? id,
    String? walkthroughId,
    int? stepIndex,
    DateTime? completedAt,
  }) {
    return copyWith(
      id: id,
      walkthroughId: walkthroughId,
      stepIndex: stepIndex,
      completedAt: completedAt,
    );
  }

  WalkthroughView patchWithWalkthroughView([WalkthroughViewPatch? patchInput]) {
    final _patcher = patchInput ?? WalkthroughViewPatch();
    final _patchMap = _patcher.patchMap;
    return WalkthroughView(
      id: _patchMap.containsKey(WalkthroughView$.id)
          ? ((_patchMap[WalkthroughView$.id] is Function)
                    ? _patchMap[WalkthroughView$.id](this.id)
                    : (_patchMap[WalkthroughView$.id] is Patch)
                    ? _patchMap[WalkthroughView$.id].applyTo(this.id)
                    : _patchMap[WalkthroughView$.id])
                as String
          : this.id,
      walkthroughId: _patchMap.containsKey(WalkthroughView$.walkthroughId)
          ? ((_patchMap[WalkthroughView$.walkthroughId] is Function)
                    ? _patchMap[WalkthroughView$.walkthroughId](
                        this.walkthroughId,
                      )
                    : (_patchMap[WalkthroughView$.walkthroughId] is Patch)
                    ? _patchMap[WalkthroughView$.walkthroughId].applyTo(
                        this.walkthroughId,
                      )
                    : _patchMap[WalkthroughView$.walkthroughId])
                as String
          : this.walkthroughId,
      stepIndex: _patchMap.containsKey(WalkthroughView$.stepIndex)
          ? ((_patchMap[WalkthroughView$.stepIndex] is Function)
                    ? _patchMap[WalkthroughView$.stepIndex](this.stepIndex)
                    : (_patchMap[WalkthroughView$.stepIndex] is Patch)
                    ? _patchMap[WalkthroughView$.stepIndex].applyTo(
                        this.stepIndex,
                      )
                    : _patchMap[WalkthroughView$.stepIndex])
                as int
          : this.stepIndex,
      completedAt: _patchMap.containsKey(WalkthroughView$.completedAt)
          ? ((_patchMap[WalkthroughView$.completedAt] is Function)
                    ? _patchMap[WalkthroughView$.completedAt](this.completedAt)
                    : (_patchMap[WalkthroughView$.completedAt] is Patch)
                    ? _patchMap[WalkthroughView$.completedAt].applyTo(
                        this.completedAt,
                      )
                    : _patchMap[WalkthroughView$.completedAt])
                as DateTime?
          : this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WalkthroughView &&
        id == other.id &&
        walkthroughId == other.walkthroughId &&
        stepIndex == other.stepIndex &&
        completedAt == other.completedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.walkthroughId,
      this.stepIndex,
      this.completedAt,
    );
  }

  @override
  String toString() {
    return 'WalkthroughView(' +
        'id: ${id}' +
        ', ' +
        'walkthroughId: ${walkthroughId}' +
        ', ' +
        'stepIndex: ${stepIndex}' +
        ', ' +
        'completedAt: ${completedAt})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is WalkthroughView &&
        walkthroughId == other.walkthroughId &&
        stepIndex == other.stepIndex &&
        completedAt == other.completedAt;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$WalkthroughViewToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$WalkthroughViewToJson(this);
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

extension WalkthroughViewPropertyHelpers on WalkthroughView {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasWalkthroughId {
    return this.walkthroughId.isNotEmpty;
  }

  bool get noWalkthroughId {
    return this.walkthroughId.isEmpty;
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
}

extension WalkthroughViewSerialization on WalkthroughView {
  Map<String, dynamic> toJson() {
    return _$WalkthroughViewToJson(this);
  }
}

enum WalkthroughView$ { id, walkthroughId, stepIndex, completedAt }

class WalkthroughViewPatch
    extends PatchBase<WalkthroughView, WalkthroughView$> {
  WalkthroughView applyTo(WalkthroughView entity) {
    return entity.patchWithWalkthroughView(this);
  }

  WalkthroughViewPatch withId(String? value) {
    patchMap[WalkthroughView$.id] = value;
    return this;
  }

  WalkthroughViewPatch withWalkthroughId(String? value) {
    patchMap[WalkthroughView$.walkthroughId] = value;
    return this;
  }

  WalkthroughViewPatch withStepIndex(int? value) {
    patchMap[WalkthroughView$.stepIndex] = value;
    return this;
  }

  WalkthroughViewPatch withCompletedAt(DateTime? value) {
    patchMap[WalkthroughView$.completedAt] = value;
    return this;
  }
}

/// Field descriptors for [WalkthroughView] query construction
abstract final class WalkthroughViewFields {
  static const id = Field<WalkthroughView, String>('id', _$id);

  static const walkthroughId = Field<WalkthroughView, String>(
    'walkthroughId',
    _$walkthroughId,
  );

  static const stepIndex = Field<WalkthroughView, int>(
    'stepIndex',
    _$stepIndex,
  );

  static const completedAt = Field<WalkthroughView, DateTime?>(
    'completedAt',
    _$completedAt,
  );

  static String _$id(WalkthroughView e) {
    return e.id;
  }

  static String _$walkthroughId(WalkthroughView e) {
    return e.walkthroughId;
  }

  static int _$stepIndex(WalkthroughView e) {
    return e.stepIndex;
  }

  static DateTime? _$completedAt(WalkthroughView e) {
    return e.completedAt;
  }
}

extension WalkthroughViewCompareE on WalkthroughView {
  Map<String, dynamic> compareToWalkthroughView(WalkthroughView other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (walkthroughId != other.walkthroughId) {
      diff['walkthroughId'] = () => other.walkthroughId;
    }

    if (stepIndex != other.stepIndex) {
      diff['stepIndex'] = () => other.stepIndex;
    }

    if (completedAt != other.completedAt) {
      diff['completedAt'] = () => other.completedAt;
    }
    return diff;
  }
}
