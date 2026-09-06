// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'user.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class User {
  User({
    required String this.id,
    String? this.email,
    String? this.displayName,
    String? this.photoUrl,
    String? this.firstName,
    String? this.lastName,
    String? this.phoneNumber,
    bool? this.isAnonymous,
    bool? this.isVerified,
    DateTime? this.verifiedAt,
    DateTime? this.lastLogin,
    DateTime? this.registeredAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final String id;

  final String? email;

  final String? displayName;

  final String? photoUrl;

  final String? firstName;

  final String? lastName;

  final String? phoneNumber;

  final bool? isAnonymous;

  final bool? isVerified;

  final DateTime? verifiedAt;

  final DateTime? lastLogin;

  final DateTime? registeredAt;

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    bool? isAnonymous,
    bool? isVerified,
    DateTime? verifiedAt,
    DateTime? lastLogin,
    DateTime? registeredAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  User copyWithField<T>(Field<User, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'email':
        return copyWith(email: value as String?);
      case 'displayName':
        return copyWith(displayName: value as String?);
      case 'photoUrl':
        return copyWith(photoUrl: value as String?);
      case 'firstName':
        return copyWith(firstName: value as String?);
      case 'lastName':
        return copyWith(lastName: value as String?);
      case 'phoneNumber':
        return copyWith(phoneNumber: value as String?);
      case 'isAnonymous':
        return copyWith(isAnonymous: value as bool?);
      case 'isVerified':
        return copyWith(isVerified: value as bool?);
      case 'verifiedAt':
        return copyWith(verifiedAt: value as DateTime?);
      case 'lastLogin':
        return copyWith(lastLogin: value as DateTime?);
      case 'registeredAt':
        return copyWith(registeredAt: value as DateTime?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'User has no settable field with this name',
        );
    }
  }

  User copyWithUser({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    bool? isAnonymous,
    bool? isVerified,
    DateTime? verifiedAt,
    DateTime? lastLogin,
    DateTime? registeredAt,
  }) {
    return copyWith(
      id: id,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      isAnonymous: isAnonymous,
      isVerified: isVerified,
      verifiedAt: verifiedAt,
      lastLogin: lastLogin,
      registeredAt: registeredAt,
    );
  }

  User patchWithUser([UserPatch? patchInput]) {
    final _patcher = patchInput ?? UserPatch();
    final _patchMap = _patcher.patchMap;
    return User(
      id: _patchMap.containsKey(User$.id)
          ? ((_patchMap[User$.id] is Function)
                    ? _patchMap[User$.id](this.id)
                    : (_patchMap[User$.id] is Patch)
                    ? _patchMap[User$.id].applyTo(this.id)
                    : _patchMap[User$.id])
                as String
          : this.id,
      email: _patchMap.containsKey(User$.email)
          ? ((_patchMap[User$.email] is Function)
                    ? _patchMap[User$.email](this.email)
                    : (_patchMap[User$.email] is Patch)
                    ? _patchMap[User$.email].applyTo(this.email)
                    : _patchMap[User$.email])
                as String?
          : this.email,
      displayName: _patchMap.containsKey(User$.displayName)
          ? ((_patchMap[User$.displayName] is Function)
                    ? _patchMap[User$.displayName](this.displayName)
                    : (_patchMap[User$.displayName] is Patch)
                    ? _patchMap[User$.displayName].applyTo(this.displayName)
                    : _patchMap[User$.displayName])
                as String?
          : this.displayName,
      photoUrl: _patchMap.containsKey(User$.photoUrl)
          ? ((_patchMap[User$.photoUrl] is Function)
                    ? _patchMap[User$.photoUrl](this.photoUrl)
                    : (_patchMap[User$.photoUrl] is Patch)
                    ? _patchMap[User$.photoUrl].applyTo(this.photoUrl)
                    : _patchMap[User$.photoUrl])
                as String?
          : this.photoUrl,
      firstName: _patchMap.containsKey(User$.firstName)
          ? ((_patchMap[User$.firstName] is Function)
                    ? _patchMap[User$.firstName](this.firstName)
                    : (_patchMap[User$.firstName] is Patch)
                    ? _patchMap[User$.firstName].applyTo(this.firstName)
                    : _patchMap[User$.firstName])
                as String?
          : this.firstName,
      lastName: _patchMap.containsKey(User$.lastName)
          ? ((_patchMap[User$.lastName] is Function)
                    ? _patchMap[User$.lastName](this.lastName)
                    : (_patchMap[User$.lastName] is Patch)
                    ? _patchMap[User$.lastName].applyTo(this.lastName)
                    : _patchMap[User$.lastName])
                as String?
          : this.lastName,
      phoneNumber: _patchMap.containsKey(User$.phoneNumber)
          ? ((_patchMap[User$.phoneNumber] is Function)
                    ? _patchMap[User$.phoneNumber](this.phoneNumber)
                    : (_patchMap[User$.phoneNumber] is Patch)
                    ? _patchMap[User$.phoneNumber].applyTo(this.phoneNumber)
                    : _patchMap[User$.phoneNumber])
                as String?
          : this.phoneNumber,
      isAnonymous: _patchMap.containsKey(User$.isAnonymous)
          ? ((_patchMap[User$.isAnonymous] is Function)
                    ? _patchMap[User$.isAnonymous](this.isAnonymous)
                    : (_patchMap[User$.isAnonymous] is Patch)
                    ? _patchMap[User$.isAnonymous].applyTo(this.isAnonymous)
                    : _patchMap[User$.isAnonymous])
                as bool?
          : this.isAnonymous,
      isVerified: _patchMap.containsKey(User$.isVerified)
          ? ((_patchMap[User$.isVerified] is Function)
                    ? _patchMap[User$.isVerified](this.isVerified)
                    : (_patchMap[User$.isVerified] is Patch)
                    ? _patchMap[User$.isVerified].applyTo(this.isVerified)
                    : _patchMap[User$.isVerified])
                as bool?
          : this.isVerified,
      verifiedAt: _patchMap.containsKey(User$.verifiedAt)
          ? ((_patchMap[User$.verifiedAt] is Function)
                    ? _patchMap[User$.verifiedAt](this.verifiedAt)
                    : (_patchMap[User$.verifiedAt] is Patch)
                    ? _patchMap[User$.verifiedAt].applyTo(this.verifiedAt)
                    : _patchMap[User$.verifiedAt])
                as DateTime?
          : this.verifiedAt,
      lastLogin: _patchMap.containsKey(User$.lastLogin)
          ? ((_patchMap[User$.lastLogin] is Function)
                    ? _patchMap[User$.lastLogin](this.lastLogin)
                    : (_patchMap[User$.lastLogin] is Patch)
                    ? _patchMap[User$.lastLogin].applyTo(this.lastLogin)
                    : _patchMap[User$.lastLogin])
                as DateTime?
          : this.lastLogin,
      registeredAt: _patchMap.containsKey(User$.registeredAt)
          ? ((_patchMap[User$.registeredAt] is Function)
                    ? _patchMap[User$.registeredAt](this.registeredAt)
                    : (_patchMap[User$.registeredAt] is Patch)
                    ? _patchMap[User$.registeredAt].applyTo(this.registeredAt)
                    : _patchMap[User$.registeredAt])
                as DateTime?
          : this.registeredAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        id == other.id &&
        email == other.email &&
        displayName == other.displayName &&
        photoUrl == other.photoUrl &&
        firstName == other.firstName &&
        lastName == other.lastName &&
        phoneNumber == other.phoneNumber &&
        isAnonymous == other.isAnonymous &&
        isVerified == other.isVerified &&
        verifiedAt == other.verifiedAt &&
        lastLogin == other.lastLogin &&
        registeredAt == other.registeredAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.email,
      this.displayName,
      this.photoUrl,
      this.firstName,
      this.lastName,
      this.phoneNumber,
      this.isAnonymous,
      this.isVerified,
      this.verifiedAt,
      this.lastLogin,
      this.registeredAt,
    );
  }

  @override
  String toString() {
    return 'User(' +
        'id: ${id}' +
        ', ' +
        'email: ${email}' +
        ', ' +
        'displayName: ${displayName}' +
        ', ' +
        'photoUrl: ${photoUrl}' +
        ', ' +
        'firstName: ${firstName}' +
        ', ' +
        'lastName: ${lastName}' +
        ', ' +
        'phoneNumber: ${phoneNumber}' +
        ', ' +
        'isAnonymous: ${isAnonymous}' +
        ', ' +
        'isVerified: ${isVerified}' +
        ', ' +
        'verifiedAt: ${verifiedAt}' +
        ', ' +
        'lastLogin: ${lastLogin}' +
        ', ' +
        'registeredAt: ${registeredAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$UserToJson(this);
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

extension UserPropertyHelpers on User {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasEmail {
    return this.email?.isNotEmpty == true;
  }

  bool get noEmail {
    return this.email?.isEmpty ?? true;
  }

  String get emailRequired {
    return this.email ?? (throw StateError('email is required but was null'));
  }

  bool get hasDisplayName {
    return this.displayName?.isNotEmpty == true;
  }

  bool get noDisplayName {
    return this.displayName?.isEmpty ?? true;
  }

  String get displayNameRequired {
    return this.displayName ??
        (throw StateError('displayName is required but was null'));
  }

  bool get hasPhotoUrl {
    return this.photoUrl?.isNotEmpty == true;
  }

  bool get noPhotoUrl {
    return this.photoUrl?.isEmpty ?? true;
  }

  String get photoUrlRequired {
    return this.photoUrl ??
        (throw StateError('photoUrl is required but was null'));
  }

  bool get hasFirstName {
    return this.firstName?.isNotEmpty == true;
  }

  bool get noFirstName {
    return this.firstName?.isEmpty ?? true;
  }

  String get firstNameRequired {
    return this.firstName ??
        (throw StateError('firstName is required but was null'));
  }

  bool get hasLastName {
    return this.lastName?.isNotEmpty == true;
  }

  bool get noLastName {
    return this.lastName?.isEmpty ?? true;
  }

  String get lastNameRequired {
    return this.lastName ??
        (throw StateError('lastName is required but was null'));
  }

  bool get hasPhoneNumber {
    return this.phoneNumber?.isNotEmpty == true;
  }

  bool get noPhoneNumber {
    return this.phoneNumber?.isEmpty ?? true;
  }

  String get phoneNumberRequired {
    return this.phoneNumber ??
        (throw StateError('phoneNumber is required but was null'));
  }

  bool get hasIsAnonymous {
    return this.isAnonymous != null;
  }

  bool get noIsAnonymous {
    return this.isAnonymous == null;
  }

  bool get isAnonymousRequired {
    return this.isAnonymous ??
        (throw StateError('isAnonymous is required but was null'));
  }

  bool get hasIsVerified {
    return this.isVerified != null;
  }

  bool get noIsVerified {
    return this.isVerified == null;
  }

  bool get isVerifiedRequired {
    return this.isVerified ??
        (throw StateError('isVerified is required but was null'));
  }

  bool get hasVerifiedAt {
    return this.verifiedAt != null;
  }

  bool get noVerifiedAt {
    return this.verifiedAt == null;
  }

  DateTime get verifiedAtRequired {
    return this.verifiedAt ??
        (throw StateError('verifiedAt is required but was null'));
  }

  bool get hasLastLogin {
    return this.lastLogin != null;
  }

  bool get noLastLogin {
    return this.lastLogin == null;
  }

  DateTime get lastLoginRequired {
    return this.lastLogin ??
        (throw StateError('lastLogin is required but was null'));
  }

  bool get hasRegisteredAt {
    return this.registeredAt != null;
  }

  bool get noRegisteredAt {
    return this.registeredAt == null;
  }

  DateTime get registeredAtRequired {
    return this.registeredAt ??
        (throw StateError('registeredAt is required but was null'));
  }
}

extension UserSerialization on User {
  Map<String, dynamic> toJson() {
    return _$UserToJson(this);
  }
}

enum User$ {
  id,
  email,
  displayName,
  photoUrl,
  firstName,
  lastName,
  phoneNumber,
  isAnonymous,
  isVerified,
  verifiedAt,
  lastLogin,
  registeredAt,
}

class UserPatch extends PatchBase<User, User$> {
  User applyTo(User entity) {
    return entity.patchWithUser(this);
  }

  UserPatch withId(String? value) {
    patchMap[User$.id] = value;
    return this;
  }

  UserPatch withEmail(String? value) {
    patchMap[User$.email] = value;
    return this;
  }

  UserPatch withDisplayName(String? value) {
    patchMap[User$.displayName] = value;
    return this;
  }

  UserPatch withPhotoUrl(String? value) {
    patchMap[User$.photoUrl] = value;
    return this;
  }

  UserPatch withFirstName(String? value) {
    patchMap[User$.firstName] = value;
    return this;
  }

  UserPatch withLastName(String? value) {
    patchMap[User$.lastName] = value;
    return this;
  }

  UserPatch withPhoneNumber(String? value) {
    patchMap[User$.phoneNumber] = value;
    return this;
  }

  UserPatch withIsAnonymous(bool? value) {
    patchMap[User$.isAnonymous] = value;
    return this;
  }

  UserPatch withIsVerified(bool? value) {
    patchMap[User$.isVerified] = value;
    return this;
  }

  UserPatch withVerifiedAt(DateTime? value) {
    patchMap[User$.verifiedAt] = value;
    return this;
  }

  UserPatch withLastLogin(DateTime? value) {
    patchMap[User$.lastLogin] = value;
    return this;
  }

  UserPatch withRegisteredAt(DateTime? value) {
    patchMap[User$.registeredAt] = value;
    return this;
  }
}

/// Field descriptors for [User] query construction
abstract final class UserFields {
  static const id = Field<User, String>('id', _$id);

  static const email = Field<User, String?>('email', _$email);

  static const displayName = Field<User, String?>('displayName', _$displayName);

  static const photoUrl = Field<User, String?>('photoUrl', _$photoUrl);

  static const firstName = Field<User, String?>('firstName', _$firstName);

  static const lastName = Field<User, String?>('lastName', _$lastName);

  static const phoneNumber = Field<User, String?>('phoneNumber', _$phoneNumber);

  static const isAnonymous = Field<User, bool?>('isAnonymous', _$isAnonymous);

  static const isVerified = Field<User, bool?>('isVerified', _$isVerified);

  static const verifiedAt = Field<User, DateTime?>('verifiedAt', _$verifiedAt);

  static const lastLogin = Field<User, DateTime?>('lastLogin', _$lastLogin);

  static const registeredAt = Field<User, DateTime?>(
    'registeredAt',
    _$registeredAt,
  );

  static String _$id(User e) {
    return e.id;
  }

  static String? _$email(User e) {
    return e.email;
  }

  static String? _$displayName(User e) {
    return e.displayName;
  }

  static String? _$photoUrl(User e) {
    return e.photoUrl;
  }

  static String? _$firstName(User e) {
    return e.firstName;
  }

  static String? _$lastName(User e) {
    return e.lastName;
  }

  static String? _$phoneNumber(User e) {
    return e.phoneNumber;
  }

  static bool? _$isAnonymous(User e) {
    return e.isAnonymous;
  }

  static bool? _$isVerified(User e) {
    return e.isVerified;
  }

  static DateTime? _$verifiedAt(User e) {
    return e.verifiedAt;
  }

  static DateTime? _$lastLogin(User e) {
    return e.lastLogin;
  }

  static DateTime? _$registeredAt(User e) {
    return e.registeredAt;
  }
}

extension UserCompareE on User {
  Map<String, dynamic> compareToUser(User other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (email != other.email) {
      diff['email'] = () => other.email;
    }

    if (displayName != other.displayName) {
      diff['displayName'] = () => other.displayName;
    }

    if (photoUrl != other.photoUrl) {
      diff['photoUrl'] = () => other.photoUrl;
    }

    if (firstName != other.firstName) {
      diff['firstName'] = () => other.firstName;
    }

    if (lastName != other.lastName) {
      diff['lastName'] = () => other.lastName;
    }

    if (phoneNumber != other.phoneNumber) {
      diff['phoneNumber'] = () => other.phoneNumber;
    }

    if (isAnonymous != other.isAnonymous) {
      diff['isAnonymous'] = () => other.isAnonymous;
    }

    if (isVerified != other.isVerified) {
      diff['isVerified'] = () => other.isVerified;
    }

    if (verifiedAt != other.verifiedAt) {
      diff['verifiedAt'] = () => other.verifiedAt;
    }

    if (lastLogin != other.lastLogin) {
      diff['lastLogin'] = () => other.lastLogin;
    }

    if (registeredAt != other.registeredAt) {
      diff['registeredAt'] = () => other.registeredAt;
    }
    return diff;
  }
}
