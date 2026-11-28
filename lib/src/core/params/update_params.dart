import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';

part 'update_params.zorphy.dart';

/// Parameters for updating an entity.
///
/// The type parameter [I] represents the ID type (e.g., `String`, `int`).
/// The type parameter [P] represents the patch type (`Zorphy Patch` or `Map<String, dynamic>`).
///
/// Example: `UpdateParams<int, TodoPatch>(id: 123, data: patch)`
///
/// This allows strongly-typed IDs and patch data instead of using `dynamic`.
@ZorphyValue()
@Deprecated(
  'Replaced in v8 by ZfaQuery<T> and concrete @ZorphyIntent classes in ZFA-008/ZFA-017',
)
abstract class $UpdateParams<I, P> implements Params {
  const $UpdateParams();

  /// The ID of the entity to update (strongly typed).
  I get id;

  /// The patch data to apply (Zorphy Patch or Partial map).
  P get data;

  /// Optional additional parameters (inherited from the params base in v2;
  /// declared explicitly under v3, whose codegen does not merge base fields).
  @override
  Map<String, dynamic>? get params;
}

/// Serialize an [UpdateParams] to a wire map; [toI] encodes the id, [toP] the patch.
///
/// Hand-written rather than the generated `toWire` — see [createParamsToWire].
Map<String, dynamic> updateParamsToWire<I, P>(
  UpdateParams<I, P> params, {
  required Object? Function(I value) toI,
  required Object? Function(P value) toP,
}) => {'params': params.params, 'id': toI(params.id), 'data': toP(params.data)};

/// Decode an [UpdateParams] from a wire map.
UpdateParams<I, P> updateParamsFromWire<I, P>(
  Map<String, dynamic> raw,
  I Function(Object? json) fromI,
  P Function(Object? json) fromP,
) => UpdateParams<I, P>.fromTrusted(
  params: raw['params'] as Map<String, dynamic>?,
  id: fromI(raw['id']),
  data: fromP(raw['data']),
);
