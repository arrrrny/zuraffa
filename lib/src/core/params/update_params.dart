import 'package:zorphy/zorphy.dart';

import 'params.dart';

part 'update_params.zorphy.dart';

part 'update_params.g.dart';

/// Parameters for updating an entity.
///
/// The type parameter [I] represents the ID type (e.g., `String`, `int`).
/// The type parameter [P] represents the patch type (`Zorphy Patch` or `Map<String, dynamic>`).
///
/// Example: `UpdateParams<int, TodoPatch>(id: 123, data: patch)`
///
/// This allows strongly-typed IDs and patch data instead of using `dynamic`.
@Zorphy(generateJson: true, generateFilter: true)
abstract class $UpdateParams<I, P> implements $Params {
  const $UpdateParams();

  /// The ID of the entity to update (strongly typed).
  I get id;

  /// The patch data to apply (Zorphy Patch or Partial map).
  P get data;
}
