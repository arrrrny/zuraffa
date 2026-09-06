// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'ai_conversation.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class AiConversation {
  AiConversation({
    required String this.id,
    required String this.sessionId,
    required DateTime this.createdAt,
    required DateTime this.updatedAt,
  });

  factory AiConversation.fromJson(Map<String, dynamic> json) =>
      _$AiConversationFromJson(json);

  final String id;

  final String sessionId;

  final DateTime createdAt;

  final DateTime updatedAt;

  AiConversation copyWith({
    String? id,
    String? sessionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiConversation(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  AiConversation copyWithField<T>(Field<AiConversation, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'sessionId':
        return copyWith(sessionId: value as String);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime);
      case 'updatedAt':
        return copyWith(updatedAt: value as DateTime);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'AiConversation has no settable field with this name',
        );
    }
  }

  AiConversation copyWithAiConversation({
    String? id,
    String? sessionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return copyWith(
      id: id,
      sessionId: sessionId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  AiConversation patchWithAiConversation([AiConversationPatch? patchInput]) {
    final _patcher = patchInput ?? AiConversationPatch();
    final _patchMap = _patcher.patchMap;
    return AiConversation(
      id: _patchMap.containsKey(AiConversation$.id)
          ? ((_patchMap[AiConversation$.id] is Function)
                    ? _patchMap[AiConversation$.id](this.id)
                    : (_patchMap[AiConversation$.id] is Patch)
                    ? _patchMap[AiConversation$.id].applyTo(this.id)
                    : _patchMap[AiConversation$.id])
                as String
          : this.id,
      sessionId: _patchMap.containsKey(AiConversation$.sessionId)
          ? ((_patchMap[AiConversation$.sessionId] is Function)
                    ? _patchMap[AiConversation$.sessionId](this.sessionId)
                    : (_patchMap[AiConversation$.sessionId] is Patch)
                    ? _patchMap[AiConversation$.sessionId].applyTo(
                        this.sessionId,
                      )
                    : _patchMap[AiConversation$.sessionId])
                as String
          : this.sessionId,
      createdAt: _patchMap.containsKey(AiConversation$.createdAt)
          ? ((_patchMap[AiConversation$.createdAt] is Function)
                    ? _patchMap[AiConversation$.createdAt](this.createdAt)
                    : (_patchMap[AiConversation$.createdAt] is Patch)
                    ? _patchMap[AiConversation$.createdAt].applyTo(
                        this.createdAt,
                      )
                    : _patchMap[AiConversation$.createdAt])
                as DateTime
          : this.createdAt,
      updatedAt: _patchMap.containsKey(AiConversation$.updatedAt)
          ? ((_patchMap[AiConversation$.updatedAt] is Function)
                    ? _patchMap[AiConversation$.updatedAt](this.updatedAt)
                    : (_patchMap[AiConversation$.updatedAt] is Patch)
                    ? _patchMap[AiConversation$.updatedAt].applyTo(
                        this.updatedAt,
                      )
                    : _patchMap[AiConversation$.updatedAt])
                as DateTime
          : this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiConversation &&
        id == other.id &&
        sessionId == other.sessionId &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(this.id, this.sessionId, this.createdAt, this.updatedAt);
  }

  @override
  String toString() {
    return 'AiConversation(' +
        'id: ${id}' +
        ', ' +
        'sessionId: ${sessionId}' +
        ', ' +
        'createdAt: ${createdAt}' +
        ', ' +
        'updatedAt: ${updatedAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$AiConversationToJson(this);
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

extension AiConversationPropertyHelpers on AiConversation {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasSessionId {
    return this.sessionId.isNotEmpty;
  }

  bool get noSessionId {
    return this.sessionId.isEmpty;
  }
}

extension AiConversationSerialization on AiConversation {
  Map<String, dynamic> toJson() {
    return _$AiConversationToJson(this);
  }
}

enum AiConversation$ { id, sessionId, createdAt, updatedAt }

class AiConversationPatch extends PatchBase<AiConversation, AiConversation$> {
  AiConversation applyTo(AiConversation entity) {
    return entity.patchWithAiConversation(this);
  }

  AiConversationPatch withId(String? value) {
    patchMap[AiConversation$.id] = value;
    return this;
  }

  AiConversationPatch withSessionId(String? value) {
    patchMap[AiConversation$.sessionId] = value;
    return this;
  }

  AiConversationPatch withCreatedAt(DateTime? value) {
    patchMap[AiConversation$.createdAt] = value;
    return this;
  }

  AiConversationPatch withUpdatedAt(DateTime? value) {
    patchMap[AiConversation$.updatedAt] = value;
    return this;
  }
}

/// Field descriptors for [AiConversation] query construction
abstract final class AiConversationFields {
  static const id = Field<AiConversation, String>('id', _$id);

  static const sessionId = Field<AiConversation, String>(
    'sessionId',
    _$sessionId,
  );

  static const createdAt = Field<AiConversation, DateTime>(
    'createdAt',
    _$createdAt,
  );

  static const updatedAt = Field<AiConversation, DateTime>(
    'updatedAt',
    _$updatedAt,
  );

  static String _$id(AiConversation e) {
    return e.id;
  }

  static String _$sessionId(AiConversation e) {
    return e.sessionId;
  }

  static DateTime _$createdAt(AiConversation e) {
    return e.createdAt;
  }

  static DateTime _$updatedAt(AiConversation e) {
    return e.updatedAt;
  }
}

extension AiConversationCompareE on AiConversation {
  Map<String, dynamic> compareToAiConversation(AiConversation other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (sessionId != other.sessionId) {
      diff['sessionId'] = () => other.sessionId;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }

    if (updatedAt != other.updatedAt) {
      diff['updatedAt'] = () => other.updatedAt;
    }
    return diff;
  }
}
