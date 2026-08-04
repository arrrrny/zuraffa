import 'package:zuraffa/zuraffa.dart';

import '../repository/todo_repository.dart';
import 'get_todos_usecase_contract.dart';

/// Default implementation of [GetTodosUseCase].
///
/// Delegates to [TodoRepository.getAll] and wraps the
/// result in a [SignalResult].
class DefaultGetTodosUseCase extends GetTodosUseCase {
  final TodoRepository _repository;

  DefaultGetTodosUseCase(this._repository, {super.interceptorRegistry});

  @override
  SignalResult<List<Todo>> executeCall(
    void params, {
    ZuraffaContext? context,
  }) {
    final todos = _repository.getAll();
    return SignalResult.success(todos);
  }
}
