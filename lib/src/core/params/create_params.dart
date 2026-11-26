import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';

part '../../../_br_/src/core/params/create_params.part.dart';


/// Parameters for creating a new entity of type [T].
///
/// The type parameter [T] represents the entity type being created.
@ZorphyValue()
abstract class $CreateParams<T> implements $$Params {
  const $CreateParams();

  /// The entity data to create.
  T get data;
}
