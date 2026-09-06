// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'feedback.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Feedback {
  Feedback({
    String? this.id,
    required String this.message,
    required FeedbackType this.type,
    String? this.imageUrl,
    DateTime? this.createdAt,
  });

  factory Feedback.fromJson(Map<String, dynamic> json) =>
      _$FeedbackFromJson(json);

  final String? id;

  final String message;

  final FeedbackType type;

  final String? imageUrl;

  final DateTime? createdAt;

  Feedback copyWith({
    String? id,
    String? message,
    FeedbackType? type,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return Feedback(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Feedback copyWithField<T>(Field<Feedback, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String?);
      case 'message':
        return copyWith(message: value as String);
      case 'type':
        return copyWith(type: value as FeedbackType);
      case 'imageUrl':
        return copyWith(imageUrl: value as String?);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Feedback has no settable field with this name',
        );
    }
  }

  Feedback copyWithFeedback({
    String? id,
    String? message,
    FeedbackType? type,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return copyWith(
      id: id,
      message: message,
      type: type,
      imageUrl: imageUrl,
      createdAt: createdAt,
    );
  }

  Feedback patchWithFeedback([FeedbackPatch? patchInput]) {
    final _patcher = patchInput ?? FeedbackPatch();
    final _patchMap = _patcher.patchMap;
    return Feedback(
      id: _patchMap.containsKey(Feedback$.id)
          ? ((_patchMap[Feedback$.id] is Function)
                    ? _patchMap[Feedback$.id](this.id)
                    : (_patchMap[Feedback$.id] is Patch)
                    ? _patchMap[Feedback$.id].applyTo(this.id)
                    : _patchMap[Feedback$.id])
                as String?
          : this.id,
      message: _patchMap.containsKey(Feedback$.message)
          ? ((_patchMap[Feedback$.message] is Function)
                    ? _patchMap[Feedback$.message](this.message)
                    : (_patchMap[Feedback$.message] is Patch)
                    ? _patchMap[Feedback$.message].applyTo(this.message)
                    : _patchMap[Feedback$.message])
                as String
          : this.message,
      type: _patchMap.containsKey(Feedback$.type)
          ? ((_patchMap[Feedback$.type] is Function)
                    ? _patchMap[Feedback$.type](this.type)
                    : (_patchMap[Feedback$.type] is Patch)
                    ? _patchMap[Feedback$.type].applyTo(this.type)
                    : _patchMap[Feedback$.type])
                as FeedbackType
          : this.type,
      imageUrl: _patchMap.containsKey(Feedback$.imageUrl)
          ? ((_patchMap[Feedback$.imageUrl] is Function)
                    ? _patchMap[Feedback$.imageUrl](this.imageUrl)
                    : (_patchMap[Feedback$.imageUrl] is Patch)
                    ? _patchMap[Feedback$.imageUrl].applyTo(this.imageUrl)
                    : _patchMap[Feedback$.imageUrl])
                as String?
          : this.imageUrl,
      createdAt: _patchMap.containsKey(Feedback$.createdAt)
          ? ((_patchMap[Feedback$.createdAt] is Function)
                    ? _patchMap[Feedback$.createdAt](this.createdAt)
                    : (_patchMap[Feedback$.createdAt] is Patch)
                    ? _patchMap[Feedback$.createdAt].applyTo(this.createdAt)
                    : _patchMap[Feedback$.createdAt])
                as DateTime?
          : this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Feedback &&
        id == other.id &&
        message == other.message &&
        type == other.type &&
        imageUrl == other.imageUrl &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.message,
      this.type,
      this.imageUrl,
      this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Feedback(' +
        'id: ${id}' +
        ', ' +
        'message: ${message}' +
        ', ' +
        'type: ${type}' +
        ', ' +
        'imageUrl: ${imageUrl}' +
        ', ' +
        'createdAt: ${createdAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$FeedbackToJson(this);
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

extension FeedbackPropertyHelpers on Feedback {
  bool get hasId {
    return this.id?.isNotEmpty == true;
  }

  bool get noId {
    return this.id?.isEmpty ?? true;
  }

  String get idRequired {
    return this.id ?? (throw StateError('id is required but was null'));
  }

  bool get hasMessage {
    return this.message.isNotEmpty;
  }

  bool get noMessage {
    return this.message.isEmpty;
  }

  bool get isTypeError {
    return this.type == FeedbackType.error;
  }

  bool get isTypeSuggestion {
    return this.type == FeedbackType.suggestion;
  }

  bool get isTypeThanks {
    return this.type == FeedbackType.thanks;
  }

  bool get hasImageUrl {
    return this.imageUrl?.isNotEmpty == true;
  }

  bool get noImageUrl {
    return this.imageUrl?.isEmpty ?? true;
  }

  String get imageUrlRequired {
    return this.imageUrl ??
        (throw StateError('imageUrl is required but was null'));
  }

  bool get hasCreatedAt {
    return this.createdAt != null;
  }

  bool get noCreatedAt {
    return this.createdAt == null;
  }

  DateTime get createdAtRequired {
    return this.createdAt ??
        (throw StateError('createdAt is required but was null'));
  }
}

extension FeedbackSerialization on Feedback {
  Map<String, dynamic> toJson() {
    return _$FeedbackToJson(this);
  }
}

enum Feedback$ { id, message, type, imageUrl, createdAt }

class FeedbackPatch extends PatchBase<Feedback, Feedback$> {
  Feedback applyTo(Feedback entity) {
    return entity.patchWithFeedback(this);
  }

  FeedbackPatch withId(String? value) {
    patchMap[Feedback$.id] = value;
    return this;
  }

  FeedbackPatch withMessage(String? value) {
    patchMap[Feedback$.message] = value;
    return this;
  }

  FeedbackPatch withType(FeedbackType? value) {
    patchMap[Feedback$.type] = value;
    return this;
  }

  FeedbackPatch withImageUrl(String? value) {
    patchMap[Feedback$.imageUrl] = value;
    return this;
  }

  FeedbackPatch withCreatedAt(DateTime? value) {
    patchMap[Feedback$.createdAt] = value;
    return this;
  }
}

/// Field descriptors for [Feedback] query construction
abstract final class FeedbackFields {
  static const id = Field<Feedback, String?>('id', _$id);

  static const message = Field<Feedback, String>('message', _$message);

  static const type = Field<Feedback, FeedbackType>('type', _$type);

  static const imageUrl = Field<Feedback, String?>('imageUrl', _$imageUrl);

  static const createdAt = Field<Feedback, DateTime?>('createdAt', _$createdAt);

  static String? _$id(Feedback e) {
    return e.id;
  }

  static String _$message(Feedback e) {
    return e.message;
  }

  static FeedbackType _$type(Feedback e) {
    return e.type;
  }

  static String? _$imageUrl(Feedback e) {
    return e.imageUrl;
  }

  static DateTime? _$createdAt(Feedback e) {
    return e.createdAt;
  }
}

extension FeedbackCompareE on Feedback {
  Map<String, dynamic> compareToFeedback(Feedback other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (message != other.message) {
      diff['message'] = () => other.message;
    }

    if (type != other.type) {
      diff['type'] = () => other.type;
    }

    if (imageUrl != other.imageUrl) {
      diff['imageUrl'] = () => other.imageUrl;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }
    return diff;
  }
}
