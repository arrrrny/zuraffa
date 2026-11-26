import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';

part '../../../_br_/src/core/params/create_params.part.dart';

/// Parameters for creating a new entity of type [T].
///
/// The type parameter [T] represents the entity type being created.
@ZorphyValue()
@Deprecated(
  'Replaced in v8 by ZfaQuery<T> and concrete @ZorphyIntent classes in ZFA-008/ZFA-017',
)
abstract class $CreateParams<T> implements $$Params {
  const $CreateParams();

  /// The entity data to create.
  T get data;

  /// Optional additional parameters (inherited from the params base in v2;
  /// declared explicitly under v3, whose codegen does not merge base fields).
  @override
  Map<String, dynamic>? get params;
}

/// Trust-boundary wire codec for [CreateParams] (v3 generic value types get no
/// generated codec).
extension CreateParamsWireCodec<T> on CreateParams<T> {
  /// Serialize to a wire map; [toElement] encodes the `T` payload.
  Map<String, dynamic> toWire([Object? Function(T value)? toElement]) => {
    'params': params,
    'data': toElement == null ? data : toElement(data),
  };
}

/// Decode a [CreateParams] from a wire map.
CreateParams<T> createParamsFromWire<T>(
  Map<String, dynamic> raw,
  T Function(Object? json) fromElement,
) {
  return CreateParams<T>.fromTrusted(
    params: raw['params'] as Map<String, dynamic>?,
    data: fromElement(raw['data']),
  );
}
