// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Customer _$CustomerFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Customer', json, ($checkedConvert) {
      final val = Customer(
        id: $checkedConvert('id', (v) => v as String),
        userId: $checkedConvert('userId', (v) => v as String),
        firstName: $checkedConvert('firstName', (v) => v as String?),
        lastName: $checkedConvert('lastName', (v) => v as String?),
        email: $checkedConvert('email', (v) => v as String?),
        profile: $checkedConvert(
          'profile',
          (v) => v == null
              ? null
              : CustomerProfile.fromJson(v as Map<String, dynamic>),
        ),
        device: $checkedConvert(
          'device',
          (v) => v == null ? null : Device.fromJson(v as Map<String, dynamic>),
        ),
        addresses: $checkedConvert(
          'addresses',
          (v) => (v as List<dynamic>?)
              ?.map((e) => CustomerAddress.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        defaultAddressId: $checkedConvert(
          'defaultAddressId',
          (v) => v as String?,
        ),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        locale: $checkedConvert(
          'locale',
          (v) => v == null ? null : Locale.fromJson(v as Map<String, dynamic>),
        ),
        isAnonymousAuth: $checkedConvert('isAnonymousAuth', (v) => v as bool?),
        latitude: $checkedConvert('latitude', (v) => (v as num?)?.toDouble()),
        longitude: $checkedConvert('longitude', (v) => (v as num?)?.toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$CustomerToJson(Customer instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'firstName': ?instance.firstName,
  'lastName': ?instance.lastName,
  'email': ?instance.email,
  'profile': ?instance.profile?.toJson(),
  'device': ?instance.device?.toJson(),
  'addresses': ?instance.addresses?.map((e) => e.toJson()).toList(),
  'defaultAddressId': ?instance.defaultAddressId,
  'createdAt': ?instance.createdAt?.toIso8601String(),
  'updatedAt': ?instance.updatedAt?.toIso8601String(),
  'locale': ?instance.locale?.toJson(),
  'isAnonymousAuth': ?instance.isAnonymousAuth,
  'latitude': ?instance.latitude,
  'longitude': ?instance.longitude,
};
