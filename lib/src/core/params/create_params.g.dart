// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateParams<T> _$CreateParamsFromJson<T>(
  Map<String, dynamic> json,
  T Function(Object? json) fromJsonT,
) => $checkedCreate('CreateParams', json, ($checkedConvert) {
  final val = CreateParams<T>(
    params: $checkedConvert('params', (v) => v as Map<String, dynamic>?),
    data: $checkedConvert('data', (v) => fromJsonT(v)),
  );
  return val;
});

Map<String, dynamic> _$CreateParamsToJson<T>(
  CreateParams<T> instance,
  Object? Function(T value) toJsonT,
) => <String, dynamic>{
  'params': ?instance.params,
  'data': toJsonT(instance.data),
};
