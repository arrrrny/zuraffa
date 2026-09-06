// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'text_spark.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class TextSpark {
  TextSpark({String? id, required String this.text, String? this.sourceChannel})
    : this.id = id ?? const Uuid().v4();

  factory TextSpark.fromJson(Map<String, dynamic> json) =>
      _$TextSparkFromJson(json);

  final String id;

  final String text;

  final String? sourceChannel;

  TextSpark copyWith({String? id, String? text, String? sourceChannel}) {
    return TextSpark(
      id: id ?? this.id,
      text: text ?? this.text,
      sourceChannel: sourceChannel ?? this.sourceChannel,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  TextSpark copyWithField<T>(Field<TextSpark, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'text':
        return copyWith(text: value as String);
      case 'sourceChannel':
        return copyWith(sourceChannel: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'TextSpark has no settable field with this name',
        );
    }
  }

  TextSpark copyWithTextSpark({
    String? id,
    String? text,
    String? sourceChannel,
  }) {
    return copyWith(id: id, text: text, sourceChannel: sourceChannel);
  }

  TextSpark patchWithTextSpark([TextSparkPatch? patchInput]) {
    final _patcher = patchInput ?? TextSparkPatch();
    final _patchMap = _patcher.patchMap;
    return TextSpark(
      id: _patchMap.containsKey(TextSpark$.id)
          ? ((_patchMap[TextSpark$.id] is Function)
                    ? _patchMap[TextSpark$.id](this.id)
                    : (_patchMap[TextSpark$.id] is Patch)
                    ? _patchMap[TextSpark$.id].applyTo(this.id)
                    : _patchMap[TextSpark$.id])
                as String
          : this.id,
      text: _patchMap.containsKey(TextSpark$.text)
          ? ((_patchMap[TextSpark$.text] is Function)
                    ? _patchMap[TextSpark$.text](this.text)
                    : (_patchMap[TextSpark$.text] is Patch)
                    ? _patchMap[TextSpark$.text].applyTo(this.text)
                    : _patchMap[TextSpark$.text])
                as String
          : this.text,
      sourceChannel: _patchMap.containsKey(TextSpark$.sourceChannel)
          ? ((_patchMap[TextSpark$.sourceChannel] is Function)
                    ? _patchMap[TextSpark$.sourceChannel](this.sourceChannel)
                    : (_patchMap[TextSpark$.sourceChannel] is Patch)
                    ? _patchMap[TextSpark$.sourceChannel].applyTo(
                        this.sourceChannel,
                      )
                    : _patchMap[TextSpark$.sourceChannel])
                as String?
          : this.sourceChannel,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextSpark &&
        id == other.id &&
        text == other.text &&
        sourceChannel == other.sourceChannel;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.text, this.sourceChannel);
  }

  @override
  String toString() {
    return 'TextSpark(' +
        'id: ${id}' +
        ', ' +
        'text: ${text}' +
        ', ' +
        'sourceChannel: ${sourceChannel})';
  }

  /// Value equality that ignores the auto-generated `id`
  /// field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)`). See issue #127.
  bool valueEquals(Object other) {
    if (identical(this, other)) return true;
    return other is TextSpark &&
        text == other.text &&
        sourceChannel == other.sourceChannel;
  }

  /// The full `toJson()` output with the auto-generated
  /// `id` field (and any other field listed in
  /// `@Zorphy(equalityExcludes: ...)` ) removed. Use a
  /// canonical serialized representation (e.g.,
  /// `toJsonValue().toString()`) or an explicit value-key
  /// type for deduplication. See issue #127.
  Map<String, dynamic> toJsonValue() {
    final Map<String, dynamic> data = _$TextSparkToJson(this);
    data.remove('id');
    return data;
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$TextSparkToJson(this);
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

extension TextSparkPropertyHelpers on TextSpark {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasText {
    return this.text.isNotEmpty;
  }

  bool get noText {
    return this.text.isEmpty;
  }

  bool get hasSourceChannel {
    return this.sourceChannel?.isNotEmpty == true;
  }

  bool get noSourceChannel {
    return this.sourceChannel?.isEmpty ?? true;
  }

  String get sourceChannelRequired {
    return this.sourceChannel ??
        (throw StateError('sourceChannel is required but was null'));
  }
}

extension TextSparkSerialization on TextSpark {
  Map<String, dynamic> toJson() {
    return _$TextSparkToJson(this);
  }
}

enum TextSpark$ { id, text, sourceChannel }

class TextSparkPatch extends PatchBase<TextSpark, TextSpark$> {
  TextSpark applyTo(TextSpark entity) {
    return entity.patchWithTextSpark(this);
  }

  TextSparkPatch withId(String? value) {
    patchMap[TextSpark$.id] = value;
    return this;
  }

  TextSparkPatch withText(String? value) {
    patchMap[TextSpark$.text] = value;
    return this;
  }

  TextSparkPatch withSourceChannel(String? value) {
    patchMap[TextSpark$.sourceChannel] = value;
    return this;
  }
}

/// Field descriptors for [TextSpark] query construction
abstract final class TextSparkFields {
  static const id = Field<TextSpark, String>('id', _$id);

  static const text = Field<TextSpark, String>('text', _$text);

  static const sourceChannel = Field<TextSpark, String?>(
    'sourceChannel',
    _$sourceChannel,
  );

  static String _$id(TextSpark e) {
    return e.id;
  }

  static String _$text(TextSpark e) {
    return e.text;
  }

  static String? _$sourceChannel(TextSpark e) {
    return e.sourceChannel;
  }
}

extension TextSparkCompareE on TextSpark {
  Map<String, dynamic> compareToTextSpark(TextSpark other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (text != other.text) {
      diff['text'] = () => other.text;
    }

    if (sourceChannel != other.sourceChannel) {
      diff['sourceChannel'] = () => other.sourceChannel;
    }
    return diff;
  }
}
