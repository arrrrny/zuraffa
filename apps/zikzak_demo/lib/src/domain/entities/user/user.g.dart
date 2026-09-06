// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) =>
    $checkedCreate('User', json, ($checkedConvert) {
      final val = User(
        id: $checkedConvert('id', (v) => v as String),
        email: $checkedConvert('email', (v) => v as String?),
        displayName: $checkedConvert('displayName', (v) => v as String?),
        photoUrl: $checkedConvert('photoUrl', (v) => v as String?),
        firstName: $checkedConvert('firstName', (v) => v as String?),
        lastName: $checkedConvert('lastName', (v) => v as String?),
        phoneNumber: $checkedConvert('phoneNumber', (v) => v as String?),
        isAnonymous: $checkedConvert('isAnonymous', (v) => v as bool?),
        isVerified: $checkedConvert('isVerified', (v) => v as bool?),
        verifiedAt: $checkedConvert(
          'verifiedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        lastLogin: $checkedConvert(
          'lastLogin',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        registeredAt: $checkedConvert(
          'registeredAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id': instance.id,
  'email': ?instance.email,
  'displayName': ?instance.displayName,
  'photoUrl': ?instance.photoUrl,
  'firstName': ?instance.firstName,
  'lastName': ?instance.lastName,
  'phoneNumber': ?instance.phoneNumber,
  'isAnonymous': ?instance.isAnonymous,
  'isVerified': ?instance.isVerified,
  'verifiedAt': ?instance.verifiedAt?.toIso8601String(),
  'lastLogin': ?instance.lastLogin?.toIso8601String(),
  'registeredAt': ?instance.registeredAt?.toIso8601String(),
};
