// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'authentication.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Authentication {
  Authentication({
    required String this.id,
    required String this.userId,
    required AuthenticationMethod this.method,
    String? this.accessToken,
    String? this.refreshToken,
    DateTime? this.expiresAt,
    required DateTime this.createdAt,
  });

  factory Authentication.fromJson(Map<String, dynamic> json) =>
      _$AuthenticationFromJson(json);

  final String id;

  final String userId;

  final AuthenticationMethod method;

  final String? accessToken;

  final String? refreshToken;

  final DateTime? expiresAt;

  final DateTime createdAt;

  Authentication copyWith({
    String? id,
    String? userId,
    AuthenticationMethod? method,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return Authentication(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      method: method ?? this.method,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Authentication copyWithField<T>(Field<Authentication, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'userId':
        return copyWith(userId: value as String);
      case 'method':
        return copyWith(method: value as AuthenticationMethod);
      case 'accessToken':
        return copyWith(accessToken: value as String?);
      case 'refreshToken':
        return copyWith(refreshToken: value as String?);
      case 'expiresAt':
        return copyWith(expiresAt: value as DateTime?);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Authentication has no settable field with this name',
        );
    }
  }

  Authentication copyWithAuthentication({
    String? id,
    String? userId,
    AuthenticationMethod? method,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return copyWith(
      id: id,
      userId: userId,
      method: method,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      createdAt: createdAt,
    );
  }

  Authentication patchWithAuthentication([AuthenticationPatch? patchInput]) {
    final _patcher = patchInput ?? AuthenticationPatch();
    final _patchMap = _patcher.patchMap;
    return Authentication(
      id: _patchMap.containsKey(Authentication$.id)
          ? ((_patchMap[Authentication$.id] is Function)
                    ? _patchMap[Authentication$.id](this.id)
                    : (_patchMap[Authentication$.id] is Patch)
                    ? _patchMap[Authentication$.id].applyTo(this.id)
                    : _patchMap[Authentication$.id])
                as String
          : this.id,
      userId: _patchMap.containsKey(Authentication$.userId)
          ? ((_patchMap[Authentication$.userId] is Function)
                    ? _patchMap[Authentication$.userId](this.userId)
                    : (_patchMap[Authentication$.userId] is Patch)
                    ? _patchMap[Authentication$.userId].applyTo(this.userId)
                    : _patchMap[Authentication$.userId])
                as String
          : this.userId,
      method: _patchMap.containsKey(Authentication$.method)
          ? ((_patchMap[Authentication$.method] is Function)
                    ? _patchMap[Authentication$.method](this.method)
                    : (_patchMap[Authentication$.method] is Patch)
                    ? _patchMap[Authentication$.method].applyTo(this.method)
                    : _patchMap[Authentication$.method])
                as AuthenticationMethod
          : this.method,
      accessToken: _patchMap.containsKey(Authentication$.accessToken)
          ? ((_patchMap[Authentication$.accessToken] is Function)
                    ? _patchMap[Authentication$.accessToken](this.accessToken)
                    : (_patchMap[Authentication$.accessToken] is Patch)
                    ? _patchMap[Authentication$.accessToken].applyTo(
                        this.accessToken,
                      )
                    : _patchMap[Authentication$.accessToken])
                as String?
          : this.accessToken,
      refreshToken: _patchMap.containsKey(Authentication$.refreshToken)
          ? ((_patchMap[Authentication$.refreshToken] is Function)
                    ? _patchMap[Authentication$.refreshToken](this.refreshToken)
                    : (_patchMap[Authentication$.refreshToken] is Patch)
                    ? _patchMap[Authentication$.refreshToken].applyTo(
                        this.refreshToken,
                      )
                    : _patchMap[Authentication$.refreshToken])
                as String?
          : this.refreshToken,
      expiresAt: _patchMap.containsKey(Authentication$.expiresAt)
          ? ((_patchMap[Authentication$.expiresAt] is Function)
                    ? _patchMap[Authentication$.expiresAt](this.expiresAt)
                    : (_patchMap[Authentication$.expiresAt] is Patch)
                    ? _patchMap[Authentication$.expiresAt].applyTo(
                        this.expiresAt,
                      )
                    : _patchMap[Authentication$.expiresAt])
                as DateTime?
          : this.expiresAt,
      createdAt: _patchMap.containsKey(Authentication$.createdAt)
          ? ((_patchMap[Authentication$.createdAt] is Function)
                    ? _patchMap[Authentication$.createdAt](this.createdAt)
                    : (_patchMap[Authentication$.createdAt] is Patch)
                    ? _patchMap[Authentication$.createdAt].applyTo(
                        this.createdAt,
                      )
                    : _patchMap[Authentication$.createdAt])
                as DateTime
          : this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Authentication &&
        id == other.id &&
        userId == other.userId &&
        method == other.method &&
        accessToken == other.accessToken &&
        refreshToken == other.refreshToken &&
        expiresAt == other.expiresAt &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.userId,
      this.method,
      this.accessToken,
      this.refreshToken,
      this.expiresAt,
      this.createdAt,
    );
  }

  @override
  String toString() {
    return 'Authentication(' +
        'id: ${id}' +
        ', ' +
        'userId: ${userId}' +
        ', ' +
        'method: ${method}' +
        ', ' +
        'accessToken: ${accessToken}' +
        ', ' +
        'refreshToken: ${refreshToken}' +
        ', ' +
        'expiresAt: ${expiresAt}' +
        ', ' +
        'createdAt: ${createdAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$AuthenticationToJson(this);
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

extension AuthenticationPropertyHelpers on Authentication {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasUserId {
    return this.userId.isNotEmpty;
  }

  bool get noUserId {
    return this.userId.isEmpty;
  }

  bool get isMethodEmail {
    return this.method == AuthenticationMethod.email;
  }

  bool get isMethodGoogle {
    return this.method == AuthenticationMethod.google;
  }

  bool get isMethodApple {
    return this.method == AuthenticationMethod.apple;
  }

  bool get isMethodAnonymous {
    return this.method == AuthenticationMethod.anonymous;
  }

  bool get hasAccessToken {
    return this.accessToken?.isNotEmpty == true;
  }

  bool get noAccessToken {
    return this.accessToken?.isEmpty ?? true;
  }

  String get accessTokenRequired {
    return this.accessToken ??
        (throw StateError('accessToken is required but was null'));
  }

  bool get hasRefreshToken {
    return this.refreshToken?.isNotEmpty == true;
  }

  bool get noRefreshToken {
    return this.refreshToken?.isEmpty ?? true;
  }

  String get refreshTokenRequired {
    return this.refreshToken ??
        (throw StateError('refreshToken is required but was null'));
  }

  bool get hasExpiresAt {
    return this.expiresAt != null;
  }

  bool get noExpiresAt {
    return this.expiresAt == null;
  }

  DateTime get expiresAtRequired {
    return this.expiresAt ??
        (throw StateError('expiresAt is required but was null'));
  }
}

extension AuthenticationSerialization on Authentication {
  Map<String, dynamic> toJson() {
    return _$AuthenticationToJson(this);
  }
}

enum Authentication$ {
  id,
  userId,
  method,
  accessToken,
  refreshToken,
  expiresAt,
  createdAt,
}

class AuthenticationPatch extends PatchBase<Authentication, Authentication$> {
  Authentication applyTo(Authentication entity) {
    return entity.patchWithAuthentication(this);
  }

  AuthenticationPatch withId(String? value) {
    patchMap[Authentication$.id] = value;
    return this;
  }

  AuthenticationPatch withUserId(String? value) {
    patchMap[Authentication$.userId] = value;
    return this;
  }

  AuthenticationPatch withMethod(AuthenticationMethod? value) {
    patchMap[Authentication$.method] = value;
    return this;
  }

  AuthenticationPatch withAccessToken(String? value) {
    patchMap[Authentication$.accessToken] = value;
    return this;
  }

  AuthenticationPatch withRefreshToken(String? value) {
    patchMap[Authentication$.refreshToken] = value;
    return this;
  }

  AuthenticationPatch withExpiresAt(DateTime? value) {
    patchMap[Authentication$.expiresAt] = value;
    return this;
  }

  AuthenticationPatch withCreatedAt(DateTime? value) {
    patchMap[Authentication$.createdAt] = value;
    return this;
  }
}

/// Field descriptors for [Authentication] query construction
abstract final class AuthenticationFields {
  static const id = Field<Authentication, String>('id', _$id);

  static const userId = Field<Authentication, String>('userId', _$userId);

  static const method = Field<Authentication, AuthenticationMethod>(
    'method',
    _$method,
  );

  static const accessToken = Field<Authentication, String?>(
    'accessToken',
    _$accessToken,
  );

  static const refreshToken = Field<Authentication, String?>(
    'refreshToken',
    _$refreshToken,
  );

  static const expiresAt = Field<Authentication, DateTime?>(
    'expiresAt',
    _$expiresAt,
  );

  static const createdAt = Field<Authentication, DateTime>(
    'createdAt',
    _$createdAt,
  );

  static String _$id(Authentication e) {
    return e.id;
  }

  static String _$userId(Authentication e) {
    return e.userId;
  }

  static AuthenticationMethod _$method(Authentication e) {
    return e.method;
  }

  static String? _$accessToken(Authentication e) {
    return e.accessToken;
  }

  static String? _$refreshToken(Authentication e) {
    return e.refreshToken;
  }

  static DateTime? _$expiresAt(Authentication e) {
    return e.expiresAt;
  }

  static DateTime _$createdAt(Authentication e) {
    return e.createdAt;
  }
}

extension AuthenticationCompareE on Authentication {
  Map<String, dynamic> compareToAuthentication(Authentication other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (userId != other.userId) {
      diff['userId'] = () => other.userId;
    }

    if (method != other.method) {
      diff['method'] = () => other.method;
    }

    if (accessToken != other.accessToken) {
      diff['accessToken'] = () => other.accessToken;
    }

    if (refreshToken != other.refreshToken) {
      diff['refreshToken'] = () => other.refreshToken;
    }

    if (expiresAt != other.expiresAt) {
      diff['expiresAt'] = () => other.expiresAt;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }
    return diff;
  }
}
