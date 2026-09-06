// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'app_notification.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class AppNotification {
  AppNotification({
    required String this.id,
    required String this.type,
    required String this.title,
    required String this.body,
    required String this.targetType,
    required String this.targetId,
    required bool this.read,
    required String this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  final String id;

  final String type;

  final String title;

  final String body;

  final String targetType;

  final String targetId;

  final bool read;

  final String createdAt;

  AppNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    String? targetType,
    String? targetId,
    bool? read,
    String? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  AppNotification copyWithField<T>(Field<AppNotification, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'type':
        return copyWith(type: value as String);
      case 'title':
        return copyWith(title: value as String);
      case 'body':
        return copyWith(body: value as String);
      case 'targetType':
        return copyWith(targetType: value as String);
      case 'targetId':
        return copyWith(targetId: value as String);
      case 'read':
        return copyWith(read: value as bool);
      case 'createdAt':
        return copyWith(createdAt: value as String);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'AppNotification has no settable field with this name',
        );
    }
  }

  AppNotification copyWithAppNotification({
    String? id,
    String? type,
    String? title,
    String? body,
    String? targetType,
    String? targetId,
    bool? read,
    String? createdAt,
  }) {
    return copyWith(
      id: id,
      type: type,
      title: title,
      body: body,
      targetType: targetType,
      targetId: targetId,
      read: read,
      createdAt: createdAt,
    );
  }

  AppNotification patchWithAppNotification([AppNotificationPatch? patchInput]) {
    final _patcher = patchInput ?? AppNotificationPatch();
    final _patchMap = _patcher.patchMap;
    return AppNotification(
      id: _patchMap.containsKey(AppNotification$.id)
          ? ((_patchMap[AppNotification$.id] is Function)
                    ? _patchMap[AppNotification$.id](this.id)
                    : (_patchMap[AppNotification$.id] is Patch)
                    ? _patchMap[AppNotification$.id].applyTo(this.id)
                    : _patchMap[AppNotification$.id])
                as String
          : this.id,
      type: _patchMap.containsKey(AppNotification$.type)
          ? ((_patchMap[AppNotification$.type] is Function)
                    ? _patchMap[AppNotification$.type](this.type)
                    : (_patchMap[AppNotification$.type] is Patch)
                    ? _patchMap[AppNotification$.type].applyTo(this.type)
                    : _patchMap[AppNotification$.type])
                as String
          : this.type,
      title: _patchMap.containsKey(AppNotification$.title)
          ? ((_patchMap[AppNotification$.title] is Function)
                    ? _patchMap[AppNotification$.title](this.title)
                    : (_patchMap[AppNotification$.title] is Patch)
                    ? _patchMap[AppNotification$.title].applyTo(this.title)
                    : _patchMap[AppNotification$.title])
                as String
          : this.title,
      body: _patchMap.containsKey(AppNotification$.body)
          ? ((_patchMap[AppNotification$.body] is Function)
                    ? _patchMap[AppNotification$.body](this.body)
                    : (_patchMap[AppNotification$.body] is Patch)
                    ? _patchMap[AppNotification$.body].applyTo(this.body)
                    : _patchMap[AppNotification$.body])
                as String
          : this.body,
      targetType: _patchMap.containsKey(AppNotification$.targetType)
          ? ((_patchMap[AppNotification$.targetType] is Function)
                    ? _patchMap[AppNotification$.targetType](this.targetType)
                    : (_patchMap[AppNotification$.targetType] is Patch)
                    ? _patchMap[AppNotification$.targetType].applyTo(
                        this.targetType,
                      )
                    : _patchMap[AppNotification$.targetType])
                as String
          : this.targetType,
      targetId: _patchMap.containsKey(AppNotification$.targetId)
          ? ((_patchMap[AppNotification$.targetId] is Function)
                    ? _patchMap[AppNotification$.targetId](this.targetId)
                    : (_patchMap[AppNotification$.targetId] is Patch)
                    ? _patchMap[AppNotification$.targetId].applyTo(
                        this.targetId,
                      )
                    : _patchMap[AppNotification$.targetId])
                as String
          : this.targetId,
      read: _patchMap.containsKey(AppNotification$.read)
          ? ((_patchMap[AppNotification$.read] is Function)
                    ? _patchMap[AppNotification$.read](this.read)
                    : (_patchMap[AppNotification$.read] is Patch)
                    ? _patchMap[AppNotification$.read].applyTo(this.read)
                    : _patchMap[AppNotification$.read])
                as bool
          : this.read,
      createdAt: _patchMap.containsKey(AppNotification$.createdAt)
          ? ((_patchMap[AppNotification$.createdAt] is Function)
                    ? _patchMap[AppNotification$.createdAt](this.createdAt)
                    : (_patchMap[AppNotification$.createdAt] is Patch)
                    ? _patchMap[AppNotification$.createdAt].applyTo(
                        this.createdAt,
                      )
                    : _patchMap[AppNotification$.createdAt])
                as String
          : this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification &&
        id == other.id &&
        type == other.type &&
        title == other.title &&
        body == other.body &&
        targetType == other.targetType &&
        targetId == other.targetId &&
        read == other.read &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.type,
      this.title,
      this.body,
      this.targetType,
      this.targetId,
      this.read,
      this.createdAt,
    );
  }

  @override
  String toString() {
    return 'AppNotification(' +
        'id: ${id}' +
        ', ' +
        'type: ${type}' +
        ', ' +
        'title: ${title}' +
        ', ' +
        'body: ${body}' +
        ', ' +
        'targetType: ${targetType}' +
        ', ' +
        'targetId: ${targetId}' +
        ', ' +
        'read: ${read}' +
        ', ' +
        'createdAt: ${createdAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$AppNotificationToJson(this);
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

extension AppNotificationPropertyHelpers on AppNotification {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasType {
    return this.type.isNotEmpty;
  }

  bool get noType {
    return this.type.isEmpty;
  }

  bool get hasTitle {
    return this.title.isNotEmpty;
  }

  bool get noTitle {
    return this.title.isEmpty;
  }

  bool get hasBody {
    return this.body.isNotEmpty;
  }

  bool get noBody {
    return this.body.isEmpty;
  }

  bool get hasTargetType {
    return this.targetType.isNotEmpty;
  }

  bool get noTargetType {
    return this.targetType.isEmpty;
  }

  bool get hasTargetId {
    return this.targetId.isNotEmpty;
  }

  bool get noTargetId {
    return this.targetId.isEmpty;
  }

  bool get hasCreatedAt {
    return this.createdAt.isNotEmpty;
  }

  bool get noCreatedAt {
    return this.createdAt.isEmpty;
  }
}

extension AppNotificationSerialization on AppNotification {
  Map<String, dynamic> toJson() {
    return _$AppNotificationToJson(this);
  }
}

enum AppNotification$ {
  id,
  type,
  title,
  body,
  targetType,
  targetId,
  read,
  createdAt,
}

class AppNotificationPatch
    extends PatchBase<AppNotification, AppNotification$> {
  AppNotification applyTo(AppNotification entity) {
    return entity.patchWithAppNotification(this);
  }

  AppNotificationPatch withId(String? value) {
    patchMap[AppNotification$.id] = value;
    return this;
  }

  AppNotificationPatch withType(String? value) {
    patchMap[AppNotification$.type] = value;
    return this;
  }

  AppNotificationPatch withTitle(String? value) {
    patchMap[AppNotification$.title] = value;
    return this;
  }

  AppNotificationPatch withBody(String? value) {
    patchMap[AppNotification$.body] = value;
    return this;
  }

  AppNotificationPatch withTargetType(String? value) {
    patchMap[AppNotification$.targetType] = value;
    return this;
  }

  AppNotificationPatch withTargetId(String? value) {
    patchMap[AppNotification$.targetId] = value;
    return this;
  }

  AppNotificationPatch withRead(bool? value) {
    patchMap[AppNotification$.read] = value;
    return this;
  }

  AppNotificationPatch withCreatedAt(String? value) {
    patchMap[AppNotification$.createdAt] = value;
    return this;
  }
}

/// Field descriptors for [AppNotification] query construction
abstract final class AppNotificationFields {
  static const id = Field<AppNotification, String>('id', _$id);

  static const type = Field<AppNotification, String>('type', _$type);

  static const title = Field<AppNotification, String>('title', _$title);

  static const body = Field<AppNotification, String>('body', _$body);

  static const targetType = Field<AppNotification, String>(
    'targetType',
    _$targetType,
  );

  static const targetId = Field<AppNotification, String>(
    'targetId',
    _$targetId,
  );

  static const read = Field<AppNotification, bool>('read', _$read);

  static const createdAt = Field<AppNotification, String>(
    'createdAt',
    _$createdAt,
  );

  static String _$id(AppNotification e) {
    return e.id;
  }

  static String _$type(AppNotification e) {
    return e.type;
  }

  static String _$title(AppNotification e) {
    return e.title;
  }

  static String _$body(AppNotification e) {
    return e.body;
  }

  static String _$targetType(AppNotification e) {
    return e.targetType;
  }

  static String _$targetId(AppNotification e) {
    return e.targetId;
  }

  static bool _$read(AppNotification e) {
    return e.read;
  }

  static String _$createdAt(AppNotification e) {
    return e.createdAt;
  }
}

extension AppNotificationCompareE on AppNotification {
  Map<String, dynamic> compareToAppNotification(AppNotification other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (type != other.type) {
      diff['type'] = () => other.type;
    }

    if (title != other.title) {
      diff['title'] = () => other.title;
    }

    if (body != other.body) {
      diff['body'] = () => other.body;
    }

    if (targetType != other.targetType) {
      diff['targetType'] = () => other.targetType;
    }

    if (targetId != other.targetId) {
      diff['targetId'] = () => other.targetId;
    }

    if (read != other.read) {
      diff['read'] = () => other.read;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }
    return diff;
  }
}
