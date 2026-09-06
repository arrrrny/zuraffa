// dart format width=80
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint

part of 'customer_profile.dart';

// **************************************************************************
// ZorphyGenerator
// **************************************************************************

@JsonSerializable(explicitToJson: true, checked: true)
class CustomerProfile {
  CustomerProfile({
    int? this.yearOfBirth,
    Gender? this.gender,
    String? this.shoppingStyle,
    String? this.shoeSize,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      _$CustomerProfileFromJson(json);

  final int? yearOfBirth;

  final Gender? gender;

  final String? shoppingStyle;

  final String? shoeSize;

  CustomerProfile copyWith({
    int? yearOfBirth,
    Gender? gender,
    String? shoppingStyle,
    String? shoeSize,
  }) {
    return CustomerProfile(
      yearOfBirth: yearOfBirth ?? this.yearOfBirth,
      gender: gender ?? this.gender,
      shoppingStyle: shoppingStyle ?? this.shoppingStyle,
      shoeSize: shoeSize ?? this.shoeSize,
    );
  }

  /// Returns a copy of this entity with [field] set to [value].
  ///
  /// Delegates to [copyWith]: the receiver is never mutated and a
  /// null [value] keeps the current field value.
  CustomerProfile copyWithField<T>(Field<CustomerProfile, T> field, T value) {
    switch (field.name) {
      case 'yearOfBirth':
        return copyWith(yearOfBirth: value as int?);
      case 'gender':
        return copyWith(gender: value as Gender?);
      case 'shoppingStyle':
        return copyWith(shoppingStyle: value as String?);
      case 'shoeSize':
        return copyWith(shoeSize: value as String?);
      default:
        throw ArgumentError.value(
          field.name,
          'field',
          'CustomerProfile has no settable field with this name',
        );
    }
  }

  CustomerProfile copyWithCustomerProfile({
    int? yearOfBirth,
    Gender? gender,
    String? shoppingStyle,
    String? shoeSize,
  }) {
    return copyWith(
      yearOfBirth: yearOfBirth,
      gender: gender,
      shoppingStyle: shoppingStyle,
      shoeSize: shoeSize,
    );
  }

  CustomerProfile patchWithCustomerProfile([CustomerProfilePatch? patchInput]) {
    final _patcher = patchInput ?? CustomerProfilePatch();
    final _patchMap = _patcher.patchMap;
    return CustomerProfile(
      yearOfBirth: _patchMap.containsKey(CustomerProfile$.yearOfBirth)
          ? ((_patchMap[CustomerProfile$.yearOfBirth] is Function)
                    ? _patchMap[CustomerProfile$.yearOfBirth](this.yearOfBirth)
                    : (_patchMap[CustomerProfile$.yearOfBirth] is Patch)
                    ? _patchMap[CustomerProfile$.yearOfBirth].applyTo(
                        this.yearOfBirth,
                      )
                    : _patchMap[CustomerProfile$.yearOfBirth])
                as int?
          : this.yearOfBirth,
      gender: _patchMap.containsKey(CustomerProfile$.gender)
          ? ((_patchMap[CustomerProfile$.gender] is Function)
                    ? _patchMap[CustomerProfile$.gender](this.gender)
                    : (_patchMap[CustomerProfile$.gender] is Patch)
                    ? _patchMap[CustomerProfile$.gender].applyTo(this.gender)
                    : _patchMap[CustomerProfile$.gender])
                as Gender?
          : this.gender,
      shoppingStyle: _patchMap.containsKey(CustomerProfile$.shoppingStyle)
          ? ((_patchMap[CustomerProfile$.shoppingStyle] is Function)
                    ? _patchMap[CustomerProfile$.shoppingStyle](
                        this.shoppingStyle,
                      )
                    : (_patchMap[CustomerProfile$.shoppingStyle] is Patch)
                    ? _patchMap[CustomerProfile$.shoppingStyle].applyTo(
                        this.shoppingStyle,
                      )
                    : _patchMap[CustomerProfile$.shoppingStyle])
                as String?
          : this.shoppingStyle,
      shoeSize: _patchMap.containsKey(CustomerProfile$.shoeSize)
          ? ((_patchMap[CustomerProfile$.shoeSize] is Function)
                    ? _patchMap[CustomerProfile$.shoeSize](this.shoeSize)
                    : (_patchMap[CustomerProfile$.shoeSize] is Patch)
                    ? _patchMap[CustomerProfile$.shoeSize].applyTo(
                        this.shoeSize,
                      )
                    : _patchMap[CustomerProfile$.shoeSize])
                as String?
          : this.shoeSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerProfile &&
        yearOfBirth == other.yearOfBirth &&
        gender == other.gender &&
        shoppingStyle == other.shoppingStyle &&
        shoeSize == other.shoeSize;
  }

  @override
  int get hashCode {
    return Object.hash(
      this.yearOfBirth,
      this.gender,
      this.shoppingStyle,
      this.shoeSize,
    );
  }

  @override
  String toString() {
    return 'CustomerProfile(' +
        'yearOfBirth: ${yearOfBirth}' +
        ', ' +
        'gender: ${gender}' +
        ', ' +
        'shoppingStyle: ${shoppingStyle}' +
        ', ' +
        'shoeSize: ${shoeSize})';
  }

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _$CustomerProfileToJson(this);
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

extension CustomerProfilePropertyHelpers on CustomerProfile {
  bool get hasYearOfBirth {
    return this.yearOfBirth != null;
  }

  bool get noYearOfBirth {
    return this.yearOfBirth == null;
  }

  int get yearOfBirthRequired {
    return this.yearOfBirth ??
        (throw StateError('yearOfBirth is required but was null'));
  }

  bool get hasGender {
    return this.gender != null;
  }

  bool get noGender {
    return this.gender == null;
  }

  Gender get genderRequired {
    return this.gender ?? (throw StateError('gender is required but was null'));
  }

  bool get isGenderMan {
    return this.gender == Gender.man;
  }

  bool get isGenderWoman {
    return this.gender == Gender.woman;
  }

  bool get hasShoppingStyle {
    return this.shoppingStyle?.isNotEmpty == true;
  }

  bool get noShoppingStyle {
    return this.shoppingStyle?.isEmpty ?? true;
  }

  String get shoppingStyleRequired {
    return this.shoppingStyle ??
        (throw StateError('shoppingStyle is required but was null'));
  }

  bool get hasShoeSize {
    return this.shoeSize?.isNotEmpty == true;
  }

  bool get noShoeSize {
    return this.shoeSize?.isEmpty ?? true;
  }

  String get shoeSizeRequired {
    return this.shoeSize ??
        (throw StateError('shoeSize is required but was null'));
  }
}

extension CustomerProfileSerialization on CustomerProfile {
  Map<String, dynamic> toJson() {
    return _$CustomerProfileToJson(this);
  }
}

enum CustomerProfile$ { yearOfBirth, gender, shoppingStyle, shoeSize }

class CustomerProfilePatch
    extends PatchBase<CustomerProfile, CustomerProfile$> {
  CustomerProfile applyTo(CustomerProfile entity) {
    return entity.patchWithCustomerProfile(this);
  }

  CustomerProfilePatch withYearOfBirth(int? value) {
    patchMap[CustomerProfile$.yearOfBirth] = value;
    return this;
  }

  CustomerProfilePatch withGender(Gender? value) {
    patchMap[CustomerProfile$.gender] = value;
    return this;
  }

  CustomerProfilePatch withShoppingStyle(String? value) {
    patchMap[CustomerProfile$.shoppingStyle] = value;
    return this;
  }

  CustomerProfilePatch withShoeSize(String? value) {
    patchMap[CustomerProfile$.shoeSize] = value;
    return this;
  }
}

/// Field descriptors for [CustomerProfile] query construction
abstract final class CustomerProfileFields {
  static const yearOfBirth = Field<CustomerProfile, int?>(
    'yearOfBirth',
    _$yearOfBirth,
  );

  static const gender = Field<CustomerProfile, Gender?>('gender', _$gender);

  static const shoppingStyle = Field<CustomerProfile, String?>(
    'shoppingStyle',
    _$shoppingStyle,
  );

  static const shoeSize = Field<CustomerProfile, String?>(
    'shoeSize',
    _$shoeSize,
  );

  static int? _$yearOfBirth(CustomerProfile e) {
    return e.yearOfBirth;
  }

  static Gender? _$gender(CustomerProfile e) {
    return e.gender;
  }

  static String? _$shoppingStyle(CustomerProfile e) {
    return e.shoppingStyle;
  }

  static String? _$shoeSize(CustomerProfile e) {
    return e.shoeSize;
  }
}

extension CustomerProfileCompareE on CustomerProfile {
  Map<String, dynamic> compareToCustomerProfile(CustomerProfile other) {
    final Map<String, dynamic> diff = {};

    if (yearOfBirth != other.yearOfBirth) {
      diff['yearOfBirth'] = () => other.yearOfBirth;
    }

    if (gender != other.gender) {
      diff['gender'] = () => other.gender;
    }

    if (shoppingStyle != other.shoppingStyle) {
      diff['shoppingStyle'] = () => other.shoppingStyle;
    }

    if (shoeSize != other.shoeSize) {
      diff['shoeSize'] = () => other.shoeSize;
    }
    return diff;
  }
}
