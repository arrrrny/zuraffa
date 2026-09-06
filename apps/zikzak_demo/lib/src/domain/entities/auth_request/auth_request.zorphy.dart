// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'auth_request.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class AuthRequest {
  AuthRequest({
    required String this.email,
    String? this.password,
    required AuthenticationMethod this.method,
  });

  factory AuthRequest.fromJson(Map<String, dynamic> json) =>
      _$AuthRequestFromJson(json);

  final String email;

  final String? password;

  final AuthenticationMethod method;

  AuthRequest copyWith({
    String? email,
    String? password,
    AuthenticationMethod? method,
  }) {
    return AuthRequest(
      email: email ?? this.email,
      password: password ?? this.password,
      method: method ?? this.method,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  AuthRequest copyWithField<T>(Field<AuthRequest, T> field, T value) {
    switch (field.name) {
      case 'email':
        return copyWith(email: value as String);
      case 'password':
        return copyWith(password: value as String?);
      case 'method':
        return copyWith(method: value as AuthenticationMethod);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'AuthRequest has no settable field with this name',
        );
    }
  }

  AuthRequest copyWithAuthRequest({
    String? email,
    String? password,
    AuthenticationMethod? method,
  }) {
    return copyWith(email: email, password: password, method: method);
  }

  AuthRequest patchWithAuthRequest([AuthRequestPatch? patchInput]) {
    final _patcher = patchInput ?? AuthRequestPatch();
    final _patchMap = _patcher.patchMap;
    return AuthRequest(
      email: _patchMap.containsKey(AuthRequest$.email)
          ? ((_patchMap[AuthRequest$.email] is Function)
                    ? _patchMap[AuthRequest$.email](this.email)
                    : (_patchMap[AuthRequest$.email] is Patch)
                    ? _patchMap[AuthRequest$.email].applyTo(this.email)
                    : _patchMap[AuthRequest$.email])
                as String
          : this.email,
      password: _patchMap.containsKey(AuthRequest$.password)
          ? ((_patchMap[AuthRequest$.password] is Function)
                    ? _patchMap[AuthRequest$.password](this.password)
                    : (_patchMap[AuthRequest$.password] is Patch)
                    ? _patchMap[AuthRequest$.password].applyTo(this.password)
                    : _patchMap[AuthRequest$.password])
                as String?
          : this.password,
      method: _patchMap.containsKey(AuthRequest$.method)
          ? ((_patchMap[AuthRequest$.method] is Function)
                    ? _patchMap[AuthRequest$.method](this.method)
                    : (_patchMap[AuthRequest$.method] is Patch)
                    ? _patchMap[AuthRequest$.method].applyTo(this.method)
                    : _patchMap[AuthRequest$.method])
                as AuthenticationMethod
          : this.method,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthRequest &&
        email == other.email &&
        password == other.password &&
        method == other.method;
  }

  @override
  int get hashCode {
    return Object.hash(this.email, this.password, this.method);
  }

  @override
  String toString() {
    return 'AuthRequest(' +
        'email: ${email}' +
        ', ' +
        'password: ${password}' +
        ', ' +
        'method: ${method})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$AuthRequestToJson(this);
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

extension AuthRequestPropertyHelpers on AuthRequest {
  bool get hasEmail {
    return this.email.isNotEmpty;
  }

  bool get noEmail {
    return this.email.isEmpty;
  }

  bool get hasPassword {
    return this.password?.isNotEmpty == true;
  }

  bool get noPassword {
    return this.password?.isEmpty ?? true;
  }

  String get passwordRequired {
    return this.password ??
        (throw StateError('password is required but was null'));
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
}

extension AuthRequestSerialization on AuthRequest {
  Map<String, dynamic> toJson() {
    return _$AuthRequestToJson(this);
  }
}

enum AuthRequest$ { email, password, method }

class AuthRequestPatch extends PatchBase<AuthRequest, AuthRequest$> {
  AuthRequest applyTo(AuthRequest entity) {
    return entity.patchWithAuthRequest(this);
  }

  AuthRequestPatch withEmail(String? value) {
    patchMap[AuthRequest$.email] = value;
    return this;
  }

  AuthRequestPatch withPassword(String? value) {
    patchMap[AuthRequest$.password] = value;
    return this;
  }

  AuthRequestPatch withMethod(AuthenticationMethod? value) {
    patchMap[AuthRequest$.method] = value;
    return this;
  }
}

/// Field descriptors for [AuthRequest] query construction
abstract final class AuthRequestFields {
  static const email = Field<AuthRequest, String>('email', _$email);

  static const password = Field<AuthRequest, String?>('password', _$password);

  static const method = Field<AuthRequest, AuthenticationMethod>(
    'method',
    _$method,
  );

  static String _$email(AuthRequest e) {
    return e.email;
  }

  static String? _$password(AuthRequest e) {
    return e.password;
  }

  static AuthenticationMethod _$method(AuthRequest e) {
    return e.method;
  }
}

extension AuthRequestCompareE on AuthRequest {
  Map<String, dynamic> compareToAuthRequest(AuthRequest other) {
    final Map<String, dynamic> diff = {};

    if (email != other.email) {
      diff['email'] = () => other.email;
    }

    if (password != other.password) {
      diff['password'] = () => other.password;
    }

    if (method != other.method) {
      diff['method'] = () => other.method;
    }
    return diff;
  }
}
