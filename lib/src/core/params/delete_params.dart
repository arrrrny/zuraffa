import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';

part '../../../_br_/src/core/params/delete_params.part.dart';

/// Parameters for deleting an entity of type [I].
///
/// The type parameter [I] represents the ID type being deleted.
@ZorphyValue()
@Deprecated(
  'Replaced in v8 by ZfaQuery<T> and concrete @ZorphyIntent classes in ZFA-008/ZFA-017',
)
abstract class $DeleteParams<I extends Object> implements $$Params {
  const $DeleteParams();

  /// The ID of the entity to delete (strongly typed).
  I get id;

  /// Optional additional parameters (inherited from the params base in v2;
  /// declared explicitly under v3, whose codegen does not merge base fields).
  @override
  Map<String, dynamic>? get params;
}

/// Trust-boundary wire codec for [DeleteParams] (v3 generic value types get no
/// generated codec).
extension DeleteParamsWireCodec<I extends Object> on DeleteParams<I> {
  /// Serialize to a wire map; [toI] encodes the id.
  Map<String, dynamic> toWire(Object? Function(I value) toI) => {
    'params': params,
    'id': toI(id),
  };
}

/// Decode a [DeleteParams] from a wire map.
DeleteParams<I> deleteParamsFromWire<I extends Object>(
  Map<String, dynamic> raw,
  I Function(Object? json) fromI,
) {
  return DeleteParams<I>.fromTrusted(
    params: raw['params'] as Map<String, dynamic>?,
    id: fromI(raw['id']),
  );
}
