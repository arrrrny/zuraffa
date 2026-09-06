// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'telemetry_event.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class TelemetryEvent {
  TelemetryEvent({
    String? id,
    required TelemetryEventType this.type,
    required String this.value,
    Map<String, dynamic>? this.context,
  }) : this.id = id ?? const Uuid().v4();

  factory TelemetryEvent.fromJson(Map<String, dynamic> json) =>
      _$TelemetryEventFromJson(json);

  final String id;

  final TelemetryEventType type;

  final String value;

  final Map<String, dynamic>? context;

  TelemetryEvent copyWith({
    String? id,
    TelemetryEventType? type,
    String? value,
    Map<String, dynamic>? context,
  }) {
    return TelemetryEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      context: context ?? this.context,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  TelemetryEvent copyWithField<T>(Field<TelemetryEvent, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'type':
        return copyWith(type: value as TelemetryEventType);
      case 'value':
        return copyWith(value: value as String);
      case 'context':
        return copyWith(context: value as Map<String, dynamic>?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'TelemetryEvent has no settable field with this name',
        );
    }
  }

  TelemetryEvent copyWithTelemetryEvent({
    String? id,
    TelemetryEventType? type,
    String? value,
    Map<String, dynamic>? context,
  }) {
    return copyWith(id: id, type: type, value: value, context: context);
  }

  TelemetryEvent patchWithTelemetryEvent([TelemetryEventPatch? patchInput]) {
    final _patcher = patchInput ?? TelemetryEventPatch();
    final _patchMap = _patcher.patchMap;
    return TelemetryEvent(
      id: _patchMap.containsKey(TelemetryEvent$.id)
          ? ((_patchMap[TelemetryEvent$.id] is Function)
                    ? _patchMap[TelemetryEvent$.id](this.id)
                    : (_patchMap[TelemetryEvent$.id] is Patch)
                    ? _patchMap[TelemetryEvent$.id].applyTo(this.id)
                    : _patchMap[TelemetryEvent$.id])
                as String
          : this.id,
      type: _patchMap.containsKey(TelemetryEvent$.type)
          ? ((_patchMap[TelemetryEvent$.type] is Function)
                    ? _patchMap[TelemetryEvent$.type](this.type)
                    : (_patchMap[TelemetryEvent$.type] is Patch)
                    ? _patchMap[TelemetryEvent$.type].applyTo(this.type)
                    : _patchMap[TelemetryEvent$.type])
                as TelemetryEventType
          : this.type,
      value: _patchMap.containsKey(TelemetryEvent$.value)
          ? ((_patchMap[TelemetryEvent$.value] is Function)
                    ? _patchMap[TelemetryEvent$.value](this.value)
                    : (_patchMap[TelemetryEvent$.value] is Patch)
                    ? _patchMap[TelemetryEvent$.value].applyTo(this.value)
                    : _patchMap[TelemetryEvent$.value])
                as String
          : this.value,
      context: _patchMap.containsKey(TelemetryEvent$.context)
          ? ((_patchMap[TelemetryEvent$.context] is Function)
                    ? _patchMap[TelemetryEvent$.context](this.context)
                    : (_patchMap[TelemetryEvent$.context] is Patch)
                    ? _patchMap[TelemetryEvent$.context].applyTo(this.context)
                    : _patchMap[TelemetryEvent$.context])
                as Map<String, dynamic>?
          : this.context,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TelemetryEvent &&
        id == other.id &&
        type == other.type &&
        value == other.value &&
        context == other.context;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.type, this.value, this.context);
  }

  @override
  String toString() {
    return 'TelemetryEvent(' +
        'id: ${id}' +
        ', ' +
        'type: ${type}' +
        ', ' +
        'value: ${value}' +
        ', ' +
        'context: ${context})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is TelemetryEvent &&
        type == other.type &&
        value == other.value &&
        context == other.context;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$TelemetryEventToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$TelemetryEventToJson(this);
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

extension TelemetryEventPropertyHelpers on TelemetryEvent {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get isTypeScreen_view {
    return this.type == TelemetryEventType.screen_view;
  }

  bool get isTypeAction {
    return this.type == TelemetryEventType.action;
  }

  bool get isTypeError {
    return this.type == TelemetryEventType.error;
  }

  bool get isTypeNetwork {
    return this.type == TelemetryEventType.network;
  }

  bool get hasValue {
    return this.value.isNotEmpty;
  }

  bool get noValue {
    return this.value.isEmpty;
  }

  Map<String, dynamic> get contextRequired {
    return this.context ??
        (throw StateError('context is required but was null'));
  }

  bool get hasContext {
    return this.context?.isNotEmpty ?? false;
  }

  bool get noContext {
    return this.context?.isEmpty ?? true;
  }
}

extension TelemetryEventSerialization on TelemetryEvent {
  Map<String, dynamic> toJson() {
    return _$TelemetryEventToJson(this);
  }
}

enum TelemetryEvent$ { id, type, value, context }

class TelemetryEventPatch extends PatchBase<TelemetryEvent, TelemetryEvent$> {
  TelemetryEvent applyTo(TelemetryEvent entity) {
    return entity.patchWithTelemetryEvent(this);
  }

  TelemetryEventPatch withId(String? value) {
    patchMap[TelemetryEvent$.id] = value;
    return this;
  }

  TelemetryEventPatch withType(TelemetryEventType? value) {
    patchMap[TelemetryEvent$.type] = value;
    return this;
  }

  TelemetryEventPatch withValue(String? value) {
    patchMap[TelemetryEvent$.value] = value;
    return this;
  }

  TelemetryEventPatch withContext(Map<String, dynamic>? value) {
    patchMap[TelemetryEvent$.context] = value;
    return this;
  }
}

/// Field descriptors for [TelemetryEvent] query construction
abstract final class TelemetryEventFields {
  static const id = Field<TelemetryEvent, String>('id', _$id);

  static const type = Field<TelemetryEvent, TelemetryEventType>('type', _$type);

  static const value = Field<TelemetryEvent, String>('value', _$value);

  static const context = Field<TelemetryEvent, Map<String, dynamic>?>(
    'context',
    _$context,
  );

  static String _$id(TelemetryEvent e) {
    return e.id;
  }

  static TelemetryEventType _$type(TelemetryEvent e) {
    return e.type;
  }

  static String _$value(TelemetryEvent e) {
    return e.value;
  }

  static Map<String, dynamic>? _$context(TelemetryEvent e) {
    return e.context;
  }
}

extension TelemetryEventCompareE on TelemetryEvent {
  Map<String, dynamic> compareToTelemetryEvent(TelemetryEvent other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (type != other.type) {
      diff['type'] = () => other.type;
    }

    if (value != other.value) {
      diff['value'] = () => other.value;
    }

    if (context != other.context) {
      diff['context'] = () => other.context;
    }
    return diff;
  }
}
