// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteParams<I> _$DeleteParamsFromJson<I>(
  Map<String, dynamic> json,
  I Function(Object? json) fromJsonI,
) => $checkedCreate('DeleteParams', json, ($checkedConvert) {
  final val = DeleteParams<I>(
    params: $checkedConvert('params', (v) => v as Map<String, dynamic>?),
    id: $checkedConvert('id', (v) => fromJsonI(v)),
  );
  return val;
});

Map<String, dynamic> _$DeleteParamsToJson<I>(
  DeleteParams<I> instance,
  Object? Function(I value) toJsonI,
) => <String, dynamic>{'params': ?instance.params, 'id': toJsonI(instance.id)};
