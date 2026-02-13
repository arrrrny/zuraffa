// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_params.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeleteParams<I> _$DeleteParamsFromJson<I>(
  Map<String, dynamic> json,
  I Function(Object? json) fromJsonI,
) => DeleteParams<I>(
  params: json['params'] as Map<String, dynamic>?,
  id: fromJsonI(json['id']),
);

Map<String, dynamic> _$DeleteParamsToJson<I>(
  DeleteParams<I> instance,
  Object? Function(I value) toJsonI,
) => <String, dynamic>{'params': instance.params, 'id': toJsonI(instance.id)};
