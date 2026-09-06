// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_address.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomerAddress _$CustomerAddressFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CustomerAddress', json, ($checkedConvert) {
      final val = CustomerAddress(
        id: $checkedConvert('id', (v) => v as String),
        customerId: $checkedConvert('customerId', (v) => v as String),
        firstName: $checkedConvert('firstName', (v) => v as String?),
        lastName: $checkedConvert('lastName', (v) => v as String?),
        company: $checkedConvert('company', (v) => v as String?),
        addressLine1: $checkedConvert('addressLine1', (v) => v as String),
        addressLine2: $checkedConvert('addressLine2', (v) => v as String?),
        apartmentSuite: $checkedConvert('apartmentSuite', (v) => v as String?),
        city: $checkedConvert('city', (v) => v as String),
        state: $checkedConvert('state', (v) => v as String),
        postalCode: $checkedConvert('postalCode', (v) => v as String),
        country: $checkedConvert('country', (v) => v as String),
        isDefault: $checkedConvert('isDefault', (v) => v as bool),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CustomerAddressToJson(CustomerAddress instance) =>
    <String, dynamic>{
      'id': instance.id,
      'customerId': instance.customerId,
      'firstName': ?instance.firstName,
      'lastName': ?instance.lastName,
      'company': ?instance.company,
      'addressLine1': instance.addressLine1,
      'addressLine2': ?instance.addressLine2,
      'apartmentSuite': ?instance.apartmentSuite,
      'city': instance.city,
      'state': instance.state,
      'postalCode': instance.postalCode,
      'country': instance.country,
      'isDefault': instance.isDefault,
      'createdAt': ?instance.createdAt?.toIso8601String(),
      'updatedAt': ?instance.updatedAt?.toIso8601String(),
    };
