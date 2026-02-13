import 'package:zorphy/zorphy.dart';
import 'params.dart';

part 'delete_params.zorphy.dart';
part 'delete_params.g.dart';

/// Parameters for creating a new entity of type [T].
///
/// The type parameter [T] represents the entity type being created.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $DeleteParams<I> {
  const $DeleteParams();

  /// The ID of the entity to delete (strongly typed).
  I get id;

  /// Optional additional parameters for the deletion.
  $Params? get params;
}
