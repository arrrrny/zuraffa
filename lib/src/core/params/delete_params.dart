import 'package:zorphy/zorphy.dart';
import 'params.dart';

part 'delete_params.zorphy.dart';
part 'delete_params.g.dart';

/// Parameters for deleting an entity of type [I].
///
/// The type parameter [I] represents the ID type being deleted.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $DeleteParams<I> implements $Params {
  const $DeleteParams();

  /// The ID of the entity to delete (strongly typed).
  I get id;
}
