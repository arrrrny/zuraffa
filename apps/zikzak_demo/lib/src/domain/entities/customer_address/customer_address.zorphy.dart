// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'customer_address.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class CustomerAddress {
  CustomerAddress({
    required String this.id,
    required String this.customerId,
    String? this.firstName,
    String? this.lastName,
    String? this.company,
    required String this.addressLine1,
    String? this.addressLine2,
    String? this.apartmentSuite,
    required String this.city,
    required String this.state,
    required String this.postalCode,
    required String this.country,
    required bool this.isDefault,
    DateTime? this.createdAt,
    DateTime? this.updatedAt,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) =>
      _$CustomerAddressFromJson(json);

  final String id;

  final String customerId;

  final String? firstName;

  final String? lastName;

  final String? company;

  final String addressLine1;

  final String? addressLine2;

  final String? apartmentSuite;

  final String city;

  final String state;

  final String postalCode;

  final String country;

  final bool isDefault;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  CustomerAddress copyWith({
    String? id,
    String? customerId,
    String? firstName,
    String? lastName,
    String? company,
    String? addressLine1,
    String? addressLine2,
    String? apartmentSuite,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      company: company ?? this.company,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      apartmentSuite: apartmentSuite ?? this.apartmentSuite,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  CustomerAddress copyWithField<T>(Field<CustomerAddress, T> field, T value) {
    switch (field.name) {
      case 'id':
        return copyWith(id: value as String);
      case 'customerId':
        return copyWith(customerId: value as String);
      case 'firstName':
        return copyWith(firstName: value as String?);
      case 'lastName':
        return copyWith(lastName: value as String?);
      case 'company':
        return copyWith(company: value as String?);
      case 'addressLine1':
        return copyWith(addressLine1: value as String);
      case 'addressLine2':
        return copyWith(addressLine2: value as String?);
      case 'apartmentSuite':
        return copyWith(apartmentSuite: value as String?);
      case 'city':
        return copyWith(city: value as String);
      case 'state':
        return copyWith(state: value as String);
      case 'postalCode':
        return copyWith(postalCode: value as String);
      case 'country':
        return copyWith(country: value as String);
      case 'isDefault':
        return copyWith(isDefault: value as bool);
      case 'createdAt':
        return copyWith(createdAt: value as DateTime?);
      case 'updatedAt':
        return copyWith(updatedAt: value as DateTime?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'CustomerAddress has no settable field with this name',
        );
    }
  }

  CustomerAddress copyWithCustomerAddress({
    String? id,
    String? customerId,
    String? firstName,
    String? lastName,
    String? company,
    String? addressLine1,
    String? addressLine2,
    String? apartmentSuite,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return copyWith(
      id: id,
      customerId: customerId,
      firstName: firstName,
      lastName: lastName,
      company: company,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      apartmentSuite: apartmentSuite,
      city: city,
      state: state,
      postalCode: postalCode,
      country: country,
      isDefault: isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  CustomerAddress patchWithCustomerAddress([CustomerAddressPatch? patchInput]) {
    final _patcher = patchInput ?? CustomerAddressPatch();
    final _patchMap = _patcher.patchMap;
    return CustomerAddress(
      id: _patchMap.containsKey(CustomerAddress$.id)
          ? ((_patchMap[CustomerAddress$.id] is Function)
                    ? _patchMap[CustomerAddress$.id](this.id)
                    : (_patchMap[CustomerAddress$.id] is Patch)
                    ? _patchMap[CustomerAddress$.id].applyTo(this.id)
                    : _patchMap[CustomerAddress$.id])
                as String
          : this.id,
      customerId: _patchMap.containsKey(CustomerAddress$.customerId)
          ? ((_patchMap[CustomerAddress$.customerId] is Function)
                    ? _patchMap[CustomerAddress$.customerId](this.customerId)
                    : (_patchMap[CustomerAddress$.customerId] is Patch)
                    ? _patchMap[CustomerAddress$.customerId].applyTo(
                        this.customerId,
                      )
                    : _patchMap[CustomerAddress$.customerId])
                as String
          : this.customerId,
      firstName: _patchMap.containsKey(CustomerAddress$.firstName)
          ? ((_patchMap[CustomerAddress$.firstName] is Function)
                    ? _patchMap[CustomerAddress$.firstName](this.firstName)
                    : (_patchMap[CustomerAddress$.firstName] is Patch)
                    ? _patchMap[CustomerAddress$.firstName].applyTo(
                        this.firstName,
                      )
                    : _patchMap[CustomerAddress$.firstName])
                as String?
          : this.firstName,
      lastName: _patchMap.containsKey(CustomerAddress$.lastName)
          ? ((_patchMap[CustomerAddress$.lastName] is Function)
                    ? _patchMap[CustomerAddress$.lastName](this.lastName)
                    : (_patchMap[CustomerAddress$.lastName] is Patch)
                    ? _patchMap[CustomerAddress$.lastName].applyTo(
                        this.lastName,
                      )
                    : _patchMap[CustomerAddress$.lastName])
                as String?
          : this.lastName,
      company: _patchMap.containsKey(CustomerAddress$.company)
          ? ((_patchMap[CustomerAddress$.company] is Function)
                    ? _patchMap[CustomerAddress$.company](this.company)
                    : (_patchMap[CustomerAddress$.company] is Patch)
                    ? _patchMap[CustomerAddress$.company].applyTo(this.company)
                    : _patchMap[CustomerAddress$.company])
                as String?
          : this.company,
      addressLine1: _patchMap.containsKey(CustomerAddress$.addressLine1)
          ? ((_patchMap[CustomerAddress$.addressLine1] is Function)
                    ? _patchMap[CustomerAddress$.addressLine1](
                        this.addressLine1,
                      )
                    : (_patchMap[CustomerAddress$.addressLine1] is Patch)
                    ? _patchMap[CustomerAddress$.addressLine1].applyTo(
                        this.addressLine1,
                      )
                    : _patchMap[CustomerAddress$.addressLine1])
                as String
          : this.addressLine1,
      addressLine2: _patchMap.containsKey(CustomerAddress$.addressLine2)
          ? ((_patchMap[CustomerAddress$.addressLine2] is Function)
                    ? _patchMap[CustomerAddress$.addressLine2](
                        this.addressLine2,
                      )
                    : (_patchMap[CustomerAddress$.addressLine2] is Patch)
                    ? _patchMap[CustomerAddress$.addressLine2].applyTo(
                        this.addressLine2,
                      )
                    : _patchMap[CustomerAddress$.addressLine2])
                as String?
          : this.addressLine2,
      apartmentSuite: _patchMap.containsKey(CustomerAddress$.apartmentSuite)
          ? ((_patchMap[CustomerAddress$.apartmentSuite] is Function)
                    ? _patchMap[CustomerAddress$.apartmentSuite](
                        this.apartmentSuite,
                      )
                    : (_patchMap[CustomerAddress$.apartmentSuite] is Patch)
                    ? _patchMap[CustomerAddress$.apartmentSuite].applyTo(
                        this.apartmentSuite,
                      )
                    : _patchMap[CustomerAddress$.apartmentSuite])
                as String?
          : this.apartmentSuite,
      city: _patchMap.containsKey(CustomerAddress$.city)
          ? ((_patchMap[CustomerAddress$.city] is Function)
                    ? _patchMap[CustomerAddress$.city](this.city)
                    : (_patchMap[CustomerAddress$.city] is Patch)
                    ? _patchMap[CustomerAddress$.city].applyTo(this.city)
                    : _patchMap[CustomerAddress$.city])
                as String
          : this.city,
      state: _patchMap.containsKey(CustomerAddress$.state)
          ? ((_patchMap[CustomerAddress$.state] is Function)
                    ? _patchMap[CustomerAddress$.state](this.state)
                    : (_patchMap[CustomerAddress$.state] is Patch)
                    ? _patchMap[CustomerAddress$.state].applyTo(this.state)
                    : _patchMap[CustomerAddress$.state])
                as String
          : this.state,
      postalCode: _patchMap.containsKey(CustomerAddress$.postalCode)
          ? ((_patchMap[CustomerAddress$.postalCode] is Function)
                    ? _patchMap[CustomerAddress$.postalCode](this.postalCode)
                    : (_patchMap[CustomerAddress$.postalCode] is Patch)
                    ? _patchMap[CustomerAddress$.postalCode].applyTo(
                        this.postalCode,
                      )
                    : _patchMap[CustomerAddress$.postalCode])
                as String
          : this.postalCode,
      country: _patchMap.containsKey(CustomerAddress$.country)
          ? ((_patchMap[CustomerAddress$.country] is Function)
                    ? _patchMap[CustomerAddress$.country](this.country)
                    : (_patchMap[CustomerAddress$.country] is Patch)
                    ? _patchMap[CustomerAddress$.country].applyTo(this.country)
                    : _patchMap[CustomerAddress$.country])
                as String
          : this.country,
      isDefault: _patchMap.containsKey(CustomerAddress$.isDefault)
          ? ((_patchMap[CustomerAddress$.isDefault] is Function)
                    ? _patchMap[CustomerAddress$.isDefault](this.isDefault)
                    : (_patchMap[CustomerAddress$.isDefault] is Patch)
                    ? _patchMap[CustomerAddress$.isDefault].applyTo(
                        this.isDefault,
                      )
                    : _patchMap[CustomerAddress$.isDefault])
                as bool
          : this.isDefault,
      createdAt: _patchMap.containsKey(CustomerAddress$.createdAt)
          ? ((_patchMap[CustomerAddress$.createdAt] is Function)
                    ? _patchMap[CustomerAddress$.createdAt](this.createdAt)
                    : (_patchMap[CustomerAddress$.createdAt] is Patch)
                    ? _patchMap[CustomerAddress$.createdAt].applyTo(
                        this.createdAt,
                      )
                    : _patchMap[CustomerAddress$.createdAt])
                as DateTime?
          : this.createdAt,
      updatedAt: _patchMap.containsKey(CustomerAddress$.updatedAt)
          ? ((_patchMap[CustomerAddress$.updatedAt] is Function)
                    ? _patchMap[CustomerAddress$.updatedAt](this.updatedAt)
                    : (_patchMap[CustomerAddress$.updatedAt] is Patch)
                    ? _patchMap[CustomerAddress$.updatedAt].applyTo(
                        this.updatedAt,
                      )
                    : _patchMap[CustomerAddress$.updatedAt])
                as DateTime?
          : this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerAddress &&
        id == other.id &&
        customerId == other.customerId &&
        firstName == other.firstName &&
        lastName == other.lastName &&
        company == other.company &&
        addressLine1 == other.addressLine1 &&
        addressLine2 == other.addressLine2 &&
        apartmentSuite == other.apartmentSuite &&
        city == other.city &&
        state == other.state &&
        postalCode == other.postalCode &&
        country == other.country &&
        isDefault == other.isDefault &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.id,
      this.customerId,
      this.firstName,
      this.lastName,
      this.company,
      this.addressLine1,
      this.addressLine2,
      this.apartmentSuite,
      this.city,
      this.state,
      this.postalCode,
      this.country,
      this.isDefault,
      this.createdAt,
      this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'CustomerAddress(' +
        'id: ${id}' +
        ', ' +
        'customerId: ${customerId}' +
        ', ' +
        'firstName: ${firstName}' +
        ', ' +
        'lastName: ${lastName}' +
        ', ' +
        'company: ${company}' +
        ', ' +
        'addressLine1: ${addressLine1}' +
        ', ' +
        'addressLine2: ${addressLine2}' +
        ', ' +
        'apartmentSuite: ${apartmentSuite}' +
        ', ' +
        'city: ${city}' +
        ', ' +
        'state: ${state}' +
        ', ' +
        'postalCode: ${postalCode}' +
        ', ' +
        'country: ${country}' +
        ', ' +
        'isDefault: ${isDefault}' +
        ', ' +
        'createdAt: ${createdAt}' +
        ', ' +
        'updatedAt: ${updatedAt})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$CustomerAddressToJson(this);
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

extension CustomerAddressPropertyHelpers on CustomerAddress {
  bool get hasId {
    return this.id.isNotEmpty;
  }

  bool get noId {
    return this.id.isEmpty;
  }

  bool get hasCustomerId {
    return this.customerId.isNotEmpty;
  }

  bool get noCustomerId {
    return this.customerId.isEmpty;
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

  bool get hasCompany {
    return this.company?.isNotEmpty == true;
  }

  bool get noCompany {
    return this.company?.isEmpty ?? true;
  }

  String get companyRequired {
    return this.company ??
        (throw StateError('company is required but was null'));
  }

  bool get hasAddressLine1 {
    return this.addressLine1.isNotEmpty;
  }

  bool get noAddressLine1 {
    return this.addressLine1.isEmpty;
  }

  bool get hasAddressLine2 {
    return this.addressLine2?.isNotEmpty == true;
  }

  bool get noAddressLine2 {
    return this.addressLine2?.isEmpty ?? true;
  }

  String get addressLine2Required {
    return this.addressLine2 ??
        (throw StateError('addressLine2 is required but was null'));
  }

  bool get hasApartmentSuite {
    return this.apartmentSuite?.isNotEmpty == true;
  }

  bool get noApartmentSuite {
    return this.apartmentSuite?.isEmpty ?? true;
  }

  String get apartmentSuiteRequired {
    return this.apartmentSuite ??
        (throw StateError('apartmentSuite is required but was null'));
  }

  bool get hasCity {
    return this.city.isNotEmpty;
  }

  bool get noCity {
    return this.city.isEmpty;
  }

  bool get hasState {
    return this.state.isNotEmpty;
  }

  bool get noState {
    return this.state.isEmpty;
  }

  bool get hasPostalCode {
    return this.postalCode.isNotEmpty;
  }

  bool get noPostalCode {
    return this.postalCode.isEmpty;
  }

  bool get hasCountry {
    return this.country.isNotEmpty;
  }

  bool get noCountry {
    return this.country.isEmpty;
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
}

extension CustomerAddressSerialization on CustomerAddress {
  Map<String, dynamic> toJson() {
    return _$CustomerAddressToJson(this);
  }
}

enum CustomerAddress$ {
  id,
  customerId,
  firstName,
  lastName,
  company,
  addressLine1,
  addressLine2,
  apartmentSuite,
  city,
  state,
  postalCode,
  country,
  isDefault,
  createdAt,
  updatedAt,
}

class CustomerAddressPatch
    extends PatchBase<CustomerAddress, CustomerAddress$> {
  CustomerAddress applyTo(CustomerAddress entity) {
    return entity.patchWithCustomerAddress(this);
  }

  CustomerAddressPatch withId(String? value) {
    patchMap[CustomerAddress$.id] = value;
    return this;
  }

  CustomerAddressPatch withCustomerId(String? value) {
    patchMap[CustomerAddress$.customerId] = value;
    return this;
  }

  CustomerAddressPatch withFirstName(String? value) {
    patchMap[CustomerAddress$.firstName] = value;
    return this;
  }

  CustomerAddressPatch withLastName(String? value) {
    patchMap[CustomerAddress$.lastName] = value;
    return this;
  }

  CustomerAddressPatch withCompany(String? value) {
    patchMap[CustomerAddress$.company] = value;
    return this;
  }

  CustomerAddressPatch withAddressLine1(String? value) {
    patchMap[CustomerAddress$.addressLine1] = value;
    return this;
  }

  CustomerAddressPatch withAddressLine2(String? value) {
    patchMap[CustomerAddress$.addressLine2] = value;
    return this;
  }

  CustomerAddressPatch withApartmentSuite(String? value) {
    patchMap[CustomerAddress$.apartmentSuite] = value;
    return this;
  }

  CustomerAddressPatch withCity(String? value) {
    patchMap[CustomerAddress$.city] = value;
    return this;
  }

  CustomerAddressPatch withState(String? value) {
    patchMap[CustomerAddress$.state] = value;
    return this;
  }

  CustomerAddressPatch withPostalCode(String? value) {
    patchMap[CustomerAddress$.postalCode] = value;
    return this;
  }

  CustomerAddressPatch withCountry(String? value) {
    patchMap[CustomerAddress$.country] = value;
    return this;
  }

  CustomerAddressPatch withIsDefault(bool? value) {
    patchMap[CustomerAddress$.isDefault] = value;
    return this;
  }

  CustomerAddressPatch withCreatedAt(DateTime? value) {
    patchMap[CustomerAddress$.createdAt] = value;
    return this;
  }

  CustomerAddressPatch withUpdatedAt(DateTime? value) {
    patchMap[CustomerAddress$.updatedAt] = value;
    return this;
  }
}

/// Field descriptors for [CustomerAddress] query construction
abstract final class CustomerAddressFields {
  static const id = Field<CustomerAddress, String>('id', _$id);

  static const customerId = Field<CustomerAddress, String>(
    'customerId',
    _$customerId,
  );

  static const firstName = Field<CustomerAddress, String?>(
    'firstName',
    _$firstName,
  );

  static const lastName = Field<CustomerAddress, String?>(
    'lastName',
    _$lastName,
  );

  static const company = Field<CustomerAddress, String?>('company', _$company);

  static const addressLine1 = Field<CustomerAddress, String>(
    'addressLine1',
    _$addressLine1,
  );

  static const addressLine2 = Field<CustomerAddress, String?>(
    'addressLine2',
    _$addressLine2,
  );

  static const apartmentSuite = Field<CustomerAddress, String?>(
    'apartmentSuite',
    _$apartmentSuite,
  );

  static const city = Field<CustomerAddress, String>('city', _$city);

  static const state = Field<CustomerAddress, String>('state', _$state);

  static const postalCode = Field<CustomerAddress, String>(
    'postalCode',
    _$postalCode,
  );

  static const country = Field<CustomerAddress, String>('country', _$country);

  static const isDefault = Field<CustomerAddress, bool>(
    'isDefault',
    _$isDefault,
  );

  static const createdAt = Field<CustomerAddress, DateTime?>(
    'createdAt',
    _$createdAt,
  );

  static const updatedAt = Field<CustomerAddress, DateTime?>(
    'updatedAt',
    _$updatedAt,
  );

  static String _$id(CustomerAddress e) {
    return e.id;
  }

  static String _$customerId(CustomerAddress e) {
    return e.customerId;
  }

  static String? _$firstName(CustomerAddress e) {
    return e.firstName;
  }

  static String? _$lastName(CustomerAddress e) {
    return e.lastName;
  }

  static String? _$company(CustomerAddress e) {
    return e.company;
  }

  static String _$addressLine1(CustomerAddress e) {
    return e.addressLine1;
  }

  static String? _$addressLine2(CustomerAddress e) {
    return e.addressLine2;
  }

  static String? _$apartmentSuite(CustomerAddress e) {
    return e.apartmentSuite;
  }

  static String _$city(CustomerAddress e) {
    return e.city;
  }

  static String _$state(CustomerAddress e) {
    return e.state;
  }

  static String _$postalCode(CustomerAddress e) {
    return e.postalCode;
  }

  static String _$country(CustomerAddress e) {
    return e.country;
  }

  static bool _$isDefault(CustomerAddress e) {
    return e.isDefault;
  }

  static DateTime? _$createdAt(CustomerAddress e) {
    return e.createdAt;
  }

  static DateTime? _$updatedAt(CustomerAddress e) {
    return e.updatedAt;
  }
}

extension CustomerAddressCompareE on CustomerAddress {
  Map<String, dynamic> compareToCustomerAddress(CustomerAddress other) {
    final Map<String, dynamic> diff = {};

    if (id != other.id) {
      diff['id'] = () => other.id;
    }

    if (customerId != other.customerId) {
      diff['customerId'] = () => other.customerId;
    }

    if (firstName != other.firstName) {
      diff['firstName'] = () => other.firstName;
    }

    if (lastName != other.lastName) {
      diff['lastName'] = () => other.lastName;
    }

    if (company != other.company) {
      diff['company'] = () => other.company;
    }

    if (addressLine1 != other.addressLine1) {
      diff['addressLine1'] = () => other.addressLine1;
    }

    if (addressLine2 != other.addressLine2) {
      diff['addressLine2'] = () => other.addressLine2;
    }

    if (apartmentSuite != other.apartmentSuite) {
      diff['apartmentSuite'] = () => other.apartmentSuite;
    }

    if (city != other.city) {
      diff['city'] = () => other.city;
    }

    if (state != other.state) {
      diff['state'] = () => other.state;
    }

    if (postalCode != other.postalCode) {
      diff['postalCode'] = () => other.postalCode;
    }

    if (country != other.country) {
      diff['country'] = () => other.country;
    }

    if (isDefault != other.isDefault) {
      diff['isDefault'] = () => other.isDefault;
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
