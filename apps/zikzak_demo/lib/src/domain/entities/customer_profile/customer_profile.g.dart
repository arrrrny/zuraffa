// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomerProfile _$CustomerProfileFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CustomerProfile', json, ($checkedConvert) {
      final val = CustomerProfile(
        yearOfBirth: $checkedConvert(
          'yearOfBirth',
          (v) => (v as num?)?.toInt(),
        ),
        gender: $checkedConvert(
          'gender',
          (v) => $enumDecodeNullable(_$GenderEnumMap, v),
        ),
        shoppingStyle: $checkedConvert('shoppingStyle', (v) => v as String?),
        shoeSize: $checkedConvert('shoeSize', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$CustomerProfileToJson(CustomerProfile instance) =>
    <String, dynamic>{
      'yearOfBirth': ?instance.yearOfBirth,
      'gender': ?_$GenderEnumMap[instance.gender],
      'shoppingStyle': ?instance.shoppingStyle,
      'shoeSize': ?instance.shoeSize,
    };

const _$GenderEnumMap = {Gender.man: 'man', Gender.woman: 'woman'};
