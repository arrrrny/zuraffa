import 'package:zorphy_annotation/zorphy_annotation.dart';

import 'params.dart';

part '../../../_br_/src/core/params/delete_params.part.dart';


/// Parameters for deleting an entity of type [I].
///
/// The type parameter [I] represents the ID type being deleted.
@ZorphyValue()
abstract class $DeleteParams<I> implements $$Params {
  const $DeleteParams();

  /// The ID of the entity to delete (strongly typed).
  I get id;
}
