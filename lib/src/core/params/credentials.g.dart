// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credentials.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Credentials _$CredentialsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Credentials', json, ($checkedConvert) {
      final val = Credentials(
        params: $checkedConvert('params', (v) => v as Map<String, dynamic>?),
      );
      return val;
    });

Map<String, dynamic> _$CredentialsToJson(Credentials instance) =>
    <String, dynamic>{'params': ?instance.params};
