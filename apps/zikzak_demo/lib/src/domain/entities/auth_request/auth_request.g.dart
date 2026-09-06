// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthRequest _$AuthRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AuthRequest', json, ($checkedConvert) {
      final val = AuthRequest(
        email: $checkedConvert('email', (v) => v as String),
        password: $checkedConvert('password', (v) => v as String?),
        method: $checkedConvert(
          'method',
          (v) => $enumDecode(_$AuthenticationMethodEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AuthRequestToJson(AuthRequest instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': ?instance.password,
      'method': _$AuthenticationMethodEnumMap[instance.method]!,
    };

const _$AuthenticationMethodEnumMap = {
  AuthenticationMethod.email: 'email',
  AuthenticationMethod.google: 'google',
  AuthenticationMethod.apple: 'apple',
  AuthenticationMethod.anonymous: 'anonymous',
};
