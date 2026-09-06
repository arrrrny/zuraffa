// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authentication.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Authentication _$AuthenticationFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Authentication', json, ($checkedConvert) {
      final val = Authentication(
        id: $checkedConvert('id', (v) => v as String),
        userId: $checkedConvert('userId', (v) => v as String),
        method: $checkedConvert(
          'method',
          (v) => $enumDecode(_$AuthenticationMethodEnumMap, v),
        ),
        accessToken: $checkedConvert('accessToken', (v) => v as String?),
        refreshToken: $checkedConvert('refreshToken', (v) => v as String?),
        expiresAt: $checkedConvert(
          'expiresAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AuthenticationToJson(Authentication instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'method': _$AuthenticationMethodEnumMap[instance.method]!,
      'accessToken': ?instance.accessToken,
      'refreshToken': ?instance.refreshToken,
      'expiresAt': ?instance.expiresAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$AuthenticationMethodEnumMap = {
  AuthenticationMethod.email: 'email',
  AuthenticationMethod.google: 'google',
  AuthenticationMethod.apple: 'apple',
  AuthenticationMethod.anonymous: 'anonymous',
};
