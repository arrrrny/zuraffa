import 'package:zuraffa/zuraffa.dart';

import '../repository/todo_repository.dart';
import '../state/todo_state.dart';

/// Type alias for a todo item represented as a map.
typedef Todo = Map<String, dynamic>;

/// Abstract contract for fetching todos.
///
/// Core and plugin code depend on this contract.
/// The default implementation is [DefaultGetTodosUseCase].
/// A plugin can provide an alternative implementation
/// and register it with `override: true`.
abstract class GetTodosUseCase
    extends InterceptableUseCase<void, List<Todo>> {
  const GetTodosUseCase({super.interceptorRegistry});
}
