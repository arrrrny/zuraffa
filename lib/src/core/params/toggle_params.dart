import 'package:zorphy/zorphy.dart';

import 'params.dart';

part 'toggle_params.zorphy.dart';

part 'toggle_params.g.dart';

/// Parameters for toggling a boolean field of an entity.
///
/// The type parameter [I] represents the ID type (e.g., `String`, `int`).
/// The type parameter [F] represents the field enum type.
///
/// Example: `ToggleParams<int, TodoField>(id: 123, field: TodoField.completed, value: true)`
@Zorphy(generateJson: true, generateFilter: true)
abstract class $ToggleParams<I, F> implements $Params {
  const $ToggleParams();

  /// The ID of the entity to update (strongly typed).
  I get id;

  /// The field to toggle.
  F get field;

  /// The target value for the field.
  bool get value;
}
