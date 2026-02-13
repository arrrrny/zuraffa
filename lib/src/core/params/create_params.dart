import 'package:zorphy/zorphy.dart';
import 'params.dart';

part 'create_params.zorphy.dart';
part 'create_params.g.dart';

/// Parameters for creating a new entity of type [T].
///
/// The type parameter [T] represents the entity type being created.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $CreateParams<T> implements $Params {
  const $CreateParams();

  /// The entity data to create.
  T get data;
}
