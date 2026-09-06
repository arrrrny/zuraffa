// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'customer.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class Customer {
  Customer({
    required String this.id,
    required String this.userId,
    String? this.firstName,
    String? this.lastName,
    String? this.email,
    CustomerProfile? this.profile,
    Device? this.device,
    List<CustomerAddress>? this.addresses,
    String? this.defaultAddressId,
    DateTime? this.createdAt,
    DateTime? this.updatedAt,
    Locale? this.locale,
    bool? this.isAnonymousAuth,
    double? this.latitude,
    double? this.longitude,
  });

  factory Customer.fromJson(Map<String, dynamic> json) =>
      _$CustomerFromJson(json);

  final String id;

  final String userId;

  final String? firstName;

  final String? lastName;

  final String? email;

  final CustomerProfile? profile;

  final Device? device;

  final List<CustomerAddress>? addresses;

  final String? defaultAddressId;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  final Locale? locale;

  final bool? isAnonymousAuth;

  final double? latitude;

  final double? longitude;

  Customer copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? email,
    CustomerProfile? profile,
    Device? device,
    List<CustomerAddress>? addresses,
    String? defaultAddressId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Locale? locale,
    bool? isAnonymousAuth,
    double? latitude,
    double? longitude,
  }) {
    return Customer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      profile: profile ?? this.profile,
      device: device ?? this.device,
      addresses: addresses ?? this.addresses,
      defaultAddressId: defaultAddressId ?? this.defaultAddressId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      locale: locale ?? this.locale,
      isAnonymousAuth: isAnonymousAuth ?? this.isAnonymousAuth,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  Customer copyWithField<T>(Field<Customer, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'userId':
        return copyWith(userId: value as String);
      case 'firstName':
        return copyWith(firstName: value as String?);
      case 'lastName':
        return copyWith(lastName: value as String?);
      case 'email':
        return copyWith(email: value as String?);
      case 'profile':
        return copyWith(profile: value as CustomerProfile?);
      case 'device':
        return copyWith(device: value as Device?);
      case 'addresses':
        return copyWith(addresses: value as List<CustomerAddress>?);
      case 'defaultAddressId':
        return copyWith(defaultAddressId: value as String?);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime?);
      case 'updatedAt':
        return copyWith(updatedAt: value as DateTime?);
      case 'locale':
        return copyWith(locale: value as Locale?);
      case 'isAnonymousAuth':
        return copyWith(isAnonymousAuth: value as bool?);
      case 'latitude':
        return copyWith(latitude: value as double?);
      case 'longitude':
        return copyWith(longitude: value as double?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'Customer has no settable field with this name',
        );
    }
  }

  Customer copyWithCustomer({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? email,
    CustomerProfile? profile,
    Device? device,
    List<CustomerAddress>? addresses,
    String? defaultAddressId,
    DateTime? createdAt,
    DateTime? updatedAt,
    Locale? locale,
    bool? isAnonymousAuth,
    double? latitude,
    double? longitude,
  }) {
    return copyWith(
      id: id,
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      profile: profile,
      device: device,
      addresses: addresses,
      defaultAddressId: defaultAddressId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      locale: locale,
      isAnonymousAuth: isAnonymousAuth,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Customer patchWithCustomer([CustomerPatch? patchInput]) {
    final _patcher = patchInput ?? CustomerPatch();
    final _patchMap = _patcher.patchMap;
    return Customer(
      id: _patchMap.containsKey(Customer$.id)
          ? ((_patchMap[Customer$.id] is Function)
                    ? _patchMap[Customer$.id](this.id)
                    : (_patchMap[Customer$.id] is Patch)
                    ? _patchMap[Customer$.id].applyTo(this.id)
                    : _patchMap[Customer$.id])
                as String
          : this.id,
      userId: _patchMap.containsKey(Customer$.userId)
          ? ((_patchMap[Customer$.userId] is Function)
                    ? _patchMap[Customer$.userId](this.userId)
                    : (_patchMap[Customer$.userId] is Patch)
                    ? _patchMap[Customer$.userId].applyTo(this.userId)
                    : _patchMap[Customer$.userId])
                as String
          : this.userId,
      firstName: _patchMap.containsKey(Customer$.firstName)
          ? ((_patchMap[Customer$.firstName] is Function)
                    ? _patchMap[Customer$.firstName](this.firstName)
                    : (_patchMap[Customer$.firstName] is Patch)
                    ? _patchMap[Customer$.firstName].applyTo(this.firstName)
                    : _patchMap[Customer$.firstName])
                as String?
          : this.firstName,
      lastName: _patchMap.containsKey(Customer$.lastName)
          ? ((_patchMap[Customer$.lastName] is Function)
                    ? _patchMap[Customer$.lastName](this.lastName)
                    : (_patchMap[Customer$.lastName] is Patch)
                    ? _patchMap[Customer$.lastName].applyTo(this.lastName)
                    : _patchMap[Customer$.lastName])
                as String?
          : this.lastName,
      email: _patchMap.containsKey(Customer$.email)
          ? ((_patchMap[Customer$.email] is Function)
                    ? _patchMap[Customer$.email](this.email)
                    : (_patchMap[Customer$.email] is Patch)
                    ? _patchMap[Customer$.email].applyTo(this.email)
                    : _patchMap[Customer$.email])
                as String?
          : this.email,
      profile: _patchMap.containsKey(Customer$.profile)
          ? ((_patchMap[Customer$.profile] is Function)
                    ? _patchMap[Customer$.profile](this.profile)
                    : (_patchMap[Customer$.profile] is Patch)
                    ? _patchMap[Customer$.profile].applyTo(this.profile)
                    : _patchMap[Customer$.profile])
                as CustomerProfile?
          : this.profile,
      device: _patchMap.containsKey(Customer$.device)
          ? ((_patchMap[Customer$.device] is Function)
                    ? _patchMap[Customer$.device](this.device)
                    : (_patchMap[Customer$.device] is Patch)
                    ? _patchMap[Customer$.device].applyTo(this.device)
                    : _patchMap[Customer$.device])
                as Device?
          : this.device,
      addresses: _patchMap.containsKey(Customer$.addresses)
          ? ((_patchMap[Customer$.addresses] is Function)
                    ? _patchMap[Customer$.addresses](this.addresses)
                    : (_patchMap[Customer$.addresses] is Patch)
                    ? _patchMap[Customer$.addresses].applyTo(this.addresses)
                    : _patchMap[Customer$.addresses])
                as List<CustomerAddress>?
          : this.addresses,
      defaultAddressId: _patchMap.containsKey(Customer$.defaultAddressId)
          ? ((_patchMap[Customer$.defaultAddressId] is Function)
                    ? _patchMap[Customer$.defaultAddressId](
                        this.defaultAddressId,
                      )
                    : (_patchMap[Customer$.defaultAddressId] is Patch)
                    ? _patchMap[Customer$.defaultAddressId].applyTo(
                        this.defaultAddressId,
                      )
                    : _patchMap[Customer$.defaultAddressId])
                as String?
          : this.defaultAddressId,
      createdAt: _patchMap.containsKey(Customer$.createdAt)
          ? ((_patchMap[Customer$.createdAt] is Function)
                    ? _patchMap[Customer$.createdAt](this.createdAt)
                    : (_patchMap[Customer$.createdAt] is Patch)
                    ? _patchMap[Customer$.createdAt].applyTo(this.createdAt)
                    : _patchMap[Customer$.createdAt])
                as DateTime?
          : this.createdAt,
      updatedAt: _patchMap.containsKey(Customer$.updatedAt)
          ? ((_patchMap[Customer$.updatedAt] is Function)
                    ? _patchMap[Customer$.updatedAt](this.updatedAt)
                    : (_patchMap[Customer$.updatedAt] is Patch)
                    ? _patchMap[Customer$.updatedAt].applyTo(this.updatedAt)
                    : _patchMap[Customer$.updatedAt])
                as DateTime?
          : this.updatedAt,
      locale: _patchMap.containsKey(Customer$.locale)
          ? ((_patchMap[Customer$.locale] is Function)
                    ? _patchMap[Customer$.locale](this.locale)
                    : (_patchMap[Customer$.locale] is Patch)
                    ? _patchMap[Customer$.locale].applyTo(this.locale)
                    : _patchMap[Customer$.locale])
                as Locale?
          : this.locale,
      isAnonymousAuth: _patchMap.containsKey(Customer$.isAnonymousAuth)
          ? ((_patchMap[Customer$.isAnonymousAuth] is Function)
                    ? _patchMap[Customer$.isAnonymousAuth](this.isAnonymousAuth)
                    : (_patchMap[Customer$.isAnonymousAuth] is Patch)
                    ? _patchMap[Customer$.isAnonymousAuth].applyTo(
                        this.isAnonymousAuth,
                      )
                    : _patchMap[Customer$.isAnonymousAuth])
                as bool?
          : this.isAnonymousAuth,
      latitude: _patchMap.containsKey(Customer$.latitude)
          ? ((_patchMap[Customer$.latitude] is Function)
                    ? _patchMap[Customer$.latitude](this.latitude)
                    : (_patchMap[Customer$.latitude] is Patch)
                    ? _patchMap[Customer$.latitude].applyTo(this.latitude)
                    : _patchMap[Customer$.latitude])
                as double?
          : this.latitude,
      longitude: _patchMap.containsKey(Customer$.longitude)
          ? ((_patchMap[Customer$.longitude] is Function)
                    ? _patchMap[Customer$.longitude](this.longitude)
                    : (_patchMap[Customer$.longitude] is Patch)
                    ? _patchMap[Customer$.longitude].applyTo(this.longitude)
                    : _patchMap[Customer$.longitude])
                as double?
          : this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Customer &&
        id == other.id &&
        userId == other.userId &&
        firstName == other.firstName &&
        lastName == other.lastName &&
        email == other.email &&
        profile == other.profile &&
        device == other.device &&
        addresses == other.addresses &&
        defaultAddressId == other.defaultAddressId &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        locale == other.locale &&
        isAnonymousAuth == other.isAnonymousAuth &&
        latitude == other.latitude &&
        longitude == other.longitude;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.userId,
      this.firstName,
      this.lastName,
      this.email,
      this.profile,
      this.device,
      this.addresses,
      this.defaultAddressId,
      this.createdAt,
      this.updatedAt,
      this.locale,
      this.isAnonymousAuth,
      this.latitude,
      this.longitude,
    );
  }

  @override
  String toString() {
    return 'Customer(' +
        'id: ${id}' +
        ', ' +
        'userId: ${userId}' +
        ', ' +
        'firstName: ${firstName}' +
        ', ' +
        'lastName: ${lastName}' +
        ', ' +
        'email: ${email}' +
        ', ' +
        'profile: ${profile}' +
        ', ' +
        'device: ${device}' +
        ', ' +
        'addresses: ${addresses}' +
        ', ' +
        'defaultAddressId: ${defaultAddressId}' +
        ', ' +
        'createdAt: ${createdAt}' +
        ', ' +
        'updatedAt: ${updatedAt}' +
        ', ' +
        'locale: ${locale}' +
        ', ' +
        'isAnonymousAuth: ${isAnonymousAuth}' +
        ', ' +
        'latitude: ${latitude}' +
        ', ' +
        'longitude: ${longitude})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$CustomerToJson(this);
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

extension CustomerPropertyHelpers on Customer {
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

  bool get hasEmail {
    return this.email?.isNotEmpty == true;
  }

  bool get noEmail {
    return this.email?.isEmpty ?? true;
  }

  String get emailRequired {
    return this.email ?? (throw StateError('email is required but was null'));
  }

  bool get hasProfile {
    return this.profile != null;
  }

  bool get noProfile {
    return this.profile == null;
  }

  CustomerProfile get profileRequired {
    return this.profile ??
        (throw StateError('profile is required but was null'));
  }

  bool get hasDevice {
    return this.device != null;
  }

  bool get noDevice {
    return this.device == null;
  }

  Device get deviceRequired {
    return this.device ?? (throw StateError('device is required but was null'));
  }

  List<CustomerAddress> get addressesRequired {
    return this.addresses ??
        (throw StateError('addresses is required but was null'));
  }

  bool get hasAddresses {
    return this.addresses?.isNotEmpty ?? false;
  }

  bool get noAddresses {
    return this.addresses?.isEmpty ?? true;
  }

  bool get hasDefaultAddressId {
    return this.defaultAddressId?.isNotEmpty == true;
  }

  bool get noDefaultAddressId {
    return this.defaultAddressId?.isEmpty ?? true;
  }

  String get defaultAddressIdRequired {
    return this.defaultAddressId ??
        (throw StateError('defaultAddressId is required but was null'));
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

  bool get hasUpdatedAt {
    return this.updatedAt != null;
  }

  bool get noUpdatedAt {
    return this.updatedAt == null;
  }

  DateTime get updatedAtRequired {
    return this.updatedAt ??
        (throw StateError('updatedAt is required but was null'));
  }

  bool get hasLocale {
    return this.locale != null;
  }

  bool get noLocale {
    return this.locale == null;
  }

  Locale get localeRequired {
    return this.locale ?? (throw StateError('locale is required but was null'));
  }

  bool get hasIsAnonymousAuth {
    return this.isAnonymousAuth != null;
  }

  bool get noIsAnonymousAuth {
    return this.isAnonymousAuth == null;
  }

  bool get isAnonymousAuthRequired {
    return this.isAnonymousAuth ??
        (throw StateError('isAnonymousAuth is required but was null'));
  }

  bool get hasLatitude {
    return this.latitude != null;
  }

  bool get noLatitude {
    return this.latitude == null;
  }

  double get latitudeRequired {
    return this.latitude ??
        (throw StateError('latitude is required but was null'));
  }

  bool get hasLongitude {
    return this.longitude != null;
  }

  bool get noLongitude {
    return this.longitude == null;
  }

  double get longitudeRequired {
    return this.longitude ??
        (throw StateError('longitude is required but was null'));
  }
}

extension CustomerSerialization on Customer {
  Map<String, dynamic> toJson() {
    return _$CustomerToJson(this);
  }
}

enum Customer$ {
  id,
  userId,
  firstName,
  lastName,
  email,
  profile,
  device,
  addresses,
  defaultAddressId,
  createdAt,
  updatedAt,
  locale,
  isAnonymousAuth,
  latitude,
  longitude,
}

class CustomerPatch extends PatchBase<Customer, Customer$> {
  Customer applyTo(Customer entity) {
    return entity.patchWithCustomer(this);
  }

  CustomerPatch withId(String? value) {
    patchMap[Customer$.id] = value;
    return this;
  }

  CustomerPatch withUserId(String? value) {
    patchMap[Customer$.userId] = value;
    return this;
  }

  CustomerPatch withFirstName(String? value) {
    patchMap[Customer$.firstName] = value;
    return this;
  }

  CustomerPatch withLastName(String? value) {
    patchMap[Customer$.lastName] = value;
    return this;
  }

  CustomerPatch withEmail(String? value) {
    patchMap[Customer$.email] = value;
    return this;
  }

  CustomerPatch withProfile(CustomerProfile? value) {
    patchMap[Customer$.profile] = value;
    return this;
  }

  CustomerPatch withProfilePatch(CustomerProfilePatch patch) {
    patchMap[Customer$.profile] = patch;
    return this;
  }

  CustomerPatch withProfilePatchFunc(
    CustomerProfilePatch Function(CustomerProfilePatch) patch,
  ) {
    patchMap[Customer$.profile] = (dynamic current) {
      var currentPatch = CustomerProfilePatch();
      return patch(currentPatch).applyTo(current as CustomerProfile);
    };
    return this;
  }

  CustomerPatch withDevice(Device? value) {
    patchMap[Customer$.device] = value;
    return this;
  }

  CustomerPatch withDevicePatch(DevicePatch patch) {
    patchMap[Customer$.device] = patch;
    return this;
  }

  CustomerPatch withDevicePatchFunc(DevicePatch Function(DevicePatch) patch) {
    patchMap[Customer$.device] = (dynamic current) {
      var currentPatch = DevicePatch();
      return patch(currentPatch).applyTo(current as Device);
    };
    return this;
  }

  CustomerPatch withAddresses(List<CustomerAddress>? value) {
    patchMap[Customer$.addresses] = value;
    return this;
  }

  CustomerPatch updateAddressesAt(
    int index,
    CustomerAddressPatch Function(CustomerAddressPatch) patch,
  ) {
    patchMap[Customer$.addresses] = (List<dynamic> list) {
      var updatedList = List<CustomerAddress>.from(list);
      if (index >= 0 && index < updatedList.length) {
        updatedList[index] = patch(
          CustomerAddressPatch(),
        ).applyTo(updatedList[index] as CustomerAddress);
      }
      return updatedList;
    };
    return this;
  }

  CustomerPatch withDefaultAddressId(String? value) {
    patchMap[Customer$.defaultAddressId] = value;
    return this;
  }

  CustomerPatch withCreatedAt(DateTime? value) {
    patchMap[Customer$.createdAt] = value;
    return this;
  }

  CustomerPatch withUpdatedAt(DateTime? value) {
    patchMap[Customer$.updatedAt] = value;
    return this;
  }

  CustomerPatch withLocale(Locale? value) {
    patchMap[Customer$.locale] = value;
    return this;
  }

  CustomerPatch withLocalePatch(LocalePatch patch) {
    patchMap[Customer$.locale] = patch;
    return this;
  }

  CustomerPatch withLocalePatchFunc(LocalePatch Function(LocalePatch) patch) {
    patchMap[Customer$.locale] = (dynamic current) {
      var currentPatch = LocalePatch();
      return patch(currentPatch).applyTo(current as Locale);
    };
    return this;
  }

  CustomerPatch withIsAnonymousAuth(bool? value) {
    patchMap[Customer$.isAnonymousAuth] = value;
    return this;
  }

  CustomerPatch withLatitude(double? value) {
    patchMap[Customer$.latitude] = value;
    return this;
  }

  CustomerPatch withLongitude(double? value) {
    patchMap[Customer$.longitude] = value;
    return this;
  }
}

/// Field descriptors for [Customer] query construction
abstract final class CustomerFields {
  static const id = Field<Customer, String>('id', _$id);

  static const userId = Field<Customer, String>('userId', _$userId);

  static const firstName = Field<Customer, String?>('firstName', _$firstName);

  static const lastName = Field<Customer, String?>('lastName', _$lastName);

  static const email = Field<Customer, String?>('email', _$email);

  static const profile = Field<Customer, CustomerProfile?>(
    'profile',
    _$profile,
  );

  static const device = Field<Customer, Device?>('device', _$device);

  static const addresses = Field<Customer, List<CustomerAddress>?>(
    'addresses',
    _$addresses,
  );

  static const defaultAddressId = Field<Customer, String?>(
    'defaultAddressId',
    _$defaultAddressId,
  );

  static const createdAt = Field<Customer, DateTime?>('createdAt', _$createdAt);

  static const updatedAt = Field<Customer, DateTime?>('updatedAt', _$updatedAt);

  static const locale = Field<Customer, Locale?>('locale', _$locale);

  static const isAnonymousAuth = Field<Customer, bool?>(
    'isAnonymousAuth',
    _$isAnonymousAuth,
  );

  static const latitude = Field<Customer, double?>('latitude', _$latitude);

  static const longitude = Field<Customer, double?>('longitude', _$longitude);

  static String _$id(Customer e) {
    return e.id;
  }

  static String _$userId(Customer e) {
    return e.userId;
  }

  static String? _$firstName(Customer e) {
    return e.firstName;
  }

  static String? _$lastName(Customer e) {
    return e.lastName;
  }

  static String? _$email(Customer e) {
    return e.email;
  }

  static CustomerProfile? _$profile(Customer e) {
    return e.profile;
  }

  static Device? _$device(Customer e) {
    return e.device;
  }

  static List<CustomerAddress>? _$addresses(Customer e) {
    return e.addresses;
  }

  static String? _$defaultAddressId(Customer e) {
    return e.defaultAddressId;
  }

  static DateTime? _$createdAt(Customer e) {
    return e.createdAt;
  }

  static DateTime? _$updatedAt(Customer e) {
    return e.updatedAt;
  }

  static Locale? _$locale(Customer e) {
    return e.locale;
  }

  static bool? _$isAnonymousAuth(Customer e) {
    return e.isAnonymousAuth;
  }

  static double? _$latitude(Customer e) {
    return e.latitude;
  }

  static double? _$longitude(Customer e) {
    return e.longitude;
  }
}

extension CustomerCompareE on Customer {
  Map<String, dynamic> compareToCustomer(Customer other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (userId != other.userId) {
      diff['userId'] = () => other.userId;
    }

    if (firstName != other.firstName) {
      diff['firstName'] = () => other.firstName;
    }

    if (lastName != other.lastName) {
      diff['lastName'] = () => other.lastName;
    }

    if (email != other.email) {
      diff['email'] = () => other.email;
    }

    if (profile != other.profile) {
      diff['profile'] = () => other.profile;
    }

    if (device != other.device) {
      diff['device'] = () => other.device;
    }

    if (addresses != other.addresses) {
      diff['addresses'] = () => other.addresses;
    }

    if (defaultAddressId != other.defaultAddressId) {
      diff['defaultAddressId'] = () => other.defaultAddressId;
    }

    if (createdAt != other.createdAt) {
      diff['createdAt'] = () => other.createdAt;
    }

    if (updatedAt != other.updatedAt) {
      diff['updatedAt'] = () => other.updatedAt;
    }

    if (locale != other.locale) {
      diff['locale'] = () => other.locale;
    }

    if (isAnonymousAuth != other.isAnonymousAuth) {
      diff['isAnonymousAuth'] = () => other.isAnonymousAuth;
    }

    if (latitude != other.latitude) {
      diff['latitude'] = () => other.latitude;
    }

    if (longitude != other.longitude) {
      diff['longitude'] = () => other.longitude;
    }
    return diff;
  }
}
